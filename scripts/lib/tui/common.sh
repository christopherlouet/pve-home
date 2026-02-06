#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Fonctions communes et wrappers gum
# =============================================================================
# Usage: source scripts/lib/tui/common.sh
#
# Fournit des wrappers pour gum avec fallback si gum n'est pas installe :
# - tui_menu : Menu de selection
# - tui_confirm : Confirmation oui/non
# - tui_input : Saisie de texte
# - tui_spin : Spinner pendant execution
# - tui_table : Affichage tableau
# - tui_banner : Banniere/titre
# =============================================================================

# Note: pas de set -euo pipefail ici, ce fichier est source par d'autres scripts

# Charger les dependances si pas deja fait
SCRIPT_DIR_TUI_COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${TUI_COLOR_PRIMARY:-}" ]]; then
    source "${SCRIPT_DIR_TUI_COMMON}/colors.sh"
fi

if [[ -z "${TUI_CONTEXT:-}" ]]; then
    source "${SCRIPT_DIR_TUI_COMMON}/config.sh"
fi

# =============================================================================
# Detection de gum
# =============================================================================

# Cache pour eviter de verifier plusieurs fois
TUI_GUM_AVAILABLE=""

# Verifie si gum est installe
tui_check_gum() {
    if [[ -z "$TUI_GUM_AVAILABLE" ]]; then
        if command -v gum &>/dev/null; then
            TUI_GUM_AVAILABLE="true"
        else
            TUI_GUM_AVAILABLE="false"
        fi
    fi
    [[ "$TUI_GUM_AVAILABLE" == "true" ]]
}

# =============================================================================
# Fonctions de logging
# =============================================================================

tui_log_info() {
    echo -e "${TUI_COLOR_INFO}${TUI_ICON_INFO}${TUI_COLOR_NC} $1"
}

tui_log_success() {
    echo -e "${TUI_COLOR_SUCCESS}${TUI_ICON_SUCCESS}${TUI_COLOR_NC} $1"
}

tui_log_warn() {
    echo -e "${TUI_COLOR_WARNING}${TUI_ICON_WARNING}${TUI_COLOR_NC} $1"
}

tui_log_error() {
    echo -e "${TUI_COLOR_ERROR}${TUI_ICON_ERROR}${TUI_COLOR_NC} $1"
}

# =============================================================================
# Wrapper tui_menu - Menu de selection
# =============================================================================
# Usage: tui_menu "Titre" "Option 1" "Option 2" "Option 3"
# Retourne: L'option selectionnee sur stdout

tui_menu() {
    local title="$1"
    shift
    local options=("$@")

    if tui_check_gum; then
        gum choose --header "$title" \
            --height 10 \
            --cursor "> " \
            --cursor.foreground 212 \
            --item.foreground 255 \
            --selected.foreground 212 \
            --header.foreground 87 \
            "${options[@]}"
    else
        # Fallback sans gum : select bash
        echo -e "${TUI_COLOR_TITLE}${title}${TUI_COLOR_NC}" >&2
        PS3="Choix: "
        select opt in "${options[@]}"; do
            if [[ -n "$opt" ]]; then
                echo "$opt"
                break
            fi
        done
    fi
}

# =============================================================================
# Wrapper tui_confirm - Confirmation oui/non
# =============================================================================
# Usage: tui_confirm "Question?"
# Retourne: 0 si oui, 1 si non

tui_confirm() {
    local message="$1"
    local default="${2:-false}"  # false = default non

    # Mode force : toujours oui
    if [[ "${TUI_FORCE_MODE:-false}" == "true" ]]; then
        tui_log_info "$message [auto: oui]"
        return 0
    fi

    if tui_check_gum; then
        if [[ "$default" == "true" ]]; then
            gum confirm --default=yes \
                --prompt.foreground "${GUM_COLOR_PRIMARY}" \
                --selected.foreground "${GUM_COLOR_SELECTED}" \
                "$message"
        else
            gum confirm \
                --prompt.foreground "${GUM_COLOR_PRIMARY}" \
                --selected.foreground "${GUM_COLOR_SELECTED}" \
                "$message"
        fi
    else
        # Fallback sans gum
        local response
        echo -en "${TUI_COLOR_PRIMARY}${message}${TUI_COLOR_NC} [o/N] "
        read -r response
        case "$response" in
            [oOyY]|[oO][uU][iI]|[yY][eE][sS]) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# =============================================================================
# Wrapper tui_input - Saisie de texte
# =============================================================================
# Usage: tui_input "Placeholder" "Valeur par defaut"
# Retourne: Le texte saisi

tui_input() {
    local placeholder="${1:-Entrez une valeur}"
    local default="${2:-}"
    local header="${3:-}"

    if tui_check_gum; then
        local args=(--placeholder "$placeholder")
        [[ -n "$default" ]] && args+=(--value "$default")
        [[ -n "$header" ]] && args+=(--header "$header" --header.foreground "${GUM_COLOR_PRIMARY}")
        args+=(--cursor.foreground "${GUM_COLOR_CURSOR}")

        gum input "${args[@]}"
    else
        # Fallback sans gum
        local response
        [[ -n "$header" ]] && echo -e "${TUI_COLOR_PRIMARY}${header}${TUI_COLOR_NC}" >&2
        echo -en "${TUI_COLOR_MUTED}${placeholder}${TUI_COLOR_NC} "
        [[ -n "$default" ]] && echo -en "[${default}] "
        read -r response
        echo "${response:-$default}"
    fi
}

# =============================================================================
# Wrapper tui_spin - Spinner pendant execution
# =============================================================================
# Usage: tui_spin "Message" commande args...
# Retourne: Le code de sortie de la commande

tui_spin() {
    local title="$1"
    shift
    local cmd=("$@")

    if tui_check_gum; then
        gum spin --spinner dot \
            --title "$title" \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- "${cmd[@]}"
    else
        # Fallback sans gum : afficher le message et executer
        echo -e "${TUI_COLOR_INFO}${TUI_ICON_SPINNER} ${title}...${TUI_COLOR_NC}"
        "${cmd[@]}"
        local status=$?
        if [[ $status -eq 0 ]]; then
            echo -e "${TUI_COLOR_SUCCESS}${TUI_ICON_SUCCESS} ${title} - termine${TUI_COLOR_NC}"
        else
            echo -e "${TUI_COLOR_ERROR}${TUI_ICON_ERROR} ${title} - echec${TUI_COLOR_NC}"
        fi
        return $status
    fi
}

# =============================================================================
# Wrapper tui_table - Affichage tableau
# =============================================================================
# Usage: echo "Col1,Col2\nVal1,Val2" | tui_table
# Ou: tui_table < fichier.csv

tui_table() {
    local separator="${1:-,}"

    if tui_check_gum; then
        gum table --separator "$separator" \
            --border.foreground "${GUM_COLOR_BORDER}"
    else
        # Fallback sans gum : column
        if command -v column &>/dev/null; then
            column -t -s "$separator"
        else
            cat  # Dernier recours
        fi
    fi
}

# =============================================================================
# Wrapper tui_banner - Banniere/titre
# =============================================================================
# Usage: tui_banner "Titre principal"

tui_banner() {
    local text="$1"
    # shellcheck disable=SC2034
    local style="${2:-bold}"  # bold, rounded, double, etc.

    if tui_check_gum; then
        gum style \
            --foreground "${GUM_COLOR_PRIMARY}" \
            --border "rounded" \
            --border-foreground "${GUM_COLOR_BORDER}" \
            --padding "0 2" \
            --margin "0" \
            --bold \
            "$text"
    else
        # Fallback sans gum
        local len=${#text}
        local border
        border=$(printf '═%.0s' $(seq 1 $((len + 4))))
        echo -e "${TUI_COLOR_PRIMARY}"
        echo "╔${border}╗"
        echo "║  ${text}  ║"
        echo "╚${border}╝"
        echo -en "${TUI_COLOR_NC}"
    fi
}

# =============================================================================
# Wrapper tui_filter - Filtrage fuzzy
# =============================================================================
# Usage: echo -e "opt1\nopt2\nopt3" | tui_filter "Rechercher..."

tui_filter() {
    local placeholder="${1:-Rechercher...}"

    if tui_check_gum; then
        gum filter --placeholder "$placeholder" \
            --indicator.foreground "${GUM_COLOR_PRIMARY}" \
            --match.foreground "${GUM_COLOR_SUCCESS}"
    else
        # Fallback sans gum : fzf ou selection manuelle
        if command -v fzf &>/dev/null; then
            fzf --prompt="$placeholder "
        else
            # Selection manuelle
            local options=()
            while IFS= read -r line; do
                options+=("$line")
            done
            tui_menu "$placeholder" "${options[@]}"
        fi
    fi
}

# =============================================================================
# Fonctions utilitaires de navigation
# =============================================================================

# Option de retour standard
tui_back_option() {
    echo "← Retour"
}

# Option de quitter standard
tui_quit_option() {
    echo "✕ Quitter"
}

# Gestionnaire d'interruption (Ctrl+C)
tui_quit_handler() {
    echo ""
    tui_log_info "Interruption detectee. Au revoir!"
    exit 0
}

# Installer le gestionnaire de Ctrl+C
trap tui_quit_handler INT SIGINT

# =============================================================================
# Verification des prerequis TUI
# =============================================================================

# Verifie tous les prerequis pour le TUI
# Usage: tui_check_prereqs
# Retourne: 0 si OK, 1 si prerequis manquants
tui_check_prereqs() {
    local missing=()
    local warnings=()

    # gum est fortement recommande mais pas obligatoire
    if ! tui_check_gum; then
        warnings+=("gum (mode degrade actif)")
    fi

    # Outils obligatoires
    local required_cmds=("bash" "ssh" "jq")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    # Outils recommandes
    local recommended_cmds=("terraform" "mc")
    for cmd in "${recommended_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            warnings+=("$cmd (certaines fonctions indisponibles)")
        fi
    done

    # Afficher le resultat
    if [[ ${#missing[@]} -gt 0 ]]; then
        tui_log_error "Prerequis manquants: ${missing[*]}"
        return 1
    fi

    if [[ ${#warnings[@]} -gt 0 ]]; then
        for warn in "${warnings[@]}"; do
            tui_log_warn "Recommande: $warn"
        done
    fi

    tui_log_success "Prerequis verifies"
    return 0
}

# =============================================================================
# Export des fonctions
# =============================================================================

export -f tui_check_gum
export -f tui_log_info tui_log_success tui_log_warn tui_log_error
export -f tui_menu tui_confirm tui_input tui_spin tui_table tui_banner tui_filter
export -f tui_back_option tui_quit_option tui_quit_handler
export -f tui_check_prereqs
