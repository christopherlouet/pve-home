#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/restore/rebuild-minio.sh
# =============================================================================
# User Story US3 - Reconstruire Minio depuis zero
# =============================================================================

SCRIPT="scripts/restore/rebuild-minio.sh"

# =============================================================================
# Tests de qualite du script
# =============================================================================

@test "rebuild-minio.sh: le script existe" {
    [ -f "$SCRIPT" ]
}

@test "rebuild-minio.sh: shellcheck doit passer sans erreur" {
    shellcheck "$SCRIPT" 2>&1 | grep -v "SC1091" | grep -E "error|warning" && exit 1 || true
}

@test "rebuild-minio.sh: utilise set -euo pipefail" {
    grep -q "set -euo pipefail" "$SCRIPT"
}

# =============================================================================
# Tests parsing arguments (T017)
# =============================================================================

@test "rebuild-minio.sh: doit afficher l'aide avec --help" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "rebuild-minio.sh" ]]
}

@test "rebuild-minio.sh: doit afficher l'aide avec -h" {
    run bash "$SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "rebuild-minio.sh: doit rejeter une option inconnue" {
    run bash "$SCRIPT" --invalid-option
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Option inconnue" ]]
}

@test "rebuild-minio.sh: utilise l'environnement monitoring par defaut" {
    grep -q 'ENV="monitoring"' "$SCRIPT"
}

@test "rebuild-minio.sh: supporte --dry-run" {
    grep -q '\-\-dry-run' "$SCRIPT"
    grep -q 'DRY_RUN=true' "$SCRIPT"
}

@test "rebuild-minio.sh: supporte --force" {
    grep -q '\-\-force' "$SCRIPT"
    grep -q 'FORCE_MODE=true' "$SCRIPT"
}

# =============================================================================
# Tests verification Minio (T017, T019)
# =============================================================================

@test "rebuild-minio.sh: implemente check_minio_health" {
    grep -q 'check_minio_health()' "$SCRIPT"
}

@test "rebuild-minio.sh: verifie healthcheck Minio /minio/health/live" {
    grep -q 'minio/health/live' "$SCRIPT"
}

@test "rebuild-minio.sh: detecte IP Minio depuis terraform.tfvars" {
    grep -q 'parse_minio_config()' "$SCRIPT"
    grep -q 'MINIO_IP=' "$SCRIPT"
    grep -q 'terraform.tfvars' "$SCRIPT"
}

# =============================================================================
# Tests terraform apply (T017)
# =============================================================================

@test "rebuild-minio.sh: execute terraform apply -target=module.minio" {
    grep -q 'terraform apply.*module.minio' "$SCRIPT"
}

@test "rebuild-minio.sh: implemente retry loop pour demarrage Minio" {
    grep -q 'wait_minio_ready()' "$SCRIPT"
    grep -q 'MINIO_HEALTHCHECK_MAX_RETRIES' "$SCRIPT"
    grep -q 'MINIO_HEALTHCHECK_RETRY_INTERVAL' "$SCRIPT"
}

@test "rebuild-minio.sh: definit les constantes de healthcheck" {
    grep -q 'DEFAULT_MINIO_PORT=9000' "$SCRIPT"
    grep -q 'MINIO_HEALTHCHECK_MAX_RETRIES=12' "$SCRIPT"
    grep -q 'MINIO_HEALTHCHECK_RETRY_INTERVAL=5' "$SCRIPT"
}

# =============================================================================
# Tests verifications (T019)
# =============================================================================

@test "rebuild-minio.sh: implemente verify_minio" {
    grep -q 'verify_minio()' "$SCRIPT"
}

@test "rebuild-minio.sh: verifie les buckets avec mc ls" {
    grep -q 'mc ls' "$SCRIPT"
}

@test "rebuild-minio.sh: verifie le versioning avec mc version info" {
    grep -q 'mc version info' "$SCRIPT"
}

@test "rebuild-minio.sh: verifie les backends Terraform" {
    grep -q 'verify_terraform_backends()' "$SCRIPT"
    grep -q 'terraform init' "$SCRIPT"
}

@test "rebuild-minio.sh: verifie les environnements prod et monitoring" {
    grep -q '"prod"' "$SCRIPT"
    grep -q '"monitoring"' "$SCRIPT"
}

# =============================================================================
# Tests rapport (T017)
# =============================================================================

@test "rebuild-minio.sh: affiche un resume de reconstruction" {
    grep -q 'RESUME DE RECONSTRUCTION' "$SCRIPT"
    grep -q 'Minio' "$SCRIPT"
}

@test "rebuild-minio.sh: affiche les actions prevues avant execution" {
    grep -q 'Actions prevues' "$SCRIPT"
}

@test "rebuild-minio.sh: source common.sh" {
    grep -q 'source.*common.sh' "$SCRIPT"
}

@test "rebuild-minio.sh: demande confirmation avant reconstruction" {
    grep -q 'confirm' "$SCRIPT"
}
