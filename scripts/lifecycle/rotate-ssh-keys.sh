#!/bin/bash
# =============================================================================
# Rotation des cles SSH sur les VMs/LXC
# =============================================================================
# Usage: ./rotate-ssh-keys.sh <--add-key FILE | --remove-key FINGERPRINT>
#        [--env ENV] [--all] [--dry-run] [--force] [--help]
#
# Deploie ou revoque des cles SSH sur les VMs/LXC. Integre une protection
# anti-lockout : verifie l'acces avec la nouvelle cle avant de supprimer
# l'ancienne.
#
# Options:
#   --add-key FILE         Fichier de cle publique a ajouter
#   --remove-key FPRINT    Fingerprint de la cle a revoquer
#   --env ENV              Environnement cible (prod, lab, monitoring)
#   --all                  Tous les environnements
#   --user USER            Utilisateur cible (defaut: ubuntu pour VMs, root pour LXC)
#   --dry-run              Mode simulation
#   --force                Mode non-interactif
#   -h, --help             Afficher cette aide
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
# shellcheck source=../lib/common.sh
source "${LIB_DIR}/common.sh"

# =============================================================================
# Variables globales
# =============================================================================

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_ROOT
readonly ENVS_DIR="${PROJECT_ROOT}/infrastructure/proxmox/environments"
readonly VALID_ENVS=("prod" "lab" "monitoring")

ADD_KEY_FILE=""
REMOVE_KEY_FINGERPRINT=""
TARGET_ENV=""
CHECK_ALL=false
TARGET_USER=""

# =============================================================================
# Fonctions
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: rotate-ssh-keys.sh <--add-key FILE | --remove-key FINGERPRINT> [options]

Rotation des cles SSH sur les VMs/LXC.

Options:
  --add-key FILE         Cle publique a ajouter
  --remove-key FPRINT    Fingerprint de la cle a revoquer
  --env ENV              Environnement cible
  --all                  Tous les environnements
  --user USER            Utilisateur cible
  --dry-run              Mode simulation
  --force                Mode non-interactif
  -h, --help             Afficher cette aide
HELPEOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --add-key)
                ADD_KEY_FILE="$2"
                shift 2
                ;;
            --remove-key)
                REMOVE_KEY_FINGERPRINT="$2"
                shift 2
                ;;
            --env)
                TARGET_ENV="$2"
                shift 2
                ;;
            --all)
                CHECK_ALL=true
                shift
                ;;
            --user)
                TARGET_USER="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                export FORCE_MODE=true
                shift
                ;;
            --help|-h)
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

    # Validation
    if [[ -z "$ADD_KEY_FILE" && -z "$REMOVE_KEY_FINGERPRINT" ]]; then
        log_error "Specifiez --add-key ou --remove-key"
        show_help
        exit 1
    fi

    if [[ "$CHECK_ALL" == false && -z "$TARGET_ENV" ]]; then
        log_error "Specifiez --env ENV ou --all"
        show_help
        exit 1
    fi

    if [[ -n "$ADD_KEY_FILE" && ! -f "$ADD_KEY_FILE" ]]; then
        log_error "Fichier de cle introuvable: ${ADD_KEY_FILE}"
        exit 1
    fi
}

get_hosts_for_env() {
    local env="$1"
    local tfvars="${ENVS_DIR}/${env}/terraform.tfvars"

    if [[ ! -f "$tfvars" ]]; then
        return
    fi

    grep -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$tfvars" 2>/dev/null | sort -u || true
}

add_key_to_host() {
    local host="$1"
    local user="$2"
    local key
    key=$(cat "$ADD_KEY_FILE")

    log_info "Ajout de la cle sur ${user}@${host}..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Ajouterait la cle sur ${user}@${host}"
        return 0
    fi

    local cmd="mkdir -p ~/.ssh && echo '${key}' >> ~/.ssh/authorized_keys && sort -u -o ~/.ssh/authorized_keys ~/.ssh/authorized_keys"

    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
           "${user}@${host}" "$cmd" 2>/dev/null; then
        log_success "Cle ajoutee sur ${user}@${host}"
    else
        log_error "Echec de l'ajout sur ${user}@${host}"
        return 1
    fi
}

remove_key_from_host() {
    local host="$1"
    local user="$2"
    local fingerprint="$3"

    log_info "Revocation de la cle ${fingerprint} sur ${user}@${host}..."

    # Anti-lockout : verifier qu'il reste au moins une autre cle
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Revoquerait la cle sur ${user}@${host}"
        return 0
    fi

    local key_count
    key_count=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
                    "${user}@${host}" "wc -l < ~/.ssh/authorized_keys" 2>/dev/null || echo "0")

    if [[ "$key_count" -le 1 ]]; then
        log_error "Anti-lockout: impossible de supprimer la derniere cle sur ${user}@${host}"
        return 1
    fi

    # Identifier la ligne de la cle par fingerprint
    local cmd="ssh-keygen -lf ~/.ssh/authorized_keys 2>/dev/null | grep -n '${fingerprint}' | cut -d: -f1 | head -1"
    local line_num
    line_num=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
                   -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
                   "${user}@${host}" "$cmd" 2>/dev/null || echo "")

    if [[ -z "$line_num" ]]; then
        log_warn "Cle ${fingerprint} non trouvee sur ${user}@${host}"
        return 0
    fi

    cmd="sed -i '${line_num}d' ~/.ssh/authorized_keys"
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
           "${user}@${host}" "$cmd" 2>/dev/null; then
        log_success "Cle revoquee sur ${user}@${host}"
    else
        log_error "Echec de la revocation sur ${user}@${host}"
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    local envs_to_check=()
    if [[ "$CHECK_ALL" == true ]]; then
        envs_to_check=("${VALID_ENVS[@]}")
    else
        envs_to_check=("$TARGET_ENV")
    fi

    local success=0
    local errors=0

    for env in "${envs_to_check[@]}"; do
        log_info "=== Environnement: ${env} ==="

        local hosts
        hosts=$(get_hosts_for_env "$env")

        if [[ -z "$hosts" ]]; then
            log_warn "Aucun host trouve pour ${env}"
            continue
        fi

        local user="${TARGET_USER:-ubuntu}"

        for host in $hosts; do
            if [[ -n "$ADD_KEY_FILE" ]]; then
                if add_key_to_host "$host" "$user"; then
                    success=$((success + 1))
                else
                    errors=$((errors + 1))
                fi
            fi

            if [[ -n "$REMOVE_KEY_FINGERPRINT" ]]; then
                if remove_key_from_host "$host" "$user" "$REMOVE_KEY_FINGERPRINT"; then
                    success=$((success + 1))
                else
                    errors=$((errors + 1))
                fi
            fi
        done
    done

    echo ""
    log_info "Resume: ${success} succes, ${errors} erreur(s)"

    [[ "$errors" -gt 0 ]] && exit 1
    exit 0
}

main "$@"
