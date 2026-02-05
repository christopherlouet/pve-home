#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Point d'entree principal
# =============================================================================
# Usage: ./scripts/tui/tui.sh [OPTIONS] [COMMAND]
#
# Interface TUI pour gerer l'infrastructure Proxmox VE homelab.
# Permet de gerer les VMs, snapshots, Terraform, deploiements, et plus.
#
# Options:
#   -h, --help          Afficher cette aide
#   -v, --version       Afficher la version
#   -e, --env ENV       Specifier l'environnement (prod, lab, monitoring)
#   -n, --no-color      Desactiver les couleurs
#   -d, --dry-run       Mode simulation (pas de modifications)
#   --no-gum            Forcer le mode sans gum (fallback bash)
#   --source-only       Charger les modules sans lancer le TUI
#
# Commandes directes:
#   status              Afficher le statut de l'infrastructure
#   terraform [action]  Executer une action Terraform
#   deploy              Deployer sur monitoring
#   drift               Verifier le drift
#
# Raccourcis clavier:
#   q         Quitter
#   ?         Aide
#   j/k       Navigation haut/bas
#   1-9       Selection rapide
#   /         Recherche
#
# Exemples:
#   ./tui.sh                    # Lancer le TUI interactif
#   ./tui.sh --env prod         # Lancer avec environnement prod
#   ./tui.sh status             # Afficher le statut directement
#   ./tui.sh terraform plan     # Executer terraform plan
#
# =============================================================================

set -o errexit
set -o nounset
set -o pipefail

# =============================================================================
# Variables globales
# =============================================================================

# Repertoire du script
TUI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUI_LIB_DIR="${TUI_SCRIPT_DIR}/lib"
TUI_MENUS_DIR="${TUI_SCRIPT_DIR}/menus"

# Options par defaut
TUI_DRY_RUN="${TUI_DRY_RUN:-false}"
TUI_NO_COLOR="${TUI_NO_COLOR:-false}"
TUI_USE_GUM="${TUI_USE_GUM:-true}"
TUI_ENVIRONMENT="${TUI_ENVIRONMENT:-}"
TUI_SOURCE_ONLY="${TUI_SOURCE_ONLY:-false}"

# =============================================================================
# Fonctions utilitaires
# =============================================================================

# Affiche l'aide
show_help() {
    cat << 'EOF'
TUI Homelab Manager - Interface de gestion Proxmox VE

Usage: tui.sh [OPTIONS] [COMMAND]

Options:
  -h, --help          Afficher cette aide
  -v, --version       Afficher la version
  -e, --env ENV       Specifier l'environnement (prod, lab, monitoring)
  -n, --no-color      Desactiver les couleurs
  -d, --dry-run       Mode simulation (pas de modifications)
  --no-gum            Forcer le mode sans gum (fallback bash)
  --source-only       Charger les modules sans lancer le TUI

Commandes directes:
  status              Afficher le statut de l'infrastructure
  terraform [action]  Executer une action Terraform (plan, apply, etc.)
  deploy              Deployer sur monitoring
  drift               Verifier le drift Terraform
  services            Gerer les services
  config              Configurer le TUI

Raccourcis clavier (mode interactif):
  q         Quitter / Retour
  ?         Afficher l'aide
  j/k       Navigation bas/haut (vim-style)
  h/l       Navigation gauche/droite
  1-9       Selection rapide des options
  /         Recherche / Filtre
  r         Rafraichir

Exemples:
  ./tui.sh                      # Lancer le TUI interactif
  ./tui.sh --env prod           # Specifier l'environnement prod
  ./tui.sh --no-color           # Mode sans couleurs
  ./tui.sh status               # Afficher le statut directement
  ./tui.sh terraform plan       # Executer terraform plan

Documentation: https://github.com/user/pve-home/docs/TUI.md
EOF
}

# Affiche la version
show_version() {
    # Charger la config pour avoir la version
    if [[ -f "${TUI_LIB_DIR}/tui-config.sh" ]]; then
        source "${TUI_LIB_DIR}/tui-config.sh"
    fi
    echo "TUI Homelab Manager v${TUI_VERSION:-1.0.0}"
}

# Verifie les prerequis
check_prerequisites() {
    local missing=()

    # Verifier bash 4+
    if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
        echo "Erreur: Bash 4+ requis (version actuelle: ${BASH_VERSION})" >&2
        exit 1
    fi

    # Verifier les commandes requises
    for cmd in ssh terraform; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    # Verifier gum (optionnel)
    if [[ "$TUI_USE_GUM" == "true" ]] && ! command -v gum &>/dev/null; then
        TUI_USE_GUM="false"
        echo "Info: gum non installe, utilisation du mode fallback bash" >&2
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Attention: Commandes manquantes (certaines fonctions seront limitees): ${missing[*]}" >&2
    fi

    return 0
}

# Retourne les dependances manquantes
get_missing_dependencies() {
    local missing=()

    for cmd in ssh terraform jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "${missing[*]}"
    fi
}

# =============================================================================
# Chargement des modules
# =============================================================================

# Charge tous les modules
load_all_modules() {
    # Charger les libs dans l'ordre
    source "${TUI_LIB_DIR}/tui-colors.sh"
    source "${TUI_LIB_DIR}/tui-config.sh"
    source "${TUI_LIB_DIR}/tui-common.sh"
    source "${TUI_LIB_DIR}/tui-keyboard.sh"

    # Charger le menu principal (qui charge les sous-menus)
    source "${TUI_MENUS_DIR}/main.sh"

    # Appliquer les options
    if [[ "$TUI_NO_COLOR" == "true" ]]; then
        TUI_COLOR_SUCCESS=""
        TUI_COLOR_ERROR=""
        TUI_COLOR_WARNING=""
        TUI_COLOR_INFO=""
        TUI_COLOR_MUTED=""
        TUI_COLOR_NC=""
    fi

    if [[ -n "$TUI_ENVIRONMENT" ]]; then
        TUI_CONTEXT="$TUI_ENVIRONMENT"
    fi

    export TUI_DRY_RUN
    export TUI_USE_GUM
}

# =============================================================================
# Gestionnaires d'evenements
# =============================================================================

# Gestionnaire de sortie propre
on_exit() {
    local exit_code=$?

    # Nettoyer le module clavier si charge
    if declare -f cleanup_keyboard &>/dev/null; then
        cleanup_keyboard
    fi

    # Restaurer le terminal
    tput cnorm 2>/dev/null || true  # Afficher le curseur

    exit $exit_code
}

# Gestionnaire Ctrl+C
on_interrupt() {
    echo ""
    echo "Interruption (Ctrl+C) - Fermeture du TUI..."
    exit 130
}

# Configurer les traps
trap on_exit EXIT
trap on_interrupt INT TERM

# =============================================================================
# Commandes directes
# =============================================================================

# Execute une commande directe (mode non-interactif)
run_direct_command() {
    local cmd="$1"
    shift

    load_all_modules

    case "$cmd" in
        "status")
            if declare -f show_health_summary &>/dev/null; then
                show_health_summary
            else
                echo "Commande status non disponible"
                return 1
            fi
            ;;
        "terraform")
            if declare -f run_terraform_command &>/dev/null; then
                run_terraform_command "$@"
            else
                echo "Commande terraform non disponible"
                return 1
            fi
            ;;
        "deploy")
            if declare -f run_deploy &>/dev/null; then
                run_deploy "$@"
            else
                echo "Commande deploy non disponible"
                return 1
            fi
            ;;
        "drift")
            if declare -f run_drift_check &>/dev/null; then
                run_drift_check "$@"
            else
                echo "Commande drift non disponible"
                return 1
            fi
            ;;
        "services")
            if declare -f list_services &>/dev/null; then
                list_services
            else
                echo "Commande services non disponible"
                return 1
            fi
            ;;
        "config")
            if declare -f show_current_config &>/dev/null; then
                show_current_config
            else
                echo "Commande config non disponible"
                return 1
            fi
            ;;
        *)
            echo "Commande inconnue: $cmd"
            echo "Utilisez --help pour voir les commandes disponibles"
            return 1
            ;;
    esac
}

# =============================================================================
# Parsing des arguments
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -e|--env)
                TUI_ENVIRONMENT="$2"
                shift 2
                ;;
            -n|--no-color)
                TUI_NO_COLOR="true"
                shift
                ;;
            -d|--dry-run)
                TUI_DRY_RUN="true"
                shift
                ;;
            --no-gum)
                TUI_USE_GUM="false"
                shift
                ;;
            --source-only)
                TUI_SOURCE_ONLY="true"
                shift
                ;;
            -*)
                echo "Option inconnue: $1" >&2
                show_help
                exit 1
                ;;
            *)
                # Commande directe
                run_direct_command "$@"
                exit $?
                ;;
        esac
    done
}

# =============================================================================
# Point d'entree principal
# =============================================================================

main() {
    # Parser les arguments
    parse_arguments "$@"

    # Verifier les prerequis
    check_prerequisites

    # Mode source-only (pour les tests)
    if [[ "$TUI_SOURCE_ONLY" == "true" ]]; then
        load_all_modules
        return 0
    fi

    # Verifier si on est en mode interactif
    if [[ ! -t 0 ]]; then
        echo "Erreur: Le TUI requiert un terminal interactif" >&2
        echo "Utilisez les commandes directes pour le mode non-interactif" >&2
        exit 1
    fi

    # Charger les modules
    load_all_modules

    # Initialiser le module clavier
    if declare -f init_keyboard &>/dev/null; then
        init_keyboard
    fi

    # Lancer le menu principal
    menu_main
}

# Lancer si execute directement (pas source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
