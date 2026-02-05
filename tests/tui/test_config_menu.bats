#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/menus/config.sh (T056-T062 - US8)
# =============================================================================
# Tests du menu configuration : preferences, environnement, SSH, logs

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts"
    TUI_LIB="${PROJECT_ROOT}/scripts/lib/tui"
    CONFIG_MENU="${TUI_DIR}/menus/config.sh"

    # Charger les libs TUI
    source "${TUI_LIB}/colors.sh"
    source "${TUI_LIB}/config.sh"
    source "${TUI_LIB}/common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_config"
    mkdir -p "${TEST_DIR}"

    # Mock config file
    TEST_CONFIG_FILE="${TEST_DIR}/tui-config.yaml"
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
# TUI Homelab Manager Configuration
version: "1.0"

# Environnement par defaut
default_environment: "monitoring"

# Parametres SSH
ssh:
  timeout: 10
  batch_mode: true
  known_hosts_check: false

# Parametres d'affichage
display:
  colors: true
  unicode: true
  animations: true
  compact_mode: false

# Parametres Terraform
terraform:
  auto_init: true
  auto_approve: false
  plan_output: true

# Logs
logging:
  level: "info"
  file: "/var/log/tui-homelab.log"
  max_size: "10M"
EOF

    # Mock config avec valeurs differentes
    TEST_CONFIG_NOCOLOR="${TEST_DIR}/tui-config-nocolor.yaml"
    cat > "${TEST_CONFIG_NOCOLOR}" << 'EOF'
version: "1.0"
default_environment: "prod"
display:
  colors: false
  unicode: false
EOF
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure (T056)
# =============================================================================

@test "config.sh existe" {
    [ -f "$CONFIG_MENU" ]
}

@test "config.sh peut etre source sans erreur" {
    run bash -c "source '${CONFIG_MENU}' && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "menu_config() est definie" {
    source "$CONFIG_MENU"
    declare -f menu_config > /dev/null
}

# =============================================================================
# Tests chargement configuration (T057)
# =============================================================================

@test "load_tui_config() est definie" {
    source "$CONFIG_MENU"
    declare -f load_tui_config > /dev/null
}

@test "load_tui_config() charge un fichier config" {
    source "$CONFIG_MENU"
    run load_tui_config "$TEST_CONFIG_FILE"
    [ "$status" -eq 0 ]
}

@test "get_config_value() est definie" {
    source "$CONFIG_MENU"
    declare -f get_config_value > /dev/null
}

@test "get_config_value() retourne une valeur" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run get_config_value "default_environment"
    [ "$status" -eq 0 ]
    [[ "$output" == "monitoring" ]]
}

@test "get_config_value() retourne valeur par defaut si cle absente" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run get_config_value "nonexistent_key" "default_value"
    [ "$status" -eq 0 ]
    [[ "$output" == "default_value" ]]
}

@test "get_config_path() retourne le chemin du fichier config" {
    source "$CONFIG_MENU"
    run get_config_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"config"* ]] || [[ "$output" == *".yaml"* ]] || [[ "$output" == *".yml"* ]]
}

@test "config_file_exists() verifie l'existence du fichier" {
    source "$CONFIG_MENU"
    run config_file_exists "$TEST_CONFIG_FILE"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests sauvegarde configuration (T058)
# =============================================================================

@test "save_tui_config() est definie" {
    source "$CONFIG_MENU"
    declare -f save_tui_config > /dev/null
}

@test "set_config_value() est definie" {
    source "$CONFIG_MENU"
    declare -f set_config_value > /dev/null
}

@test "set_config_value() modifie une valeur" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run set_config_value "default_environment" "prod"
    [ "$status" -eq 0 ]
}

@test "create_default_config() est definie" {
    source "$CONFIG_MENU"
    declare -f create_default_config > /dev/null
}

@test "create_default_config() cree un fichier avec valeurs par defaut" {
    source "$CONFIG_MENU"
    local new_config="${TEST_DIR}/new-config.yaml"
    run create_default_config "$new_config"
    [ "$status" -eq 0 ]
    [ -f "$new_config" ]
}

# =============================================================================
# Tests environnement par defaut (T059)
# =============================================================================

@test "get_default_environment() est definie" {
    source "$CONFIG_MENU"
    declare -f get_default_environment > /dev/null
}

@test "get_default_environment() retourne l'environnement" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run get_default_environment
    [ "$status" -eq 0 ]
    [[ "$output" == "monitoring" ]] || [[ "$output" == "prod" ]] || [[ "$output" == "lab" ]]
}

@test "set_default_environment() est definie" {
    source "$CONFIG_MENU"
    declare -f set_default_environment > /dev/null
}

@test "get_available_environments() liste les environnements" {
    source "$CONFIG_MENU"
    run get_available_environments
    [ "$status" -eq 0 ]
    [[ "$output" == *"prod"* ]] || [[ "$output" == *"monitoring"* ]] || [[ "$output" == *"lab"* ]]
}

@test "select_default_environment() est definie" {
    source "$CONFIG_MENU"
    declare -f select_default_environment > /dev/null
}

# =============================================================================
# Tests parametres SSH (T060)
# =============================================================================

@test "get_ssh_config() est definie" {
    source "$CONFIG_MENU"
    declare -f get_ssh_config > /dev/null
}

@test "get_ssh_timeout() retourne le timeout" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run get_ssh_timeout
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "set_ssh_timeout() est definie" {
    source "$CONFIG_MENU"
    declare -f set_ssh_timeout > /dev/null
}

@test "get_ssh_batch_mode() retourne le mode batch" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run get_ssh_batch_mode
    [ "$status" -eq 0 ]
    [[ "$output" == "true" ]] || [[ "$output" == "false" ]]
}

@test "test_ssh_connection() est definie" {
    source "$CONFIG_MENU"
    declare -f test_ssh_connection > /dev/null
}

# =============================================================================
# Tests parametres affichage (T061)
# =============================================================================

@test "get_display_config() est definie" {
    source "$CONFIG_MENU"
    declare -f get_display_config > /dev/null
}

@test "is_colors_enabled() retourne l'etat des couleurs" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run is_colors_enabled
    [ "$status" -eq 0 ]
    [[ "$output" == "true" ]] || [[ "$output" == "false" ]]
}

@test "is_unicode_enabled() retourne l'etat unicode" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run is_unicode_enabled
    [ "$status" -eq 0 ]
    [[ "$output" == "true" ]] || [[ "$output" == "false" ]]
}

@test "toggle_colors() est definie" {
    source "$CONFIG_MENU"
    declare -f toggle_colors > /dev/null
}

@test "toggle_unicode() est definie" {
    source "$CONFIG_MENU"
    declare -f toggle_unicode > /dev/null
}

@test "toggle_animations() est definie" {
    source "$CONFIG_MENU"
    declare -f toggle_animations > /dev/null
}

@test "is_compact_mode() retourne l'etat compact" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run is_compact_mode
    [ "$status" -eq 0 ]
    [[ "$output" == "true" ]] || [[ "$output" == "false" ]]
}

# =============================================================================
# Tests parametres Terraform (T062)
# =============================================================================

@test "get_terraform_config() est definie" {
    source "$CONFIG_MENU"
    declare -f get_terraform_config > /dev/null
}

@test "is_auto_init_enabled() retourne l'etat auto-init" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run is_auto_init_enabled
    [ "$status" -eq 0 ]
    [[ "$output" == "true" ]] || [[ "$output" == "false" ]]
}

@test "is_auto_approve_enabled() retourne l'etat auto-approve" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run is_auto_approve_enabled
    [ "$status" -eq 0 ]
    [[ "$output" == "true" ]] || [[ "$output" == "false" ]]
}

@test "toggle_auto_init() est definie" {
    source "$CONFIG_MENU"
    declare -f toggle_auto_init > /dev/null
}

@test "toggle_auto_approve() est definie" {
    source "$CONFIG_MENU"
    declare -f toggle_auto_approve > /dev/null
}

# =============================================================================
# Tests parametres logs
# =============================================================================

@test "get_log_level() retourne le niveau de log" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run get_log_level
    [ "$status" -eq 0 ]
    [[ "$output" == "info" ]] || [[ "$output" == "debug" ]] || [[ "$output" == "warn" ]] || [[ "$output" == "error" ]]
}

@test "set_log_level() est definie" {
    source "$CONFIG_MENU"
    declare -f set_log_level > /dev/null
}

@test "get_log_file() retourne le fichier de log" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run get_log_file
    [ "$status" -eq 0 ]
    [[ "$output" == *"log"* ]]
}

# =============================================================================
# Tests actions menu
# =============================================================================

@test "get_config_actions() retourne les actions disponibles" {
    source "$CONFIG_MENU"
    run get_config_actions
    [ "$status" -eq 0 ]
    [[ "$output" == *"Environnement"* ]] || [[ "$output" == *"environment"* ]]
    [[ "$output" == *"Affichage"* ]] || [[ "$output" == *"display"* ]] || [[ "$output" == *"Display"* ]]
}

@test "show_current_config() est definie" {
    source "$CONFIG_MENU"
    declare -f show_current_config > /dev/null
}

@test "show_current_config() affiche la configuration" {
    source "$CONFIG_MENU"
    load_tui_config "$TEST_CONFIG_FILE"
    run show_current_config
    [ "$status" -eq 0 ]
    [[ "$output" == *"monitoring"* ]] || [[ "$output" == *"environment"* ]] || [[ "$output" == *"config"* ]]
}

@test "reset_config() est definie" {
    source "$CONFIG_MENU"
    declare -f reset_config > /dev/null
}

@test "reset_config() requiert confirmation" {
    source "$CONFIG_MENU"
    local func_def
    func_def=$(declare -f reset_config)
    [[ "$func_def" == *"confirm"* ]] || [[ "$func_def" == *"tui_confirm"* ]]
}

# =============================================================================
# Tests integration menu
# =============================================================================

@test "menu_config gere le retour au menu principal" {
    source "$CONFIG_MENU"
    declare -f menu_config > /dev/null
}

@test "config.sh source les dependances TUI" {
    grep -q "common.sh\|colors.sh" "$CONFIG_MENU" || \
    grep -q "source.*lib" "$CONFIG_MENU"
}

@test "menu_display_settings() est definie" {
    source "$CONFIG_MENU"
    declare -f menu_display_settings > /dev/null
}

@test "menu_ssh_settings() est definie" {
    source "$CONFIG_MENU"
    declare -f menu_ssh_settings > /dev/null
}

@test "menu_terraform_settings() est definie" {
    source "$CONFIG_MENU"
    declare -f menu_terraform_settings > /dev/null
}

# =============================================================================
# Tests validation
# =============================================================================

@test "validate_environment() valide les environnements connus" {
    source "$CONFIG_MENU"
    run validate_environment "monitoring"
    [ "$status" -eq 0 ]
}

@test "validate_environment() rejette environnement invalide" {
    source "$CONFIG_MENU"
    run validate_environment "invalid_env_xyz"
    [ "$status" -ne 0 ]
}

@test "validate_log_level() valide les niveaux connus" {
    source "$CONFIG_MENU"
    run validate_log_level "info"
    [ "$status" -eq 0 ]
}

@test "validate_ssh_timeout() valide les timeouts numeriques" {
    source "$CONFIG_MENU"
    run validate_ssh_timeout "30"
    [ "$status" -eq 0 ]
}

@test "validate_ssh_timeout() rejette valeurs non numeriques" {
    source "$CONFIG_MENU"
    run validate_ssh_timeout "abc"
    [ "$status" -ne 0 ]
}
