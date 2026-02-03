#!/usr/bin/env bats
# =============================================================================
# Tests BATS : scripts/lifecycle/expire-lab-vms.sh
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/lifecycle" && pwd)"
    export LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
    export EXPIRE_SCRIPT="${SCRIPT_DIR}/expire-lab-vms.sh"

    # Source common.sh pour les fonctions utilitaires
    source "${LIB_DIR}/common.sh"

    # Mock tfvars pour les tests
    mkdir -p "${TEST_DIR}/infrastructure/proxmox/environments/lab"
    echo 'pve_ip = "192.168.1.101"' > "${TEST_DIR}/infrastructure/proxmox/environments/lab/terraform.tfvars"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests de base
# =============================================================================

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

@test "expire-lab-vms.sh passe shellcheck" {
    if ! command -v shellcheck &>/dev/null; then
        skip "shellcheck non installe"
    fi
    # -x permet de suivre les fichiers sources, -e SC1091 ignore les fichiers non trouves
    run shellcheck -x -e SC1091 "$EXPIRE_SCRIPT"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests parsing arguments
# =============================================================================

@test "expire-lab-vms.sh accepte --node" {
    run "$EXPIRE_SCRIPT" --help
    [[ "$output" == *"--node"* ]]
}

@test "expire-lab-vms.sh accepte --force" {
    run "$EXPIRE_SCRIPT" --help
    [[ "$output" == *"--force"* ]]
}

# =============================================================================
# Tests format date expiration
# =============================================================================

@test "format date aujourd'hui YYYY-MM-DD" {
    local today
    today=$(date +%Y-%m-%d)
    # Verifier format
    [[ "$today" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

@test "comparaison date expiree detectee" {
    local today="2025-02-03"
    local expire_date="2025-02-01"
    # En bash, comparaison string fonctionne pour YYYY-MM-DD
    [[ "$expire_date" < "$today" ]]
}

@test "comparaison date future non expiree" {
    local today="2025-02-03"
    local expire_date="2025-02-10"
    [[ ! "$expire_date" < "$today" ]]
}

@test "comparaison date meme jour = expire" {
    local today="2025-02-03"
    local expire_date="2025-02-03"
    # Script traite egal comme expire
    [[ "$expire_date" < "$today" || "$expire_date" == "$today" ]]
}

# =============================================================================
# Tests parsing tags expires:YYYY-MM-DD
# =============================================================================

@test "extraction tag expires depuis tags simples" {
    local tags="expires:2025-02-15"
    local expire_date=""
    for tag in ${tags//;/ }; do
        if [[ "$tag" == expires:* ]]; then
            expire_date="${tag#expires:}"
        fi
    done
    [ "$expire_date" = "2025-02-15" ]
}

@test "extraction tag expires depuis tags multiples" {
    local tags="env:lab;expires:2025-03-01;owner:chris"
    local expire_date=""
    IFS=';' read -ra tag_array <<< "$tags"
    for tag in "${tag_array[@]}"; do
        if [[ "$tag" == expires:* ]]; then
            expire_date="${tag#expires:}"
        fi
    done
    [ "$expire_date" = "2025-03-01" ]
}

@test "extraction tag expires absent retourne vide" {
    local tags="env:lab;owner:chris"
    local expire_date=""
    IFS=';' read -ra tag_array <<< "$tags"
    for tag in "${tag_array[@]}"; do
        if [[ "$tag" == expires:* ]]; then
            expire_date="${tag#expires:}"
        fi
    done
    [ -z "$expire_date" ]
}

@test "tag expires avec format invalide" {
    local tags="expires:invalid-date"
    local expire_date=""
    for tag in ${tags//;/ }; do
        if [[ "$tag" == expires:* ]]; then
            expire_date="${tag#expires:}"
        fi
    done
    # Le tag est extrait mais le format est invalide
    [ "$expire_date" = "invalid-date" ]
    # La validation devrait echouer
    [[ ! "$expire_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

# =============================================================================
# Tests parsing JSON Proxmox (simulation)
# =============================================================================

@test "parsing JSON resources vide" {
    local json='[]'
    local count
    count=$(echo "$json" | python3 -c "
import sys, json
resources = json.load(sys.stdin)
print(len(resources))
" 2>/dev/null)
    [ "$count" = "0" ]
}

@test "parsing JSON resources avec VMs" {
    local json='[{"vmid": 100, "name": "test-vm", "status": "running", "tags": "expires:2025-02-01"}]'
    local output
    output=$(echo "$json" | python3 -c "
import sys, json
resources = json.load(sys.stdin)
for r in resources:
    vmid = r.get('vmid', '')
    name = r.get('name', '')
    status = r.get('status', '')
    tags = r.get('tags', '')
    for tag in tags.split(';'):
        if tag.startswith('expires:'):
            expire_date = tag.split(':')[1]
            print(f'{vmid}|{name}|{status}|{expire_date}')
" 2>/dev/null)
    [ "$output" = "100|test-vm|running|2025-02-01" ]
}

@test "parsing JSON resources sans tag expires" {
    local json='[{"vmid": 100, "name": "test-vm", "status": "running", "tags": "env:prod"}]'
    local output
    output=$(echo "$json" | python3 -c "
import sys, json
resources = json.load(sys.stdin)
for r in resources:
    tags = r.get('tags', '')
    for tag in tags.split(';'):
        if tag.startswith('expires:'):
            print('found')
" 2>/dev/null)
    [ -z "$output" ]
}

@test "parsing JSON resources VM stoppee" {
    local json='[{"vmid": 101, "name": "stopped-vm", "status": "stopped", "tags": "expires:2025-01-01"}]'
    local status_val
    status_val=$(echo "$json" | python3 -c "
import sys, json
resources = json.load(sys.stdin)
for r in resources:
    print(r.get('status', ''))
" 2>/dev/null)
    [ "$status_val" = "stopped" ]
}

# =============================================================================
# Tests logique expiration
# =============================================================================

@test "VM running + expiree = action requise" {
    local status="running"
    local expire_date="2025-01-01"
    local today="2025-02-03"
    local action_required=false

    if [[ "$expire_date" < "$today" || "$expire_date" == "$today" ]]; then
        if [[ "$status" == "running" ]]; then
            action_required=true
        fi
    fi

    [ "$action_required" = "true" ]
}

@test "VM stopped + expiree = pas d'action" {
    local status="stopped"
    local expire_date="2025-01-01"
    local today="2025-02-03"
    local action_required=false

    if [[ "$expire_date" < "$today" || "$expire_date" == "$today" ]]; then
        if [[ "$status" == "running" ]]; then
            action_required=true
        fi
    fi

    [ "$action_required" = "false" ]
}

@test "VM running + non expiree = pas d'action" {
    local status="running"
    local expire_date="2025-12-31"
    local today="2025-02-03"
    local action_required=false

    if [[ "$expire_date" < "$today" || "$expire_date" == "$today" ]]; then
        if [[ "$status" == "running" ]]; then
            action_required=true
        fi
    fi

    [ "$action_required" = "false" ]
}

# =============================================================================
# Tests metriques Prometheus
# =============================================================================

@test "format metrique lab expiration valide" {
    local prom_output
    prom_output=$(cat << 'EOF'
# HELP pve_lab_expired_total VMs/LXC expired and stopped
# TYPE pve_lab_expired_total gauge
pve_lab_expired_total 2
# HELP pve_lab_expiration_last_check Last expiration check timestamp
# TYPE pve_lab_expiration_last_check gauge
pve_lab_expiration_last_check 1234567890
EOF
)
    [[ "$prom_output" == *"# HELP pve_lab_expired_total"* ]]
    [[ "$prom_output" == *"# TYPE pve_lab_expired_total gauge"* ]]
    [[ "$prom_output" == *"pve_lab_expired_total 2"* ]]
}

# =============================================================================
# Tests mode dry-run
# =============================================================================

@test "expire-lab-vms.sh source common.sh" {
    grep -q 'source.*common.sh' "$EXPIRE_SCRIPT"
}

@test "expire-lab-vms.sh utilise DRY_RUN" {
    grep -q 'DRY_RUN' "$EXPIRE_SCRIPT"
}

@test "expire-lab-vms.sh affiche [DRY-RUN] en mode simulation" {
    grep -q '\[DRY-RUN\]' "$EXPIRE_SCRIPT"
}

# =============================================================================
# Tests protection lab uniquement
# =============================================================================

@test "expire-lab-vms.sh utilise tfvars lab par defaut" {
    grep -q 'environments/lab/terraform.tfvars' "$EXPIRE_SCRIPT"
}

# =============================================================================
# Tests securite
# =============================================================================

@test "expire-lab-vms.sh utilise set -euo pipefail" {
    grep -q "set -euo pipefail" "$EXPIRE_SCRIPT"
}

@test "expire-lab-vms.sh utilise ssh_exec pour SSH securise" {
    grep -q "ssh_exec" "$EXPIRE_SCRIPT"
}

@test "expire-lab-vms.sh n'a pas de StrictHostKeyChecking hardcode" {
    run grep "StrictHostKeyChecking" "$EXPIRE_SCRIPT"
    [ "$status" -ne 0 ]
}

# =============================================================================
# Tests edge cases
# =============================================================================

@test "gestion tags vides" {
    local tags=""
    local expire_date=""
    for tag in ${tags//;/ }; do
        if [[ "$tag" == expires:* ]]; then
            expire_date="${tag#expires:}"
        fi
    done
    [ -z "$expire_date" ]
}

@test "gestion vmid numerique" {
    local vmid="100"
    [[ "$vmid" =~ ^[0-9]+$ ]]
}

@test "gestion vmid avec zeros" {
    local vmid="00100"
    # Proxmox utilise des VMIDs numeriques, les zeros de tete sont valides
    [[ "$vmid" =~ ^[0-9]+$ ]]
}
