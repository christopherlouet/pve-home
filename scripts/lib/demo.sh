#!/bin/bash
# =============================================================================
# Script de demonstration de la bibliotheque common.sh
# =============================================================================
# Usage: ./scripts/lib/demo.sh [--dry-run] [--force]
#
# Demonstration des fonctionnalites de common.sh
# =============================================================================

set -euo pipefail

# Source la bibliotheque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# Fonctions de demonstration
# =============================================================================

demo_logging() {
    log_info "=== Demonstration des fonctions de logging ==="
    log_info "Ceci est un message d'information"
    log_success "Ceci est un message de succes"
    log_warn "Ceci est un avertissement"
    log_error "Ceci est une erreur (mais le script continue)"
    echo
}

demo_confirmation() {
    log_info "=== Demonstration de la confirmation ==="
    if confirm "Voulez-vous continuer la demonstration ?"; then
        log_success "Vous avez accepte"
    else
        log_warn "Vous avez refuse"
    fi
    echo
}

demo_check_prereqs() {
    log_info "=== Verification des prerequis ==="

    log_info "Verification de 'bash'..."
    if check_command "bash"; then
        log_success "bash est disponible"
    else
        log_error "bash n'est pas disponible"
    fi

    log_info "Verification de tous les prerequis..."
    if check_prereqs; then
        log_success "Tous les prerequis sont presents"
    else
        log_warn "Certains prerequis sont manquants (normal si terraform/mc/jq ne sont pas installes)"
    fi
    echo
}

demo_dry_run() {
    log_info "=== Demonstration du mode dry-run ==="

    log_info "Execution d'une commande avec dry_run..."
    dry_run echo 'Cette commande est executee'

    log_info "Execution d'une commande echo directe..."
    dry_run echo "Test direct"
    echo
}

demo_backup_point() {
    log_info "=== Demonstration de create_backup_point ==="

    local backup_file
    backup_file=$(create_backup_point "demo-component" "/tmp/demo-backups")

    if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
        log_success "Point de sauvegarde cree: ${backup_file}"
        log_info "Contenu:"
        cat "$backup_file"
    fi
    echo
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Parser les arguments communs
    parse_common_args "$@"

    echo
    log_info "============================================="
    log_info " Demonstration de la bibliotheque common.sh"
    log_info "============================================="
    echo
    log_info "Mode DRY_RUN: ${DRY_RUN}"
    log_info "Mode FORCE: ${FORCE_MODE}"
    echo

    demo_logging

    if [[ "$FORCE_MODE" != true ]]; then
        demo_confirmation
    fi

    demo_check_prereqs
    demo_dry_run
    demo_backup_point

    log_success "Demonstration terminee !"
}

main "$@"
