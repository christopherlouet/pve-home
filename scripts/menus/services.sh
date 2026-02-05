#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Menu Services (T049-T055 - US7)
# =============================================================================
# Usage: source scripts/menus/services.sh && menu_services
#
# Menu de gestion des services : liste, activation/desactivation, demarrage/arret.
# =============================================================================

# =============================================================================
# Variables
# =============================================================================

SERVICES_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_TUI_DIR="$(cd "${SERVICES_MENU_DIR}/.." && pwd)"

# Charger les libs TUI si pas deja fait
if [[ -z "${TUI_COLOR_NC:-}" ]]; then
    source "${SERVICES_TUI_DIR}/lib/colors.sh"
fi
if [[ -z "${TUI_PROJECT_ROOT:-}" ]]; then
    source "${SERVICES_TUI_DIR}/lib/config.sh"
fi
if ! declare -f tui_menu &>/dev/null; then
    source "${SERVICES_TUI_DIR}/lib/common.sh"
fi

# Services connus du homelab
readonly KNOWN_SERVICES=("monitoring" "minio" "backup" "telegram" "harbor" "grafana" "prometheus" "loki")

# Chemin des environnements
SERVICES_ENV_DIR="${TUI_PROJECT_ROOT}/infrastructure/proxmox/environments"

# =============================================================================
# Detection automatique du host pour les services
# =============================================================================

# Retourne l'IP du host ou tourne un service
# Usage: get_service_host "minio" -> "192.168.1.52"
get_service_host() {
    local service="$1"
    local host_ip=""

    # Chercher dans les fichiers tfvars
    for env_dir in "${SERVICES_ENV_DIR}"/*/; do
        local tfvars_file="${env_dir}terraform.tfvars"
        [[ -f "$tfvars_file" ]] || continue

        case "$service" in
            minio)
                # Minio a son propre bloc avec une IP (conteneur LXC)
                host_ip=$(grep -A15 "^minio" "$tfvars_file" 2>/dev/null | \
                    grep -oP 'ip\s*=\s*"\K[0-9.]+' | head -1)
                ;;
            grafana|prometheus|loki|alertmanager)
                # Services du monitoring-stack (VM avec docker-compose)
                host_ip=$(grep -A15 "^monitoring" "$tfvars_file" 2>/dev/null | \
                    grep -oP 'ip\s*=\s*"\K[0-9.]+' | head -1)
                ;;
            monitoring)
                # Le service monitoring lui-meme (VM)
                host_ip=$(grep -A15 "^monitoring" "$tfvars_file" 2>/dev/null | \
                    grep -oP 'ip\s*=\s*"\K[0-9.]+' | head -1)
                ;;
            backup|telegram|harbor)
                # Services de configuration Proxmox (pas de conteneur Docker)
                # backup = job vzdump, telegram = notifications, harbor = registry
                # Retourner vide car ces services n'ont pas de statut "running"
                host_ip=""
                ;;
        esac

        [[ -n "$host_ip" ]] && break
    done

    echo "$host_ip"
}

# Retourne le user SSH pour une IP donnee
# VMs (.51, .101, .102, .103) = ubuntu
# Proxmox/LXC (.50, .52, .100) = root
get_ssh_user_for_ip() {
    local ip="$1"
    local last_octet="${ip##*.}"

    case "$last_octet" in
        51|101|102|103)
            echo "ubuntu"
            ;;
        *)
            echo "root"
            ;;
    esac
}

# Retourne le user@host pour SSH vers un service
get_service_ssh_target() {
    local service="$1"

    local host_ip
    host_ip=$(get_service_host "$service")

    if [[ -n "$host_ip" ]]; then
        local ssh_user
        ssh_user=$(get_ssh_user_for_ip "$host_ip")
        echo "${ssh_user}@${host_ip}"
    fi
}

# =============================================================================
# Fonctions utilitaires (T050)
# =============================================================================

# Retourne la liste des services disponibles
get_available_services() {
    for service in "${KNOWN_SERVICES[@]}"; do
        echo "$service"
    done
}

# Retourne le statut d'un service (enabled/disabled + running/stopped)
get_service_status() {
    local service="$1"
    local tfvars_file="${2:-}"

    local enabled
    enabled=$(get_service_enabled "$service" "$tfvars_file")

    local running
    running=$(get_service_running "$service")

    echo "${enabled}|${running}"
}

# Verifie si un service est active dans tfvars
get_service_enabled() {
    local service="$1"
    local tfvars_file="${2:-}"

    # Services du monitoring-stack heritent du statut de monitoring
    local check_service="$service"
    case "$service" in
        grafana|prometheus|loki|alertmanager|promtail)
            check_service="monitoring"
            ;;
    esac

    # Si pas de fichier specifie, chercher dans les environnements
    if [[ -z "$tfvars_file" ]]; then
        for env_dir in "${SERVICES_ENV_DIR}"/*/; do
            local tf_file="${env_dir}terraform.tfvars"
            if [[ -f "$tf_file" ]]; then
                local result
                result=$(_check_service_in_tfvars "$check_service" "$tf_file")
                if [[ -n "$result" ]]; then
                    echo "$result"
                    return 0
                fi
            fi
        done
        echo "unknown"
        return 0
    fi

    _check_service_in_tfvars "$service" "$tfvars_file"
}

# Helper pour verifier un service dans un fichier tfvars
_check_service_in_tfvars() {
    local service="$1"
    local tfvars_file="$2"

    if [[ ! -f "$tfvars_file" ]]; then
        echo "unknown"
        return 0
    fi

    # Methode simplifiee : grep direct pour enabled dans le bloc du service
    # Extraire le bloc du service et chercher enabled
    local block_content
    block_content=$(awk "/^[[:space:]]*${service}[[:space:]]*=/{found=1} found{print; if(/\}/)exit}" "$tfvars_file" 2>/dev/null)

    if [[ -n "$block_content" ]]; then
        # Chercher enabled = true/false dans le bloc
        if echo "$block_content" | grep -qE 'enabled[[:space:]]*=[[:space:]]*true'; then
            echo "true"
            return 0
        elif echo "$block_content" | grep -qE 'enabled[[:space:]]*=[[:space:]]*false'; then
            echo "false"
            return 0
        else
            # Bloc existe mais pas d'enabled explicite = actif
            echo "true"
            return 0
        fi
    fi

    echo "unknown"
}

# Cache des services par host (evite SSH multiples)
# Format: "IP1:service1,service2;IP2:service3,service4"
_SERVICES_CACHE_DATA=""

# Recupere la liste des services running d'un host (docker + systemd, avec cache)
_get_host_services() {
    local ssh_target="$1"
    # Extraire l'IP pour la cle du cache
    local cache_key="${ssh_target##*@}"

    # Chercher dans le cache (format IP:services)
    local cached
    cached=$(echo "$_SERVICES_CACHE_DATA" | tr ';' '\n' | grep "^${cache_key}:" | cut -d: -f2-)
    if [[ -n "$cached" ]]; then
        echo "$cached" | tr ',' '\n'
        return 0
    fi

    # Recuperer containers docker ET services systemd running
    local services
    services=$(ssh -n -o ConnectTimeout=3 -o BatchMode=yes "${ssh_target}" \
        "{ docker ps --format '{{.Names}}' 2>/dev/null; systemctl list-units --type=service --state=running --no-legend 2>/dev/null | awk '{gsub(/\.service/,\"\"); print \$1}'; } | sort -u" 2>/dev/null || echo "")

    # Mettre en cache (format IP:service1,service2)
    local services_csv
    services_csv=$(echo "$services" | tr '\n' ',' | sed 's/,$//')
    if [[ -n "$_SERVICES_CACHE_DATA" ]]; then
        _SERVICES_CACHE_DATA="${_SERVICES_CACHE_DATA};${cache_key}:${services_csv}"
    else
        _SERVICES_CACHE_DATA="${cache_key}:${services_csv}"
    fi

    echo "$services"
}

# Verifie si un service est en cours d'execution
get_service_running() {
    local service="$1"

    # Auto-detection du host si MONITORING_HOST non defini
    local ssh_target="${MONITORING_HOST:-}"
    if [[ -z "$ssh_target" ]]; then
        ssh_target=$(get_service_ssh_target "$service")
    fi

    # Sans host, retourner unknown
    if [[ -z "$ssh_target" ]]; then
        echo "unknown"
        return 0
    fi

    # Pour le service "monitoring", verifier si grafana OU prometheus OU loki tourne
    local check_name="$service"
    if [[ "$service" == "monitoring" ]]; then
        check_name="grafana|prometheus|loki"
    fi

    # Recuperer les services (docker + systemd, avec cache)
    local services
    services=$(_get_host_services "$ssh_target")

    if [[ -z "$services" ]]; then
        echo "unknown"
        return 0
    fi

    # Verifier si le service est dans la liste
    if echo "$services" | grep -qE "^(${check_name})$"; then
        echo "running"
    else
        echo "stopped"
    fi
}

# Alias pour get_service_running
check_service_running() {
    get_service_running "$@"
}

# Formate le statut d'un service pour l'affichage
format_service_status() {
    local service="$1"
    local enabled="${2:-unknown}"
    local running="${3:-unknown}"

    local enabled_icon running_icon

    case "$enabled" in
        "true"|"enabled"|"actif")
            enabled_icon="${TUI_COLOR_SUCCESS}[ON]${TUI_COLOR_NC}"
            ;;
        "false"|"disabled"|"inactif")
            enabled_icon="${TUI_COLOR_ERROR}[OFF]${TUI_COLOR_NC}"
            ;;
        *)
            enabled_icon="${TUI_COLOR_MUTED}[--]${TUI_COLOR_NC}"
            ;;
    esac

    case "$running" in
        "running"|"up"|"active")
            running_icon="${TUI_COLOR_SUCCESS}●${TUI_COLOR_NC}"
            ;;
        "stopped"|"down"|"inactive")
            running_icon="${TUI_COLOR_ERROR}●${TUI_COLOR_NC}"
            ;;
        *)
            running_icon="${TUI_COLOR_MUTED}○${TUI_COLOR_NC}"
            ;;
    esac

    echo -e "${running_icon} ${service} ${enabled_icon}"
}

# Retourne l'icone de statut
get_service_status_icon() {
    local status="$1"

    case "$status" in
        "running"|"up"|"active"|"on")
            echo -e "${TUI_COLOR_SUCCESS}[ON]${TUI_COLOR_NC}"
            ;;
        "stopped"|"down"|"inactive"|"off")
            echo -e "${TUI_COLOR_ERROR}[OFF]${TUI_COLOR_NC}"
            ;;
        *)
            echo -e "${TUI_COLOR_MUTED}[--]${TUI_COLOR_NC}"
            ;;
    esac
}

# Liste tous les services avec leur statut
list_services() {
    echo ""
    tui_log_info "Services disponibles :"
    echo ""

    for service in "${KNOWN_SERVICES[@]}"; do
        local status enabled running
        status=$(get_service_status "$service")
        enabled=$(echo "$status" | cut -d'|' -f1)
        running=$(echo "$status" | cut -d'|' -f2)

        format_service_status "$service" "$enabled" "$running"
    done
}

# =============================================================================
# Fonctions enable/disable (T051)
# =============================================================================

# Active ou desactive un service
toggle_service() {
    local service="$1"
    local new_state="${2:-}"

    # Verifier l'etat actuel
    local current_state
    current_state=$(get_service_enabled "$service")

    if [[ -z "$new_state" ]]; then
        if [[ "$current_state" == "true" ]]; then
            new_state="false"
        else
            new_state="true"
        fi
    fi

    # Demander confirmation
    local action_text
    if [[ "$new_state" == "true" ]]; then
        action_text="activer"
    else
        action_text="desactiver"
    fi

    if ! tui_confirm "Voulez-vous ${action_text} le service ${service} ?"; then
        tui_log_info "Operation annulee"
        return 1
    fi

    # Mettre a jour le tfvars
    update_tfvars_enabled "$service" "$new_state"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        tui_log_success "Service ${service} ${action_text}"
        propose_terraform_apply "$service"
    else
        tui_log_error "Echec de la modification"
    fi

    return $exit_code
}

# Active un service
enable_service() {
    local service="$1"

    if ! tui_confirm "Voulez-vous activer le service ${service} ?"; then
        tui_log_info "Operation annulee"
        return 1
    fi

    update_tfvars_enabled "$service" "true"
}

# Desactive un service
disable_service() {
    local service="$1"

    if ! tui_confirm "Voulez-vous desactiver le service ${service} ?"; then
        tui_log_info "Operation annulee"
        return 1
    fi

    update_tfvars_enabled "$service" "false"
}

# Met a jour l'attribut enabled dans le tfvars
# Note: Cette fonction doit etre appelee apres tui_confirm au niveau appelant
update_tfvars_enabled() {
    local service="$1"
    local new_value="$2"
    local tfvars_file="${3:-}"
    local skip_confirm="${4:-false}"

    # Securite: verifier que l'appelant a confirme (ou skip explicite)
    if [[ "$skip_confirm" != "true" ]] && [[ -z "${_TFVARS_CONFIRMED:-}" ]]; then
        tui_log_warn "Modification tfvars sans confirmation - utilisez tui_confirm avant"
    fi

    # Trouver le fichier tfvars contenant le service
    if [[ -z "$tfvars_file" ]]; then
        for env_dir in "${SERVICES_ENV_DIR}"/*/; do
            local tf_file="${env_dir}terraform.tfvars"
            if [[ -f "$tf_file" ]] && grep -q "^[[:space:]]*${service}[[:space:]]*=" "$tf_file"; then
                tfvars_file="$tf_file"
                break
            fi
        done
    fi

    if [[ -z "$tfvars_file" ]] || [[ ! -f "$tfvars_file" ]]; then
        tui_log_error "Fichier tfvars introuvable pour le service ${service}"
        return 1
    fi

    # Modifier le fichier avec sed
    if grep -q "${service}.*enabled" "$tfvars_file"; then
        sed -i "s/\(${service}.*enabled[[:space:]]*=[[:space:]]*\)\(true\|false\)/\1${new_value}/" "$tfvars_file"
    else
        tui_log_warn "Attribut enabled non trouve pour ${service}"
        return 1
    fi

    return 0
}

# Alias pour update_tfvars_enabled
modify_tfvars() {
    update_tfvars_enabled "$@"
}

# Version dry-run de toggle_service
toggle_service_dry_run() {
    local service="$1"
    local new_state="${2:-}"

    local current_state
    current_state=$(get_service_enabled "$service")

    if [[ -z "$new_state" ]]; then
        if [[ "$current_state" == "true" ]]; then
            new_state="false"
        else
            new_state="true"
        fi
    fi

    echo "[DRY-RUN] Service ${service}: ${current_state} -> ${new_state}"
}

# =============================================================================
# Fonctions terraform apply (T052)
# =============================================================================

# Propose d'appliquer les changements Terraform
propose_terraform_apply() {
    local service="$1"

    echo ""
    tui_log_info "Les fichiers tfvars ont ete modifies."

    if tui_confirm "Voulez-vous appliquer les changements avec Terraform ?"; then
        run_terraform_apply_for_service "$service"
    else
        tui_log_info "Pensez a executer 'terraform apply' manuellement"
    fi
}

# Alias pour propose_terraform_apply
suggest_apply() {
    propose_terraform_apply "$@"
}

# Execute terraform apply pour le service
run_terraform_apply_for_service() {
    local service="$1"

    # Trouver l'environnement du service
    local env_dir=""
    for dir in "${SERVICES_ENV_DIR}"/*/; do
        if [[ -f "${dir}terraform.tfvars" ]] && grep -q "^[[:space:]]*${service}[[:space:]]*=" "${dir}terraform.tfvars"; then
            env_dir="$dir"
            break
        fi
    done

    if [[ -z "$env_dir" ]]; then
        tui_log_error "Environnement introuvable pour ${service}"
        return 1
    fi

    tui_log_info "Execution de terraform apply dans ${env_dir}..."
    echo ""

    (cd "$env_dir" && terraform apply -auto-approve)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        tui_log_success "Terraform apply termine"
    else
        tui_log_error "Echec de terraform apply"
    fi

    return $exit_code
}

# Alias pour run_terraform_apply_for_service
apply_service_changes() {
    run_terraform_apply_for_service "$@"
}

# =============================================================================
# Fonctions start/stop service (T053)
# =============================================================================

# Demarre un service
start_service() {
    local service="$1"

    tui_log_info "Demarrage du service ${service}..."

    local cmd
    cmd=$(get_service_command "$service" "start")

    execute_service_command "$cmd" "$service"
}

# Arrete un service
stop_service() {
    local service="$1"

    if ! tui_confirm "Voulez-vous arreter le service ${service} ?"; then
        tui_log_info "Operation annulee"
        return 1
    fi

    tui_log_info "Arret du service ${service}..."

    local cmd
    cmd=$(get_service_command "$service" "stop")

    execute_service_command "$cmd" "$service"
}

# Redemarre un service
restart_service() {
    local service="$1"

    tui_log_info "Redemarrage du service ${service}..."

    local cmd
    cmd=$(get_service_command "$service" "restart")

    execute_service_command "$cmd" "$service"
}

# Retourne la commande appropriee pour un service
get_service_command() {
    local service="$1"
    local action="$2"

    # Determiner le type de service (docker ou systemd)
    case "$service" in
        "monitoring"|"grafana"|"prometheus"|"loki"|"minio")
            echo "docker compose -f /opt/${service}/docker-compose.yml ${action}"
            ;;
        *)
            echo "systemctl ${action} ${service}"
            ;;
    esac
}

# Execute une commande sur le service via SSH
execute_service_command() {
    local cmd="$1"
    local service="$2"

    # Auto-detection du host si MONITORING_HOST non defini
    local ssh_target="${MONITORING_HOST:-}"
    if [[ -z "$ssh_target" ]]; then
        ssh_target=$(get_service_ssh_target "$service")
    fi

    if [[ -z "$ssh_target" ]]; then
        tui_log_error "Impossible de determiner le host pour ${service}"
        tui_log_info "Commande a executer manuellement : ${cmd}"
        tui_log_info "Ou definir MONITORING_HOST=root@<ip>"
        return 1
    fi

    tui_log_info "Connexion a ${ssh_target}..."
    local output exit_code
    # -n pour eviter que SSH consomme stdin (important dans les boucles)
    output=$(ssh -n -o ConnectTimeout=10 -o BatchMode=yes "${ssh_target}" "$cmd" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        tui_log_success "Commande executee avec succes"
        show_service_status "$service"
    else
        handle_service_error "$output" "$service"
    fi

    return $exit_code
}

# Alias pour execute_service_command
run_service_command() {
    execute_service_command "$@"
}

# =============================================================================
# Fonctions d'affichage (T054)
# =============================================================================

# Affiche le statut d'un service
show_service_status() {
    local service="$1"

    echo ""
    tui_log_info "Statut de ${service} :"

    local status enabled running
    status=$(get_service_status "$service")
    enabled=$(echo "$status" | cut -d'|' -f1)
    running=$(echo "$status" | cut -d'|' -f2)

    format_service_status "$service" "$enabled" "$running"
}

# Alias pour show_service_status
display_service_status() {
    show_service_status "$@"
}

# Rafraichit le statut d'un service
refresh_service_status() {
    local service="$1"

    tui_log_info "Rafraichissement du statut..."
    show_service_status "$service"
}

# Alias pour refresh_service_status
update_service_display() {
    refresh_service_status "$@"
}

# =============================================================================
# Fonctions de gestion d'erreurs
# =============================================================================

# Gere les erreurs de service
handle_service_error() {
    local error_output="$1"
    local service="${2:-}"

    echo ""
    tui_log_error "Erreur lors de l'operation sur ${service}"
    echo ""

    if [[ "$error_output" == *"Connection refused"* ]]; then
        tui_log_error "Connection refused - verifiez que le service SSH est accessible"
    elif [[ "$error_output" == *"Permission denied"* ]]; then
        tui_log_error "Permission denied - verifiez les droits SSH"
    elif [[ "$error_output" == *"not found"* ]]; then
        tui_log_error "Service non trouve"
    else
        echo "Details: ${error_output}"
    fi
}

# Verifie les prerequis
check_services_prerequisites() {
    local missing=()

    if ! command -v ssh &>/dev/null; then
        missing+=("ssh")
    fi

    if ! command -v terraform &>/dev/null; then
        missing+=("terraform")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        tui_log_error "Commandes manquantes: ${missing[*]}"
        return 1
    fi

    return 0
}

# =============================================================================
# Actions du menu
# =============================================================================

# Retourne les actions disponibles
get_services_actions() {
    echo "1. 📋 Lister les services"
    echo "2. ✅ Activer un service"
    echo "3. ❌ Desactiver un service"
    echo "4. ▶️  Demarrer un service"
    echo "5. ⏹️  Arreter un service"
    echo "6. 🔄 Redemarrer un service"
    echo "7. ↩️  Retour - Revenir au menu principal"
}

# Selection d'un service
select_service() {
    local options=()

    for service in "${KNOWN_SERVICES[@]}"; do
        local status enabled running
        status=$(get_service_status "$service")
        enabled=$(echo "$status" | cut -d'|' -f1)
        running=$(echo "$status" | cut -d'|' -f2)

        local formatted
        formatted=$(format_service_status "$service" "$enabled" "$running")
        options+=("$formatted")
    done
    options+=("$(tui_back_option)")

    local choice
    choice=$(tui_menu "Selectionner un service" "${options[@]}")

    # Extraire le nom du service
    for service in "${KNOWN_SERVICES[@]}"; do
        if [[ "$choice" == *"$service"* ]]; then
            echo "$service"
            return 0
        fi
    done

    return 1
}

# Menu d'action pour un service
menu_service_action() {
    local service="$1"

    local options=(
        "1. ℹ️  Voir le statut"
        "2. ✅ Activer"
        "3. ❌ Desactiver"
        "4. ▶️  Demarrer"
        "5. ⏹️  Arreter"
        "6. 🔄 Redemarrer"
        "$(tui_back_option)"
    )

    tui_menu "Actions pour ${service}" "${options[@]}"
}

# Alias pour menu_service_action
select_service_action() {
    menu_service_action "$@"
}

# =============================================================================
# Menu principal services
# =============================================================================

menu_services() {
    local running=true

    while $running; do
        clear
        tui_banner "Services"
        echo -e "${TUI_COLOR_WHITE}Gestion des services du homelab${TUI_COLOR_NC}"

        # Afficher un resume rapide
        list_services

        # Selection action
        local options=(
            "1. 📋 Lister les services"
            "2. ✅ Activer un service"
            "3. ❌ Desactiver un service"
            "4. ▶️  Demarrer un service"
            "5. ⏹️  Arreter un service"
            "6. 🔄 Redemarrer un service"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Que voulez-vous faire ?" "${options[@]}")

        case "$choice" in
            "1."*|*"Lister"*)
                list_services
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "2."*|*"Activer"*)
                local service
                service=$(select_service)
                if [[ -n "$service" ]]; then
                    enable_service "$service"
                    echo ""
                    tui_log_info "Appuyez sur Entree pour continuer..."
                    read -r
                fi
                ;;
            "3."*|*"Desactiver"*)
                local service
                service=$(select_service)
                if [[ -n "$service" ]]; then
                    disable_service "$service"
                    echo ""
                    tui_log_info "Appuyez sur Entree pour continuer..."
                    read -r
                fi
                ;;
            "4."*|*"Demarrer"*)
                local service
                service=$(select_service)
                if [[ -n "$service" ]]; then
                    start_service "$service"
                    echo ""
                    tui_log_info "Appuyez sur Entree pour continuer..."
                    read -r
                fi
                ;;
            "5."*|*"Arreter"*)
                local service
                service=$(select_service)
                if [[ -n "$service" ]]; then
                    stop_service "$service"
                    echo ""
                    tui_log_info "Appuyez sur Entree pour continuer..."
                    read -r
                fi
                ;;
            "6."*|*"Redemarrer"*)
                local service
                service=$(select_service)
                if [[ -n "$service" ]]; then
                    restart_service "$service"
                    echo ""
                    tui_log_info "Appuyez sur Entree pour continuer..."
                    read -r
                fi
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

export -f menu_services
export -f get_available_services get_service_status get_service_enabled get_service_running check_service_running
export -f format_service_status get_service_status_icon list_services
export -f toggle_service enable_service disable_service update_tfvars_enabled modify_tfvars toggle_service_dry_run
export -f propose_terraform_apply suggest_apply run_terraform_apply_for_service apply_service_changes
export -f start_service stop_service restart_service get_service_command execute_service_command run_service_command
export -f show_service_status display_service_status refresh_service_status update_service_display
export -f handle_service_error check_services_prerequisites
export -f get_services_actions select_service menu_service_action select_service_action
