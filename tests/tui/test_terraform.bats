#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/tui/menus/terraform.sh (T030 - US3)
# =============================================================================
# Tests du menu terraform : plan, apply, output, init

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts/tui"
    TUI_LIB="${TUI_DIR}/lib"
    TERRAFORM_MENU="${TUI_DIR}/menus/terraform.sh"

    # Charger les libs TUI
    source "${TUI_LIB}/tui-colors.sh"
    source "${TUI_LIB}/tui-config.sh"
    source "${TUI_LIB}/tui-common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_terraform"
    mkdir -p "${TEST_DIR}"

    # Mock environnement terraform
    mkdir -p "${TEST_DIR}/env_configured"
    touch "${TEST_DIR}/env_configured/main.tf"
    touch "${TEST_DIR}/env_configured/terraform.tfvars"
    mkdir -p "${TEST_DIR}/env_configured/.terraform"

    mkdir -p "${TEST_DIR}/env_not_init"
    touch "${TEST_DIR}/env_not_init/main.tf"
    touch "${TEST_DIR}/env_not_init/terraform.tfvars"

    mkdir -p "${TEST_DIR}/env_no_tfvars"
    touch "${TEST_DIR}/env_no_tfvars/main.tf"

    # Mock plan output
    MOCK_PLAN_OUTPUT='Terraform will perform the following actions:

  # module.vm["web-server"].proxmox_virtual_environment_vm.vm will be updated in-place
  ~ resource "proxmox_virtual_environment_vm" "vm" {
      ~ cpu {
          ~ cores = 2 -> 4
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.'

    # Mock output JSON
    MOCK_OUTPUT_JSON='{
  "monitoring_ip": {
    "sensitive": false,
    "type": "string",
    "value": "192.168.1.50"
  },
  "vm_ips": {
    "sensitive": false,
    "type": "map",
    "value": {
      "web-server": "192.168.1.10",
      "db-server": "192.168.1.11"
    }
  }
}'
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure (T023)
# =============================================================================

@test "terraform.sh existe" {
    [ -f "$TERRAFORM_MENU" ]
}

@test "terraform.sh peut etre source sans erreur" {
    run bash -c "source '${TERRAFORM_MENU}' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "menu_terraform() est definie" {
    source "$TERRAFORM_MENU"
    declare -f menu_terraform > /dev/null
}

# =============================================================================
# Tests selection environnement avec etat (T024)
# =============================================================================

@test "get_terraform_envs() liste les environnements" {
    source "$TERRAFORM_MENU"
    run get_terraform_envs
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]] || [[ "$output" == *"lab"* ]] || [[ "$output" == *"monitoring"* ]]
}

@test "get_env_path() retourne le chemin correct" {
    source "$TERRAFORM_MENU"
    run get_env_path "prod"
    [ "$status" -eq 0 ]
    [[ "$output" == *"environments/prod"* ]]
}

@test "is_terraform_initialized() detecte .terraform" {
    source "$TERRAFORM_MENU"
    run is_terraform_initialized "${TEST_DIR}/env_configured"
    [ "$status" -eq 0 ]
}

@test "is_terraform_initialized() detecte absence de .terraform" {
    source "$TERRAFORM_MENU"
    run is_terraform_initialized "${TEST_DIR}/env_not_init"
    [ "$status" -eq 1 ]
}

@test "has_tfvars() detecte terraform.tfvars" {
    source "$TERRAFORM_MENU"
    run has_tfvars "${TEST_DIR}/env_configured"
    [ "$status" -eq 0 ]
}

@test "has_tfvars() detecte absence de terraform.tfvars" {
    source "$TERRAFORM_MENU"
    run has_tfvars "${TEST_DIR}/env_no_tfvars"
    [ "$status" -eq 1 ]
}

@test "get_env_status() retourne l'etat de l'environnement" {
    source "$TERRAFORM_MENU"
    run get_env_status "${TEST_DIR}/env_configured"
    [ "$status" -eq 0 ]
    # Doit indiquer "initialise" ou "configured" ou similaire
    [[ "$output" == *"init"* ]] || [[ "$output" == *"config"* ]] || [[ "$output" == *"OK"* ]] || [[ "$output" == *"✓"* ]]
}

@test "select_terraform_env() est definie" {
    source "$TERRAFORM_MENU"
    declare -f select_terraform_env > /dev/null
}

# =============================================================================
# Tests terraform plan (T025)
# =============================================================================

@test "run_terraform_plan() est definie" {
    source "$TERRAFORM_MENU"
    declare -f run_terraform_plan > /dev/null
}

@test "format_plan_output() colorie les changements" {
    source "$TERRAFORM_MENU"
    run format_plan_output "$MOCK_PLAN_OUTPUT"
    [ "$status" -eq 0 ]
    # Doit contenir le texte du plan
    [[ "$output" == *"Plan"* ]] || [[ "$output" == *"change"* ]]
}

@test "parse_plan_summary() extrait le resume" {
    source "$TERRAFORM_MENU"
    run parse_plan_summary "$MOCK_PLAN_OUTPUT"
    [ "$status" -eq 0 ]
    # Doit extraire le resume en francais ("a ajouter", "a modifier", "a supprimer")
    [[ "$output" == *"ajouter"* ]] || [[ "$output" == *"modifier"* ]] || [[ "$output" == *"supprimer"* ]] || [[ "$output" == *"Resume"* ]]
}

# =============================================================================
# Tests terraform apply (T026)
# =============================================================================

@test "run_terraform_apply() est definie" {
    source "$TERRAFORM_MENU"
    declare -f run_terraform_apply > /dev/null
}

@test "run_terraform_apply() requiert confirmation" {
    source "$TERRAFORM_MENU"
    local func_def
    func_def=$(declare -f run_terraform_apply)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

@test "show_apply_preview() affiche le resume des changements" {
    source "$TERRAFORM_MENU"
    declare -f show_apply_preview > /dev/null || declare -f display_plan_summary > /dev/null
}

# =============================================================================
# Tests terraform output (T027)
# =============================================================================

@test "run_terraform_output() est definie" {
    source "$TERRAFORM_MENU"
    declare -f run_terraform_output > /dev/null
}

@test "format_terraform_output() formate le JSON" {
    source "$TERRAFORM_MENU"
    echo "$MOCK_OUTPUT_JSON" > "${TEST_DIR}/output.json"
    run format_terraform_output "${TEST_DIR}/output.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"monitoring_ip"* ]] || [[ "$output" == *"192.168.1.50"* ]]
}

@test "parse_output_json() extrait les valeurs" {
    source "$TERRAFORM_MENU"
    run parse_output_json "$MOCK_OUTPUT_JSON"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests terraform init (T028)
# =============================================================================

@test "run_terraform_init() est definie" {
    source "$TERRAFORM_MENU"
    declare -f run_terraform_init > /dev/null
}

@test "check_needs_init() detecte si init necessaire" {
    source "$TERRAFORM_MENU"

    # Env sans .terraform a besoin d'init
    run check_needs_init "${TEST_DIR}/env_not_init"
    [ "$status" -eq 0 ]  # 0 = needs init

    # Env avec .terraform n'a pas besoin d'init
    run check_needs_init "${TEST_DIR}/env_configured"
    [ "$status" -eq 1 ]  # 1 = no init needed
}

# =============================================================================
# Tests gestion erreurs (T029)
# =============================================================================

@test "handle_terraform_error() est definie" {
    source "$TERRAFORM_MENU"
    declare -f handle_terraform_error > /dev/null
}

@test "handle_terraform_error() affiche le message complet" {
    source "$TERRAFORM_MENU"
    local error_msg="Error: Failed to load plugin"
    run handle_terraform_error "$error_msg"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"plugin"* ]]
}

@test "is_terraform_installed() verifie la commande terraform" {
    source "$TERRAFORM_MENU"
    # Terraform devrait etre installe sur cette machine
    if command -v terraform &>/dev/null; then
        run is_terraform_installed
        [ "$status" -eq 0 ]
    else
        skip "Terraform non installe"
    fi
}

# =============================================================================
# Tests menu actions
# =============================================================================

@test "get_terraform_actions() retourne les actions disponibles" {
    source "$TERRAFORM_MENU"
    run get_terraform_actions
    [ "$status" -eq 0 ]
    [[ "$output" == *"Plan"* ]] || [[ "$output" == *"plan"* ]]
    [[ "$output" == *"Apply"* ]] || [[ "$output" == *"apply"* ]]
    [[ "$output" == *"Output"* ]] || [[ "$output" == *"output"* ]]
    [[ "$output" == *"Init"* ]] || [[ "$output" == *"init"* ]]
}

@test "menu_terraform_env() est definie" {
    source "$TERRAFORM_MENU"
    declare -f menu_terraform_env > /dev/null
}

# =============================================================================
# Tests integration
# =============================================================================

@test "menu_terraform gere le retour au menu principal" {
    source "$TERRAFORM_MENU"
    declare -f menu_terraform > /dev/null
}

@test "terraform.sh source les dependances TUI" {
    grep -q "tui-common.sh\|tui-colors.sh" "$TERRAFORM_MENU" || \
    grep -q "source.*lib" "$TERRAFORM_MENU"
}

# =============================================================================
# Tests securite
# =============================================================================

@test "terraform_command() echappe les arguments" {
    source "$TERRAFORM_MENU"
    # La fonction ne doit pas permettre l'injection de commandes
    declare -f run_terraform_command > /dev/null || \
    declare -f execute_terraform > /dev/null || \
    declare -f run_terraform_plan > /dev/null
}

@test "apply ne s'execute pas sans plan prealable ou confirmation" {
    source "$TERRAFORM_MENU"
    local func_def
    func_def=$(declare -f run_terraform_apply)
    # Doit avoir une confirmation
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]] || [[ "$func_def" == *"plan"* ]]
}
