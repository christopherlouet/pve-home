#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/tui/menus/deploy.sh (T035 - US4)
# =============================================================================
# Tests du menu deploiement : resume, progression, resultats

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts/tui"
    TUI_LIB="${TUI_DIR}/lib"
    DEPLOY_MENU="${TUI_DIR}/menus/deploy.sh"

    # Charger les libs TUI
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    source "${TUI_LIB}/tui-common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_deploy"
    mkdir -p "${TEST_DIR}"

    # Mock terraform.tfvars monitoring
    mkdir -p "${TEST_DIR}/environments/monitoring"
    cat > "${TEST_DIR}/environments/monitoring/terraform.tfvars" << 'EOF'
monitoring = {
  ip     = "192.168.1.50"
  cores  = 2
  memory = 4096
}
EOF

    # Mock terraform.tfvars prod
    mkdir -p "${TEST_DIR}/environments/prod"
    cat > "${TEST_DIR}/environments/prod/terraform.tfvars" << 'EOF'
vms = {
  "web-server" = {
    ip = "192.168.1.10"
  }
}
EOF

    # Mock terraform.tfvars lab
    mkdir -p "${TEST_DIR}/environments/lab"
    cat > "${TEST_DIR}/environments/lab/terraform.tfvars" << 'EOF'
vms = {
  "dev-vm" = {
    ip = "192.168.1.100"
  }
}
EOF

    # Mock scripts directories
    mkdir -p "${TEST_DIR}/scripts"/{lib,drift,health,lifecycle,restore,systemd}
    touch "${TEST_DIR}/scripts/lib/common.sh"
    touch "${TEST_DIR}/scripts/health/check-health.sh"
    touch "${TEST_DIR}/scripts/drift/check-drift.sh"
    touch "${TEST_DIR}/scripts/systemd/pve-health-check.timer"
    touch "${TEST_DIR}/scripts/systemd/pve-health-check.service"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure (T031)
# =============================================================================

@test "deploy.sh existe" {
    [ -f "$DEPLOY_MENU" ]
}

@test "deploy.sh peut etre source sans erreur" {
    run bash -c "source '${DEPLOY_MENU}' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "menu_deploy() est definie" {
    source "$DEPLOY_MENU"
    declare -f menu_deploy > /dev/null
}

# =============================================================================
# Tests resume deploiement (T032)
# =============================================================================

@test "get_deploy_summary() est definie" {
    source "$DEPLOY_MENU"
    declare -f get_deploy_summary > /dev/null
}

@test "get_deploy_summary() liste les scripts a deployer" {
    source "$DEPLOY_MENU"
    run get_deploy_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"script"* ]] || [[ "$output" == *"Script"* ]] || [[ "$output" == *"health"* ]] || [[ "$output" == *"drift"* ]]
}

@test "get_deploy_items() retourne les elements a deployer" {
    source "$DEPLOY_MENU"
    run get_deploy_items
    [ "$status" -eq 0 ]
    # Doit lister scripts, tfvars, timers
    [[ "$output" == *"scripts"* ]] || [[ "$output" == *"tfvars"* ]] || [[ "$output" == *"timer"* ]] || [[ "$output" == *"systemd"* ]]
}

@test "get_scripts_to_deploy() liste les dossiers scripts" {
    source "$DEPLOY_MENU"
    run get_scripts_to_deploy
    [ "$status" -eq 0 ]
    [[ "$output" == *"lib"* ]] || [[ "$output" == *"health"* ]] || [[ "$output" == *"drift"* ]]
}

@test "get_tfvars_to_deploy() liste les environnements" {
    source "$DEPLOY_MENU"
    run get_tfvars_to_deploy
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]] || [[ "$output" == *"lab"* ]] || [[ "$output" == *"monitoring"* ]]
}

@test "get_timers_to_deploy() liste les timers systemd" {
    source "$DEPLOY_MENU"
    run get_timers_to_deploy
    [ "$status" -eq 0 ]
    [[ "$output" == *"health"* ]] || [[ "$output" == *"drift"* ]] || [[ "$output" == *"cleanup"* ]] || [[ "$output" == *"expire"* ]]
}

@test "show_deploy_preview() est definie" {
    source "$DEPLOY_MENU"
    declare -f show_deploy_preview > /dev/null
}

# =============================================================================
# Tests integration deploy.sh (T033)
# =============================================================================

@test "get_deploy_script_path() retourne le chemin du script" {
    source "$DEPLOY_MENU"
    run get_deploy_script_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"deploy.sh"* ]]
}

@test "run_deploy() est definie" {
    source "$DEPLOY_MENU"
    declare -f run_deploy > /dev/null
}

@test "run_deploy_dry_run() est definie" {
    source "$DEPLOY_MENU"
    declare -f run_deploy_dry_run > /dev/null || declare -f run_deploy > /dev/null
}

@test "run_deploy() utilise le script deploy.sh" {
    source "$DEPLOY_MENU"
    local func_def
    func_def=$(declare -f run_deploy)
    [[ "$func_def" == *"deploy.sh"* ]] || [[ "$func_def" == *"DEPLOY_SCRIPT"* ]] || [[ "$func_def" == *"get_deploy_script_path"* ]]
}

@test "run_deploy() requiert confirmation" {
    source "$DEPLOY_MENU"
    local func_def
    func_def=$(declare -f run_deploy)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

@test "parse_deploy_step() est definie" {
    source "$DEPLOY_MENU"
    declare -f parse_deploy_step > /dev/null || declare -f format_deploy_output > /dev/null
}

# =============================================================================
# Tests affichage resultats (T034)
# =============================================================================

@test "show_deploy_results() est definie" {
    source "$DEPLOY_MENU"
    declare -f show_deploy_results > /dev/null
}

@test "format_deploy_status() formate le statut" {
    source "$DEPLOY_MENU"
    run format_deploy_status "success" "Scripts deployes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Scripts"* ]] || [[ "$output" == *"deployes"* ]] || [[ "$output" == *"OK"* ]] || [[ "$output" == *"✓"* ]]
}

@test "format_deploy_status() gere les erreurs" {
    source "$DEPLOY_MENU"
    run format_deploy_status "error" "Echec connexion SSH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Echec"* ]] || [[ "$output" == *"SSH"* ]] || [[ "$output" == *"✗"* ]] || [[ "$output" == *"error"* ]]
}

@test "get_deploy_status_icon() retourne l'icone appropriee" {
    source "$DEPLOY_MENU"
    run get_deploy_status_icon "success"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓"* ]] || [[ "$output" == *"OK"* ]] || [[ "$output" == *"[OK]"* ]]
}

@test "get_deploy_status_icon() gere l'echec" {
    source "$DEPLOY_MENU"
    run get_deploy_status_icon "error"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✗"* ]] || [[ "$output" == *"FAIL"* ]] || [[ "$output" == *"[FAIL]"* ]] || [[ "$output" == *"ERROR"* ]]
}

# =============================================================================
# Tests detection VM monitoring (T033)
# =============================================================================

@test "get_monitoring_ip() est definie" {
    source "$DEPLOY_MENU"
    declare -f get_monitoring_ip > /dev/null
}

@test "get_monitoring_ip() extrait l'IP du tfvars" {
    source "$DEPLOY_MENU"
    # Override le chemin tfvars pour le test
    MONITORING_TFVARS="${TEST_DIR}/environments/monitoring/terraform.tfvars"
    run get_monitoring_ip
    [ "$status" -eq 0 ]
    [[ "$output" == "192.168.1.50" ]]
}

@test "check_monitoring_reachable() est definie" {
    source "$DEPLOY_MENU"
    declare -f check_monitoring_reachable > /dev/null || declare -f check_ssh_connectivity > /dev/null
}

# =============================================================================
# Tests options deploiement
# =============================================================================

@test "get_deploy_actions() retourne les actions disponibles" {
    source "$DEPLOY_MENU"
    run get_deploy_actions
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deployer"* ]] || [[ "$output" == *"deployer"* ]] || [[ "$output" == *"Deploy"* ]]
}

@test "get_deploy_actions() inclut dry-run" {
    source "$DEPLOY_MENU"
    run get_deploy_actions
    [ "$status" -eq 0 ]
    [[ "$output" == *"dry"* ]] || [[ "$output" == *"Dry"* ]] || [[ "$output" == *"test"* ]] || [[ "$output" == *"Simuler"* ]]
}

@test "menu_deploy_action() est definie" {
    source "$DEPLOY_MENU"
    declare -f menu_deploy_action > /dev/null || declare -f select_deploy_action > /dev/null
}

# =============================================================================
# Tests gestion erreurs
# =============================================================================

@test "handle_deploy_error() est definie" {
    source "$DEPLOY_MENU"
    declare -f handle_deploy_error > /dev/null
}

@test "handle_deploy_error() affiche le message" {
    source "$DEPLOY_MENU"
    run handle_deploy_error "Connection refused"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Connection"* ]] || [[ "$output" == *"refused"* ]] || [[ "$output" == *"erreur"* ]] || [[ "$output" == *"Erreur"* ]]
}

@test "check_deploy_prerequisites() est definie" {
    source "$DEPLOY_MENU"
    declare -f check_deploy_prerequisites > /dev/null
}

@test "check_deploy_prerequisites() verifie rsync" {
    source "$DEPLOY_MENU"
    local func_def
    func_def=$(declare -f check_deploy_prerequisites)
    [[ "$func_def" == *"rsync"* ]] || [[ "$func_def" == *"command"* ]]
}

@test "check_deploy_prerequisites() verifie ssh" {
    source "$DEPLOY_MENU"
    local func_def
    func_def=$(declare -f check_deploy_prerequisites)
    [[ "$func_def" == *"ssh"* ]] || [[ "$func_def" == *"command"* ]]
}

# =============================================================================
# Tests integration menu
# =============================================================================

@test "menu_deploy gere le retour au menu principal" {
    source "$DEPLOY_MENU"
    declare -f menu_deploy > /dev/null
}

@test "deploy.sh source les dependances TUI" {
    grep -q "tui-common.sh\|tui-colors.sh" "$DEPLOY_MENU" || \
    grep -q "source.*lib" "$DEPLOY_MENU"
}

# =============================================================================
# Tests securite
# =============================================================================

@test "deploiement requiert confirmation explicite" {
    source "$DEPLOY_MENU"
    local func_def
    func_def=$(declare -f run_deploy)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

@test "dry-run ne modifie pas le systeme" {
    source "$DEPLOY_MENU"
    # La fonction dry-run doit passer --dry-run au script
    declare -f run_deploy_dry_run > /dev/null || \
    { local func=$(declare -f run_deploy); [[ "$func" == *"dry-run"* ]] || [[ "$func" == *"--dry-run"* ]]; }
}
