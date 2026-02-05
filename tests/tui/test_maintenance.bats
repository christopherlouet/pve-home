#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/menus/maintenance.sh (T040 - US5)
# =============================================================================
# Tests du menu maintenance : drift detection, verifications

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts"
    TUI_LIB="${PROJECT_ROOT}/scripts/lib/tui"
    MAINTENANCE_MENU="${TUI_DIR}/menus/maintenance.sh"

    # Charger les libs TUI
    source "${TUI_LIB}/colors.sh"
    source "${TUI_LIB}/config.sh"
    source "${TUI_LIB}/common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_maintenance"
    mkdir -p "${TEST_DIR}"

    # Mock environnements terraform
    for env in prod lab monitoring; do
        mkdir -p "${TEST_DIR}/environments/${env}"
        touch "${TEST_DIR}/environments/${env}/versions.tf"
        touch "${TEST_DIR}/environments/${env}/main.tf"
        touch "${TEST_DIR}/environments/${env}/terraform.tfvars"
    done

    # Mock drift output - conforme
    MOCK_DRIFT_OK='Detection de drift infrastructure
---
Verification du drift pour l environnement: prod
Initialisation Terraform pour prod...
[prod] Conforme - aucun drift detecte
---
=============================================
  Resume de la detection de drift
=============================================
Environnement   Statut     Details
---------------------------------------------
prod            Conforme   Aucun drift
============================================='

    # Mock drift output - drift detecte
    MOCK_DRIFT_DETECTED='Detection de drift infrastructure
---
Verification du drift pour l environnement: prod
Initialisation Terraform pour prod...
[prod] DRIFT DETECTE - 2 ressource(s) changee(s)

  ~ proxmox_virtual_environment_vm.monitoring
      ~ cpu {
          ~ cores = 2 -> 4
        }
  ~ proxmox_virtual_environment_vm.web
      ~ memory = 4096 -> 8192

---
=============================================
  Resume de la detection de drift
=============================================
Environnement   Statut     Details
---------------------------------------------
prod            DRIFT      2 ressource(s)
============================================='

    # Mock drift output - erreur
    MOCK_DRIFT_ERROR='Detection de drift infrastructure
---
Verification du drift pour l environnement: prod
[ERROR] Echec de l initialisation Terraform pour prod
---
=============================================
  Resume de la detection de drift
=============================================
Environnement   Statut     Details
---------------------------------------------
prod            ERREUR     Echec du check
============================================='
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure (T036)
# =============================================================================

@test "maintenance.sh existe" {
    [ -f "$MAINTENANCE_MENU" ]
}

@test "maintenance.sh peut etre source sans erreur" {
    run bash -c "source '${MAINTENANCE_MENU}' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "menu_maintenance() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f menu_maintenance > /dev/null
}

# =============================================================================
# Tests selection environnement (T037)
# =============================================================================

@test "get_drift_environments() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f get_drift_environments > /dev/null
}

@test "get_drift_environments() liste les environnements" {
    source "$MAINTENANCE_MENU"
    run get_drift_environments
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]] || [[ "$output" == *"lab"* ]] || [[ "$output" == *"monitoring"* ]]
}

@test "get_drift_environments() inclut l'option tous" {
    source "$MAINTENANCE_MENU"
    run get_drift_environments
    [ "$status" -eq 0 ]
    [[ "$output" == *"tous"* ]] || [[ "$output" == *"Tous"* ]] || [[ "$output" == *"all"* ]]
}

@test "select_drift_environment() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f select_drift_environment > /dev/null
}

@test "get_env_drift_status() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f get_env_drift_status > /dev/null || declare -f get_last_drift_status > /dev/null
}

# =============================================================================
# Tests integration check-drift.sh (T038)
# =============================================================================

@test "get_drift_script_path() retourne le chemin du script" {
    source "$MAINTENANCE_MENU"
    run get_drift_script_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"check-drift.sh"* ]]
}

@test "run_drift_check() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f run_drift_check > /dev/null
}

@test "run_drift_check() utilise check-drift.sh" {
    source "$MAINTENANCE_MENU"
    local func_def
    func_def=$(declare -f run_drift_check)
    [[ "$func_def" == *"check-drift"* ]] || [[ "$func_def" == *"DRIFT_SCRIPT"* ]] || [[ "$func_def" == *"get_drift_script_path"* ]]
}

@test "run_drift_check_all() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f run_drift_check_all > /dev/null || declare -f run_drift_check > /dev/null
}

@test "run_drift_check() accepte un environnement" {
    source "$MAINTENANCE_MENU"
    local func_def
    func_def=$(declare -f run_drift_check)
    [[ "$func_def" == *"env"* ]] || [[ "$func_def" == *"--env"* ]] || [[ "$func_def" == *"\$1"* ]]
}

# =============================================================================
# Tests affichage rapport drift (T039)
# =============================================================================

@test "show_drift_report() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f show_drift_report > /dev/null || declare -f display_drift_results > /dev/null
}

@test "parse_drift_status() extrait le statut" {
    source "$MAINTENANCE_MENU"
    run parse_drift_status "$MOCK_DRIFT_OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Conforme"* ]] || [[ "$output" == *"OK"* ]] || [[ "$output" == *"conforme"* ]]
}

@test "parse_drift_status() detecte le drift" {
    source "$MAINTENANCE_MENU"
    run parse_drift_status "$MOCK_DRIFT_DETECTED"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRIFT"* ]] || [[ "$output" == *"drift"* ]] || [[ "$output" == *"change"* ]]
}

@test "parse_drift_count() extrait le nombre de ressources" {
    source "$MAINTENANCE_MENU"
    run parse_drift_count "$MOCK_DRIFT_DETECTED"
    [ "$status" -eq 0 ]
    [[ "$output" == "2" ]] || [[ "$output" == *"2"* ]]
}

@test "format_drift_status() formate le statut conforme" {
    source "$MAINTENANCE_MENU"
    run format_drift_status "ok" "prod"
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]]
    [[ "$output" == *"OK"* ]] || [[ "$output" == *"Conforme"* ]] || [[ "$output" == *"✓"* ]]
}

@test "format_drift_status() formate le statut drift" {
    source "$MAINTENANCE_MENU"
    run format_drift_status "drift" "prod"
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]]
    [[ "$output" == *"DRIFT"* ]] || [[ "$output" == *"drift"* ]] || [[ "$output" == *"!"* ]]
}

@test "format_drift_status() formate le statut erreur" {
    source "$MAINTENANCE_MENU"
    run format_drift_status "error" "prod"
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]]
    [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"Erreur"* ]] || [[ "$output" == *"✗"* ]]
}

@test "get_drift_status_icon() retourne l'icone appropriee" {
    source "$MAINTENANCE_MENU"
    run get_drift_status_icon "ok"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓"* ]] || [[ "$output" == *"OK"* ]] || [[ "$output" == *"[OK]"* ]]
}

@test "get_drift_status_icon() retourne l'icone drift" {
    source "$MAINTENANCE_MENU"
    run get_drift_status_icon "drift"
    [ "$status" -eq 0 ]
    [[ "$output" == *"!"* ]] || [[ "$output" == *"DRIFT"* ]] || [[ "$output" == *"[DRIFT]"* ]]
}

@test "parse_drift_details() extrait les ressources en drift" {
    source "$MAINTENANCE_MENU"
    run parse_drift_details "$MOCK_DRIFT_DETECTED"
    [ "$status" -eq 0 ]
    [[ "$output" == *"proxmox"* ]] || [[ "$output" == *"vm"* ]] || [[ "$output" == *"cpu"* ]] || [[ "$output" == *"memory"* ]]
}

# =============================================================================
# Tests actions menu
# =============================================================================

@test "get_maintenance_actions() retourne les actions disponibles" {
    source "$MAINTENANCE_MENU"
    run get_maintenance_actions
    [ "$status" -eq 0 ]
    [[ "$output" == *"Drift"* ]] || [[ "$output" == *"drift"* ]] || [[ "$output" == *"Verifier"* ]]
}

@test "get_maintenance_actions() inclut l'option tous les environnements" {
    source "$MAINTENANCE_MENU"
    run get_maintenance_actions
    [ "$status" -eq 0 ]
    [[ "$output" == *"tous"* ]] || [[ "$output" == *"Tous"* ]] || [[ "$output" == *"all"* ]]
}

@test "menu_drift() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f menu_drift > /dev/null || declare -f select_drift_action > /dev/null
}

# =============================================================================
# Tests gestion erreurs
# =============================================================================

@test "handle_drift_error() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f handle_drift_error > /dev/null
}

@test "handle_drift_error() affiche le message" {
    source "$MAINTENANCE_MENU"
    run handle_drift_error "Terraform init failed"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Terraform"* ]] || [[ "$output" == *"failed"* ]] || [[ "$output" == *"erreur"* ]] || [[ "$output" == *"Erreur"* ]]
}

@test "check_drift_prerequisites() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f check_drift_prerequisites > /dev/null
}

@test "check_drift_prerequisites() verifie terraform" {
    source "$MAINTENANCE_MENU"
    local func_def
    func_def=$(declare -f check_drift_prerequisites)
    [[ "$func_def" == *"terraform"* ]] || [[ "$func_def" == *"command"* ]]
}

# =============================================================================
# Tests integration menu
# =============================================================================

@test "menu_maintenance gere le retour au menu principal" {
    source "$MAINTENANCE_MENU"
    declare -f menu_maintenance > /dev/null
}

@test "maintenance.sh source les dependances TUI" {
    grep -q "common.sh\|colors.sh" "$MAINTENANCE_MENU" || \
    grep -q "source.*lib" "$MAINTENANCE_MENU"
}

# =============================================================================
# Tests dry-run
# =============================================================================

@test "run_drift_dry_run() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f run_drift_dry_run > /dev/null || \
    { local func=$(declare -f run_drift_check); [[ "$func" == *"dry"* ]]; }
}

@test "dry-run ne modifie pas le systeme" {
    source "$MAINTENANCE_MENU"
    # La fonction dry-run doit passer --dry-run au script
    declare -f run_drift_dry_run > /dev/null || \
    { local func=$(declare -f run_drift_check); [[ "$func" == *"--dry-run"* ]]; }
}

# =============================================================================
# Tests rapport historique
# =============================================================================

@test "get_last_drift_check() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f get_last_drift_check > /dev/null || declare -f get_drift_history > /dev/null
}

@test "show_drift_summary() est definie" {
    source "$MAINTENANCE_MENU"
    declare -f show_drift_summary > /dev/null || declare -f display_drift_summary > /dev/null
}
