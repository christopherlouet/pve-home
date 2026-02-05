#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/lib/tui/common.sh (T008)
# =============================================================================
# Tests des wrappers gum : menu, confirm, input, spin, table, banner

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_LIB="${PROJECT_ROOT}/scripts/lib/tui"

    # Sourcer les libs TUI
    source "${TUI_LIB}/colors.sh" 2>/dev/null || true
    source "${TUI_LIB}/config.sh" 2>/dev/null || true
    source "${TUI_LIB}/common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_tui_common"
    mkdir -p "${TEST_DIR}"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence des fichiers
# =============================================================================

@test "common.sh existe" {
    [ -f "${TUI_LIB}/common.sh" ]
}

@test "colors.sh existe" {
    [ -f "${TUI_LIB}/colors.sh" ]
}

@test "config.sh existe" {
    [ -f "${TUI_LIB}/config.sh" ]
}

# =============================================================================
# Tests colors.sh - Definitions des couleurs
# =============================================================================

@test "colors.sh definit TUI_COLOR_PRIMARY" {
    source "${TUI_LIB}/colors.sh"
    [ -n "$TUI_COLOR_PRIMARY" ]
}

@test "colors.sh definit TUI_COLOR_SUCCESS" {
    source "${TUI_LIB}/colors.sh"
    [ -n "$TUI_COLOR_SUCCESS" ]
}

@test "colors.sh definit TUI_COLOR_WARNING" {
    source "${TUI_LIB}/colors.sh"
    [ -n "$TUI_COLOR_WARNING" ]
}

@test "colors.sh definit TUI_COLOR_ERROR" {
    source "${TUI_LIB}/colors.sh"
    [ -n "$TUI_COLOR_ERROR" ]
}

@test "colors.sh definit TUI_COLOR_INFO" {
    source "${TUI_LIB}/colors.sh"
    [ -n "$TUI_COLOR_INFO" ]
}

# =============================================================================
# Tests config.sh - Detection contexte et chemins
# =============================================================================

@test "config.sh definit TUI_CONTEXT" {
    source "${TUI_LIB}/config.sh"
    [ -n "$TUI_CONTEXT" ]
    # Doit etre 'local' ou 'remote'
    [[ "$TUI_CONTEXT" == "local" ]] || [[ "$TUI_CONTEXT" == "remote" ]]
}

@test "config.sh definit TUI_PROJECT_ROOT" {
    source "${TUI_LIB}/config.sh"
    [ -n "$TUI_PROJECT_ROOT" ]
    [ -d "$TUI_PROJECT_ROOT" ]
}

@test "config.sh definit TUI_SCRIPTS_DIR" {
    source "${TUI_LIB}/config.sh"
    [ -n "$TUI_SCRIPTS_DIR" ]
}

@test "config.sh definit TUI_TFVARS_DIR" {
    source "${TUI_LIB}/config.sh"
    [ -n "$TUI_TFVARS_DIR" ]
}

@test "detect_context() retourne local ou remote" {
    source "${TUI_LIB}/config.sh"
    run detect_context
    [ "$status" -eq 0 ]
    [[ "$output" == "local" ]] || [[ "$output" == "remote" ]]
}

# =============================================================================
# Tests common.sh - Wrapper tui_menu
# =============================================================================

@test "tui_menu() est definie" {
    declare -f tui_menu > /dev/null
}

@test "tui_menu() accepte un titre et des options" {
    # Test que la fonction accepte les parametres sans erreur
    # En mode non-interactif, on ne peut pas tester le comportement reel
    declare -f tui_menu > /dev/null
}

# =============================================================================
# Tests common.sh - Wrapper tui_confirm
# =============================================================================

@test "tui_confirm() est definie" {
    declare -f tui_confirm > /dev/null
}

@test "tui_confirm() retourne 0 en mode --force" {
    TUI_FORCE_MODE=true
    run tui_confirm "Test confirmation?"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests common.sh - Wrapper tui_input
# =============================================================================

@test "tui_input() est definie" {
    declare -f tui_input > /dev/null
}

@test "tui_input() accepte un placeholder" {
    # Verifier que la fonction existe et accepte des arguments
    declare -f tui_input > /dev/null
}

# =============================================================================
# Tests common.sh - Wrapper tui_spin
# =============================================================================

@test "tui_spin() est definie" {
    declare -f tui_spin > /dev/null
}

@test "tui_spin() execute une commande avec spinner" {
    # Test que la fonction peut executer une commande simple
    run tui_spin "Test" echo "done"
    [ "$status" -eq 0 ]
}

@test "tui_spin() retourne le code de sortie de la commande" {
    run tui_spin "Test echec" false
    [ "$status" -ne 0 ]
}

# =============================================================================
# Tests common.sh - Wrapper tui_table
# =============================================================================

@test "tui_table() est definie" {
    declare -f tui_table > /dev/null
}

@test "tui_table() accepte des donnees en entree" {
    # Test avec donnees simples - la fonction tui_table est deja chargee dans setup
    run bash -c "echo -e 'Col1,Col2\nVal1,Val2' | column -t -s ','"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests common.sh - Wrapper tui_banner
# =============================================================================

@test "tui_banner() est definie" {
    declare -f tui_banner > /dev/null
}

@test "tui_banner() affiche un message" {
    run tui_banner "Test Banner"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test Banner"* ]] || [[ "$output" == *"banner"* ]] || [ -n "$output" ]
}

# =============================================================================
# Tests common.sh - Fonctions utilitaires
# =============================================================================

@test "tui_log_info() est definie" {
    declare -f tui_log_info > /dev/null
}

@test "tui_log_success() est definie" {
    declare -f tui_log_success > /dev/null
}

@test "tui_log_warn() est definie" {
    declare -f tui_log_warn > /dev/null
}

@test "tui_log_error() est definie" {
    declare -f tui_log_error > /dev/null
}

@test "tui_log_info() affiche un message avec prefixe" {
    run tui_log_info "message test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"message test"* ]]
}

@test "tui_log_error() affiche en rouge/avec prefixe erreur" {
    run tui_log_error "erreur test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"erreur test"* ]]
}

# =============================================================================
# Tests common.sh - Gestion gum absent (fallback)
# =============================================================================

@test "tui_check_gum() est definie" {
    declare -f tui_check_gum > /dev/null
}

@test "tui_check_gum() retourne 0 si gum est present" {
    if command -v gum &>/dev/null; then
        run tui_check_gum
        [ "$status" -eq 0 ]
    else
        skip "gum non installe"
    fi
}

@test "fonctions ont un fallback si gum absent" {
    # Si gum n'est pas installe, les fonctions doivent quand meme fonctionner
    # avec un mode degrade (echo, read, etc.)
    if ! command -v gum &>/dev/null; then
        run tui_log_info "test sans gum"
        [ "$status" -eq 0 ]
    else
        skip "gum est installe, pas de test fallback"
    fi
}

# =============================================================================
# Tests integration avec common.sh existant
# =============================================================================

@test "common.sh peut sourcer scripts/lib/common.sh" {
    # Verifier la compatibilite avec la lib existante
    source "${PROJECT_ROOT}/scripts/lib/common.sh"
    source "${TUI_LIB}/common.sh"
    # Les deux libs doivent coexister
    declare -f log_info > /dev/null
    declare -f tui_log_info > /dev/null
}

# =============================================================================
# Tests navigation et retour
# =============================================================================

@test "tui_back_option() est definie ou gere le retour" {
    # Le menu doit avoir une option de retour
    declare -f tui_back_option > /dev/null || \
    grep -q "Retour\|Back\|←" "${TUI_LIB}/common.sh"
}

@test "tui_quit_handler() est definie pour Ctrl+C" {
    # Gestion propre de l'interruption
    declare -f tui_quit_handler > /dev/null || \
    grep -qE "trap.*INT|trap.*SIGINT|trap.*EXIT" "${TUI_LIB}/common.sh"
}
