#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/restore/restore-tfstate.sh
# =============================================================================
# T012 - Tests BATS pour restore-tfstate.sh
# =============================================================================

SCRIPT="scripts/restore/restore-tfstate.sh"

# =============================================================================
# Tests de qualite du script
# =============================================================================

@test "restore-tfstate.sh: le script existe" {
    [ -f "$SCRIPT" ]
}

@test "restore-tfstate.sh: shellcheck doit passer sans erreur" {
    shellcheck "$SCRIPT" 2>&1 | grep -v "SC1091" | grep -E "error|warning" && exit 1 || true
}

@test "restore-tfstate.sh: utilise set -euo pipefail" {
    grep -q "set -euo pipefail" "$SCRIPT"
}

# =============================================================================
# Tests parsing arguments (T012.1)
# =============================================================================

@test "restore-tfstate.sh: --help affiche l'aide" {
    run bash "$SCRIPT" --help
    [[ $status -eq 0 ]]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--env" ]]
    [[ "$output" =~ "--list" ]]
    [[ "$output" =~ "--restore" ]]
}

@test "restore-tfstate.sh: erreur si --env manquant" {
    run bash "$SCRIPT" --list
    [[ $status -ne 0 ]]
    [[ "$output" =~ "Option --env est requise" ]]
}

@test "restore-tfstate.sh: erreur si environnement invalide" {
    run bash "$SCRIPT" --env invalid --list
    [[ $status -ne 0 ]]
    [[ "$output" =~ "Environnement invalide" ]]
    [[ "$output" =~ "prod|lab|monitoring" ]]
}

@test "restore-tfstate.sh: supporte les environnements prod, lab, monitoring" {
    grep -q 'prod' "$SCRIPT"
    grep -q 'lab' "$SCRIPT"
    grep -q 'monitoring' "$SCRIPT"
}

@test "restore-tfstate.sh: supporte --dry-run" {
    grep -q '\-\-dry-run' "$SCRIPT"
    grep -q 'DRY_RUN=true' "$SCRIPT"
}

@test "restore-tfstate.sh: affiche [DRY-RUN] en mode dry-run" {
    grep -q '\[DRY-RUN\]' "$SCRIPT"
}

@test "restore-tfstate.sh: supporte --force" {
    grep -q '\-\-force' "$SCRIPT"
    grep -q 'FORCE_MODE=true' "$SCRIPT"
}

@test "restore-tfstate.sh: erreur si --restore sans version-id" {
    run bash "$SCRIPT" --env prod --restore
    [[ $status -ne 0 ]]
    [[ "$output" =~ "version-id requis" ]]
}

# =============================================================================
# Tests validation environnement (T012.2)
# =============================================================================

@test "restore-tfstate.sh: detecte le repertoire environnement" {
    grep -q 'infrastructure/proxmox/environments' "$SCRIPT"
}

@test "restore-tfstate.sh: verifie l'existence de backend.tf" {
    grep -q 'backend.tf' "$SCRIPT"
}

# =============================================================================
# Tests listing versions (T012.3)
# =============================================================================

@test "restore-tfstate.sh: implemente list_versions()" {
    grep -q 'list_versions()' "$SCRIPT"
}

@test "restore-tfstate.sh: liste les versions avec mc ls --versions" {
    grep -q 'mc ls --versions' "$SCRIPT"
}

# =============================================================================
# Tests restauration version (T012.4)
# =============================================================================

@test "restore-tfstate.sh: implemente restore_version()" {
    grep -q 'restore_version()' "$SCRIPT"
}

@test "restore-tfstate.sh: sauvegarde version actuelle avant restauration (EF-006)" {
    grep -q 'Sauvegarde de la version actuelle' "$SCRIPT"
}

@test "restore-tfstate.sh: telecharge la version avec mc cp --version-id" {
    grep -q 'mc cp --version-id' "$SCRIPT"
}

@test "restore-tfstate.sh: execute terraform init apres restauration" {
    grep -q 'terraform init' "$SCRIPT"
}

@test "restore-tfstate.sh: execute terraform plan apres restauration" {
    grep -q 'terraform plan' "$SCRIPT"
}

# =============================================================================
# Tests mode fallback vers backend local (T012.5)
# =============================================================================

@test "restore-tfstate.sh: implemente fallback_local()" {
    grep -q 'fallback_local()' "$SCRIPT"
}

@test "restore-tfstate.sh: sauvegarde backend.tf en backend.tf.minio-backup" {
    grep -q 'backend.tf.minio-backup' "$SCRIPT"
}

@test "restore-tfstate.sh: remplace backend S3 par backend local" {
    grep -q 'backend local' "$SCRIPT"
}

@test "restore-tfstate.sh: fallback execute terraform init -migrate-state" {
    grep -q 'terraform init -migrate-state' "$SCRIPT"
}

# =============================================================================
# Tests mode retour vers Minio (T012.6)
# =============================================================================

@test "restore-tfstate.sh: implemente return_to_minio()" {
    grep -q 'return_to_minio()' "$SCRIPT"
}

@test "restore-tfstate.sh: verifie healthcheck Minio avant retour" {
    grep -q 'curl.*health\|health.*curl' "$SCRIPT" || grep -q 'healthcheck\|health' "$SCRIPT"
}

@test "restore-tfstate.sh: restaure backend.tf depuis backup lors du retour" {
    grep -q 'backend.tf.minio-backup' "$SCRIPT"
}

@test "restore-tfstate.sh: retour execute terraform init -migrate-state" {
    grep -q 'terraform init -migrate-state' "$SCRIPT"
}

# =============================================================================
# Tests configuration mc (T012.7, T012.8)
# =============================================================================

@test "restore-tfstate.sh: implemente configure_mc()" {
    grep -q 'configure_mc()' "$SCRIPT"
}

@test "restore-tfstate.sh: configure mc avec alias homelab" {
    grep -q 'mc alias set' "$SCRIPT"
    grep -q 'homelab' "$SCRIPT"
}

@test "restore-tfstate.sh: gere erreur si mc alias set echoue" {
    grep -q 'configure_mc || exit\|configure_mc.*exit' "$SCRIPT"
}

# =============================================================================
# Tests rapport et common
# =============================================================================

@test "restore-tfstate.sh: source common.sh" {
    grep -q 'source.*common.sh' "$SCRIPT"
}

@test "restore-tfstate.sh: demande confirmation avant actions destructrices" {
    grep -q 'confirm' "$SCRIPT"
}

@test "restore-tfstate.sh: mode --force skip la confirmation" {
    grep -q 'FORCE_MODE' "$SCRIPT"
    grep -q 'confirm' "$SCRIPT"
}
