#!/usr/bin/env bash
# =============================================================================
# TUI Homelab Manager - Point d'entree principal (T005)
# =============================================================================
# Usage: ./homelab-manager.sh [options]
#
# Interface textuelle unifiee pour la gestion du homelab Proxmox VE.
# Permet de gerer health checks, snapshots, Terraform, services, etc.
#
# Prerequis:
#   - gum (recommande, mode degrade sans)
#   - bash 4.0+
#   - ssh, jq
#
# Documentation: scripts/tui/README.md
# =============================================================================

set -euo pipefail

# =============================================================================
# Variables globales
# =============================================================================

# Repertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les bibliotheques TUI
source "${SCRIPT_DIR}/lib/tui-colors.sh"
source "${SCRIPT_DIR}/lib/tui-config.sh"
source "${SCRIPT_DIR}/lib/tui-common.sh"

# =============================================================================
# Fonctions d'aide et version
# =============================================================================

show_version() {
    echo "homelab-manager version ${TUI_VERSION}"
}

show_help() {
    cat << 'EOF'
Usage: homelab-manager.sh [options]

TUI Homelab Manager - Interface textuelle pour gerer le homelab Proxmox VE.

Options:
  -h, --help           Afficher cette aide
  -V, --version        Afficher la version
  --check-prereqs      Verifier les prerequis
  --show-context       Afficher le contexte d'execution (local/remote)
  --non-interactive    Mode non-interactif (pour scripts)
  --force              Mode force (pas de confirmations)
  --dry-run            Mode simulation (pas d'execution reelle)

Prerequis:
  - gum (recommande pour l'interface graphique, mode degrade sans)
  - bash 4.0+
  - ssh, jq (obligatoires)
  - terraform, mc (recommandes)

Exemples:
  homelab-manager.sh                  # Lancer le TUI interactif
  homelab-manager.sh --check-prereqs  # Verifier les prerequiss
  homelab-manager.sh --show-context   # Voir si local ou VM monitoring

Documentation: scripts/tui/README.md
EOF
}

show_context() {
    echo "Contexte: ${TUI_CONTEXT}"
    echo "Racine projet: ${TUI_PROJECT_ROOT}"
    echo "Scripts: ${TUI_SCRIPTS_DIR}"
    echo "Tfvars: ${TUI_TFVARS_DIR}"
}

# =============================================================================
# Parsing des arguments
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -V|--version)
                show_version
                exit 0
                ;;
            --check-prereqs)
                tui_check_prereqs
                exit $?
                ;;
            --show-context)
                show_context
                exit 0
                ;;
            --non-interactive)
                TUI_NON_INTERACTIVE=true
                export TUI_NON_INTERACTIVE
                shift
                ;;
            --force)
                TUI_FORCE_MODE=true
                export TUI_FORCE_MODE
                shift
                ;;
            --dry-run)
                TUI_DRY_RUN=true
                export TUI_DRY_RUN
                shift
                ;;
            -*)
                tui_log_error "Option inconnue: $1"
                echo "Utilisez --help pour voir les options disponibles."
                exit 1
                ;;
            *)
                tui_log_error "Argument inconnu: $1"
                echo "Utilisez --help pour voir les options disponibles."
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Point d'entree principal
# =============================================================================

main() {
    # Parser les arguments
    parse_args "$@"

    # Verifier les prerequis minimaux
    if ! command -v bash &>/dev/null; then
        echo "Erreur: bash est requis" >&2
        exit 1
    fi

    # Avertir si gum n'est pas disponible
    if ! tui_check_gum; then
        tui_log_warn "gum non installe - mode degrade actif"
        tui_log_info "Installez gum pour une meilleure experience: https://github.com/charmbracelet/gum"
        echo ""
    fi

    # Charger et lancer le menu principal
    source "${SCRIPT_DIR}/menus/main.sh"
    menu_main
}

# =============================================================================
# Execution
# =============================================================================

# Point d'entree
main "$@"
