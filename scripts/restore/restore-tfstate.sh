#!/bin/bash
# =============================================================================
# Script de restauration du state Terraform depuis Minio S3
# =============================================================================
# Usage: ./restore-tfstate.sh --env <ENV> [options]
#
# Ce script permet de:
# - Lister les versions disponibles du state Terraform
# - Restaurer une version precedente depuis Minio
# - Basculer vers un backend local (fallback) si Minio est indisponible
# - Retourner au backend Minio apres reparation
#
# Environnements supportes : prod, lab, monitoring
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration et imports
# =============================================================================

# Detecter le repertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common lib
# shellcheck source=scripts/lib/common.sh
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# =============================================================================
# Variables globales
# =============================================================================

ENV=""
MODE=""
VERSION_ID=""
MC_ALIAS="homelab"

# Repertoires
INFRASTRUCTURE_DIR="${PROJECT_ROOT}/infrastructure/proxmox/environments"

# =============================================================================
# Fonctions d'aide
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: restore-tfstate.sh --env <ENV> [options]

Script de restauration du state Terraform depuis Minio S3.

Options:
  --env <ENV>           Environnement (prod|lab|monitoring) - REQUIS
  --list                Lister les versions disponibles du state
  --restore <VERSION>   Restaurer une version specifique
  --fallback            Basculer vers le backend local (si Minio indisponible)
  --return              Retourner au backend Minio apres reparation
  --dry-run             Afficher les commandes sans les executer
  --force               Mode non-interactif (pas de confirmation)
  -h, --help            Afficher cette aide

Exemples:
  # Lister les versions du state prod
  ./restore-tfstate.sh --env prod --list

  # Restaurer une version specifique
  ./restore-tfstate.sh --env prod --restore version-id-abc123

  # Basculer vers backend local (fallback)
  ./restore-tfstate.sh --env prod --fallback

  # Retourner au backend Minio
  ./restore-tfstate.sh --env prod --return

Mode fallback:
  Si Minio est inaccessible, utilisez --fallback pour basculer temporairement
  vers un backend local. Une fois Minio retabli, utilisez --return pour migrer
  l'etat vers Minio.
HELPEOF
}

# =============================================================================
# Parsing des arguments (T013)
# =============================================================================

parse_args() {
    if [[ $# -eq 0 ]]; then
        log_error "Aucun argument fourni"
        show_help
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option --env requiert un argument"
                    exit 1
                fi
                ENV="$2"
                shift 2
                ;;
            --list)
                MODE="list"
                shift
                ;;
            --restore)
                MODE="restore"
                if [[ -z "${2:-}" ]]; then
                    log_error "version-id requis"
                    log_error "Usage: --restore <version-id>"
                    exit 1
                fi
                VERSION_ID="$2"
                shift 2
                ;;
            --fallback)
                MODE="fallback"
                shift
                ;;
            --return)
                MODE="return"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Verifier que --env est fourni
    if [[ -z "$ENV" ]]; then
        log_error "Option --env est requise"
        show_help
        exit 1
    fi

    # Valider l'environnement
    if [[ ! "$ENV" =~ ^(prod|lab|monitoring)$ ]]; then
        log_error "Environnement invalide: ${ENV}"
        log_error "Environnements valides: prod|lab|monitoring"
        exit 1
    fi

    # Verifier qu'un mode est choisi
    if [[ -z "$MODE" ]]; then
        log_error "Veuillez specifier une action: --list, --restore, --fallback, ou --return"
        show_help
        exit 1
    fi
}

# =============================================================================
# Configuration mc (T013)
# =============================================================================

configure_mc() {
    local env_dir="${INFRASTRUCTURE_DIR}/${ENV}"
    local tfvars_file="${env_dir}/terraform.tfvars"

    log_info "Configuration du client Minio (mc) pour l'environnement ${ENV}..."

    # Verifier que le fichier tfvars existe
    if [[ ! -f "$tfvars_file" ]]; then
        log_error "Fichier terraform.tfvars introuvable: ${tfvars_file}"
        return 1
    fi

    # Parser les valeurs Minio depuis le tfvars
    # Le format HCL est: minio = { ip = "...", root_user = "...", root_password = "...", port = ... }
    # On utilise grep + sed pour extraire les valeurs
    local minio_ip minio_user minio_password minio_port

    minio_ip=$(grep -A15 '^minio' "$tfvars_file" | grep -E '^\s*ip\s*=' | sed -E 's/.*ip\s*=\s*"([^"]+)".*/\1/' | xargs)
    minio_user=$(grep -A15 '^minio' "$tfvars_file" | grep -E '^\s*root_user\s*=' | sed -E 's/.*root_user\s*=\s*"([^"]+)".*/\1/' | xargs)
    minio_password=$(grep -A15 '^minio' "$tfvars_file" | grep -E '^\s*root_password\s*=' | sed -E 's/.*root_password\s*=\s*"([^"]+)".*/\1/' | xargs)
    minio_port=$(grep -A15 '^minio' "$tfvars_file" | grep -E '^\s*port\s*=' | sed -E 's/.*port\s*=\s*([0-9]+).*/\1/' | xargs)

    if [[ -z "$minio_ip" || -z "$minio_user" || -z "$minio_password" || -z "$minio_port" ]]; then
        log_error "Impossible de parser la configuration Minio depuis ${tfvars_file}"
        log_error "Verifiez que le bloc 'minio' est present avec ip, root_user, root_password, port"
        return 1
    fi

    local minio_endpoint="http://${minio_ip}:${minio_port}"

    log_info "Endpoint Minio: ${minio_endpoint}"

    # Configurer l'alias mc
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] mc alias set ${MC_ALIAS} ${minio_endpoint} ${minio_user} ****"
        return 0
    fi

    if ! mc alias set "${MC_ALIAS}" "${minio_endpoint}" "${minio_user}" "${minio_password}" &>/dev/null; then
        log_error "Impossible de configurer mc avec l'alias ${MC_ALIAS}"
        log_error "Verifiez que Minio est accessible a ${minio_endpoint}"
        return 1
    fi

    log_success "Client mc configure avec succes"
    return 0
}

# =============================================================================
# Mode liste (T013)
# =============================================================================

list_versions() {
    local bucket="tfstate-${ENV}"
    local object_path="${bucket}/terraform.tfstate"

    log_info "Liste des versions du state Terraform pour l'environnement ${ENV}..."
    log_info "Bucket: ${bucket}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] mc ls --versions ${MC_ALIAS}/${object_path}"
        return 0
    fi

    # Lister les versions
    local versions_output
    if ! versions_output=$(mc ls --versions "${MC_ALIAS}/${object_path}" 2>&1); then
        log_error "Impossible de lister les versions du state"
        log_error "Sortie mc: ${versions_output}"
        return 1
    fi

    echo ""
    echo "Versions disponibles:"
    echo "-------------------------------------------"
    echo "$versions_output"
    echo "-------------------------------------------"
    echo ""
    log_info "Pour restaurer une version: ./restore-tfstate.sh --env ${ENV} --restore <version-id>"

    return 0
}

# =============================================================================
# Mode restauration (T014)
# =============================================================================

restore_version() {
    local bucket="tfstate-${ENV}"
    local object_path="${bucket}/terraform.tfstate"
    local env_dir="${INFRASTRUCTURE_DIR}/${ENV}"
    local backup_file="${env_dir}/terraform.tfstate.backup"
    local restore_file="${env_dir}/terraform.tfstate.restore"

    log_info "Restauration de la version ${VERSION_ID} pour l'environnement ${ENV}..."

    # EF-006: Sauvegarder la version actuelle avant ecrasement
    log_info "Sauvegarde de la version actuelle..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] mc cp ${MC_ALIAS}/${object_path} ${backup_file}"
    else
        if ! mc cp "${MC_ALIAS}/${object_path}" "${backup_file}" &>/dev/null; then
            log_warn "Impossible de sauvegarder la version actuelle"
            log_warn "Continuation sans backup..."
        else
            log_success "Version actuelle sauvegardee: ${backup_file}"
        fi
    fi

    # Telecharger la version cible
    log_info "Telechargement de la version ${VERSION_ID}..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] mc cp --version-id ${VERSION_ID} ${MC_ALIAS}/${object_path} ${restore_file}"
    else
        if ! mc cp --version-id "${VERSION_ID}" "${MC_ALIAS}/${object_path}" "${restore_file}"; then
            log_error "Impossible de telecharger la version ${VERSION_ID}"
            return 1
        fi
        log_success "Version ${VERSION_ID} telechargee"
    fi

    # Uploader comme version courante
    log_info "Upload de la version restauree comme version courante..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] mc cp ${restore_file} ${MC_ALIAS}/${object_path}"
    else
        if ! mc cp "${restore_file}" "${MC_ALIAS}/${object_path}"; then
            log_error "Impossible d'uploader la version restauree"
            return 1
        fi
        log_success "Version restauree uploadee"
        rm -f "${restore_file}"
    fi

    # Executer terraform init -reconfigure
    log_info "Reinitialisation du backend Terraform..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] cd ${env_dir} && terraform init -reconfigure"
    else
        if ! (cd "${env_dir}" && terraform init -reconfigure &>/dev/null); then
            log_error "Echec de terraform init -reconfigure"
            return 1
        fi
        log_success "Backend Terraform reinitialise"
    fi

    # Executer terraform plan pour verification
    log_info "Verification avec terraform plan..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] cd ${env_dir} && terraform plan"
    else
        log_info "Execution de terraform plan (cela peut prendre quelques secondes)..."
        if ! (cd "${env_dir}" && terraform plan); then
            log_warn "terraform plan a detecte des changements ou erreurs"
            log_warn "Verifiez la sortie ci-dessus"
        fi
    fi

    log_success "Restauration terminee"
    log_info "Version restauree: ${VERSION_ID}"
    log_info "Backup disponible: ${backup_file}"

    return 0
}

# =============================================================================
# Mode fallback vers backend local (T015)
# =============================================================================

fallback_local() {
    local env_dir="${INFRASTRUCTURE_DIR}/${ENV}"
    local backend_file="${env_dir}/backend.tf"
    local backup_backend="${env_dir}/backend.tf.minio-backup"

    log_info "Basculement vers le backend local pour l'environnement ${ENV}..."

    # Verifier que backend.tf existe
    if [[ ! -f "$backend_file" ]]; then
        log_error "Fichier backend.tf introuvable: ${backend_file}"
        return 1
    fi

    # Sauvegarder backend.tf original
    log_info "Sauvegarde de backend.tf original..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] cp ${backend_file} ${backup_backend}"
    else
        cp "${backend_file}" "${backup_backend}"
        log_success "backend.tf sauvegarde: ${backup_backend}"
    fi

    # Remplacer le contenu par un backend local vide
    log_info "Remplacement du backend S3 par backend local..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Ecriture backend local dans ${backend_file}"
    else
        cat > "${backend_file}" << 'EOF'
# =============================================================================
# Backend local temporaire (Minio indisponible)
# =============================================================================
# Cree automatiquement par restore-tfstate.sh --fallback
# Pour retourner au backend Minio: ./restore-tfstate.sh --env <ENV> --return
# =============================================================================

terraform {
  # Backend local (state stocke dans terraform.tfstate local)
}
EOF
        log_success "Backend local ecrit dans ${backend_file}"
    fi

    # Executer terraform init -migrate-state
    log_info "Migration du state vers le backend local..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] cd ${env_dir} && terraform init -migrate-state"
    else
        log_info "Execution de terraform init -migrate-state (repondez 'yes' si demande)..."
        if ! (cd "${env_dir}" && terraform init -migrate-state); then
            log_error "Echec de la migration vers le backend local"
            log_error "Restauration de backend.tf original..."
            cp "${backup_backend}" "${backend_file}"
            return 1
        fi
        log_success "State migre vers le backend local"
    fi

    # Verification avec terraform plan
    log_info "Verification avec terraform plan..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] cd ${env_dir} && terraform plan"
    else
        if ! (cd "${env_dir}" && terraform plan &>/dev/null); then
            log_warn "terraform plan a detecte des changements ou erreurs"
        else
            log_success "terraform plan OK"
        fi
    fi

    log_success "Basculement vers backend local termine"
    log_info "Backend local actif. Utiliser --return quand Minio est retabli."
    log_info "Backup backend.tf: ${backup_backend}"

    return 0
}

# =============================================================================
# Mode retour vers Minio (T016)
# =============================================================================

return_to_minio() {
    local env_dir="${INFRASTRUCTURE_DIR}/${ENV}"
    local backend_file="${env_dir}/backend.tf"
    local backup_backend="${env_dir}/backend.tf.minio-backup"

    log_info "Retour au backend Minio pour l'environnement ${ENV}..."

    # Verifier que le backup existe
    if [[ ! -f "$backup_backend" ]]; then
        log_error "Backup backend.tf introuvable: ${backup_backend}"
        log_error "Impossible de restaurer le backend Minio"
        return 1
    fi

    # Verifier healthcheck Minio
    log_info "Verification de la disponibilite de Minio..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] curl healthcheck Minio"
    else
        # Parser l'IP et le port depuis le backup backend.tf
        local minio_endpoint
        minio_endpoint=$(grep -o 'http://[^"]*' "${backup_backend}" | head -1 || echo "")

        if [[ -z "$minio_endpoint" ]]; then
            log_error "Impossible de detecter l'endpoint Minio depuis ${backup_backend}"
            return 1
        fi

        log_info "Endpoint Minio: ${minio_endpoint}"

        if ! curl -sf "${minio_endpoint}/minio/health/live" &>/dev/null; then
            log_error "Minio n'est pas accessible a ${minio_endpoint}"
            log_error "Verifiez que le conteneur Minio est demarre"
            return 1
        fi
        log_success "Minio est accessible"
    fi

    # Restaurer backend.tf depuis le backup
    log_info "Restauration de backend.tf original..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] cp ${backup_backend} ${backend_file}"
    else
        cp "${backup_backend}" "${backend_file}"
        log_success "backend.tf restaure"
    fi

    # Executer terraform init -migrate-state
    log_info "Migration du state vers le backend Minio..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] cd ${env_dir} && terraform init -migrate-state"
    else
        log_info "Execution de terraform init -migrate-state (repondez 'yes' si demande)..."
        if ! (cd "${env_dir}" && terraform init -migrate-state); then
            log_error "Echec de la migration vers le backend Minio"
            log_error "Le backend local reste actif"
            return 1
        fi
        log_success "State migre vers le backend Minio"
    fi

    # Verification avec terraform plan
    log_info "Verification avec terraform plan..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] cd ${env_dir} && terraform plan"
    else
        if ! (cd "${env_dir}" && terraform plan &>/dev/null); then
            log_warn "terraform plan a detecte des changements ou erreurs"
        else
            log_success "terraform plan OK"
        fi
    fi

    # Supprimer le fichier backup
    if [[ "$DRY_RUN" == false ]]; then
        rm -f "${backup_backend}"
        log_success "Backup backend.tf supprime"
    fi

    log_success "Backend Minio S3 restaure avec succes."
    log_info "Le state Terraform est maintenant synchronise avec Minio"

    return 0
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Parser les arguments
    parse_args "$@"

    # Afficher l'environnement cible
    log_info "Environnement: ${ENV}"
    log_info "Mode: ${MODE}"

    # Executer l'action demandee
    case "$MODE" in
        list)
            configure_mc || exit 1
            list_versions || exit 1
            ;;
        restore)
            configure_mc || exit 1
            if ! confirm "Restaurer la version ${VERSION_ID} pour l'environnement ${ENV}?"; then
                log_info "Restauration annulee"
                exit 0
            fi
            restore_version || exit 1
            ;;
        fallback)
            if ! confirm "Basculer vers le backend local pour l'environnement ${ENV}?"; then
                log_info "Fallback annule"
                exit 0
            fi
            fallback_local || exit 1
            ;;
        return)
            if ! confirm "Retourner au backend Minio pour l'environnement ${ENV}?"; then
                log_info "Retour annule"
                exit 0
            fi
            configure_mc || exit 1
            return_to_minio || exit 1
            ;;
        *)
            log_error "Mode inconnu: ${MODE}"
            exit 1
            ;;
    esac

    log_success "Operation terminee avec succes"
    exit 0
}

# Lancer le script
main "$@"
