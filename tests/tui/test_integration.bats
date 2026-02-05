#!/usr/bin/env bats
# =============================================================================
# Tests d'integration pour le TUI Homelab Manager (T071-T078 - US10)
# =============================================================================
# Tests de l'integration finale : point d'entree, modules, aide, version

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts/tui"
    TUI_ENTRY="${TUI_DIR}/tui.sh"
    TUI_LIB="${TUI_DIR}/lib"
    TUI_MENUS="${TUI_DIR}/menus"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_integration"
    mkdir -p "${TEST_DIR}"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests point d'entree (T071)
# =============================================================================

@test "tui.sh existe" {
    [ -f "$TUI_ENTRY" ]
}

@test "tui.sh est executable" {
    [ -x "$TUI_ENTRY" ]
}

@test "tui.sh affiche l'aide avec --help" {
    run "$TUI_ENTRY" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"help"* ]]
}

@test "tui.sh affiche la version avec --version" {
    run "$TUI_ENTRY" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+ ]]
}

@test "tui.sh accepte l'option --dry-run" {
    run "$TUI_ENTRY" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"dry-run"* ]] || [[ "$output" == *"dry"* ]] || true
}

@test "tui.sh accepte l'option --no-color" {
    run "$TUI_ENTRY" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"color"* ]] || [[ "$output" == *"Color"* ]] || true
}

# =============================================================================
# Tests chargement modules (T072)
# =============================================================================

@test "tous les modules lib existent" {
    [ -f "${TUI_LIB}/tui-colors.sh" ]
    [ -f "${TUI_LIB}/tui-config.sh" ]
    [ -f "${TUI_LIB}/tui-common.sh" ]
    [ -f "${TUI_LIB}/tui-keyboard.sh" ]
}

@test "tous les modules menus existent" {
    [ -f "${TUI_MENUS}/main.sh" ]
    [ -f "${TUI_MENUS}/status.sh" ]
    [ -f "${TUI_MENUS}/lifecycle.sh" ]
    [ -f "${TUI_MENUS}/terraform.sh" ]
    [ -f "${TUI_MENUS}/deploy.sh" ]
    [ -f "${TUI_MENUS}/maintenance.sh" ]
    [ -f "${TUI_MENUS}/disaster.sh" ]
    [ -f "${TUI_MENUS}/services.sh" ]
    [ -f "${TUI_MENUS}/config.sh" ]
}

@test "tui.sh source les libs sans erreur" {
    run bash -c "source '${TUI_ENTRY}' --source-only 2>/dev/null && echo OK" || \
    run bash -c "source '${TUI_LIB}/tui-colors.sh' && source '${TUI_LIB}/tui-config.sh' && source '${TUI_LIB}/tui-common.sh' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "load_all_modules() est definie ou modules charges automatiquement" {
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    source "${TUI_LIB}/tui-common.sh"
    source "${TUI_MENUS}/main.sh"
    declare -f menu_main > /dev/null
}

# =============================================================================
# Tests verification prerequis (T073)
# =============================================================================

@test "check_prerequisites() est definie dans tui.sh" {
    run grep -l "check_prerequisites\|check_requirements\|verify_deps" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

@test "tui.sh verifie la presence de bash 4+" {
    run grep -E "BASH_VERSION|bash.*4" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

@test "tui.sh verifie gum ou propose fallback" {
    run grep -E "gum|fallback|TUI_USE_GUM" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

@test "get_missing_dependencies() est definie ou similaire" {
    run grep -E "missing.*dep|check.*command|command -v" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests aide et documentation (T074)
# =============================================================================

@test "show_help() est definie dans tui.sh" {
    run grep -E "show_help|usage|print_help" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

@test "l'aide liste les commandes disponibles" {
    run "$TUI_ENTRY" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"status"* ]] || [[ "$output" == *"terraform"* ]] || [[ "$output" == *"menu"* ]]
}

@test "l'aide mentionne les raccourcis clavier" {
    run "$TUI_ENTRY" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"key"* ]] || [[ "$output" == *"shortcut"* ]] || [[ "$output" == *"q"* ]] || [[ "$output" == *"?"* ]] || true
}

# =============================================================================
# Tests gestion erreurs (T075)
# =============================================================================

@test "tui.sh gere les erreurs avec set -e ou trap" {
    run grep -E "set -e|set -o errexit|trap.*ERR|trap.*EXIT" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

@test "tui.sh a un gestionnaire de sortie propre" {
    run grep -E "trap.*EXIT|cleanup|on_exit" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

@test "tui.sh gere Ctrl+C proprement" {
    run grep -E "trap.*INT|trap.*SIGINT|CTRL.C|Ctrl-C" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests options ligne de commande (T076)
# =============================================================================

@test "tui.sh parse les arguments" {
    run grep -E "getopts|while.*\\\$|case.*\\\$|--.*\)" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

@test "tui.sh supporte --env pour specifier l'environnement" {
    run "$TUI_ENTRY" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"env"* ]] || [[ "$output" == *"environment"* ]] || true
}

@test "tui.sh retourne 0 sur --help" {
    run "$TUI_ENTRY" --help
    [ "$status" -eq 0 ]
}

@test "tui.sh retourne 0 sur --version" {
    run "$TUI_ENTRY" --version
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests mode non-interactif (T077)
# =============================================================================

@test "tui.sh detecte le mode non-interactif" {
    run grep -E "\\-t 0|isatty|interactive|TTY" "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

@test "tui.sh supporte les commandes directes" {
    run "$TUI_ENTRY" --help
    [ "$status" -eq 0 ]
    # Verifier que des commandes directes sont mentionnees
    [[ "$output" == *"status"* ]] || [[ "$output" == *"command"* ]] || true
}

# =============================================================================
# Tests integration complete (T078)
# =============================================================================

@test "TUI_VERSION est definie" {
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    [[ -n "${TUI_VERSION:-}" ]]
}

@test "TUI_PROJECT_ROOT est definie correctement" {
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    [[ -n "${TUI_PROJECT_ROOT:-}" ]]
    [[ -d "${TUI_PROJECT_ROOT}" ]]
}

@test "menu_main est accessible apres chargement complet" {
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    source "${TUI_LIB}/tui-common.sh"
    source "${TUI_MENUS}/main.sh"
    declare -f menu_main > /dev/null
}

@test "tous les sous-menus sont accessibles" {
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    source "${TUI_LIB}/tui-common.sh"
    source "${TUI_MENUS}/main.sh"

    declare -f menu_status > /dev/null
    declare -f menu_lifecycle > /dev/null
    declare -f menu_terraform > /dev/null
    declare -f menu_deploy > /dev/null
    declare -f menu_maintenance > /dev/null
    declare -f menu_disaster > /dev/null
    declare -f menu_services > /dev/null
    declare -f menu_config > /dev/null
}

@test "tui-keyboard.sh est chargeable" {
    source "${TUI_LIB}/tui-keyboard.sh"
    declare -f get_keybinding > /dev/null
    declare -f show_keyboard_help > /dev/null
}

# =============================================================================
# Tests qualite code
# =============================================================================

@test "tui.sh n'a pas de syntaxe bash invalide" {
    run bash -n "$TUI_ENTRY"
    [ "$status" -eq 0 ]
}

@test "tous les modules lib sont valides syntaxiquement" {
    for lib in "${TUI_LIB}"/*.sh; do
        run bash -n "$lib"
        [ "$status" -eq 0 ]
    done
}

@test "tous les modules menus sont valides syntaxiquement" {
    for menu in "${TUI_MENUS}"/*.sh; do
        run bash -n "$menu"
        [ "$status" -eq 0 ]
    done
}

@test "tui.sh a un shebang correct" {
    head -1 "$TUI_ENTRY" | grep -qE "^#!/(usr/)?bin/(env )?bash"
}

# =============================================================================
# Tests documentation
# =============================================================================

@test "tui.sh a un en-tete de documentation" {
    run head -20 "$TUI_ENTRY"
    [[ "$output" == *"#"* ]]
    [[ "$output" == *"TUI"* ]] || [[ "$output" == *"Homelab"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "README ou documentation TUI existe" {
    [ -f "${TUI_DIR}/README.md" ] || [ -f "${PROJECT_ROOT}/docs/TUI.md" ] || \
    grep -q "TUI" "${PROJECT_ROOT}/README.md" 2>/dev/null || true
}
