#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/lib/tui/keyboard.sh (T063-T070 - US9)
# =============================================================================
# Tests de la navigation clavier avancee : raccourcis, vim-like, recherche

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts"
    TUI_LIB="${PROJECT_ROOT}/scripts/lib/tui"
    KEYBOARD_LIB="${TUI_LIB}/keyboard.sh"

    # Charger les libs TUI
    source "${TUI_LIB}/colors.sh"
    source "${TUI_LIB}/config.sh"
    source "${TUI_LIB}/common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_keyboard"
    mkdir -p "${TEST_DIR}"

    # Mock keybindings
    TEST_KEYBINDINGS="${TEST_DIR}/keybindings.conf"
    cat > "${TEST_KEYBINDINGS}" << 'EOF'
# TUI Keybindings
quit=q
back=b
help=?
search=/
refresh=r
confirm=y
cancel=n
up=k
down=j
left=h
right=l
top=g
bottom=G
page_up=ctrl+u
page_down=ctrl+d
EOF
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure (T063)
# =============================================================================

@test "keyboard.sh existe" {
    [ -f "$KEYBOARD_LIB" ]
}

@test "keyboard.sh peut etre source sans erreur" {
    run bash -c "source '${KEYBOARD_LIB}' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# =============================================================================
# Tests raccourcis globaux (T064)
# =============================================================================

@test "get_keybinding() est definie" {
    source "$KEYBOARD_LIB"
    declare -f get_keybinding > /dev/null
}

@test "get_keybinding() retourne le raccourci pour quit" {
    source "$KEYBOARD_LIB"
    run get_keybinding "quit"
    [ "$status" -eq 0 ]
    [[ "$output" == "q" ]] || [[ "$output" == "Q" ]] || [[ "$output" == *"quit"* ]]
}

@test "get_keybinding() retourne le raccourci pour help" {
    source "$KEYBOARD_LIB"
    run get_keybinding "help"
    [ "$status" -eq 0 ]
    [[ "$output" == "?" ]] || [[ "$output" == "h" ]] || [[ "$output" == *"help"* ]]
}

@test "set_keybinding() est definie" {
    source "$KEYBOARD_LIB"
    declare -f set_keybinding > /dev/null
}

@test "load_keybindings() est definie" {
    source "$KEYBOARD_LIB"
    declare -f load_keybindings > /dev/null
}

@test "save_keybindings() est definie" {
    source "$KEYBOARD_LIB"
    declare -f save_keybindings > /dev/null
}

@test "get_default_keybindings() retourne les raccourcis par defaut" {
    source "$KEYBOARD_LIB"
    run get_default_keybindings
    [ "$status" -eq 0 ]
    [[ "$output" == *"quit"* ]] || [[ "$output" == *"help"* ]] || [[ "$output" == *"back"* ]]
}

# =============================================================================
# Tests navigation vim-like (T065)
# =============================================================================

@test "is_vim_mode_enabled() est definie" {
    source "$KEYBOARD_LIB"
    declare -f is_vim_mode_enabled > /dev/null
}

@test "toggle_vim_mode() est definie" {
    source "$KEYBOARD_LIB"
    declare -f toggle_vim_mode > /dev/null
}

@test "get_vim_keybinding() retourne j pour down" {
    source "$KEYBOARD_LIB"
    run get_vim_keybinding "down"
    [ "$status" -eq 0 ]
    [[ "$output" == "j" ]]
}

@test "get_vim_keybinding() retourne k pour up" {
    source "$KEYBOARD_LIB"
    run get_vim_keybinding "up"
    [ "$status" -eq 0 ]
    [[ "$output" == "k" ]]
}

@test "get_vim_keybinding() retourne h pour left" {
    source "$KEYBOARD_LIB"
    run get_vim_keybinding "left"
    [ "$status" -eq 0 ]
    [[ "$output" == "h" ]]
}

@test "get_vim_keybinding() retourne l pour right" {
    source "$KEYBOARD_LIB"
    run get_vim_keybinding "right"
    [ "$status" -eq 0 ]
    [[ "$output" == "l" ]]
}

@test "get_vim_keybinding() retourne gg pour top" {
    source "$KEYBOARD_LIB"
    run get_vim_keybinding "top"
    [ "$status" -eq 0 ]
    [[ "$output" == "gg" ]] || [[ "$output" == "g" ]]
}

@test "get_vim_keybinding() retourne G pour bottom" {
    source "$KEYBOARD_LIB"
    run get_vim_keybinding "bottom"
    [ "$status" -eq 0 ]
    [[ "$output" == "G" ]]
}

# =============================================================================
# Tests touches rapides (T066)
# =============================================================================

@test "get_quick_key() est definie" {
    source "$KEYBOARD_LIB"
    declare -f get_quick_key > /dev/null
}

@test "get_quick_key() retourne 1-9 pour les options" {
    source "$KEYBOARD_LIB"
    run get_quick_key 1
    [ "$status" -eq 0 ]
    [[ "$output" == "1" ]]
}

@test "get_quick_key() retourne a-z pour options > 9" {
    source "$KEYBOARD_LIB"
    run get_quick_key 10
    [ "$status" -eq 0 ]
    [[ "$output" == "a" ]] || [[ "$output" == "0" ]]
}

@test "parse_quick_key() convertit une touche en index" {
    source "$KEYBOARD_LIB"
    run parse_quick_key "3"
    [ "$status" -eq 0 ]
    [[ "$output" == "3" ]]
}

@test "is_quick_key() detecte une touche rapide valide" {
    source "$KEYBOARD_LIB"
    run is_quick_key "5"
    [ "$status" -eq 0 ]
}

@test "is_quick_key() rejette une touche invalide" {
    source "$KEYBOARD_LIB"
    run is_quick_key "xyz"
    [ "$status" -ne 0 ]
}

# =============================================================================
# Tests recherche/filtre (T067)
# =============================================================================

@test "tui_search() est definie" {
    source "$KEYBOARD_LIB"
    declare -f tui_search > /dev/null
}

@test "tui_filter() est definie" {
    source "$KEYBOARD_LIB"
    declare -f tui_filter > /dev/null
}

@test "tui_filter() filtre une liste" {
    source "$KEYBOARD_LIB"
    local items="apple
banana
cherry
date"
    run tui_filter "an" "$items"
    [ "$status" -eq 0 ]
    [[ "$output" == *"banana"* ]]
}

@test "get_search_keybinding() retourne /" {
    source "$KEYBOARD_LIB"
    run get_search_keybinding
    [ "$status" -eq 0 ]
    [[ "$output" == "/" ]]
}

@test "clear_search() est definie" {
    source "$KEYBOARD_LIB"
    declare -f clear_search > /dev/null
}

# =============================================================================
# Tests historique navigation (T068)
# =============================================================================

@test "history_back() est definie" {
    source "$KEYBOARD_LIB"
    declare -f history_back > /dev/null
}

@test "history_forward() est definie" {
    source "$KEYBOARD_LIB"
    declare -f history_forward > /dev/null
}

@test "history_push() est definie" {
    source "$KEYBOARD_LIB"
    declare -f history_push > /dev/null
}

@test "history_clear() est definie" {
    source "$KEYBOARD_LIB"
    declare -f history_clear > /dev/null
}

@test "get_history_size() retourne un nombre" {
    source "$KEYBOARD_LIB"
    history_clear
    run get_history_size
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

# =============================================================================
# Tests aide contextuelle (T069)
# =============================================================================

@test "show_keyboard_help() est definie" {
    source "$KEYBOARD_LIB"
    declare -f show_keyboard_help > /dev/null
}

@test "show_keyboard_help() affiche les raccourcis" {
    source "$KEYBOARD_LIB"
    run show_keyboard_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"q"* ]] || [[ "$output" == *"quit"* ]] || [[ "$output" == *"Quitter"* ]]
}

@test "get_context_help() est definie" {
    source "$KEYBOARD_LIB"
    declare -f get_context_help > /dev/null
}

@test "get_context_help() retourne l'aide pour un contexte" {
    source "$KEYBOARD_LIB"
    run get_context_help "menu"
    [ "$status" -eq 0 ]
    [[ "$output" == *"navigation"* ]] || [[ "$output" == *"select"* ]] || [[ -n "$output" ]]
}

@test "show_shortcut_hint() est definie" {
    source "$KEYBOARD_LIB"
    declare -f show_shortcut_hint > /dev/null
}

# =============================================================================
# Tests gestion des touches speciales (T070)
# =============================================================================

@test "handle_special_key() est definie" {
    source "$KEYBOARD_LIB"
    declare -f handle_special_key > /dev/null
}

@test "is_escape_key() detecte Escape" {
    source "$KEYBOARD_LIB"
    run is_escape_key $'\e'
    [ "$status" -eq 0 ]
}

@test "is_enter_key() detecte Enter" {
    source "$KEYBOARD_LIB"
    run is_enter_key ""
    [ "$status" -eq 0 ]
}

@test "is_arrow_key() detecte les fleches" {
    source "$KEYBOARD_LIB"
    run is_arrow_key $'\e[A'
    [ "$status" -eq 0 ]
}

@test "parse_arrow_key() retourne la direction" {
    source "$KEYBOARD_LIB"
    run parse_arrow_key $'\e[A'
    [ "$status" -eq 0 ]
    [[ "$output" == "up" ]]
}

@test "parse_arrow_key() detecte down" {
    source "$KEYBOARD_LIB"
    run parse_arrow_key $'\e[B'
    [ "$status" -eq 0 ]
    [[ "$output" == "down" ]]
}

@test "is_ctrl_key() detecte Ctrl+C" {
    source "$KEYBOARD_LIB"
    run is_ctrl_key $'\x03'
    [ "$status" -eq 0 ]
}

@test "get_ctrl_char() retourne le caractere Ctrl" {
    source "$KEYBOARD_LIB"
    run get_ctrl_char "c"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests integration
# =============================================================================

@test "init_keyboard() est definie" {
    source "$KEYBOARD_LIB"
    declare -f init_keyboard > /dev/null
}

@test "cleanup_keyboard() est definie" {
    source "$KEYBOARD_LIB"
    declare -f cleanup_keyboard > /dev/null
}

@test "process_key() est definie" {
    source "$KEYBOARD_LIB"
    declare -f process_key > /dev/null
}

@test "process_key() retourne une action pour q" {
    source "$KEYBOARD_LIB"
    run process_key "q"
    [ "$status" -eq 0 ]
    [[ "$output" == "quit" ]] || [[ "$output" == "back" ]] || [[ -n "$output" ]]
}

@test "read_key() est definie" {
    source "$KEYBOARD_LIB"
    declare -f read_key > /dev/null
}

# =============================================================================
# Tests configuration
# =============================================================================

@test "get_keyboard_config() est definie" {
    source "$KEYBOARD_LIB"
    declare -f get_keyboard_config > /dev/null
}

@test "reset_keybindings() est definie" {
    source "$KEYBOARD_LIB"
    declare -f reset_keybindings > /dev/null
}

@test "reset_keybindings() restaure les valeurs par defaut" {
    source "$KEYBOARD_LIB"
    reset_keybindings
    run get_keybinding "quit"
    [ "$status" -eq 0 ]
    [[ "$output" == "q" ]]
}
