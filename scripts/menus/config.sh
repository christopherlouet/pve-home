#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Menu Configuration (T056-T062 - US8)
# =============================================================================
# Usage: source scripts/menus/config.sh && menu_config
#
# Menu de configuration globale : preferences, environnement, SSH, affichage.
# =============================================================================

# =============================================================================
# Variables
# =============================================================================

CONFIG_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_TUI_DIR="$(cd "${CONFIG_MENU_DIR}/.." && pwd)"

# Charger les libs TUI si pas deja fait
if [[ -z "${TUI_COLOR_NC:-}" ]]; then
    source "${CONFIG_TUI_DIR}/lib/colors.sh"
fi
if [[ -z "${TUI_PROJECT_ROOT:-}" ]]; then
    source "${CONFIG_TUI_DIR}/lib/config.sh"
fi
if ! declare -f tui_menu &>/dev/null; then
    source "${CONFIG_TUI_DIR}/lib/common.sh"
fi

# Chemin du fichier de configuration
CONFIG_FILE_PATH="${TUI_PROJECT_ROOT}/.tui-config.yaml"
CONFIG_FILE_PATH_ALT="${HOME}/.config/tui-homelab/config.yaml"

# Environnements valides
readonly CONFIG_VALID_ENVS=("prod" "lab" "monitoring")

# Niveaux de log valides
readonly CONFIG_VALID_LOG_LEVELS=("debug" "info" "warn" "error")

# Configuration en memoire (associative array)
# Declarer le tableau globalement pour eviter les problemes avec set -u
if ! declare -p TUI_CONFIG &>/dev/null; then
    declare -gA TUI_CONFIG
fi

# =============================================================================
# Fonctions de chargement configuration (T057)
# =============================================================================

# Retourne le chemin du fichier de configuration
get_config_path() {
    if [[ -f "$CONFIG_FILE_PATH" ]]; then
        echo "$CONFIG_FILE_PATH"
    elif [[ -f "$CONFIG_FILE_PATH_ALT" ]]; then
        echo "$CONFIG_FILE_PATH_ALT"
    else
        echo "$CONFIG_FILE_PATH"
    fi
}

# Verifie si le fichier de configuration existe
config_file_exists() {
    local config_file="${1:-$(get_config_path)}"
    [[ -f "$config_file" ]]
}

# Charge la configuration depuis un fichier YAML
# shellcheck disable=SC2120
load_tui_config() {
    local config_file="${1:-$(get_config_path)}"

    if [[ ! -f "$config_file" ]]; then
        # Creer la configuration par defaut si elle n'existe pas
        create_default_config "$config_file"
    fi

    # Parser le YAML simple (cle: valeur)
    while IFS= read -r line; do
        # Ignorer les commentaires et lignes vides
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Parser les cles de premier niveau
        if [[ "$line" =~ ^([a-z_]+):[[:space:]]*\"?([^\"]*)\"?$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            TUI_CONFIG["$key"]="$value"
        fi

        # Parser les cles imbriquees (ssh.timeout, display.colors, etc.)
        if [[ "$line" =~ ^[[:space:]]+([a-z_]+):[[:space:]]*\"?([^\"]*)\"?$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Determiner le parent en fonction du contexte
            if [[ "${_current_section:-}" != "" ]]; then
                TUI_CONFIG["${_current_section}.${key}"]="$value"
            else
                TUI_CONFIG["$key"]="$value"
            fi
        fi

        # Detecter les sections
        if [[ "$line" =~ ^([a-z_]+):$ ]]; then
            _current_section="${BASH_REMATCH[1]}"
        fi
    done < "$config_file"

    unset _current_section
    return 0
}

# Retourne une valeur de configuration
get_config_value() {
    local key="$1"
    local default="${2:-}"

    # Utiliser une variable intermediaire pour eviter les erreurs de syntaxe
    # Note: TUI_CONFIG est declare dans tui.sh
    local value=""
    value="${TUI_CONFIG[$key]:-}"

    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# =============================================================================
# Fonctions de sauvegarde configuration (T058)
# =============================================================================

# Definit une valeur de configuration
set_config_value() {
    local key="$1"
    local value="$2"

    TUI_CONFIG["$key"]="$value"
    return 0
}

# Sauvegarde la configuration dans un fichier
save_tui_config() {
    local config_file="${1:-$(get_config_path)}"

    # Creer le repertoire si necessaire
    local config_dir
    config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir"

    # Generer le fichier YAML
    cat > "$config_file" << EOF
# TUI Homelab Manager Configuration
# Generated: $(date -Iseconds)
version: "1.0"

# Environnement par defaut
default_environment: "${TUI_CONFIG[default_environment]:-monitoring}"

# Parametres SSH
ssh:
  timeout: ${TUI_CONFIG[ssh.timeout]:-10}
  batch_mode: ${TUI_CONFIG[ssh.batch_mode]:-true}
  known_hosts_check: ${TUI_CONFIG[ssh.known_hosts_check]:-false}

# Parametres d'affichage
display:
  colors: ${TUI_CONFIG[display.colors]:-true}
  unicode: ${TUI_CONFIG[display.unicode]:-true}
  animations: ${TUI_CONFIG[display.animations]:-true}
  compact_mode: ${TUI_CONFIG[display.compact_mode]:-false}

# Parametres Terraform
terraform:
  auto_init: ${TUI_CONFIG[terraform.auto_init]:-true}
  auto_approve: ${TUI_CONFIG[terraform.auto_approve]:-false}
  plan_output: ${TUI_CONFIG[terraform.plan_output]:-true}

# Logs
logging:
  level: "${TUI_CONFIG[logging.level]:-info}"
  file: "${TUI_CONFIG[logging.file]:-/var/log/tui-homelab.log}"
  max_size: "${TUI_CONFIG[logging.max_size]:-10M}"
EOF

    tui_log_success "Configuration sauvegardee dans ${config_file}"
    return 0
}

# Cree une configuration par defaut
create_default_config() {
    local config_file="${1:-$(get_config_path)}"

    # Initialiser les valeurs par defaut
    TUI_CONFIG[default_environment]="monitoring"
    TUI_CONFIG[ssh.timeout]="10"
    TUI_CONFIG[ssh.batch_mode]="true"
    TUI_CONFIG[ssh.known_hosts_check]="false"
    TUI_CONFIG[display.colors]="true"
    TUI_CONFIG[display.unicode]="true"
    TUI_CONFIG[display.animations]="true"
    TUI_CONFIG[display.compact_mode]="false"
    TUI_CONFIG[terraform.auto_init]="true"
    TUI_CONFIG[terraform.auto_approve]="false"
    TUI_CONFIG[terraform.plan_output]="true"
    TUI_CONFIG[logging.level]="info"
    TUI_CONFIG[logging.file]="/var/log/tui-homelab.log"
    TUI_CONFIG[logging.max_size]="10M"

    save_tui_config "$config_file"
    return 0
}

# =============================================================================
# Fonctions environnement par defaut (T059)
# =============================================================================

# Retourne l'environnement par defaut
get_default_environment() {
    get_config_value "default_environment" "monitoring"
}

# Definit l'environnement par defaut
set_default_environment() {
    local env="$1"

    if ! validate_environment "$env"; then
        tui_log_error "Environnement invalide: ${env}"
        return 1
    fi

    set_config_value "default_environment" "$env"
    tui_log_success "Environnement par defaut: ${env}"
    return 0
}

# Liste les environnements disponibles
get_available_environments() {
    local env_dir="${TUI_PROJECT_ROOT}/infrastructure/proxmox/environments"

    if [[ -d "$env_dir" ]]; then
        for dir in "${env_dir}"/*/; do
            if [[ -d "$dir" ]]; then
                basename "$dir"
            fi
        done
    else
        # Fallback sur les environnements connus
        for env in "${CONFIG_VALID_ENVS[@]}"; do
            echo "$env"
        done
    fi
}

# Valide un nom d'environnement
validate_environment() {
    local env="$1"

    for valid_env in "${CONFIG_VALID_ENVS[@]}"; do
        if [[ "$env" == "$valid_env" ]]; then
            return 0
        fi
    done

    return 1
}

# Menu de selection d'environnement
select_default_environment() {
    local options=()
    local current_env
    current_env=$(get_default_environment)

    while IFS= read -r env; do
        if [[ "$env" == "$current_env" ]]; then
            options+=("● ${env} (actuel)")
        else
            options+=("○ ${env}")
        fi
    done < <(get_available_environments)
    options+=("$(tui_back_option)")

    local choice
    choice=$(tui_menu "Selectionner l'environnement par defaut" "${options[@]}")

    # Gerer le retour explicitement
    if [[ "$choice" == *"Retour"* ]] || [[ "$choice" == *"back"* ]] || [[ -z "$choice" ]]; then
        return 0
    fi

    # Extraire le nom de l'environnement
    for env in "${CONFIG_VALID_ENVS[@]}"; do
        if [[ "$choice" == *"$env"* ]]; then
            set_default_environment "$env"
            return 0
        fi
    done

    return 0
}

# =============================================================================
# Fonctions parametres SSH (T060)
# =============================================================================

# Retourne la configuration SSH
get_ssh_config() {
    echo "timeout: $(get_ssh_timeout)"
    echo "batch_mode: $(get_ssh_batch_mode)"
    echo "known_hosts_check: $(get_config_value 'ssh.known_hosts_check' 'false')"
}

# Retourne le timeout SSH
get_ssh_timeout() {
    get_config_value "ssh.timeout" "10"
}

# Definit le timeout SSH
set_ssh_timeout() {
    local timeout="$1"

    if ! validate_ssh_timeout "$timeout"; then
        tui_log_error "Timeout invalide: ${timeout}"
        return 1
    fi

    set_config_value "ssh.timeout" "$timeout"
    tui_log_success "Timeout SSH: ${timeout}s"
    return 0
}

# Valide un timeout SSH
validate_ssh_timeout() {
    local timeout="$1"

    if [[ "$timeout" =~ ^[0-9]+$ ]] && [[ "$timeout" -gt 0 ]] && [[ "$timeout" -le 300 ]]; then
        return 0
    fi

    return 1
}

# Retourne le mode batch SSH
get_ssh_batch_mode() {
    get_config_value "ssh.batch_mode" "true"
}

# Teste la connexion SSH
# shellcheck disable=SC2120
test_ssh_connection() {
    local host="${1:-}"

    # Auto-detection de l'hote si non specifie
    if [[ -z "$host" ]]; then
        local env tfvars_path
        env=$(get_default_environment 2>/dev/null) || env="monitoring"
        tfvars_path="${TUI_PROJECT_ROOT}/infrastructure/proxmox/environments/${env}/terraform.tfvars"

        if [[ -f "$tfvars_path" ]]; then
            # Essayer proxmox_endpoint d'abord (format: https://IP:8006)
            local endpoint
            endpoint=$(grep -E "^proxmox_endpoint\s*=" "$tfvars_path" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1) || true
            if [[ -n "$endpoint" ]]; then
                # Extraire l'IP de l'URL
                host=$(echo "$endpoint" | sed -E 's|https?://([0-9.]+).*|\1|') || true
            fi
            # Fallback sur pve_ip si existe
            if [[ -z "$host" ]]; then
                host=$(grep -E "^pve_ip\s*=" "$tfvars_path" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' | head -1) || true
            fi
        fi
    fi

    if [[ -z "$host" ]]; then
        tui_log_error "Aucun hote specifie et impossible de detecter depuis tfvars"
        return 0
    fi

    local timeout
    timeout=$(get_ssh_timeout 2>/dev/null) || timeout="10"

    tui_log_info "Test de connexion SSH vers root@${host}..."

    if ssh -n -o ConnectTimeout="$timeout" -o BatchMode=yes "root@${host}" "echo OK" &>/dev/null; then
        tui_log_success "Connexion SSH OK vers ${host}"
    else
        tui_log_error "Echec de la connexion SSH vers ${host}"
    fi

    return 0
}

# =============================================================================
# Fonctions parametres affichage (T061)
# =============================================================================

# Retourne la configuration d'affichage
get_display_config() {
    echo "colors: $(is_colors_enabled)"
    echo "unicode: $(is_unicode_enabled)"
    echo "animations: $(get_config_value 'display.animations' 'true')"
    echo "compact_mode: $(is_compact_mode)"
}

# Verifie si les couleurs sont activees
is_colors_enabled() {
    get_config_value "display.colors" "true"
}

# Verifie si unicode est active
is_unicode_enabled() {
    get_config_value "display.unicode" "true"
}

# Verifie si le mode compact est active
is_compact_mode() {
    get_config_value "display.compact_mode" "false"
}

# Active/desactive les couleurs
toggle_colors() {
    local current
    current=$(is_colors_enabled)

    if [[ "$current" == "true" ]]; then
        set_config_value "display.colors" "false"
        tui_log_info "Couleurs desactivees"
    else
        set_config_value "display.colors" "true"
        tui_log_info "Couleurs activees"
    fi
}

# Active/desactive unicode
toggle_unicode() {
    local current
    current=$(is_unicode_enabled)

    if [[ "$current" == "true" ]]; then
        set_config_value "display.unicode" "false"
        tui_log_info "Unicode desactive"
    else
        set_config_value "display.unicode" "true"
        tui_log_info "Unicode active"
    fi
}

# Active/desactive les animations
toggle_animations() {
    local current
    current=$(get_config_value "display.animations" "true")

    if [[ "$current" == "true" ]]; then
        set_config_value "display.animations" "false"
        tui_log_info "Animations desactivees"
    else
        set_config_value "display.animations" "true"
        tui_log_info "Animations activees"
    fi
}

# =============================================================================
# Fonctions parametres Terraform (T062)
# =============================================================================

# Retourne la configuration Terraform
get_terraform_config() {
    echo "auto_init: $(is_auto_init_enabled)"
    echo "auto_approve: $(is_auto_approve_enabled)"
    echo "plan_output: $(get_config_value 'terraform.plan_output' 'true')"
}

# Verifie si auto-init est active
is_auto_init_enabled() {
    get_config_value "terraform.auto_init" "true"
}

# Verifie si auto-approve est active
is_auto_approve_enabled() {
    get_config_value "terraform.auto_approve" "false"
}

# Active/desactive auto-init
toggle_auto_init() {
    local current
    current=$(is_auto_init_enabled)

    if [[ "$current" == "true" ]]; then
        set_config_value "terraform.auto_init" "false"
        tui_log_info "Auto-init desactive"
    else
        set_config_value "terraform.auto_init" "true"
        tui_log_info "Auto-init active"
    fi
}

# Active/desactive auto-approve
toggle_auto_approve() {
    local current
    current=$(is_auto_approve_enabled)

    if [[ "$current" == "true" ]]; then
        set_config_value "terraform.auto_approve" "false"
        tui_log_info "Auto-approve desactive"
    else
        set_config_value "terraform.auto_approve" "true"
        tui_log_warn "Auto-approve active - attention aux modifications automatiques!"
    fi
}

# =============================================================================
# Fonctions parametres logs
# =============================================================================

# Retourne le niveau de log
get_log_level() {
    get_config_value "logging.level" "info"
}

# Definit le niveau de log
set_log_level() {
    local level="$1"

    if ! validate_log_level "$level"; then
        tui_log_error "Niveau de log invalide: ${level}"
        return 1
    fi

    set_config_value "logging.level" "$level"
    tui_log_success "Niveau de log: ${level}"
    return 0
}

# Valide un niveau de log
validate_log_level() {
    local level="$1"

    for valid_level in "${CONFIG_VALID_LOG_LEVELS[@]}"; do
        if [[ "$level" == "$valid_level" ]]; then
            return 0
        fi
    done

    return 1
}

# Retourne le fichier de log
get_log_file() {
    get_config_value "logging.file" "/var/log/tui-homelab.log"
}

# =============================================================================
# Fonctions d'affichage
# =============================================================================

# Retourne les actions disponibles
get_config_actions() {
    echo "1. 🌐 Environnement par defaut"
    echo "2. 🖥️  Affichage (couleurs, unicode)"
    echo "3. 🔗 Parametres SSH"
    echo "4. 🏗️  Parametres Terraform"
    echo "5. 📝 Niveau de log"
    echo "6. 📋 Voir la configuration actuelle"
    echo "7. 🔄 Reinitialiser la configuration"
    echo "8. 💾 Sauvegarder les modifications"
    echo "9. ↩️  Retour - Revenir au menu principal"
}

# Affiche la configuration actuelle
show_current_config() {
    # Charger la configuration si pas encore fait
    # Desactiver nounset temporairement pour la verification du tableau
    local old_nounset=""
    if [[ -o nounset ]]; then
        old_nounset="true"
        set +u
    fi

    # Declarer le tableau si pas encore fait
    if [[ -z "${TUI_CONFIG+x}" ]]; then
        declare -gA TUI_CONFIG
    fi

    if [[ ${#TUI_CONFIG[@]} -eq 0 ]]; then
        load_tui_config
    fi

    # Restaurer nounset
    if [[ "$old_nounset" == "true" ]]; then
        set -u
    fi

    echo ""
    tui_banner "Configuration actuelle"

    echo -e "${TUI_COLOR_INFO}Environnement par defaut:${TUI_COLOR_NC} $(get_default_environment)"
    echo ""

    echo -e "${TUI_COLOR_INFO}Affichage:${TUI_COLOR_NC}"
    echo "  Couleurs: $(is_colors_enabled)"
    echo "  Unicode: $(is_unicode_enabled)"
    echo "  Mode compact: $(is_compact_mode)"
    echo ""

    echo -e "${TUI_COLOR_INFO}SSH:${TUI_COLOR_NC}"
    echo "  Timeout: $(get_ssh_timeout)s"
    echo "  Mode batch: $(get_ssh_batch_mode)"
    echo ""

    echo -e "${TUI_COLOR_INFO}Terraform:${TUI_COLOR_NC}"
    echo "  Auto-init: $(is_auto_init_enabled)"
    echo "  Auto-approve: $(is_auto_approve_enabled)"
    echo ""

    echo -e "${TUI_COLOR_INFO}Logs:${TUI_COLOR_NC}"
    echo "  Niveau: $(get_log_level)"
    echo "  Fichier: $(get_log_file)"
}

# Reinitialise la configuration
reset_config() {
    if ! tui_confirm "Voulez-vous reinitialiser la configuration par defaut ?"; then
        tui_log_info "Operation annulee"
        return 0  # Annulation n'est pas une erreur
    fi

    # Vider la configuration actuelle
    TUI_CONFIG=()

    # Recreer avec les valeurs par defaut
    create_default_config

    tui_log_success "Configuration reinitialisee"
    return 0
}

# =============================================================================
# Sous-menus
# =============================================================================

# Menu parametres d'affichage
menu_display_settings() {
    local running=true

    while $running; do
        tui_banner "Parametres d'affichage"

        local colors_status unicode_status anim_status compact_status
        colors_status=$(is_colors_enabled)
        unicode_status=$(is_unicode_enabled)
        anim_status=$(get_config_value "display.animations" "true")
        compact_status=$(is_compact_mode)

        local options=(
            "1. 🎨 Couleurs: ${colors_status}"
            "2. ✨ Unicode: ${unicode_status}"
            "3. 🎬 Animations: ${anim_status}"
            "4. 📦 Mode compact: ${compact_status}"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Parametres d'affichage" "${options[@]}")

        case "$choice" in
            "1."*|*"Couleurs"*)
                toggle_colors
                ;;
            "2."*|*"Unicode"*)
                toggle_unicode
                ;;
            "3."*|*"Animations"*)
                toggle_animations
                ;;
            "4."*|*"compact"*)
                local current
                current=$(is_compact_mode)
                if [[ "$current" == "true" ]]; then
                    set_config_value "display.compact_mode" "false"
                else
                    set_config_value "display.compact_mode" "true"
                fi
                ;;
            *"Retour"*|*"back"*|"")
                running=false
                ;;
        esac
    done
}

# Menu parametres SSH
menu_ssh_settings() {
    local running=true

    while $running; do
        tui_banner "Parametres SSH"

        local timeout batch_mode
        timeout=$(get_ssh_timeout)
        batch_mode=$(get_ssh_batch_mode)

        local options=(
            "1. ⏱️  Timeout: ${timeout}s"
            "2. 🔄 Mode batch: ${batch_mode}"
            "3. 🧪 Tester la connexion"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Parametres SSH" "${options[@]}")

        case "$choice" in
            "1."*|*"Timeout"*)
                local new_timeout
                new_timeout=$(tui_input "Nouveau timeout (secondes)" "$timeout")
                if [[ -n "$new_timeout" ]]; then
                    set_ssh_timeout "$new_timeout"
                fi
                ;;
            "2."*|*"batch"*)
                if [[ "$batch_mode" == "true" ]]; then
                    set_config_value "ssh.batch_mode" "false"
                else
                    set_config_value "ssh.batch_mode" "true"
                fi
                ;;
            "3."*|*"Tester"*)
                test_ssh_connection
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Retour"*|*"back"*|"")
                running=false
                ;;
        esac
    done
}

# Menu parametres Terraform
menu_terraform_settings() {
    local running=true

    while $running; do
        tui_banner "Parametres Terraform"

        local auto_init auto_approve plan_output
        auto_init=$(is_auto_init_enabled)
        auto_approve=$(is_auto_approve_enabled)
        plan_output=$(get_config_value "terraform.plan_output" "true")

        local options=(
            "1. 🚀 Auto-init: ${auto_init}"
            "2. ✅ Auto-approve: ${auto_approve}"
            "3. 📋 Afficher plan: ${plan_output}"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Parametres Terraform" "${options[@]}")

        case "$choice" in
            "1."*|*"init"*)
                toggle_auto_init
                ;;
            "2."*|*"approve"*)
                toggle_auto_approve
                ;;
            "3."*|*"plan"*)
                local current
                current=$(get_config_value "terraform.plan_output" "true")
                if [[ "$current" == "true" ]]; then
                    set_config_value "terraform.plan_output" "false"
                else
                    set_config_value "terraform.plan_output" "true"
                fi
                ;;
            *"Retour"*|*"back"*|"")
                running=false
                ;;
        esac
    done
}

# =============================================================================
# Menu principal configuration
# =============================================================================

menu_config() {
    local running=true

    # Charger la configuration au demarrage
    load_tui_config

    while $running; do
        clear
        tui_banner "Configuration"
        echo -e "${TUI_COLOR_WHITE}Gestion des preferences du TUI${TUI_COLOR_NC}"

        local options=(
            "1. 🌐 Environnement par defaut"
            "2. 🖥️  Affichage (couleurs, unicode)"
            "3. 🔗 Parametres SSH"
            "4. 🏗️  Parametres Terraform"
            "5. 📝 Niveau de log"
            "6. 📋 Voir la configuration actuelle"
            "7. 🔄 Reinitialiser la configuration"
            "8. 💾 Sauvegarder les modifications"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Que voulez-vous configurer ?" "${options[@]}")

        case "$choice" in
            "1."*|*"Environnement"*)
                select_default_environment
                ;;
            "2."*|*"Affichage"*)
                menu_display_settings
                ;;
            "3."*|*"SSH"*)
                menu_ssh_settings
                ;;
            "4."*|*"Terraform"*)
                menu_terraform_settings
                ;;
            "5."*|*"log"*)
                local current_log options_log=()
                current_log=$(get_log_level 2>/dev/null) || current_log="info"
                for level in debug info warn error; do
                    if [[ "$level" == "$current_log" ]]; then
                        options_log+=("● ${level} (actuel)")
                    else
                        options_log+=("○ ${level}")
                    fi
                done
                options_log+=("$(tui_back_option)")
                local log_choice
                log_choice=$(tui_menu "Niveau de log" "${options_log[@]}")
                if [[ "$log_choice" != *"Retour"* ]] && [[ -n "$log_choice" ]]; then
                    # Extraire le niveau du choix (enlever ● ○ et (actuel))
                    local selected_level
                    selected_level=$(echo "$log_choice" | sed 's/[●○] //' | sed 's/ (actuel)//')
                    set_log_level "$selected_level"
                fi
                ;;
            "6."*|*"Voir"*|*"actuelle"*)
                show_current_config
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "7."*|*"Reinitialiser"*)
                reset_config
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "8."*|*"Sauvegarder"*)
                save_tui_config
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Retour"*|*"back"*|"")
                running=false
                ;;
            *)
                tui_log_warn "Option non reconnue"
                ;;
        esac
    done
}

# =============================================================================
# Export des fonctions
# =============================================================================

export -f menu_config
export -f get_config_path config_file_exists load_tui_config get_config_value
export -f save_tui_config set_config_value create_default_config
export -f get_default_environment set_default_environment get_available_environments
export -f validate_environment select_default_environment
export -f get_ssh_config get_ssh_timeout set_ssh_timeout validate_ssh_timeout
export -f get_ssh_batch_mode test_ssh_connection
export -f get_display_config is_colors_enabled is_unicode_enabled is_compact_mode
export -f toggle_colors toggle_unicode toggle_animations
export -f get_terraform_config is_auto_init_enabled is_auto_approve_enabled
export -f toggle_auto_init toggle_auto_approve
export -f get_log_level set_log_level validate_log_level get_log_file
export -f get_config_actions show_current_config reset_config
export -f menu_display_settings menu_ssh_settings menu_terraform_settings
