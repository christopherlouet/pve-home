#!/usr/bin/env bats
# =============================================================================
# Tests BATS : scripts/lifecycle/rotate-ssh-keys.sh
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/lifecycle" && pwd)"
    export ROTATE_SCRIPT="${SCRIPT_DIR}/rotate-ssh-keys.sh"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

@test "rotate-ssh-keys.sh existe et est executable" {
    [ -f "$ROTATE_SCRIPT" ]
    [ -x "$ROTATE_SCRIPT" ]
}

@test "rotate-ssh-keys.sh affiche l'aide avec --help" {
    run "$ROTATE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--add-key"* ]]
    [[ "$output" == *"--remove-key"* ]]
}

@test "rotate-ssh-keys.sh echoue sans action" {
    run "$ROTATE_SCRIPT" --env prod
    [ "$status" -ne 0 ]
    [[ "$output" == *"--add-key"* ]] || [[ "$output" == *"--remove-key"* ]]
}

@test "rotate-ssh-keys.sh echoue sans env" {
    run "$ROTATE_SCRIPT" --add-key /dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"--env"* ]] || [[ "$output" == *"--all"* ]]
}

@test "rotate-ssh-keys.sh echoue avec fichier inexistant" {
    run "$ROTATE_SCRIPT" --add-key /nonexistent --env prod
    [ "$status" -ne 0 ]
    [[ "$output" == *"introuvable"* ]]
}
