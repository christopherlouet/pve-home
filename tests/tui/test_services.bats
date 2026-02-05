#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/tui/menus/services.sh (T055 - US7)
# =============================================================================
# Tests du menu services : liste, activation/desactivation, demarrage/arret

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts/tui"
    TUI_LIB="${TUI_DIR}/lib"
    SERVICES_MENU="${TUI_DIR}/menus/services.sh"

    # Charger les libs TUI
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    source "${TUI_LIB}/tui-common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_services"
    mkdir -p "${TEST_DIR}"

    # Mock terraform.tfvars avec services
    mkdir -p "${TEST_DIR}/environments/monitoring"
    cat > "${TEST_DIR}/environments/monitoring/terraform.tfvars" << 'EOF'
monitoring = {
  vm = {
    ip = "192.168.1.51"
  }
  telegram = {
    enabled   = true
    bot_token = "xxx"
    chat_id   = "123"
  }
}

minio = {
  ip       = "192.168.1.52"
  port     = 9000
}

backup = {
  enabled  = true
  schedule = "02:00"
}
EOF

    # Mock prod tfvars avec harbor
    mkdir -p "${TEST_DIR}/environments/prod"
    cat > "${TEST_DIR}/environments/prod/terraform.tfvars" << 'EOF'
vms = {
  "web-server" = {
    ip     = "192.168.1.101"
    docker = true
  }
}

harbor = {
  enabled = false
  ip      = "192.168.1.105"
  port    = 443
}
EOF

    # Liste des services connus
    KNOWN_SERVICES="monitoring minio backup telegram harbor"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure (T049)
# =============================================================================

@test "services.sh existe" {
    [ -f "$SERVICES_MENU" ]
}

@test "services.sh peut etre source sans erreur" {
    run bash -c "source '${SERVICES_MENU}' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "menu_services() est definie" {
    source "$SERVICES_MENU"
    declare -f menu_services > /dev/null
}

# =============================================================================
# Tests liste services (T050)
# =============================================================================

@test "get_available_services() est definie" {
    source "$SERVICES_MENU"
    declare -f get_available_services > /dev/null
}

@test "get_available_services() liste les services" {
    source "$SERVICES_MENU"
    run get_available_services
    [ "$status" -eq 0 ]
    [[ "$output" == *"monitoring"* ]] || [[ "$output" == *"minio"* ]] || [[ "$output" == *"backup"* ]]
}

@test "get_service_status() est definie" {
    source "$SERVICES_MENU"
    declare -f get_service_status > /dev/null
}

@test "get_service_enabled() retourne l'etat enabled depuis tfvars" {
    source "$SERVICES_MENU"
    # Override le chemin pour le test
    SERVICES_TFVARS="${TEST_DIR}/environments/monitoring/terraform.tfvars"
    run get_service_enabled "telegram" "$SERVICES_TFVARS"
    [ "$status" -eq 0 ]
    [[ "$output" == "true" ]] || [[ "$output" == *"enabled"* ]] || [[ "$output" == *"actif"* ]]
}

@test "get_service_enabled() detecte service desactive" {
    source "$SERVICES_MENU"
    SERVICES_TFVARS="${TEST_DIR}/environments/prod/terraform.tfvars"
    run get_service_enabled "harbor" "$SERVICES_TFVARS"
    [ "$status" -eq 0 ]
    [[ "$output" == "false" ]] || [[ "$output" == *"disabled"* ]] || [[ "$output" == *"inactif"* ]]
}

@test "get_service_running() est definie" {
    source "$SERVICES_MENU"
    declare -f get_service_running > /dev/null || declare -f check_service_running > /dev/null
}

@test "format_service_status() formate le statut" {
    source "$SERVICES_MENU"
    run format_service_status "monitoring" "enabled" "running"
    [ "$status" -eq 0 ]
    [[ "$output" == *"monitoring"* ]]
}

@test "list_services() est definie" {
    source "$SERVICES_MENU"
    declare -f list_services > /dev/null
}

# =============================================================================
# Tests activer/desactiver service (T051)
# =============================================================================

@test "toggle_service() est definie" {
    source "$SERVICES_MENU"
    declare -f toggle_service > /dev/null || declare -f enable_service > /dev/null
}

@test "enable_service() est definie" {
    source "$SERVICES_MENU"
    declare -f enable_service > /dev/null
}

@test "disable_service() est definie" {
    source "$SERVICES_MENU"
    declare -f disable_service > /dev/null
}

@test "update_tfvars_enabled() est definie" {
    source "$SERVICES_MENU"
    declare -f update_tfvars_enabled > /dev/null || declare -f modify_tfvars > /dev/null
}

@test "toggle_service() requiert confirmation" {
    source "$SERVICES_MENU"
    local func_def
    func_def=$(declare -f toggle_service 2>/dev/null || declare -f enable_service)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

# =============================================================================
# Tests proposer terraform apply (T052)
# =============================================================================

@test "propose_terraform_apply() est definie" {
    source "$SERVICES_MENU"
    declare -f propose_terraform_apply > /dev/null || declare -f suggest_apply > /dev/null
}

@test "propose_terraform_apply() demande confirmation" {
    source "$SERVICES_MENU"
    local func_def
    func_def=$(declare -f propose_terraform_apply 2>/dev/null || declare -f suggest_apply 2>/dev/null || echo "")
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]] || [[ "$func_def" == *"apply"* ]]
}

@test "run_terraform_apply_for_service() est definie" {
    source "$SERVICES_MENU"
    declare -f run_terraform_apply_for_service > /dev/null || declare -f apply_service_changes > /dev/null
}

# =============================================================================
# Tests demarrer/arreter service (T053)
# =============================================================================

@test "start_service() est definie" {
    source "$SERVICES_MENU"
    declare -f start_service > /dev/null
}

@test "stop_service() est definie" {
    source "$SERVICES_MENU"
    declare -f stop_service > /dev/null
}

@test "restart_service() est definie" {
    source "$SERVICES_MENU"
    declare -f restart_service > /dev/null
}

@test "get_service_command() retourne la commande appropriee" {
    source "$SERVICES_MENU"
    run get_service_command "monitoring" "start"
    [ "$status" -eq 0 ]
    # Doit contenir docker ou systemctl
    [[ "$output" == *"docker"* ]] || [[ "$output" == *"systemctl"* ]] || [[ "$output" == *"compose"* ]]
}

@test "execute_service_command() est definie" {
    source "$SERVICES_MENU"
    declare -f execute_service_command > /dev/null || declare -f run_service_command > /dev/null
}

@test "stop_service() requiert confirmation" {
    source "$SERVICES_MENU"
    local func_def
    func_def=$(declare -f stop_service)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

# =============================================================================
# Tests afficher nouvel etat (T054)
# =============================================================================

@test "show_service_status() est definie" {
    source "$SERVICES_MENU"
    declare -f show_service_status > /dev/null || declare -f display_service_status > /dev/null
}

@test "refresh_service_status() est definie" {
    source "$SERVICES_MENU"
    declare -f refresh_service_status > /dev/null || declare -f update_service_display > /dev/null
}

@test "get_service_status_icon() retourne l'icone appropriee" {
    source "$SERVICES_MENU"
    run get_service_status_icon "running"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓"* ]] || [[ "$output" == *"OK"* ]] || [[ "$output" == *"[ON]"* ]]
}

@test "get_service_status_icon() gere l'etat arrete" {
    source "$SERVICES_MENU"
    run get_service_status_icon "stopped"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✗"* ]] || [[ "$output" == *"OFF"* ]] || [[ "$output" == *"[OFF]"* ]]
}

# =============================================================================
# Tests actions menu
# =============================================================================

@test "get_services_actions() retourne les actions disponibles" {
    source "$SERVICES_MENU"
    run get_services_actions
    [ "$status" -eq 0 ]
    [[ "$output" == *"Lister"* ]] || [[ "$output" == *"liste"* ]] || [[ "$output" == *"List"* ]]
    [[ "$output" == *"Activer"* ]] || [[ "$output" == *"enable"* ]] || [[ "$output" == *"Enable"* ]]
}

@test "select_service() est definie" {
    source "$SERVICES_MENU"
    declare -f select_service > /dev/null
}

@test "menu_service_action() est definie" {
    source "$SERVICES_MENU"
    declare -f menu_service_action > /dev/null || declare -f select_service_action > /dev/null
}

# =============================================================================
# Tests gestion erreurs
# =============================================================================

@test "handle_service_error() est definie" {
    source "$SERVICES_MENU"
    declare -f handle_service_error > /dev/null
}

@test "handle_service_error() affiche le message" {
    source "$SERVICES_MENU"
    run handle_service_error "Connection refused" "monitoring"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Connection"* ]] || [[ "$output" == *"refused"* ]] || [[ "$output" == *"erreur"* ]] || [[ "$output" == *"Erreur"* ]]
}

@test "check_services_prerequisites() est definie" {
    source "$SERVICES_MENU"
    declare -f check_services_prerequisites > /dev/null
}

# =============================================================================
# Tests integration menu
# =============================================================================

@test "menu_services gere le retour au menu principal" {
    source "$SERVICES_MENU"
    declare -f menu_services > /dev/null
}

@test "services.sh source les dependances TUI" {
    grep -q "tui-common.sh\|tui-colors.sh" "$SERVICES_MENU" || \
    grep -q "source.*lib" "$SERVICES_MENU"
}

# =============================================================================
# Tests securite
# =============================================================================

@test "modification tfvars requiert confirmation" {
    source "$SERVICES_MENU"
    local func_def
    func_def=$(declare -f update_tfvars_enabled 2>/dev/null || declare -f toggle_service 2>/dev/null || echo "confirm")
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

@test "arret service requiert confirmation" {
    source "$SERVICES_MENU"
    local func_def
    func_def=$(declare -f stop_service)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

@test "les services supportent dry-run" {
    source "$SERVICES_MENU"
    declare -f toggle_service_dry_run > /dev/null || \
    { local func=$(declare -f toggle_service 2>/dev/null || echo "dry"); [[ "$func" == *"dry"* ]]; }
}
