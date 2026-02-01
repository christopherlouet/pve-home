#!/usr/bin/env bats
# =============================================================================
# Tests BATS : scripts/drift/check-drift.sh
# =============================================================================
# Verifie le parsing d'arguments, la generation de metriques, le mode dry-run,
# et la gestion des erreurs.
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/drift" && pwd)"
    export CHECK_DRIFT_SCRIPT="${SCRIPT_DIR}/check-drift.sh"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Qualite du script
# =============================================================================

@test "check-drift.sh existe et est executable" {
    [ -f "$CHECK_DRIFT_SCRIPT" ]
    [ -x "$CHECK_DRIFT_SCRIPT" ]
}

@test "check-drift.sh passe shellcheck" {
    if ! command -v shellcheck &>/dev/null; then
        skip "shellcheck non installe"
    fi
    run shellcheck -x -S warning "$CHECK_DRIFT_SCRIPT"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Parsing des arguments
# =============================================================================

@test "check-drift.sh affiche l'aide avec --help" {
    run "$CHECK_DRIFT_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--env"* ]]
    [[ "$output" == *"--all"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "check-drift.sh affiche l'aide avec -h" {
    run "$CHECK_DRIFT_SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"--env"* ]]
}

@test "check-drift.sh echoue sans arguments" {
    run "$CHECK_DRIFT_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--env"* ]] || [[ "$output" == *"--all"* ]]
}

@test "check-drift.sh rejette un environnement invalide" {
    run "$CHECK_DRIFT_SCRIPT" --env invalid
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalide"* ]] || [[ "$output" == *"invalid"* ]]
}

@test "check-drift.sh accepte --env prod" {
    run "$CHECK_DRIFT_SCRIPT" --env prod --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]]
}

@test "check-drift.sh accepte --env lab" {
    run "$CHECK_DRIFT_SCRIPT" --env lab --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"lab"* ]]
}

@test "check-drift.sh accepte --env monitoring" {
    run "$CHECK_DRIFT_SCRIPT" --env monitoring --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"monitoring"* ]]
}

@test "check-drift.sh accepte --all" {
    run "$CHECK_DRIFT_SCRIPT" --all --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]]
    [[ "$output" == *"lab"* ]]
    [[ "$output" == *"monitoring"* ]]
}

@test "check-drift.sh rejette une option inconnue" {
    run "$CHECK_DRIFT_SCRIPT" --unknown
    [ "$status" -ne 0 ]
    [[ "$output" == *"inconnue"* ]] || [[ "$output" == *"unknown"* ]]
}

# =============================================================================
# Mode dry-run
# =============================================================================

@test "check-drift.sh --dry-run affiche DRY-RUN" {
    run "$CHECK_DRIFT_SCRIPT" --env prod --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "check-drift.sh --dry-run n'execute pas terraform" {
    run "$CHECK_DRIFT_SCRIPT" --all --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

# =============================================================================
# Resume
# =============================================================================

@test "check-drift.sh affiche un resume" {
    run "$CHECK_DRIFT_SCRIPT" --all --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"Resume"* ]] || [[ "$output" == *"resume"* ]]
}
