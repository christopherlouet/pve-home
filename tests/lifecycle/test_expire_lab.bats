#!/usr/bin/env bats
# =============================================================================
# Tests BATS : scripts/lifecycle/expire-lab-vms.sh
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/lifecycle" && pwd)"
    export EXPIRE_SCRIPT="${SCRIPT_DIR}/expire-lab-vms.sh"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

@test "expire-lab-vms.sh existe et est executable" {
    [ -f "$EXPIRE_SCRIPT" ]
    [ -x "$EXPIRE_SCRIPT" ]
}

@test "expire-lab-vms.sh affiche l'aide avec --help" {
    run "$EXPIRE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--node"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "expire-lab-vms.sh rejette une option inconnue" {
    run "$EXPIRE_SCRIPT" --unknown
    [ "$status" -ne 0 ]
}
