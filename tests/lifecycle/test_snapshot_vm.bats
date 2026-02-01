#!/usr/bin/env bats
# =============================================================================
# Tests BATS : scripts/lifecycle/snapshot-vm.sh
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/lifecycle" && pwd)"
    export SNAPSHOT_SCRIPT="${SCRIPT_DIR}/snapshot-vm.sh"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

@test "snapshot-vm.sh existe et est executable" {
    [ -f "$SNAPSHOT_SCRIPT" ]
    [ -x "$SNAPSHOT_SCRIPT" ]
}

@test "snapshot-vm.sh affiche l'aide avec --help" {
    run "$SNAPSHOT_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"create"* ]]
    [[ "$output" == *"list"* ]]
    [[ "$output" == *"rollback"* ]]
    [[ "$output" == *"delete"* ]]
}

@test "snapshot-vm.sh echoue sans arguments" {
    run "$SNAPSHOT_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"requis"* ]] || [[ "$output" == *"Action"* ]]
}

@test "snapshot-vm.sh echoue sans VMID" {
    run "$SNAPSHOT_SCRIPT" create
    [ "$status" -ne 0 ]
    [[ "$output" == *"VMID"* ]]
}

@test "snapshot-vm.sh rejette un VMID non numerique" {
    run "$SNAPSHOT_SCRIPT" create abc
    [ "$status" -ne 0 ]
    [[ "$output" == *"numerique"* ]]
}

@test "snapshot-vm.sh rejette une action invalide" {
    run "$SNAPSHOT_SCRIPT" invalid 100
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalide"* ]]
}

@test "snapshot-vm.sh rollback necessite --name" {
    run "$SNAPSHOT_SCRIPT" rollback 100
    [ "$status" -ne 0 ]
    [[ "$output" == *"--name"* ]] || [[ "$output" == *"nom"* ]]
}

@test "snapshot-vm.sh delete necessite --name" {
    run "$SNAPSHOT_SCRIPT" delete 100
    [ "$status" -ne 0 ]
    [[ "$output" == *"--name"* ]] || [[ "$output" == *"nom"* ]]
}

@test "snapshot-vm.sh create accepte --dry-run" {
    run "$SNAPSHOT_SCRIPT" create 100 --node 192.168.1.100 --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "snapshot-vm.sh list accepte --dry-run" {
    run "$SNAPSHOT_SCRIPT" list 100 --node 192.168.1.100 --dry-run --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}
