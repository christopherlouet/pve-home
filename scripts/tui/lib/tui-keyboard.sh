#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Keyboard Navigation (T063-T070 - US9)
# =============================================================================
# Usage: source scripts/tui/lib/tui-keyboard.sh
#
# Gestion avancee de la navigation clavier : raccourcis, vim-like, recherche.
# =============================================================================

# =============================================================================
# Variables
# =============================================================================

# Raccourcis par defaut (initialises avec =() pour compatibilite set -o nounset)
declare -A TUI_KEYBINDINGS=()
declare -A TUI_VIM_KEYS=()
declare -a TUI_NAV_HISTORY=()

# Configuration
TUI_VIM_MODE="${TUI_VIM_MODE:-true}"
TUI_HISTORY_MAX="${TUI_HISTORY_MAX:-50}"

# Initialiser les raccourcis par defaut
_init_default_keybindings() {
    # Desactiver nounset pour les affectations de tableau associatif
    local _old_opts=""
    [[ -o nounset ]] && _old_opts="u" && set +u

    TUI_KEYBINDINGS[quit]="q"
    TUI_KEYBINDINGS[back]="b"
    TUI_KEYBINDINGS[help]="?"
    TUI_KEYBINDINGS[search]="/"
    TUI_KEYBINDINGS[refresh]="r"
    TUI_KEYBINDINGS[confirm]="y"
    TUI_KEYBINDINGS[cancel]="n"
    TUI_KEYBINDINGS[up]="k"
    TUI_KEYBINDINGS[down]="j"
    TUI_KEYBINDINGS[left]="h"
    TUI_KEYBINDINGS[right]="l"
    TUI_KEYBINDINGS[top]="g"
    TUI_KEYBINDINGS[bottom]="G"
    TUI_KEYBINDINGS[page_up]="ctrl+u"
    TUI_KEYBINDINGS[page_down]="ctrl+d"

    # Restaurer nounset si necessaire
    [[ "$_old_opts" == "u" ]] && set -u
}

# Initialiser les touches vim
_init_vim_keys() {
    # Desactiver nounset pour les affectations de tableau associatif
    local _old_opts=""
    [[ -o nounset ]] && _old_opts="u" && set +u

    TUI_VIM_KEYS[up]="k"
    TUI_VIM_KEYS[down]="j"
    TUI_VIM_KEYS[left]="h"
    TUI_VIM_KEYS[right]="l"
    TUI_VIM_KEYS[top]="gg"
    TUI_VIM_KEYS[bottom]="G"
    TUI_VIM_KEYS[page_up]="ctrl+u"
    TUI_VIM_KEYS[page_down]="ctrl+d"
    TUI_VIM_KEYS[delete]="x"
    TUI_VIM_KEYS[yank]="y"

    # Restaurer nounset si necessaire
    [[ "$_old_opts" == "u" ]] && set -u
}

# Initialiser au chargement
_init_default_keybindings
_init_vim_keys

# =============================================================================
# Fonctions raccourcis globaux (T064)
# =============================================================================

# Retourne le raccourci pour une action
get_keybinding() {
    local action="$1"
    echo "${TUI_KEYBINDINGS[$action]:-}"
}

# Definit un raccourci pour une action
set_keybinding() {
    local action="$1"
    local key="$2"
    TUI_KEYBINDINGS[$action]="$key"
}

# Charge les raccourcis depuis un fichier
load_keybindings() {
    local file="${1:-${TUI_PROJECT_ROOT:-.}/.tui-keybindings}"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    while IFS='=' read -r action key; do
        # Ignorer les commentaires et lignes vides
        [[ "$action" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${action// }" ]] && continue

        action="${action// }"
        key="${key// }"
        TUI_KEYBINDINGS[$action]="$key"
    done < "$file"
}

# Sauvegarde les raccourcis dans un fichier
save_keybindings() {
    local file="${1:-${TUI_PROJECT_ROOT:-.}/.tui-keybindings}"

    {
        echo "# TUI Keybindings"
        echo "# Generated: $(date -Iseconds)"
        for action in "${!TUI_KEYBINDINGS[@]}"; do
            echo "${action}=${TUI_KEYBINDINGS[$action]}"
        done
    } > "$file"
}

# Retourne les raccourcis par defaut
get_default_keybindings() {
    echo "quit=q"
    echo "back=b"
    echo "help=?"
    echo "search=/"
    echo "refresh=r"
    echo "confirm=y"
    echo "cancel=n"
    echo "up=k"
    echo "down=j"
}

# Reinitialise les raccourcis par defaut
reset_keybindings() {
    TUI_KEYBINDINGS=()
    _init_default_keybindings
}

# =============================================================================
# Fonctions navigation vim-like (T065)
# =============================================================================

# Verifie si le mode vim est active
is_vim_mode_enabled() {
    [[ "$TUI_VIM_MODE" == "true" ]] && echo "true" || echo "false"
}

# Active/desactive le mode vim
toggle_vim_mode() {
    if [[ "$TUI_VIM_MODE" == "true" ]]; then
        TUI_VIM_MODE="false"
        echo "Mode vim desactive"
    else
        TUI_VIM_MODE="true"
        echo "Mode vim active"
    fi
}

# Retourne la touche vim pour une action
get_vim_keybinding() {
    local action="$1"
    echo "${TUI_VIM_KEYS[$action]:-}"
}

# =============================================================================
# Fonctions touches rapides (T066)
# =============================================================================

# Retourne la touche rapide pour un index
get_quick_key() {
    local index="$1"

    if [[ "$index" -ge 1 ]] && [[ "$index" -le 9 ]]; then
        echo "$index"
    elif [[ "$index" -eq 10 ]]; then
        echo "0"
    elif [[ "$index" -gt 10 ]] && [[ "$index" -le 36 ]]; then
        # a=11, b=12, ... z=36
        local offset=$((index - 11))
        printf "\\x$(printf '%02x' $((97 + offset)))"
    else
        echo ""
    fi
}

# Convertit une touche rapide en index
parse_quick_key() {
    local key="$1"

    if [[ "$key" =~ ^[1-9]$ ]]; then
        echo "$key"
    elif [[ "$key" == "0" ]]; then
        echo "10"
    elif [[ "$key" =~ ^[a-z]$ ]]; then
        local char_code
        char_code=$(printf '%d' "'$key")
        echo $((char_code - 97 + 11))
    else
        echo "0"
    fi
}

# Verifie si c'est une touche rapide valide
is_quick_key() {
    local key="$1"
    [[ "$key" =~ ^[0-9a-z]$ ]]
}

# =============================================================================
# Fonctions recherche/filtre (T067)
# =============================================================================

# Variable pour stocker la recherche en cours
TUI_SEARCH_TERM=""

# Lance une recherche interactive
tui_search() {
    local prompt="${1:-Recherche: }"

    if command -v gum &>/dev/null; then
        TUI_SEARCH_TERM=$(gum input --placeholder "$prompt")
    else
        read -r -p "$prompt" TUI_SEARCH_TERM
    fi

    echo "$TUI_SEARCH_TERM"
}

# Filtre une liste avec un terme
tui_filter() {
    local term="$1"
    local items="$2"

    if [[ -z "$term" ]]; then
        echo "$items"
        return
    fi

    echo "$items" | grep -i "$term" || true
}

# Retourne le raccourci de recherche
get_search_keybinding() {
    echo "/"
}

# Efface la recherche en cours
clear_search() {
    TUI_SEARCH_TERM=""
}

# =============================================================================
# Fonctions historique navigation (T068)
# =============================================================================

# Ajoute une entree a l'historique
history_push() {
    local entry="$1"

    TUI_NAV_HISTORY+=("$entry")

    # Limiter la taille de l'historique
    if [[ ${#TUI_NAV_HISTORY[@]} -gt $TUI_HISTORY_MAX ]]; then
        TUI_NAV_HISTORY=("${TUI_NAV_HISTORY[@]:1}")
    fi
}

# Retourne en arriere dans l'historique
history_back() {
    if [[ ${#TUI_NAV_HISTORY[@]} -gt 0 ]]; then
        local last_index=$((${#TUI_NAV_HISTORY[@]} - 1))
        local entry="${TUI_NAV_HISTORY[$last_index]}"
        unset 'TUI_NAV_HISTORY[$last_index]'
        echo "$entry"
        return 0
    fi
    return 1
}

# Avance dans l'historique (placeholder pour future implementation)
history_forward() {
    # Non implemente - necessite un historique forward separe
    return 1
}

# Efface l'historique
history_clear() {
    TUI_NAV_HISTORY=()
}

# Retourne la taille de l'historique
get_history_size() {
    echo "${#TUI_NAV_HISTORY[@]}"
}

# =============================================================================
# Fonctions aide contextuelle (T069)
# =============================================================================

# Affiche l'aide des raccourcis clavier
show_keyboard_help() {
    echo ""
    echo "=== Raccourcis clavier ==="
    echo ""
    echo "  q        Quitter"
    echo "  b        Retour"
    echo "  ?        Aide"
    echo "  /        Recherche"
    echo "  r        Rafraichir"
    echo ""
    echo "=== Navigation (vim) ==="
    echo ""
    echo "  j/↓      Descendre"
    echo "  k/↑      Monter"
    echo "  h/←      Gauche"
    echo "  l/→      Droite"
    echo "  g        Debut"
    echo "  G        Fin"
    echo ""
    echo "=== Selection rapide ==="
    echo ""
    echo "  1-9      Options 1-9"
    echo "  0        Option 10"
    echo "  a-z      Options 11+"
    echo ""
}

# Retourne l'aide contextuelle
get_context_help() {
    local context="${1:-menu}"

    case "$context" in
        "menu")
            echo "Navigation: j/k ou fleches | Selection: 1-9 | Quitter: q"
            ;;
        "input")
            echo "Valider: Enter | Annuler: Escape | Effacer: Ctrl+U"
            ;;
        "confirm")
            echo "Oui: y | Non: n | Annuler: Escape"
            ;;
        "search")
            echo "Recherche: taper le texte | Valider: Enter | Annuler: Escape"
            ;;
        *)
            echo "Aide: ? | Quitter: q"
            ;;
    esac
}

# Affiche un hint de raccourci
show_shortcut_hint() {
    local action="$1"
    local key
    key=$(get_keybinding "$action")

    if [[ -n "$key" ]]; then
        echo -e "\e[2m[$key]\e[0m"
    fi
}

# =============================================================================
# Fonctions touches speciales (T070)
# =============================================================================

# Gere une touche speciale
handle_special_key() {
    local key="$1"

    if is_escape_key "$key"; then
        echo "escape"
    elif is_enter_key "$key"; then
        echo "enter"
    elif is_arrow_key "$key"; then
        parse_arrow_key "$key"
    elif is_ctrl_key "$key"; then
        echo "ctrl"
    else
        echo "unknown"
    fi
}

# Detecte la touche Escape
is_escape_key() {
    local key="$1"
    [[ "$key" == $'\e' ]] || [[ "$key" == $'\x1b' ]]
}

# Detecte la touche Enter
is_enter_key() {
    local key="$1"
    [[ -z "$key" ]] || [[ "$key" == $'\n' ]] || [[ "$key" == $'\r' ]]
}

# Detecte une touche fleche
is_arrow_key() {
    local key="$1"
    [[ "$key" == $'\e[A' ]] || [[ "$key" == $'\e[B' ]] || \
    [[ "$key" == $'\e[C' ]] || [[ "$key" == $'\e[D' ]]
}

# Parse une touche fleche et retourne la direction
parse_arrow_key() {
    local key="$1"

    case "$key" in
        $'\e[A') echo "up" ;;
        $'\e[B') echo "down" ;;
        $'\e[C') echo "right" ;;
        $'\e[D') echo "left" ;;
        *) echo "unknown" ;;
    esac
}

# Detecte une touche Ctrl
is_ctrl_key() {
    local key="$1"
    # Ctrl characters are in range 0x01-0x1A
    [[ "$key" =~ ^$'\x01'|$'\x02'|$'\x03'|$'\x04'|$'\x05'|$'\x06'|$'\x07'|$'\x08'|$'\x09'|$'\x0a'|$'\x0b'|$'\x0c'|$'\x0d'|$'\x0e'|$'\x0f'|$'\x10'|$'\x11'|$'\x12'|$'\x13'|$'\x14'|$'\x15'|$'\x16'|$'\x17'|$'\x18'|$'\x19'|$'\x1a'$ ]]
}

# Retourne le caractere Ctrl pour une lettre
get_ctrl_char() {
    local char="$1"
    local char_lower="${char,,}"

    # Ctrl+a = 0x01, Ctrl+b = 0x02, etc.
    local offset
    offset=$(printf '%d' "'$char_lower")
    offset=$((offset - 96))

    printf "\\x$(printf '%02x' $offset)"
}

# =============================================================================
# Fonctions integration
# =============================================================================

# Initialise le module clavier
init_keyboard() {
    _init_default_keybindings
    _init_vim_keys
    history_clear

    # Charger les keybindings personnalises si existants
    load_keybindings

    # Configurer le terminal pour la lecture des touches
    if [[ -t 0 ]]; then
        # Sauvegarder les settings du terminal
        TUI_TERM_SETTINGS=$(stty -g 2>/dev/null || true)
    fi
}

# Nettoie le module clavier
cleanup_keyboard() {
    # Restaurer les settings du terminal
    if [[ -n "${TUI_TERM_SETTINGS:-}" ]]; then
        stty "$TUI_TERM_SETTINGS" 2>/dev/null || true
    fi
}

# Traite une touche et retourne l'action correspondante
process_key() {
    local key="$1"

    # Verifier les raccourcis globaux
    for action in "${!TUI_KEYBINDINGS[@]}"; do
        if [[ "${TUI_KEYBINDINGS[$action]}" == "$key" ]]; then
            echo "$action"
            return 0
        fi
    done

    # Verifier les touches vim si mode actif
    if [[ "$TUI_VIM_MODE" == "true" ]]; then
        for action in "${!TUI_VIM_KEYS[@]}"; do
            if [[ "${TUI_VIM_KEYS[$action]}" == "$key" ]]; then
                echo "$action"
                return 0
            fi
        done
    fi

    # Verifier les touches rapides
    if is_quick_key "$key"; then
        echo "quick:$(parse_quick_key "$key")"
        return 0
    fi

    # Touche non reconnue
    echo "unknown"
    return 1
}

# Lit une touche du terminal
read_key() {
    local timeout="${1:-0}"
    local key

    if [[ $timeout -gt 0 ]]; then
        read -r -s -n 1 -t "$timeout" key
    else
        read -r -s -n 1 key
    fi

    # Gerer les sequences d'echappement (fleches, etc.)
    if [[ "$key" == $'\e' ]]; then
        read -r -s -n 2 -t 0.1 rest
        key="${key}${rest}"
    fi

    echo "$key"
}

# Retourne la configuration du clavier
get_keyboard_config() {
    echo "vim_mode=$(is_vim_mode_enabled)"
    echo "history_max=$TUI_HISTORY_MAX"
    echo "history_size=$(get_history_size)"
}

# =============================================================================
# Export des fonctions
# =============================================================================

export -f get_keybinding set_keybinding load_keybindings save_keybindings
export -f get_default_keybindings reset_keybindings
export -f is_vim_mode_enabled toggle_vim_mode get_vim_keybinding
export -f get_quick_key parse_quick_key is_quick_key
export -f tui_search tui_filter get_search_keybinding clear_search
export -f history_push history_back history_forward history_clear get_history_size
export -f show_keyboard_help get_context_help show_shortcut_hint
export -f handle_special_key is_escape_key is_enter_key is_arrow_key
export -f parse_arrow_key is_ctrl_key get_ctrl_char
export -f init_keyboard cleanup_keyboard process_key read_key get_keyboard_config
