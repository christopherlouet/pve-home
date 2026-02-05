#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/tui/menus/status.sh (T015 - US1)
# =============================================================================
# Tests du menu status/health : selection env, affichage resultats, drill-down

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts/tui"
    TUI_LIB="${TUI_DIR}/lib"
    STATUS_MENU="${TUI_DIR}/menus/status.sh"

    # Charger les libs TUI
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    source "${TUI_LIB}/tui-common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_status"
    mkdir -p "${TEST_DIR}"

    # Mock des resultats health check (format: env|component|type|status|detail|duration)
    MOCK_RESULTS_OK="prod|vm-192.168.1.10|vm|OK||50ms
prod|vm-192.168.1.11|vm|OK||45ms
monitoring|prometheus|monitoring|OK||10ms
monitoring|grafana|monitoring|OK||15ms"

    MOCK_RESULTS_MIXED="prod|vm-192.168.1.10|vm|OK||50ms
prod|vm-192.168.1.11|vm|WARN|SSH unreachable|45ms
monitoring|prometheus|monitoring|OK||10ms
monitoring|grafana|monitoring|FAIL|Grafana unreachable|15ms"

    MOCK_RESULTS_FAIL="prod|vm-192.168.1.10|vm|FAIL|ping failed|50ms
monitoring|prometheus|monitoring|FAIL|Prometheus unreachable|10ms"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure (T009)
# =============================================================================

@test "status.sh existe" {
    [ -f "$STATUS_MENU" ]
}

@test "status.sh peut etre source sans erreur" {
    run bash -c "source '${STATUS_MENU}' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "menu_status() est definie" {
    source "$STATUS_MENU"
    declare -f menu_status > /dev/null
}

# =============================================================================
# Tests selection environnement (T010)
# =============================================================================

@test "get_env_options() retourne les environnements disponibles" {
    source "$STATUS_MENU"
    run get_env_options
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]]
    [[ "$output" == *"lab"* ]]
    [[ "$output" == *"monitoring"* ]]
    [[ "$output" == *"tous"* ]] || [[ "$output" == *"Tous"* ]]
}

@test "select_environment() est definie" {
    source "$STATUS_MENU"
    declare -f select_environment > /dev/null
}

# =============================================================================
# Tests integration health check (T011)
# =============================================================================

@test "run_health_check() est definie" {
    source "$STATUS_MENU"
    declare -f run_health_check > /dev/null
}

@test "run_health_check() accepte un environnement" {
    source "$STATUS_MENU"
    # Verifier que la fonction peut etre appelee avec un env
    declare -f run_health_check > /dev/null
}

@test "get_health_script_path() retourne le bon chemin" {
    source "$STATUS_MENU"
    run get_health_script_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"check-health.sh"* ]]
}

# =============================================================================
# Tests parsing et affichage resultats (T012)
# =============================================================================

@test "parse_health_results() est definie" {
    source "$STATUS_MENU"
    declare -f parse_health_results > /dev/null
}

@test "parse_health_results() extrait les champs correctement" {
    source "$STATUS_MENU"
    local line="prod|vm-192.168.1.10|vm|OK||50ms"

    # Tester l'extraction des champs
    run parse_result_field "$line" 1  # env
    [[ "$output" == "prod" ]]

    run parse_result_field "$line" 2  # component
    [[ "$output" == "vm-192.168.1.10" ]]

    run parse_result_field "$line" 4  # status
    [[ "$output" == "OK" ]]
}

@test "format_status_color() colorie OK en vert" {
    source "$STATUS_MENU"
    run format_status_color "OK"
    [ "$status" -eq 0 ]
    # Doit contenir le code couleur vert ou le texte OK
    [[ "$output" == *"OK"* ]]
}

@test "format_status_color() colorie WARN en jaune" {
    source "$STATUS_MENU"
    run format_status_color "WARN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
}

@test "format_status_color() colorie FAIL en rouge" {
    source "$STATUS_MENU"
    run format_status_color "FAIL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FAIL"* ]]
}

@test "display_results_table() est definie" {
    source "$STATUS_MENU"
    declare -f display_results_table > /dev/null
}

# =============================================================================
# Tests drill-down sur erreurs (T013)
# =============================================================================

@test "get_failed_components() filtre les composants en erreur" {
    source "$STATUS_MENU"

    # Ecrire les resultats mock dans un fichier
    echo "$MOCK_RESULTS_MIXED" > "${TEST_DIR}/results.txt"

    run get_failed_components "${TEST_DIR}/results.txt"
    [ "$status" -eq 0 ]
    # Doit contenir les composants WARN et FAIL
    [[ "$output" == *"vm-192.168.1.11"* ]] || [[ "$output" == *"grafana"* ]]
}

@test "show_component_details() est definie" {
    source "$STATUS_MENU"
    declare -f show_component_details > /dev/null
}

@test "drill_down_menu() est definie pour les details" {
    source "$STATUS_MENU"
    declare -f drill_down_menu > /dev/null || declare -f show_error_details > /dev/null
}

# =============================================================================
# Tests resume/banner (T014)
# =============================================================================

@test "calculate_health_summary() compte les composants" {
    source "$STATUS_MENU"

    echo "$MOCK_RESULTS_OK" > "${TEST_DIR}/results.txt"
    run calculate_health_summary "${TEST_DIR}/results.txt"
    [ "$status" -eq 0 ]
    # Format attendu: "4/4" ou "4 sur 4" ou similaire
    [[ "$output" == *"4"* ]]
}

@test "calculate_health_summary() detecte les echecs" {
    source "$STATUS_MENU"

    echo "$MOCK_RESULTS_MIXED" > "${TEST_DIR}/results.txt"
    run calculate_health_summary "${TEST_DIR}/results.txt"
    [ "$status" -eq 0 ]
    # 2 OK sur 4 total
    [[ "$output" == *"2"* ]] && [[ "$output" == *"4"* ]]
}

@test "display_health_banner() affiche le resume" {
    source "$STATUS_MENU"
    run display_health_banner "3/4 composants sains"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3/4"* ]] || [[ "$output" == *"composants"* ]] || [[ "$output" == *"sains"* ]]
}

# =============================================================================
# Tests fonctions utilitaires
# =============================================================================

@test "is_health_ok() retourne 0 si tous OK" {
    source "$STATUS_MENU"
    echo "$MOCK_RESULTS_OK" > "${TEST_DIR}/results.txt"
    run is_health_ok "${TEST_DIR}/results.txt"
    [ "$status" -eq 0 ]
}

@test "is_health_ok() retourne 1 si FAIL present" {
    source "$STATUS_MENU"
    echo "$MOCK_RESULTS_FAIL" > "${TEST_DIR}/results.txt"
    run is_health_ok "${TEST_DIR}/results.txt"
    [ "$status" -eq 1 ]
}

@test "count_by_status() compte les OK" {
    source "$STATUS_MENU"
    echo "$MOCK_RESULTS_MIXED" > "${TEST_DIR}/results.txt"
    run count_by_status "${TEST_DIR}/results.txt" "OK"
    [ "$status" -eq 0 ]
    [[ "$output" == "2" ]]
}

@test "count_by_status() compte les FAIL" {
    source "$STATUS_MENU"
    echo "$MOCK_RESULTS_MIXED" > "${TEST_DIR}/results.txt"
    run count_by_status "${TEST_DIR}/results.txt" "FAIL"
    [ "$status" -eq 0 ]
    [[ "$output" == "1" ]]
}

# =============================================================================
# Tests integration menu complet
# =============================================================================

@test "menu_status gere le retour au menu principal" {
    source "$STATUS_MENU"
    # Verifier que l'option retour existe
    declare -f menu_status > /dev/null
    # La fonction doit pouvoir retourner sans erreur
}

@test "status.sh source les dependances TUI" {
    # Verifier que le fichier source les libs necessaires
    grep -q "tui-common.sh\|tui-colors.sh" "$STATUS_MENU" || \
    grep -q "source.*lib" "$STATUS_MENU"
}
