#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/restore/rebuild-monitoring.sh
# =============================================================================
# User Story US4 - Reconstruire la stack monitoring
# =============================================================================

SCRIPT="scripts/restore/rebuild-monitoring.sh"

# =============================================================================
# Tests de qualite du script
# =============================================================================

@test "rebuild-monitoring.sh: le script existe" {
    [ -f "$SCRIPT" ]
}

@test "rebuild-monitoring.sh: shellcheck doit passer sans erreur" {
    shellcheck "$SCRIPT" 2>&1 | grep -v "SC1091" | grep -E "error|warning" && exit 1 || true
}

@test "rebuild-monitoring.sh: utilise set -euo pipefail" {
    grep -q "set -euo pipefail" "$SCRIPT"
}

# =============================================================================
# Tests parsing arguments (T018)
# =============================================================================

@test "rebuild-monitoring.sh: doit afficher l'aide avec --help" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "rebuild-monitoring.sh" ]]
}

@test "rebuild-monitoring.sh: doit afficher l'aide avec -h" {
    run bash "$SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "rebuild-monitoring.sh: doit rejeter une option inconnue" {
    run bash "$SCRIPT" --invalid-option
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Option inconnue" ]]
}

@test "rebuild-monitoring.sh: doit rejeter un mode invalide" {
    run bash "$SCRIPT" --mode invalid
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Mode invalide" ]]
}

@test "rebuild-monitoring.sh: doit rejeter un VMID non numerique" {
    run bash "$SCRIPT" --vmid abc
    [ "$status" -ne 0 ]
    [[ "$output" =~ "VMID invalide" ]]
}

@test "rebuild-monitoring.sh: supporte mode restore" {
    grep -q '"restore"' "$SCRIPT"
}

@test "rebuild-monitoring.sh: supporte mode rebuild" {
    grep -q '"rebuild"' "$SCRIPT"
}

@test "rebuild-monitoring.sh: supporte --dry-run" {
    grep -q '\-\-dry-run' "$SCRIPT"
    grep -q 'DRY_RUN=true' "$SCRIPT"
}

@test "rebuild-monitoring.sh: supporte --force" {
    grep -q '\-\-force' "$SCRIPT"
    grep -q 'FORCE_MODE=true' "$SCRIPT"
}

# =============================================================================
# Tests mode restore (T018)
# =============================================================================

@test "rebuild-monitoring.sh: mode restore appelle restore-vm.sh" {
    grep -q 'restore-vm.sh' "$SCRIPT"
    grep -q 'restore_vm_monitoring()' "$SCRIPT"
}

# =============================================================================
# Tests mode rebuild (T018)
# =============================================================================

@test "rebuild-monitoring.sh: mode rebuild avertit perte historique metriques" {
    grep -q 'historique.*metriques sera perdu' "$SCRIPT"
}

@test "rebuild-monitoring.sh: mode rebuild execute terraform apply -target=module.monitoring_stack" {
    grep -q 'terraform apply.*module.monitoring_stack' "$SCRIPT"
}

# =============================================================================
# Tests verification services Docker (T018, T020)
# =============================================================================

@test "rebuild-monitoring.sh: implemente verify_docker_services" {
    grep -q 'verify_docker_services()' "$SCRIPT"
    grep -q 'docker ps' "$SCRIPT"
}

@test "rebuild-monitoring.sh: verifie prometheus, grafana, alertmanager" {
    grep -q '"prometheus"' "$SCRIPT"
    grep -q '"grafana"' "$SCRIPT"
    grep -q '"alertmanager"' "$SCRIPT"
}

# =============================================================================
# Tests verifications HTTP (T020)
# =============================================================================

@test "rebuild-monitoring.sh: implemente verify_prometheus avec healthcheck" {
    grep -q 'verify_prometheus()' "$SCRIPT"
    grep -q '9090.*healthy\|DEFAULT_PROMETHEUS_PORT.*9090' "$SCRIPT"
}

@test "rebuild-monitoring.sh: implemente verify_grafana avec healthcheck" {
    grep -q 'verify_grafana()' "$SCRIPT"
    grep -q '3000.*health\|DEFAULT_GRAFANA_PORT.*3000' "$SCRIPT"
}

@test "rebuild-monitoring.sh: implemente verify_alertmanager avec healthcheck" {
    grep -q 'verify_alertmanager()' "$SCRIPT"
    grep -q '9093.*healthy\|DEFAULT_ALERTMANAGER_PORT.*9093' "$SCRIPT"
}

@test "rebuild-monitoring.sh: definit les ports par defaut" {
    grep -q 'DEFAULT_PROMETHEUS_PORT=9090' "$SCRIPT"
    grep -q 'DEFAULT_GRAFANA_PORT=3000' "$SCRIPT"
    grep -q 'DEFAULT_ALERTMANAGER_PORT=9093' "$SCRIPT"
}

# =============================================================================
# Tests rapport (T018, T020)
# =============================================================================

@test "rebuild-monitoring.sh: affiche un resume de reconstruction" {
    grep -q 'RESUME DE RECONSTRUCTION' "$SCRIPT"
}

@test "rebuild-monitoring.sh: affiche un resume pre-execution avec actions prevues" {
    grep -q 'Actions prevues' "$SCRIPT"
}

@test "rebuild-monitoring.sh: source common.sh" {
    grep -q 'source.*common.sh' "$SCRIPT"
}

@test "rebuild-monitoring.sh: verifie les prerequis ssh et curl" {
    grep -q '"ssh"' "$SCRIPT"
    grep -q '"curl"' "$SCRIPT"
}

@test "rebuild-monitoring.sh: demande confirmation avant reconstruction" {
    grep -q 'confirm' "$SCRIPT"
}

@test "rebuild-monitoring.sh: detecte le repertoire Terraform monitoring" {
    grep -q 'detect_terraform_dir()' "$SCRIPT"
    grep -q 'monitoring' "$SCRIPT"
}

@test "rebuild-monitoring.sh: parse la config monitoring depuis tfvars" {
    grep -q 'parse_monitoring_config()' "$SCRIPT"
    grep -q 'MONITORING_IP' "$SCRIPT"
}
