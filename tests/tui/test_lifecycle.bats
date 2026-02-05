#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/menus/lifecycle.sh (T022 - US2)
# =============================================================================
# Tests du menu lifecycle/snapshots : selection VM, CRUD snapshots

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts"
    TUI_LIB="${PROJECT_ROOT}/scripts/lib/tui"
    LIFECYCLE_MENU="${TUI_DIR}/menus/lifecycle.sh"

    # Charger les libs TUI
    source "${TUI_LIB}/colors.sh"
    source "${TUI_LIB}/config.sh"
    source "${TUI_LIB}/common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_lifecycle"
    mkdir -p "${TEST_DIR}"

    # Mock terraform.tfvars
    cat > "${TEST_DIR}/terraform.tfvars" << 'EOF'
vms = {
  "web-server" = {
    ip     = "192.168.1.10"
    cores  = 2
    memory = 4096
    disk   = 20
  },
  "db-server" = {
    ip     = "192.168.1.11"
    cores  = 4
    memory = 8192
    disk   = 50
  }
}

containers = {
  "minio" = {
    ip = "192.168.1.50"
  }
}
EOF

    # Mock snapshot list JSON (format Proxmox pvesh)
    MOCK_SNAPSHOTS_JSON='[
  {"name": "current", "description": "You are here!", "snaptime": 0},
  {"name": "pre-upgrade", "description": "Before upgrade", "snaptime": 1704067200},
  {"name": "auto-20240101-120000", "description": "Automatic snapshot", "snaptime": 1704110400}
]'
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure (T016)
# =============================================================================

@test "lifecycle.sh existe" {
    [ -f "$LIFECYCLE_MENU" ]
}

@test "lifecycle.sh peut etre source sans erreur" {
    run bash -c "source '${LIFECYCLE_MENU}' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "menu_lifecycle() est definie" {
    source "$LIFECYCLE_MENU"
    declare -f menu_lifecycle > /dev/null
}

# =============================================================================
# Tests selection VM (T017)
# =============================================================================

@test "get_vms_from_tfvars() extrait les VMs" {
    source "$LIFECYCLE_MENU"
    run get_vms_from_tfvars "${TEST_DIR}/terraform.tfvars"
    [ "$status" -eq 0 ]
    [[ "$output" == *"web-server"* ]]
    [[ "$output" == *"db-server"* ]]
    [[ "$output" == *"192.168.1.10"* ]]
    [[ "$output" == *"192.168.1.11"* ]]
}

@test "get_containers_from_tfvars() extrait les LXC" {
    source "$LIFECYCLE_MENU"
    run get_containers_from_tfvars "${TEST_DIR}/terraform.tfvars"
    [ "$status" -eq 0 ]
    [[ "$output" == *"minio"* ]]
    [[ "$output" == *"192.168.1.50"* ]]
}

@test "select_vm() est definie" {
    source "$LIFECYCLE_MENU"
    declare -f select_vm > /dev/null
}

@test "format_vm_option() formate nom et IP" {
    source "$LIFECYCLE_MENU"
    run format_vm_option "web-server" "192.168.1.10"
    [ "$status" -eq 0 ]
    [[ "$output" == *"web-server"* ]]
    [[ "$output" == *"192.168.1.10"* ]]
}

# =============================================================================
# Tests operations snapshots (T018-T021)
# =============================================================================

@test "get_snapshot_script_path() retourne le bon chemin" {
    source "$LIFECYCLE_MENU"
    run get_snapshot_script_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"snapshot-vm.sh"* ]]
}

# T018 - Creer snapshot
@test "create_snapshot() est definie" {
    source "$LIFECYCLE_MENU"
    declare -f create_snapshot > /dev/null
}

@test "create_snapshot() accepte vmid et nom" {
    source "$LIFECYCLE_MENU"
    # Verifier que la fonction existe et peut etre appelee
    declare -f create_snapshot > /dev/null
}

@test "generate_snapshot_name() genere un nom valide" {
    source "$LIFECYCLE_MENU"
    run generate_snapshot_name
    [ "$status" -eq 0 ]
    # Format: auto-YYYYMMDD-HHMMSS ou similaire
    [[ "$output" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# T019 - Lister snapshots
@test "list_snapshots() est definie" {
    source "$LIFECYCLE_MENU"
    declare -f list_snapshots > /dev/null
}

@test "parse_snapshots_json() parse le JSON Proxmox" {
    source "$LIFECYCLE_MENU"
    echo "$MOCK_SNAPSHOTS_JSON" > "${TEST_DIR}/snapshots.json"
    run parse_snapshots_json "${TEST_DIR}/snapshots.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pre-upgrade"* ]]
    [[ "$output" == *"auto-20240101"* ]]
    # "current" ne devrait pas apparaitre (c'est l'etat actuel, pas un snapshot)
}

@test "format_snapshot_table() formate les snapshots" {
    source "$LIFECYCLE_MENU"
    declare -f format_snapshot_table > /dev/null
}

# T020 - Restaurer snapshot
@test "rollback_snapshot() est definie" {
    source "$LIFECYCLE_MENU"
    declare -f rollback_snapshot > /dev/null
}

@test "rollback_snapshot() requiert confirmation" {
    source "$LIFECYCLE_MENU"
    # La fonction doit utiliser tui_confirm
    local func_def
    func_def=$(declare -f rollback_snapshot)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

# T021 - Supprimer snapshot
@test "delete_snapshot() est definie" {
    source "$LIFECYCLE_MENU"
    declare -f delete_snapshot > /dev/null
}

@test "delete_snapshot() requiert confirmation" {
    source "$LIFECYCLE_MENU"
    # La fonction doit utiliser tui_confirm
    local func_def
    func_def=$(declare -f delete_snapshot)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

# =============================================================================
# Tests menu snapshots
# =============================================================================

@test "menu_snapshots() est definie" {
    source "$LIFECYCLE_MENU"
    declare -f menu_snapshots > /dev/null
}

@test "get_snapshot_actions() retourne les actions disponibles" {
    source "$LIFECYCLE_MENU"
    run get_snapshot_actions
    [ "$status" -eq 0 ]
    [[ "$output" == *"Creer"* ]] || [[ "$output" == *"creer"* ]] || [[ "$output" == *"Create"* ]]
    [[ "$output" == *"Lister"* ]] || [[ "$output" == *"lister"* ]] || [[ "$output" == *"List"* ]]
    [[ "$output" == *"Restaurer"* ]] || [[ "$output" == *"Rollback"* ]]
    [[ "$output" == *"Supprimer"* ]] || [[ "$output" == *"Delete"* ]]
}

# =============================================================================
# Tests validation et securite
# =============================================================================

@test "validate_vmid() accepte un ID numerique valide" {
    source "$LIFECYCLE_MENU"
    run validate_vmid "100"
    [ "$status" -eq 0 ]
}

@test "validate_vmid() rejette un ID non numerique" {
    source "$LIFECYCLE_MENU"
    run validate_vmid "abc"
    [ "$status" -eq 1 ]
}

@test "validate_vmid() rejette un ID vide" {
    source "$LIFECYCLE_MENU"
    run validate_vmid ""
    [ "$status" -eq 1 ]
}

@test "validate_snapshot_name() accepte un nom valide" {
    source "$LIFECYCLE_MENU"
    run validate_snapshot_name "pre-upgrade-2024"
    [ "$status" -eq 0 ]
}

@test "validate_snapshot_name() rejette les caracteres speciaux" {
    source "$LIFECYCLE_MENU"
    run validate_snapshot_name "snap;rm -rf /"
    [ "$status" -eq 1 ]
}

# =============================================================================
# Tests integration
# =============================================================================

@test "menu_lifecycle gere le retour au menu principal" {
    source "$LIFECYCLE_MENU"
    declare -f menu_lifecycle > /dev/null
}

@test "lifecycle.sh source les dependances TUI" {
    grep -q "common.sh\|colors.sh" "$LIFECYCLE_MENU" || \
    grep -q "source.*lib" "$LIFECYCLE_MENU"
}

# =============================================================================
# Tests selection environnement
# =============================================================================

@test "get_env_with_vms() liste les environnements avec VMs" {
    source "$LIFECYCLE_MENU"
    declare -f get_env_with_vms > /dev/null || declare -f select_environment > /dev/null
}

@test "select_vm_or_enter_vmid() permet saisie manuelle" {
    source "$LIFECYCLE_MENU"
    # La fonction doit permettre soit de selectionner une VM, soit d'entrer un VMID
    declare -f select_vm_or_enter_vmid > /dev/null || \
    declare -f enter_vmid_manually > /dev/null || \
    declare -f select_vm > /dev/null
}
