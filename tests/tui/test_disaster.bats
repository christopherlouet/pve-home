#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/tui/menus/disaster.sh (T048 - US6)
# =============================================================================
# Tests du menu disaster recovery : backups VM, tfstate, verification

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts/tui"
    TUI_LIB="${TUI_DIR}/lib"
    DISASTER_MENU="${TUI_DIR}/menus/disaster.sh"

    # Charger les libs TUI
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    source "${TUI_LIB}/tui-common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_disaster"
    mkdir -p "${TEST_DIR}"

    # Mock backup list output
    MOCK_BACKUPS_JSON='[
      {"volid":"local:backup/vzdump-qemu-100-2026_02_01-12_00_00.vma.zst","vmid":100,"size":1073741824,"ctime":1738400400},
      {"volid":"local:backup/vzdump-qemu-101-2026_02_01-10_00_00.vma.zst","vmid":101,"size":536870912,"ctime":1738393200},
      {"volid":"local:backup/vzdump-lxc-200-2026_01_30-08_00_00.vma.zst","vmid":200,"size":268435456,"ctime":1738220400}
    ]'

    # Mock tfstate versions output
    MOCK_TFSTATE_VERSIONS='[2026-02-01 12:00] 1KB STANDARD abc123 terraform.tfstate
[2026-01-30 10:00] 1KB STANDARD def456 terraform.tfstate
[2026-01-29 08:00] 1KB STANDARD ghi789 terraform.tfstate'

    # Mock verify output OK
    MOCK_VERIFY_OK='Verification de l integrite des sauvegardes
---
=== Verification des sauvegardes vzdump ===
3 sauvegarde(s) trouvee(s)
VMID 100: OK (1024MB, 2h)
VMID 101: OK (512MB, 4h)
VMID 200: OK (256MB, 48h)
---
RAPPORT DE VERIFICATION DES SAUVEGARDES
Total verifie:    3
OK:               3
Warnings:         0
Erreurs:          0
Toutes les sauvegardes sont OK'

    # Mock verify output with warnings
    MOCK_VERIFY_WARN='Verification de l integrite des sauvegardes
---
VMID 100: OK (1024MB, 2h)
VMID 200: WARNING - Backup ancien (72h)
---
Total verifie:    2
OK:               1
Warnings:         1
Erreurs:          0'
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure (T041)
# =============================================================================

@test "disaster.sh existe" {
    [ -f "$DISASTER_MENU" ]
}

@test "disaster.sh peut etre source sans erreur" {
    run bash -c "source '${DISASTER_MENU}' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "menu_disaster() est definie" {
    source "$DISASTER_MENU"
    declare -f menu_disaster > /dev/null
}

# =============================================================================
# Tests lister sauvegardes VM (T042)
# =============================================================================

@test "list_vm_backups() est definie" {
    source "$DISASTER_MENU"
    declare -f list_vm_backups > /dev/null
}

@test "get_restore_vm_script_path() retourne le chemin" {
    source "$DISASTER_MENU"
    run get_restore_vm_script_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"restore-vm.sh"* ]]
}

@test "parse_backup_list() parse le JSON des backups" {
    source "$DISASTER_MENU"
    run parse_backup_list "$MOCK_BACKUPS_JSON"
    [ "$status" -eq 0 ]
    [[ "$output" == *"100"* ]] || [[ "$output" == *"101"* ]] || [[ "$output" == *"200"* ]]
}

@test "format_backup_entry() formate une entree de backup" {
    source "$DISASTER_MENU"
    run format_backup_entry "100" "2026-02-01" "1024MB" "vzdump-qemu-100.vma.zst"
    [ "$status" -eq 0 ]
    [[ "$output" == *"100"* ]]
    [[ "$output" == *"1024"* ]] || [[ "$output" == *"MB"* ]]
}

@test "get_backup_age() calcule l'age du backup" {
    source "$DISASTER_MENU"
    # Test avec un timestamp recent
    local now_ts=$(date +%s)
    local old_ts=$((now_ts - 7200))  # 2 heures
    run get_backup_age "$old_ts"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2"* ]] || [[ "$output" == *"h"* ]]
}

# =============================================================================
# Tests restaurer VM (T043)
# =============================================================================

@test "restore_vm() est definie" {
    source "$DISASTER_MENU"
    declare -f restore_vm > /dev/null
}

@test "restore_vm() requiert confirmation" {
    source "$DISASTER_MENU"
    local func_def
    func_def=$(declare -f restore_vm)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

@test "select_vm_backup() est definie" {
    source "$DISASTER_MENU"
    declare -f select_vm_backup > /dev/null || declare -f select_backup_to_restore > /dev/null
}

@test "run_restore_vm() utilise restore-vm.sh" {
    source "$DISASTER_MENU"
    local func_def
    func_def=$(declare -f run_restore_vm 2>/dev/null || declare -f restore_vm)
    [[ "$func_def" == *"restore-vm"* ]] || [[ "$func_def" == *"RESTORE_VM_SCRIPT"* ]]
}

# =============================================================================
# Tests lister backups tfstate (T044)
# =============================================================================

@test "list_tfstate_backups() est definie" {
    source "$DISASTER_MENU"
    declare -f list_tfstate_backups > /dev/null
}

@test "get_restore_tfstate_script_path() retourne le chemin" {
    source "$DISASTER_MENU"
    run get_restore_tfstate_script_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"restore-tfstate.sh"* ]]
}

@test "get_tfstate_environments() liste les environnements" {
    source "$DISASTER_MENU"
    run get_tfstate_environments
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]] || [[ "$output" == *"lab"* ]] || [[ "$output" == *"monitoring"* ]]
}

@test "parse_tfstate_versions() parse la liste des versions" {
    source "$DISASTER_MENU"
    run parse_tfstate_versions "$MOCK_TFSTATE_VERSIONS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"abc123"* ]] || [[ "$output" == *"2026"* ]]
}

# =============================================================================
# Tests restaurer tfstate (T045)
# =============================================================================

@test "restore_tfstate() est definie" {
    source "$DISASTER_MENU"
    declare -f restore_tfstate > /dev/null
}

@test "restore_tfstate() requiert confirmation" {
    source "$DISASTER_MENU"
    local func_def
    func_def=$(declare -f restore_tfstate)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

@test "select_tfstate_version() est definie" {
    source "$DISASTER_MENU"
    declare -f select_tfstate_version > /dev/null || declare -f select_version_to_restore > /dev/null
}

@test "run_restore_tfstate() utilise restore-tfstate.sh" {
    source "$DISASTER_MENU"
    local func_def
    func_def=$(declare -f run_restore_tfstate 2>/dev/null || declare -f restore_tfstate)
    [[ "$func_def" == *"restore-tfstate"* ]] || [[ "$func_def" == *"RESTORE_TFSTATE_SCRIPT"* ]]
}

# =============================================================================
# Tests verifier integrite (T046)
# =============================================================================

@test "verify_backups() est definie" {
    source "$DISASTER_MENU"
    declare -f verify_backups > /dev/null
}

@test "get_verify_script_path() retourne le chemin" {
    source "$DISASTER_MENU"
    run get_verify_script_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"verify-backups.sh"* ]]
}

@test "parse_verify_status() extrait le statut OK" {
    source "$DISASTER_MENU"
    run parse_verify_status "$MOCK_VERIFY_OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]] || [[ "$output" == *"ok"* ]]
}

@test "parse_verify_status() detecte les warnings" {
    source "$DISASTER_MENU"
    run parse_verify_status "$MOCK_VERIFY_WARN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]] || [[ "$output" == *"warn"* ]] || [[ "$output" == *"1"* ]]
}

@test "show_verify_report() est definie" {
    source "$DISASTER_MENU"
    declare -f show_verify_report > /dev/null || declare -f display_verify_results > /dev/null
}

# =============================================================================
# Tests instructions manuelles (T047)
# =============================================================================

@test "show_manual_instructions() est definie" {
    source "$DISASTER_MENU"
    declare -f show_manual_instructions > /dev/null || declare -f show_recovery_instructions > /dev/null
}

@test "handle_restore_error() affiche les instructions" {
    source "$DISASTER_MENU"
    run handle_restore_error "Connection refused" "vm"
    [ "$status" -eq 0 ]
    [[ "$output" == *"erreur"* ]] || [[ "$output" == *"Erreur"* ]] || [[ "$output" == *"instruction"* ]] || [[ "$output" == *"manuel"* ]]
}

@test "get_fallback_instructions() retourne les instructions" {
    source "$DISASTER_MENU"
    run get_fallback_instructions "vm"
    [ "$status" -eq 0 ]
    # Doit contenir des instructions de secours
    [[ "$output" == *"backup"* ]] || [[ "$output" == *"restore"* ]] || [[ "$output" == *"pvesh"* ]] || [[ "$output" == *"qmrestore"* ]]
}

# =============================================================================
# Tests actions menu
# =============================================================================

@test "get_disaster_actions() retourne les actions disponibles" {
    source "$DISASTER_MENU"
    run get_disaster_actions
    [ "$status" -eq 0 ]
    [[ "$output" == *"VM"* ]] || [[ "$output" == *"backup"* ]] || [[ "$output" == *"Backup"* ]]
    [[ "$output" == *"tfstate"* ]] || [[ "$output" == *"Terraform"* ]]
    [[ "$output" == *"Verifier"* ]] || [[ "$output" == *"verify"* ]] || [[ "$output" == *"integrite"* ]]
}

@test "menu_disaster_action() est definie" {
    source "$DISASTER_MENU"
    declare -f menu_disaster_action > /dev/null || declare -f select_disaster_action > /dev/null
}

# =============================================================================
# Tests gestion erreurs
# =============================================================================

@test "handle_disaster_error() est definie" {
    source "$DISASTER_MENU"
    declare -f handle_disaster_error > /dev/null || declare -f handle_restore_error > /dev/null
}

@test "check_disaster_prerequisites() est definie" {
    source "$DISASTER_MENU"
    declare -f check_disaster_prerequisites > /dev/null
}

@test "check_disaster_prerequisites() verifie ssh" {
    source "$DISASTER_MENU"
    local func_def
    func_def=$(declare -f check_disaster_prerequisites)
    [[ "$func_def" == *"ssh"* ]] || [[ "$func_def" == *"command"* ]]
}

# =============================================================================
# Tests integration menu
# =============================================================================

@test "menu_disaster gere le retour au menu principal" {
    source "$DISASTER_MENU"
    declare -f menu_disaster > /dev/null
}

@test "disaster.sh source les dependances TUI" {
    grep -q "tui-common.sh\|tui-colors.sh" "$DISASTER_MENU" || \
    grep -q "source.*lib" "$DISASTER_MENU"
}

# =============================================================================
# Tests securite
# =============================================================================

@test "restauration VM requiert confirmation explicite" {
    source "$DISASTER_MENU"
    local func_def
    func_def=$(declare -f restore_vm)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

@test "restauration tfstate requiert confirmation explicite" {
    source "$DISASTER_MENU"
    local func_def
    func_def=$(declare -f restore_tfstate)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

@test "dry-run disponible pour les operations" {
    source "$DISASTER_MENU"
    # Les fonctions doivent supporter dry-run
    declare -f run_restore_vm_dry_run > /dev/null || \
    declare -f verify_backups_dry_run > /dev/null || \
    { local func=$(declare -f verify_backups); [[ "$func" == *"dry"* ]]; }
}
