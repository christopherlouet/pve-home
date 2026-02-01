#!/bin/bash
# =============================================================================
# Script de reconstruction de la stack monitoring
# =============================================================================
# Usage: ./rebuild-monitoring.sh [options]
#
# Reconstruit la VM monitoring et ses services (Prometheus, Grafana, Alertmanager).
# Deux modes:
# - restore (defaut): restaure depuis le dernier backup vzdump
# - rebuild: reconstruit depuis zero via Terraform (historique metriques perdu)
#
# Options:
#   --mode MODE            Mode de reconstruction (restore|rebuild, defaut: restore)
#   --node NODE            Noeud Proxmox cible (pour mode restore)
#   --vmid VMID            VMID de la VM monitoring (pour mode restore)
#   --dry-run              Afficher les actions sans les executer
#   --force                Mode non-interactif (pas de confirmation)
#   -h, --help             Afficher cette aide
#
# Exemples:
#   ./rebuild-monitoring.sh --dry-run              # Simuler restauration depuis backup
#   ./rebuild-monitoring.sh --mode rebuild         # Reconstruction complete via Terraform
#   ./rebuild-monitoring.sh --vmid 9001 --force    # Restauration VM 9001 sans confirmation
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
readonly DEFAULT_PROMETHEUS_PORT=9090
readonly DEFAULT_GRAFANA_PORT=3000
readonly DEFAULT_ALERTMANAGER_PORT=9093
readonly SSH_WAIT_TIME=30

# Variables
MODE="restore"
NODE=""
VMID=""
MONITORING_IP=""
TERRAFORM_DIR=""
START_TIME=$(date +%s)

# =============================================================================
# Fonctions de parsing et aide
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: rebuild-monitoring.sh [options]

Reconstruit la VM monitoring et ses services.

Options:
  --mode MODE            Mode de reconstruction (restore|rebuild, defaut: restore)
  --node NODE            Noeud Proxmox cible (pour mode restore)
  --vmid VMID            VMID de la VM monitoring (pour mode restore)
  --dry-run              Afficher les actions sans les executer
  --force                Mode non-interactif (pas de confirmation)
  -h, --help             Afficher cette aide

Modes:
  restore                Restaurer depuis le dernier backup vzdump (defaut)
  rebuild                Reconstruire depuis zero via Terraform (historique metriques perdu)

Exemples:
  ./rebuild-monitoring.sh --dry-run
  ./rebuild-monitoring.sh --mode rebuild
  ./rebuild-monitoring.sh --vmid 9001 --force

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
            --mode)
                MODE="${2:?--mode necessite une valeur}"
                if [[ "$MODE" != "restore" ]] && [[ "$MODE" != "rebuild" ]]; then
                    log_error "Mode invalide: ${MODE}. Attendu: restore ou rebuild"
                    exit 1
                fi
                shift 2
                ;;
            --node)
                NODE="${2:?--node necessite une valeur}"
                shift 2
                ;;
            --vmid)
                VMID="${2:?--vmid necessite une valeur}"
                if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
                    log_error "VMID invalide: doit etre un nombre"
                    exit 1
                fi
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
# Fonctions metier (T018, T020)
# =============================================================================

detect_terraform_dir() {
    # Detecter le repertoire Terraform de l'environnement monitoring
    local base_dir="${SCRIPT_DIR}/../../infrastructure/proxmox/environments"
    TERRAFORM_DIR="${base_dir}/monitoring"

    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Repertoire Terraform introuvable: ${TERRAFORM_DIR}"
        exit 1
    fi

    log_info "Repertoire Terraform: ${TERRAFORM_DIR}"
}

parse_monitoring_config() {
    local tfvars_file="${TERRAFORM_DIR}/terraform.tfvars"

    if [[ ! -f "$tfvars_file" ]]; then
        log_error "Fichier terraform.tfvars introuvable: ${tfvars_file}"
        exit 1
    fi

    # Parser la config monitoring depuis terraform.tfvars
    # Format attendu: monitoring = { vm = { ip = "192.168.1.51", ... }, ... }
    MONITORING_IP=$(grep -A 10 "^monitoring\\s*=" "$tfvars_file" | grep "ip\\s*=" | sed -E 's/.*ip\s*=\s*"([^"]+)".*/\1/' | head -1)

    if [[ -z "$MONITORING_IP" ]]; then
        log_error "Impossible de detecter l'IP monitoring depuis ${tfvars_file}"
        exit 1
    fi

    # Si NODE non specifie, detecter depuis tfvars
    if [[ -z "$NODE" ]]; then
        NODE=$(grep "^default_node\\s*=" "$tfvars_file" | sed -E 's/.*=\s*"([^"]+)".*/\1/' | head -1)
        if [[ -z "$NODE" ]]; then
            log_error "Impossible de detecter le noeud depuis ${tfvars_file}"
            exit 1
        fi
    fi

    log_info "Configuration monitoring: ${MONITORING_IP} sur node ${NODE}"
}

restore_vm_monitoring() {
    log_info "Mode: restore - Appel de restore-vm.sh..."

    local restore_script="${SCRIPT_DIR}/restore-vm.sh"

    if [[ ! -f "$restore_script" ]]; then
        log_error "Script restore-vm.sh introuvable: ${restore_script}"
        exit 1
    fi

    # Construire les arguments
    local args=()

    if [[ -n "$VMID" ]]; then
        args+=("$VMID")
    else
        log_error "VMID requis pour mode restore"
        log_error "Specifiez --vmid <id> ou utilisez --mode rebuild"
        exit 1
    fi

    if [[ -n "$NODE" ]]; then
        args+=("--node" "$NODE")
    fi

    if [[ "$DRY_RUN" == true ]]; then
        args+=("--dry-run")
    fi

    if [[ "$FORCE_MODE" == true ]]; then
        args+=("--force")
    fi

    log_info "Execution: ${restore_script} ${args[*]}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] restore-vm.sh ${args[*]}"
        return 0
    fi

    if ! bash "$restore_script" "${args[@]}"; then
        log_error "Echec de la restauration VM monitoring"
        exit 1
    fi

    log_success "Restauration VM monitoring terminee"
}

rebuild_vm_monitoring() {
    log_warn "Mode: rebuild - L'historique metriques sera perdu !"

    if ! confirm "Confirmer reconstruction complete (historique Prometheus perdu) ?"; then
        log_error "Reconstruction annulee par l'utilisateur"
        exit 1
    fi

    log_info "Reconstruction de la VM monitoring via Terraform..."

    cd "$TERRAFORM_DIR" || exit 1

    local tf_cmd="terraform apply -target=module.monitoring_stack -auto-approve"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ${tf_cmd}"
        return 0
    fi

    log_info "Execution: ${tf_cmd}"
    if ! terraform apply -target=module.monitoring_stack -auto-approve; then
        log_error "Echec de la reconstruction monitoring"
        exit 1
    fi

    log_success "VM monitoring reconstruite"
}

verify_docker_services() {
    log_info "Verification services Docker sur ${MONITORING_IP}..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh root@${MONITORING_IP} docker ps"
        return 0
    fi

    # Attendre que SSH soit accessible
    log_info "Attente SSH (${SSH_WAIT_TIME}s)..."
    sleep $SSH_WAIT_TIME

    # Verifier docker ps
    log_info "Verification conteneurs Docker (docker ps)..."
    local docker_ps
    docker_ps=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "root@${MONITORING_IP}" "docker ps --format '{{.Names}}'" 2>/dev/null || echo "")

    if [[ -z "$docker_ps" ]]; then
        log_warn "Impossible de lister les conteneurs Docker"
        return 1
    fi

    # Verifier que prometheus, grafana, alertmanager sont up
    local services=("prometheus" "grafana" "alertmanager")
    for service in "${services[@]}"; do
        if echo "$docker_ps" | grep -q "$service"; then
            log_success "Service ${service}: up"
        else
            log_warn "Service ${service}: absent ou down"
        fi
    done
}

verify_prometheus() {
    log_info "Verification healthcheck Prometheus..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] curl http://${MONITORING_IP}:${DEFAULT_PROMETHEUS_PORT}/-/healthy"
        return 0
    fi

    if curl -sf --max-time 10 "http://${MONITORING_IP}:${DEFAULT_PROMETHEUS_PORT}/-/healthy" &>/dev/null; then
        log_success "Prometheus: healthy"
    else
        log_warn "Prometheus: healthcheck echoue"
    fi
}

verify_grafana() {
    log_info "Verification healthcheck Grafana..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] curl http://${MONITORING_IP}:${DEFAULT_GRAFANA_PORT}/api/health"
        return 0
    fi

    if curl -sf --max-time 10 "http://${MONITORING_IP}:${DEFAULT_GRAFANA_PORT}/api/health" &>/dev/null; then
        log_success "Grafana: healthy"
    else
        log_warn "Grafana: healthcheck echoue"
    fi
}

verify_alertmanager() {
    log_info "Verification healthcheck Alertmanager..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] curl http://${MONITORING_IP}:${DEFAULT_ALERTMANAGER_PORT}/-/healthy"
        return 0
    fi

    if curl -sf --max-time 10 "http://${MONITORING_IP}:${DEFAULT_ALERTMANAGER_PORT}/-/healthy" &>/dev/null; then
        log_success "Alertmanager: healthy"
    else
        log_warn "Alertmanager: healthcheck echoue"
    fi
}

show_summary() {
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    echo ""
    log_info "============================================="
    log_info " RESUME DE RECONSTRUCTION - Monitoring"
    log_info "============================================="
    echo ""
    echo "  Mode:               ${MODE}"
    echo "  IP Monitoring:      ${MONITORING_IP}"
    echo "  Node:               ${NODE}"
    if [[ -n "$VMID" ]]; then
        echo "  VMID:               ${VMID}"
    fi
    echo "  Terraform dir:      ${TERRAFORM_DIR}"
    echo "  Duree:              ${duration}s"
    echo "  Mode dry-run:       ${DRY_RUN}"
    echo ""
    log_info "Statut services:"
    echo "  Prometheus:         Voir logs ci-dessus"
    echo "  Grafana:            Voir logs ci-dessus"
    echo "  Alertmanager:       Voir logs ci-dessus"
    echo ""
    log_success "Reconstruction monitoring reussie !"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    log_info "============================================="
    log_info " Reconstruction stack monitoring"
    log_info "============================================="
    echo ""

    # Parsing arguments
    parse_args "$@"

    log_info "Mode: ${MODE}"

    # Afficher mode dry-run si active
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Mode DRY-RUN active: aucune action ne sera executee"
    fi

    # Verification des prerequis
    local missing=()
    for cmd in "ssh" "curl"; do
        if ! check_command "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ "$MODE" == "rebuild" ]]; then
        if ! check_command "terraform"; then
            missing+=("terraform")
        fi
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Outils manquants: ${missing[*]}"
        log_error "Installez les prerequis avant de continuer"
        exit 1
    fi

    # Detection repertoire Terraform
    detect_terraform_dir

    # Parser configuration monitoring
    parse_monitoring_config

    # Resume pre-execution et confirmation (EF-002)
    echo ""
    log_info "=== RESUME ==="
    echo "  Mode:               ${MODE}"
    echo "  IP Monitoring:      ${MONITORING_IP}"
    echo "  Node:               ${NODE}"
    if [[ -n "$VMID" ]]; then
        echo "  VMID:               ${VMID}"
    fi
    echo ""
    log_info "Actions prevues:"
    if [[ "$MODE" == "restore" ]]; then
        echo "  1. Appeler restore-vm.sh pour restaurer la VM monitoring"
        echo "  2. Verifier services Docker (prometheus, grafana, alertmanager)"
        echo "  3. Verifier healthchecks HTTP"
    else
        echo "  1. Reconstruire VM monitoring via Terraform"
        echo "  2. Verifier services Docker (prometheus, grafana, alertmanager)"
        echo "  3. Verifier healthchecks HTTP"
        echo ""
        log_warn "ATTENTION: L'historique des metriques Prometheus sera perdu"
    fi
    echo ""

    if ! confirm "Continuer avec la reconstruction ?"; then
        log_error "Reconstruction annulee par l'utilisateur"
        exit 1
    fi

    # Reconstruction selon le mode
    if [[ "$MODE" == "restore" ]]; then
        restore_vm_monitoring
    else
        rebuild_vm_monitoring
    fi

    # Verifications
    verify_docker_services || true
    verify_prometheus || true
    verify_grafana || true
    verify_alertmanager || true

    # Resume
    show_summary
}

main "$@"
