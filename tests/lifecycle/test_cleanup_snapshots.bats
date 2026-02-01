#!/usr/bin/env bats
# =============================================================================
# Tests BATS : scripts/lifecycle/cleanup-snapshots.sh
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/lifecycle" && pwd)"
    export CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup-snapshots.sh"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

@test "cleanup-snapshots.sh existe et est executable" {
    [ -f "$CLEANUP_SCRIPT" ]
    [ -x "$CLEANUP_SCRIPT" ]
}

@test "cleanup-snapshots.sh affiche l'aide avec --help" {
    run "$CLEANUP_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--max-age"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "cleanup-snapshots.sh rejette une option inconnue" {
    run "$CLEANUP_SCRIPT" --unknown
    [ "$status" -ne 0 ]
}
