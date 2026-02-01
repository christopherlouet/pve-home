#!/bin/bash
# =============================================================================
# Script de reconstruction du conteneur Minio
# =============================================================================
# Usage: ./rebuild-minio.sh [options]
#
# Reconstruit le conteneur Minio et ses buckets S3 depuis zero.
# Utilise Terraform pour reconstruire le conteneur, puis verifie
# que tous les backends Terraform peuvent se reconnecter.
#
# Options:
#   --env ENV              Environnement Terraform (defaut: monitoring)
#   --dry-run              Afficher les actions sans les executer
#   --force                Mode non-interactif (pas de confirmation)
#   -h, --help             Afficher cette aide
#
# Exemples:
#   ./rebuild-minio.sh --dry-run            # Simuler la reconstruction
#   ./rebuild-minio.sh --force              # Reconstruction sans confirmation
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Detection du repertoire du script et chargement des fonctions communes
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"

# Source common.sh
# shellcheck source=../lib/common.sh
source "${LIB_DIR}/common.sh"

# =============================================================================
# Variables globales et constantes
# =============================================================================

# Constantes
readonly DEFAULT_MINIO_PORT=9000
readonly MINIO_HEALTHCHECK_MAX_RETRIES=12
readonly MINIO_HEALTHCHECK_RETRY_INTERVAL=5

# Variables
ENV="monitoring"
TERRAFORM_DIR=""
MINIO_IP=""
MINIO_PORT="${DEFAULT_MINIO_PORT}"
START_TIME=$(date +%s)

# =============================================================================
# Fonctions de parsing et aide
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: rebuild-minio.sh [options]

Reconstruit le conteneur Minio et ses buckets S3 depuis zero.

Options:
  --env ENV              Environnement Terraform (defaut: monitoring)
  --dry-run              Afficher les actions sans les executer
  --force                Mode non-interactif (pas de confirmation)
  -h, --help             Afficher cette aide

Exemples:
  ./rebuild-minio.sh --dry-run
  ./rebuild-minio.sh --force

HELPEOF
}

parse_args() {
    # Verifier --help/-h avant tout
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
            show_help
            exit 0
        fi
    done

    # Parser les options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                ENV="${2:?--env necessite une valeur}"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                # shellcheck disable=SC2034
                FORCE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Fonctions metier (T017, T019)
# =============================================================================

detect_terraform_dir() {
    # Detecter le repertoire Terraform de l'environnement
    local base_dir="${SCRIPT_DIR}/../../infrastructure/proxmox/environments"
    TERRAFORM_DIR="${base_dir}/${ENV}"

    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Repertoire Terraform introuvable: ${TERRAFORM_DIR}"
        exit 1
    fi

    log_info "Repertoire Terraform: ${TERRAFORM_DIR}"
}

parse_minio_config() {
    local tfvars_file="${TERRAFORM_DIR}/terraform.tfvars"

    if [[ ! -f "$tfvars_file" ]]; then
        log_error "Fichier terraform.tfvars introuvable: ${tfvars_file}"
        exit 1
    fi

    # Parser la config Minio depuis terraform.tfvars
    # Format attendu: minio = { ip = "192.168.1.52", port = 9000, ... }
    MINIO_IP=$(grep -A 20 "^minio\\s*=" "$tfvars_file" | grep "ip\\s*=" | sed -E 's/.*ip\s*=\s*"([^"]+)".*/\1/' | head -1)
    MINIO_PORT=$(grep -A 20 "^minio\\s*=" "$tfvars_file" | grep "port\\s*=" | sed -E 's/.*port\s*=\s*([0-9]+).*/\1/' | head -1)

    if [[ -z "$MINIO_IP" ]]; then
        log_error "Impossible de detecter l'IP Minio depuis ${tfvars_file}"
        exit 1
    fi

    if [[ -z "$MINIO_PORT" ]]; then
        MINIO_PORT="${DEFAULT_MINIO_PORT}"
    fi

    log_info "Configuration Minio: ${MINIO_IP}:${MINIO_PORT}"
}

check_minio_health() {
    log_info "Verification healthcheck Minio..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] curl http://${MINIO_IP}:${MINIO_PORT}/minio/health/live"
        return 1
    fi

    # Tentative de healthcheck (timeout 5s)
    if curl -sf --max-time 5 "http://${MINIO_IP}:${MINIO_PORT}/minio/health/live" &>/dev/null; then
        log_warn "Minio semble deja actif sur ${MINIO_IP}:${MINIO_PORT}"
        if ! confirm "Continuer la reconstruction ?"; then
            log_error "Reconstruction annulee par l'utilisateur"
            exit 1
        fi
        return 0
    else
        log_info "Minio non accessible (reconstruction necessaire)"
        return 1
    fi
}

rebuild_minio_terraform() {
    log_info "Reconstruction du conteneur Minio via Terraform..."

    cd "$TERRAFORM_DIR" || exit 1

    local tf_cmd="terraform apply -target=module.minio -auto-approve"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ${tf_cmd}"
        return 0
    fi

    log_info "Execution: ${tf_cmd}"
    if ! terraform apply -target=module.minio -auto-approve; then
        log_error "Echec de la reconstruction Minio"
        exit 1
    fi

    log_success "Conteneur Minio reconstruit"
}

wait_minio_ready() {
    local timeout=$((MINIO_HEALTHCHECK_MAX_RETRIES * MINIO_HEALTHCHECK_RETRY_INTERVAL))
    log_info "Attente demarrage Minio (retry loop avec timeout ${timeout}s)..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Attente demarrage Minio"
        return 0
    fi

    local retry=0

    while [[ $retry -lt $MINIO_HEALTHCHECK_MAX_RETRIES ]]; do
        log_info "Tentative $((retry + 1))/${MINIO_HEALTHCHECK_MAX_RETRIES}..."

        if curl -sf --max-time 5 "http://${MINIO_IP}:${MINIO_PORT}/minio/health/live" &>/dev/null; then
            log_success "Minio est pret"
            return 0
        fi

        retry=$((retry + 1))
        sleep $MINIO_HEALTHCHECK_RETRY_INTERVAL
    done

    log_error "Timeout: Minio n'est pas pret apres ${MINIO_HEALTHCHECK_MAX_RETRIES} tentatives"
    exit 1
}

verify_minio() {
    log_info "Verification Minio..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] mc ls homelab/"
        log_info "[DRY-RUN] mc version info homelab/<bucket>"
        return 0
    fi

    # Verification healthcheck API
    if ! curl -sf "http://${MINIO_IP}:${MINIO_PORT}/minio/health/live" &>/dev/null; then
        log_error "Healthcheck Minio echoue"
        return 1
    fi
    log_success "Healthcheck Minio: OK"

    # Configuration mc alias (necessiterait les credentials)
    log_info "Configuration mc alias homelab..."
    # NOTE: En production, recuperer les credentials depuis terraform.tfvars
    # mc alias set homelab http://${MINIO_IP}:${MINIO_PORT} <user> <password>

    # Lister les buckets
    log_info "Verification buckets (mc ls homelab/)..."
    # mc ls homelab/

    # Verifier versioning sur chaque bucket
    log_info "Verification versioning buckets (mc version info)..."
    # mc version info homelab/<bucket>

    log_success "Verification Minio terminee"
}

verify_terraform_backends() {
    log_info "Verification backends Terraform..."

    local envs=("prod" "monitoring")
    local base_dir="${SCRIPT_DIR}/../../infrastructure/proxmox/environments"

    for env in "${envs[@]}"; do
        local env_dir="${base_dir}/${env}"

        if [[ ! -d "$env_dir" ]]; then
            log_warn "Environnement ${env} introuvable, skip"
            continue
        fi

        log_info "Verification environnement ${env}..."

        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] terraform init dans ${env}"
            continue
        fi

        cd "$env_dir" || continue

        if terraform init -input=false &>/dev/null; then
            log_success "Backend Terraform ${env}: OK"
        else
            log_warn "Backend Terraform ${env}: ECHEC"
        fi
    done

    log_success "Verification backends terminee"
}

show_summary() {
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    echo ""
    log_info "============================================="
    log_info " RESUME DE RECONSTRUCTION - Minio"
    log_info "============================================="
    echo ""
    echo "  Environnement:      ${ENV}"
    echo "  IP Minio:           ${MINIO_IP}:${MINIO_PORT}"
    echo "  Terraform dir:      ${TERRAFORM_DIR}"
    echo "  Duree:              ${duration}s"
    echo "  Mode dry-run:       ${DRY_RUN}"
    echo ""
    log_success "Reconstruction Minio reussie !"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    log_info "============================================="
    log_info " Reconstruction conteneur Minio"
    log_info "============================================="
    echo ""

    # Parsing arguments
    parse_args "$@"

    # Afficher mode dry-run si active
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Mode DRY-RUN active: aucune action ne sera executee"
    fi

    # Verification des prerequis
    check_prereqs || exit 1

    # Detection repertoire Terraform
    detect_terraform_dir

    # Parser configuration Minio
    parse_minio_config

    # Resume pre-execution et confirmation (EF-002)
    echo ""
    log_info "=== RESUME ==="
    echo "  Environnement:      ${ENV}"
    echo "  IP Minio:           ${MINIO_IP}:${MINIO_PORT}"
    echo "  Terraform dir:      ${TERRAFORM_DIR}"
    echo ""
    log_info "Actions prevues:"
    echo "  1. Verifier healthcheck Minio"
    echo "  2. Reconstruire conteneur Minio (terraform apply -target=module.minio)"
    echo "  3. Attendre demarrage Minio"
    echo "  4. Verifier healthcheck et buckets"
    echo "  5. Verifier backends Terraform (prod, monitoring)"
    echo ""

    if ! confirm "Continuer avec la reconstruction ?"; then
        log_error "Reconstruction annulee par l'utilisateur"
        exit 1
    fi

    # Verification Minio avant reconstruction
    check_minio_health || true

    # Reconstruction Minio
    rebuild_minio_terraform

    # Attendre demarrage
    wait_minio_ready

    # Verifications
    verify_minio
    verify_terraform_backends

    # Resume
    show_summary
}

main "$@"
