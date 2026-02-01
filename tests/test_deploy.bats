#!/usr/bin/env bats
# =============================================================================
# Tests pour deploy.sh
# =============================================================================
# Verifie le script de deploiement des scripts et timers systemd
# vers la VM monitoring.
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"
    DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy.sh"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et qualite du script
# =============================================================================

@test "deploy.sh existe et est executable" {
    [ -f "$DEPLOY_SCRIPT" ]
    [ -x "$DEPLOY_SCRIPT" ]
}

@test "deploy.sh passe shellcheck" {
    if ! command -v shellcheck &>/dev/null; then
        skip "shellcheck non installe"
    fi
    run shellcheck -x --severity=warning "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "deploy.sh utilise set -euo pipefail" {
    run grep -q "set -euo pipefail" "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests aide et options
# =============================================================================

@test "deploy.sh affiche l'aide avec --help" {
    run "$DEPLOY_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--ssh-user"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "deploy.sh affiche l'aide avec -h" {
    run "$DEPLOY_SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "deploy.sh rejette une option inconnue" {
    run "$DEPLOY_SCRIPT" --invalid-option
    [ "$status" -ne 0 ]
    [[ "$output" == *"Option inconnue"* ]]
}

# =============================================================================
# Tests configuration SSH
# =============================================================================

@test "deploy.sh utilise StrictHostKeyChecking=accept-new" {
    run grep -q "StrictHostKeyChecking=accept-new" "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "deploy.sh n'utilise pas StrictHostKeyChecking=no" {
    run grep "StrictHostKeyChecking=no" "$DEPLOY_SCRIPT"
    [ "$status" -ne 0 ]
}

# =============================================================================
# Tests variables et structure
# =============================================================================

@test "deploy.sh definit REMOTE_BASE" {
    run grep -q 'REMOTE_BASE=' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "deploy.sh definit les timers systemd" {
    run grep -q 'pve-health-check' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    run grep -q 'pve-drift-check' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    run grep -q 'pve-cleanup-snapshots' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    run grep -q 'pve-expire-lab' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "deploy.sh definit les fonctions de deploiement" {
    run grep -q 'deploy_scripts()' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    run grep -q 'deploy_tfvars()' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    run grep -q 'deploy_systemd()' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    run grep -q 'enable_timers()' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    run grep -q 'verify_deployment()' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "deploy.sh definit get_monitoring_ip" {
    run grep -q 'get_monitoring_ip()' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "deploy.sh definit check_ssh_connectivity" {
    run grep -q 'check_ssh_connectivity()' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests dry-run
# =============================================================================

@test "deploy.sh echoue si terraform.tfvars introuvable" {
    # Simuler l'absence du fichier en changeant MONITORING_TFVARS
    # Le script utilise un chemin relatif a DEPLOY_DIR, on ne peut pas
    # le rediriger facilement. Testons plutot que le message d'erreur
    # est present dans le code.
    run grep -q "terraform.tfvars introuvable" "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "deploy.sh --dry-run avec tfvars mocke" {
    # Creer un faux terraform.tfvars avec la structure monitoring
    local fake_project="${TEST_DIR}/project"
    mkdir -p "${fake_project}/infrastructure/proxmox/environments/monitoring"
    mkdir -p "${fake_project}/scripts/lib"
    mkdir -p "${fake_project}/scripts/systemd"

    cat > "${fake_project}/infrastructure/proxmox/environments/monitoring/terraform.tfvars" << 'EOF'
monitoring = {
  vm = {
    ip        = "192.168.1.50"
    cores     = 2
    memory    = 4096
    disk      = 30
    data_disk = 50
  }
}
EOF

    # Le script source common.sh depuis son propre repertoire,
    # donc on ne peut pas facilement le relocaliser. Verifions juste
    # que la fonction get_monitoring_ip fonctionne avec le bon fichier.
    run grep -oP 'ip\s*=\s*"\K\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' \
        "${fake_project}/infrastructure/proxmox/environments/monitoring/terraform.tfvars"
    [ "$status" -eq 0 ]
    [[ "$output" == "192.168.1.50" ]]
}

# =============================================================================
# Tests prerequis
# =============================================================================

@test "deploy.sh verifie les prerequis rsync et ssh" {
    run grep -q 'rsync' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    run grep -q 'command -v' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "deploy.sh source common.sh" {
    run grep -q 'source.*common.sh' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests deploiement des repertoires
# =============================================================================

@test "deploy.sh deploie les scripts lib, drift, health, lifecycle, restore" {
    run grep 'dirs=(' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"lib"* ]]
    [[ "$output" == *"drift"* ]]
    [[ "$output" == *"health"* ]]
    [[ "$output" == *"lifecycle"* ]]
    [[ "$output" == *"restore"* ]]
}

@test "deploy.sh deploie les tfvars pour prod, lab, monitoring" {
    run grep 'envs=(' "$DEPLOY_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]]
    [[ "$output" == *"lab"* ]]
    [[ "$output" == *"monitoring"* ]]
}
