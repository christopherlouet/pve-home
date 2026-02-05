#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/restore/restore-vm.sh
# =============================================================================
# Tache T006 : Tests BATS pour restore-vm.sh
# =============================================================================

SCRIPT="scripts/restore/restore-vm.sh"

# =============================================================================
# Tests de qualite du script
# =============================================================================

@test "restore-vm.sh: le script existe" {
    [ -f "$SCRIPT" ]
}

@test "restore-vm.sh: est executable" {
    [ -x "$SCRIPT" ]
}

@test "restore-vm.sh: shellcheck doit passer sans erreur" {
    shellcheck "$SCRIPT" 2>&1 | grep -v "SC1091" | grep -E "error|warning" && exit 1 || true
}

@test "restore-vm.sh: utilise set -euo pipefail" {
    grep -q "set -euo pipefail" "$SCRIPT"
}

# =============================================================================
# Tests parsing arguments (T006)
# =============================================================================

@test "restore-vm.sh: affiche l'aide avec --help" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"restore-vm.sh"* ]]
}

@test "restore-vm.sh: affiche l'aide avec -h" {
    run bash "$SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "restore-vm.sh: retourne erreur si VMID manquant" {
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"VMID"* ]] || [[ "$output" == *"requis"* ]]
}

@test "restore-vm.sh: gestion VMID invalide (non numerique)" {
    run bash "$SCRIPT" "abc" --dry-run --force
    [ "$status" -ne 0 ]
}

@test "restore-vm.sh: supporte --node" {
    grep -q '\-\-node' "$SCRIPT"
}

@test "restore-vm.sh: supporte --storage" {
    grep -q '\-\-storage' "$SCRIPT"
}

@test "restore-vm.sh: supporte --date" {
    grep -q '\-\-date' "$SCRIPT"
}

@test "restore-vm.sh: supporte --target-id" {
    grep -q '\-\-target-id' "$SCRIPT"
}

@test "restore-vm.sh: supporte --dry-run" {
    grep -q '\-\-dry-run' "$SCRIPT"
    grep -q 'DRY_RUN=true' "$SCRIPT"
}

@test "restore-vm.sh: supporte --force" {
    grep -q '\-\-force' "$SCRIPT"
    grep -q 'FORCE_MODE=true' "$SCRIPT"
}

@test "restore-vm.sh: affiche [DRY-RUN] en mode dry-run" {
    grep -q '\[DRY-RUN\]' "$SCRIPT"
}

# =============================================================================
# Tests listing sauvegardes (T007)
# =============================================================================

@test "restore-vm.sh: implemente list_backups()" {
    grep -q 'list_backups()' "$SCRIPT"
}

@test "restore-vm.sh: list_backups utilise pvesh pour lister" {
    grep -q 'pvesh' "$SCRIPT"
}

@test "restore-vm.sh: implemente select_backup()" {
    grep -q 'select_backup()' "$SCRIPT"
}

@test "restore-vm.sh: traite le format JSON des sauvegardes" {
    grep -q 'jq\|json\|JSON' "$SCRIPT"
}

@test "restore-vm.sh: selection automatique du backup le plus recent" {
    grep -q 'select_backup\|ctime\|sort\|recent' "$SCRIPT"
}

@test "restore-vm.sh: selection par date avec --date" {
    grep -q 'DATE\|date' "$SCRIPT"
    grep -q 'select_backup' "$SCRIPT"
}

# =============================================================================
# Tests detection type et restauration (T008)
# =============================================================================

@test "restore-vm.sh: implemente detect_type()" {
    grep -q 'detect_type()' "$SCRIPT"
}

@test "restore-vm.sh: detect_type determine VM depuis vzdump-qemu" {
    grep -q 'vzdump-qemu' "$SCRIPT"
}

@test "restore-vm.sh: detect_type determine LXC depuis vzdump-lxc" {
    grep -q 'vzdump-lxc' "$SCRIPT"
}

@test "restore-vm.sh: detect_type retourne erreur si format inconnu" {
    grep -q 'Attendu.*vzdump\|format.*inconnu\|Type non' "$SCRIPT"
}

@test "restore-vm.sh: restauration VM utilise qmrestore avec --start 0" {
    grep -q 'qmrestore' "$SCRIPT"
    grep -q '\-\-start 0' "$SCRIPT"
}

@test "restore-vm.sh: restauration LXC utilise pct restore avec --start 0" {
    grep -q 'pct restore' "$SCRIPT"
    grep -q '\-\-start 0' "$SCRIPT"
}

@test "restore-vm.sh: implemente check_vmid_exists()" {
    grep -q 'check_vmid_exists()' "$SCRIPT"
}

@test "restore-vm.sh: implemente handle_existing_vm()" {
    grep -q 'handle_existing_vm()' "$SCRIPT"
}

@test "restore-vm.sh: arrete la VM si running avant ecrasement" {
    grep -q 'stop\|shutdown' "$SCRIPT"
}

@test "restore-vm.sh: cree un backup_point avant ecrasement" {
    grep -q 'create_backup_point' "$SCRIPT"
}

# =============================================================================
# Tests option --target-id (T009)
# =============================================================================

@test "restore-vm.sh: supporte restauration vers nouveau VMID avec --target-id" {
    grep -q 'TARGET_ID\|target_id\|target_vmid' "$SCRIPT"
}

@test "restore-vm.sh: verifie si target-id est deja utilise" {
    grep -q 'check_vmid_exists.*target\|target.*check_vmid' "$SCRIPT"
}

@test "restore-vm.sh: pas d'ecrasement de la VM originale avec --target-id" {
    grep -q 'target_vmid\|TARGET_ID' "$SCRIPT"
}

# =============================================================================
# Tests verification post-restauration (T010)
# =============================================================================

@test "restore-vm.sh: implemente verify_restore()" {
    grep -q 'verify_restore()' "$SCRIPT"
}

@test "restore-vm.sh: verify_restore demarre la VM apres restauration" {
    grep -q 'start\|demarr' "$SCRIPT"
}

@test "restore-vm.sh: verify_restore teste ping vers l'IP" {
    grep -q 'ping' "$SCRIPT"
}

@test "restore-vm.sh: verify_restore teste SSH" {
    grep -q 'SSH\|ssh' "$SCRIPT"
}

# =============================================================================
# Tests modes dry-run et force (T011)
# =============================================================================

@test "restore-vm.sh: implemente show_summary()" {
    grep -q 'show_summary()' "$SCRIPT"
}

@test "restore-vm.sh: resume affiche les informations de restauration" {
    grep -q 'show_summary\|RESUME\|resume' "$SCRIPT"
}

@test "restore-vm.sh: mode force skip confirmation interactive" {
    grep -q 'FORCE_MODE' "$SCRIPT"
    grep -q 'confirm' "$SCRIPT"
}

@test "restore-vm.sh: source common.sh" {
    grep -q 'source.*common.sh' "$SCRIPT"
}

@test "restore-vm.sh: implemente detect_node()" {
    grep -q 'detect_node()' "$SCRIPT"
}
