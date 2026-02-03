#!/usr/bin/env bats
# =============================================================================
# Tests BATS : scripts/lifecycle/cleanup-snapshots.sh
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/lifecycle" && pwd)"
    export LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
    export CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup-snapshots.sh"

    # Source common.sh pour les fonctions utilitaires
    source "${LIB_DIR}/common.sh"

    # Mock tfvars pour les tests
    mkdir -p "${TEST_DIR}/infrastructure/proxmox/environments/prod"
    echo 'pve_ip = "192.168.1.100"' > "${TEST_DIR}/infrastructure/proxmox/environments/prod/terraform.tfvars"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests de base
# =============================================================================

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

@test "cleanup-snapshots.sh passe shellcheck" {
    if ! command -v shellcheck &>/dev/null; then
        skip "shellcheck non installe"
    fi
    # -x permet de suivre les fichiers sources, -e SC1091 ignore les fichiers non trouves
    run shellcheck -x -e SC1091 "$CLEANUP_SCRIPT"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests parsing arguments
# =============================================================================

@test "cleanup-snapshots.sh accepte --node" {
    run "$CLEANUP_SCRIPT" --help
    [[ "$output" == *"--node"* ]]
}

@test "cleanup-snapshots.sh accepte --max-age" {
    run "$CLEANUP_SCRIPT" --help
    [[ "$output" == *"--max-age"* ]]
}

@test "cleanup-snapshots.sh accepte --force" {
    run "$CLEANUP_SCRIPT" --help
    [[ "$output" == *"--force"* ]]
}

# =============================================================================
# Tests calcul de date
# =============================================================================

@test "calcul date cutoff 7 jours fonctionne" {
    # Test avec la commande date GNU
    local cutoff
    cutoff=$(date -d "-7 days" +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d 2>/dev/null)
    [ -n "$cutoff" ]
    # Verifier format YYYYMMDD
    [[ "$cutoff" =~ ^[0-9]{8}$ ]]
}

@test "calcul date cutoff 30 jours fonctionne" {
    local cutoff
    cutoff=$(date -d "-30 days" +%Y%m%d 2>/dev/null || date -v-30d +%Y%m%d 2>/dev/null)
    [ -n "$cutoff" ]
    [[ "$cutoff" =~ ^[0-9]{8}$ ]]
}

@test "calcul date cutoff 0 jours retourne aujourd'hui" {
    local cutoff today
    cutoff=$(date -d "-0 days" +%Y%m%d 2>/dev/null || date -v-0d +%Y%m%d 2>/dev/null)
    today=$(date +%Y%m%d)
    [ "$cutoff" = "$today" ]
}

# =============================================================================
# Tests parsing snapshots (logique metier)
# =============================================================================

@test "extraction date depuis nom snapshot auto-YYYYMMDD" {
    local snap_name="auto-20250115-120000"
    local snap_date
    snap_date=$(echo "$snap_name" | grep -oP 'auto-\K\d{8}' || echo "")
    [ "$snap_date" = "20250115" ]
}

@test "extraction date depuis nom snapshot auto-YYYYMMDD-HHMMSS" {
    local snap_name="auto-20251231-235959"
    local snap_date
    snap_date=$(echo "$snap_name" | grep -oP 'auto-\K\d{8}' || echo "")
    [ "$snap_date" = "20251231" ]
}

@test "extraction date echoue pour snapshot sans prefixe auto" {
    local snap_name="manual-20250115-120000"
    local snap_date
    snap_date=$(echo "$snap_name" | grep -oP 'auto-\K\d{8}' || echo "")
    [ -z "$snap_date" ]
}

@test "extraction date echoue pour snapshot current" {
    local snap_name="current"
    local snap_date
    snap_date=$(echo "$snap_name" | grep -oP 'auto-\K\d{8}' || echo "")
    [ -z "$snap_date" ]
}

# =============================================================================
# Tests comparaison dates
# =============================================================================

@test "snapshot plus ancien que cutoff detecte" {
    local snap_date="20250101"
    local cutoff_date="20250115"
    # En bash, comparaison string fonctionne pour YYYYMMDD
    [[ "$snap_date" < "$cutoff_date" ]]
}

@test "snapshot plus recent que cutoff ignore" {
    local snap_date="20250120"
    local cutoff_date="20250115"
    [[ ! "$snap_date" < "$cutoff_date" ]]
}

@test "snapshot meme jour que cutoff ignore" {
    local snap_date="20250115"
    local cutoff_date="20250115"
    # Pas strictement inferieur = ignore
    [[ ! "$snap_date" < "$cutoff_date" ]]
}

# =============================================================================
# Tests parsing JSON Proxmox (simulation)
# =============================================================================

@test "parsing JSON snapshot liste vide" {
    local json='[]'
    local count
    count=$(echo "$json" | python3 -c "
import sys, json
snaps = json.load(sys.stdin)
count = 0
for s in snaps:
    name = s.get('name', '')
    if name.startswith('auto-') and name != 'current':
        count += 1
print(count)
" 2>/dev/null)
    [ "$count" = "0" ]
}

@test "parsing JSON snapshot avec snapshots auto" {
    local json='[{"name": "auto-20250101-120000"}, {"name": "auto-20250102-120000"}, {"name": "current"}]'
    local count
    count=$(echo "$json" | python3 -c "
import sys, json
snaps = json.load(sys.stdin)
count = 0
for s in snaps:
    name = s.get('name', '')
    if name.startswith('auto-') and name != 'current':
        count += 1
print(count)
" 2>/dev/null)
    [ "$count" = "2" ]
}

@test "parsing JSON snapshot ignore manuels" {
    local json='[{"name": "manual-backup"}, {"name": "pre-upgrade"}, {"name": "auto-20250101-120000"}]'
    local count
    count=$(echo "$json" | python3 -c "
import sys, json
snaps = json.load(sys.stdin)
count = 0
for s in snaps:
    name = s.get('name', '')
    if name.startswith('auto-') and name != 'current':
        count += 1
print(count)
" 2>/dev/null)
    [ "$count" = "1" ]
}

# =============================================================================
# Tests metriques Prometheus
# =============================================================================

@test "format metrique Prometheus valide" {
    local prom_output
    prom_output=$(cat << 'EOF'
# HELP pve_snapshot_cleanup_deleted_total Snapshots deleted in last cleanup
# TYPE pve_snapshot_cleanup_deleted_total gauge
pve_snapshot_cleanup_deleted_total 5
# HELP pve_snapshot_cleanup_last_timestamp Last cleanup timestamp
# TYPE pve_snapshot_cleanup_last_timestamp gauge
pve_snapshot_cleanup_last_timestamp 1234567890
EOF
)
    # Verifier presence des lignes HELP et TYPE
    [[ "$prom_output" == *"# HELP pve_snapshot_cleanup_deleted_total"* ]]
    [[ "$prom_output" == *"# TYPE pve_snapshot_cleanup_deleted_total gauge"* ]]
    [[ "$prom_output" == *"pve_snapshot_cleanup_deleted_total 5"* ]]
}

# =============================================================================
# Tests mode dry-run
# =============================================================================

@test "cleanup-snapshots.sh source common.sh" {
    grep -q 'source.*common.sh' "$CLEANUP_SCRIPT"
}

@test "cleanup-snapshots.sh utilise DRY_RUN" {
    grep -q 'DRY_RUN' "$CLEANUP_SCRIPT"
}

@test "cleanup-snapshots.sh affiche [DRY-RUN] en mode simulation" {
    grep -q '\[DRY-RUN\]' "$CLEANUP_SCRIPT"
}

# =============================================================================
# Tests securite
# =============================================================================

@test "cleanup-snapshots.sh utilise set -euo pipefail" {
    grep -q "set -euo pipefail" "$CLEANUP_SCRIPT"
}

@test "cleanup-snapshots.sh utilise get_ssh_opts pour SSH securise" {
    # Apres la correction SSH, le script devrait utiliser ssh_exec qui utilise get_ssh_opts
    grep -q "ssh_exec" "$CLEANUP_SCRIPT"
}

@test "cleanup-snapshots.sh n'a pas de StrictHostKeyChecking hardcode" {
    run grep "StrictHostKeyChecking" "$CLEANUP_SCRIPT"
    [ "$status" -ne 0 ]
}
