#!/usr/bin/env bats
# =============================================================================
# Tests BATS : scripts/health/check-health.sh
# =============================================================================
# Verifie le parsing d'arguments, le mode dry-run, et les exclusions.
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/health" && pwd)"
    export CHECK_HEALTH_SCRIPT="${SCRIPT_DIR}/check-health.sh"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Qualite du script
# =============================================================================

@test "check-health.sh existe et est executable" {
    [ -f "$CHECK_HEALTH_SCRIPT" ]
    [ -x "$CHECK_HEALTH_SCRIPT" ]
}

@test "check-health.sh passe shellcheck" {
    if ! command -v shellcheck &>/dev/null; then
        skip "shellcheck non installe"
    fi
    run shellcheck -x -S warning "$CHECK_HEALTH_SCRIPT"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Parsing des arguments
# =============================================================================

@test "check-health.sh affiche l'aide avec --help" {
    run "$CHECK_HEALTH_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--env"* ]]
    [[ "$output" == *"--all"* ]]
    [[ "$output" == *"--component"* ]]
    [[ "$output" == *"--exclude"* ]]
    [[ "$output" == *"--timeout"* ]]
}

@test "check-health.sh affiche l'aide avec -h" {
    run "$CHECK_HEALTH_SCRIPT" -h
    [ "$status" -eq 0 ]
}

@test "check-health.sh echoue sans arguments" {
    run "$CHECK_HEALTH_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--env"* ]] || [[ "$output" == *"--all"* ]]
}

@test "check-health.sh rejette un environnement invalide" {
    run "$CHECK_HEALTH_SCRIPT" --env invalid
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalide"* ]]
}

@test "check-health.sh rejette un composant invalide" {
    run "$CHECK_HEALTH_SCRIPT" --env prod --component invalid
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalide"* ]]
}

@test "check-health.sh accepte --env prod" {
    run "$CHECK_HEALTH_SCRIPT" --env prod --dry-run --force
    [ "$status" -eq 0 ]
}

@test "check-health.sh accepte --all" {
    run "$CHECK_HEALTH_SCRIPT" --all --dry-run --force
    [ "$status" -eq 0 ]
}

@test "check-health.sh accepte --component vm" {
    run "$CHECK_HEALTH_SCRIPT" --env prod --component vm --dry-run --force
    [ "$status" -eq 0 ]
}

@test "check-health.sh accepte --component monitoring" {
    run "$CHECK_HEALTH_SCRIPT" --env monitoring --component monitoring --dry-run --force
    [ "$status" -eq 0 ]
}

@test "check-health.sh rejette une option inconnue" {
    run "$CHECK_HEALTH_SCRIPT" --unknown
    [ "$status" -ne 0 ]
}

# =============================================================================
# Mode dry-run
# =============================================================================

@test "check-health.sh --dry-run affiche DRY-RUN" {
    run "$CHECK_HEALTH_SCRIPT" --env prod --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]] || [[ "$output" == *"dry-run"* ]] || [[ "$output" == *"Rapport"* ]]
}

# =============================================================================
# Rapport
# =============================================================================

@test "check-health.sh affiche un rapport" {
    run "$CHECK_HEALTH_SCRIPT" --all --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"Rapport"* ]] || [[ "$output" == *"rapport"* ]] || [[ "$output" == *"sante"* ]]
}
