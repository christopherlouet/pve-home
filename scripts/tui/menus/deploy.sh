#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Menu Deploiement (T031-T034 - US4)
# =============================================================================
# Usage: source scripts/tui/menus/deploy.sh && menu_deploy
#
# Menu de deploiement des scripts et timers sur la VM monitoring.
# =============================================================================

# =============================================================================
# Variables
# =============================================================================

DEPLOY_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_TUI_DIR="$(cd "${DEPLOY_MENU_DIR}/.." && pwd)"

# Charger les libs TUI si pas deja fait
if [[ -z "${TUI_COLOR_NC:-}" ]]; then
    source "${DEPLOY_TUI_DIR}/lib/tui-colors.sh"
fi
if [[ -z "${TUI_PROJECT_ROOT:-}" ]]; then
    source "${DEPLOY_TUI_DIR}/lib/tui-config.sh"
fi
if ! declare -f tui_menu &>/dev/null; then
    source "${DEPLOY_TUI_DIR}/lib/tui-common.sh"
fi

# Chemin du script deploy.sh
DEPLOY_SCRIPT="${TUI_PROJECT_ROOT}/scripts/deploy.sh"

# Chemin du tfvars monitoring (peut etre override pour les tests)
MONITORING_TFVARS="${MONITORING_TFVARS:-${TUI_PROJECT_ROOT}/infrastructure/proxmox/environments/monitoring/terraform.tfvars}"

# Dossiers de scripts a deployer
readonly DEPLOY_SCRIPT_DIRS=("lib" "drift" "health" "lifecycle" "restore")

# Environnements tfvars a deployer
readonly DEPLOY_ENVS=("prod" "lab" "monitoring")

# Timers systemd a deployer
readonly DEPLOY_TIMERS=(
    "pve-health-check"
    "pve-drift-check"
    "pve-cleanup-snapshots"
    "pve-expire-lab"
)

# =============================================================================
# Fonctions utilitaires
# =============================================================================

# Retourne le chemin du script deploy.sh
get_deploy_script_path() {
    echo "${DEPLOY_SCRIPT}"
}

# Extrait l'IP de la VM monitoring depuis terraform.tfvars
get_monitoring_ip() {
    if [[ ! -f "$MONITORING_TFVARS" ]]; then
        return 1
    fi

    local ip
    ip=$(awk '/^monitoring\s*=\s*\{/,/^\}/' "$MONITORING_TFVARS" \
        | grep -oP 'ip\s*=\s*"\K\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' \
        | head -1 || echo "")

    if [[ -z "$ip" ]]; then
        return 1
    fi

    echo "$ip"
}

# Verifie si la VM monitoring est joignable
check_monitoring_reachable() {
    local ip="${1:-}"

    if [[ -z "$ip" ]]; then
        ip=$(get_monitoring_ip) || return 1
    fi

    # Test ping rapide
    ping -c 1 -W 2 "$ip" &>/dev/null
}

# Verifie la connectivite SSH
check_ssh_connectivity() {
    local ip="${1:-}"
    local user="${2:-ubuntu}"

    if [[ -z "$ip" ]]; then
        ip=$(get_monitoring_ip) || return 1
    fi

    ssh -o ConnectTimeout=5 -o BatchMode=yes "${user}@${ip}" "exit" &>/dev/null
}

# =============================================================================
# Fonctions de resume (T032)
# =============================================================================

# Liste les scripts a deployer
get_scripts_to_deploy() {
    local scripts_dir="${TUI_PROJECT_ROOT}/scripts"

    for dir in "${DEPLOY_SCRIPT_DIRS[@]}"; do
        if [[ -d "${scripts_dir}/${dir}" ]]; then
            echo "scripts/${dir}/"
        fi
    done
}

# Liste les tfvars a deployer
get_tfvars_to_deploy() {
    local envs_dir="${TUI_PROJECT_ROOT}/infrastructure/proxmox/environments"

    for env in "${DEPLOY_ENVS[@]}"; do
        if [[ -f "${envs_dir}/${env}/terraform.tfvars" ]]; then
            echo "${env}/terraform.tfvars"
        fi
    done
}

# Liste les timers systemd a deployer
get_timers_to_deploy() {
    for timer in "${DEPLOY_TIMERS[@]}"; do
        echo "${timer}.timer"
    done
}

# Liste tous les elements a deployer
get_deploy_items() {
    echo "=== Scripts ==="
    get_scripts_to_deploy
    echo ""
    echo "=== Terraform tfvars ==="
    get_tfvars_to_deploy
    echo ""
    echo "=== Timers systemd ==="
    get_timers_to_deploy
}

# Resume du deploiement
get_deploy_summary() {
    local scripts_count=0
    local tfvars_count=0
    local timers_count=${#DEPLOY_TIMERS[@]}

    # Compter les scripts
    local scripts_dir="${TUI_PROJECT_ROOT}/scripts"
    for dir in "${DEPLOY_SCRIPT_DIRS[@]}"; do
        if [[ -d "${scripts_dir}/${dir}" ]]; then
            ((scripts_count++))
        fi
    done

    # Compter les tfvars
    local envs_dir="${TUI_PROJECT_ROOT}/infrastructure/proxmox/environments"
    for env in "${DEPLOY_ENVS[@]}"; do
        if [[ -f "${envs_dir}/${env}/terraform.tfvars" ]]; then
            ((tfvars_count++))
        fi
    done

    echo "Resume du deploiement :"
    echo "  - ${scripts_count} dossiers de scripts"
    echo "  - ${tfvars_count} fichiers terraform.tfvars"
    echo "  - ${timers_count} timers systemd"
}

# Affiche l'apercu du deploiement
show_deploy_preview() {
    tui_banner "Apercu du deploiement"

    local monitoring_ip
    monitoring_ip=$(get_monitoring_ip 2>/dev/null) || monitoring_ip="non detectee"

    echo -e "${TUI_COLOR_MUTED}VM monitoring: ${monitoring_ip}${TUI_COLOR_NC}"
    echo ""

    get_deploy_summary
    echo ""

    echo -e "${TUI_COLOR_INFO}Elements a deployer :${TUI_COLOR_NC}"
    echo ""

    echo -e "${TUI_COLOR_PRIMARY}Scripts :${TUI_COLOR_NC}"
    get_scripts_to_deploy | while read -r item; do
        echo "  - ${item}"
    done
    echo ""

    echo -e "${TUI_COLOR_PRIMARY}Terraform tfvars :${TUI_COLOR_NC}"
    get_tfvars_to_deploy | while read -r item; do
        echo "  - ${item}"
    done
    echo ""

    echo -e "${TUI_COLOR_PRIMARY}Timers systemd :${TUI_COLOR_NC}"
    get_timers_to_deploy | while read -r item; do
        echo "  - ${item}"
    done
}

# =============================================================================
# Fonctions de deploiement (T033)
# =============================================================================

# Verifie les prerequis
check_deploy_prerequisites() {
    local missing=()

    for cmd in rsync ssh; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        tui_log_error "Commandes manquantes: ${missing[*]}"
        return 1
    fi

    if [[ ! -f "$DEPLOY_SCRIPT" ]]; then
        tui_log_error "Script deploy.sh introuvable: ${DEPLOY_SCRIPT}"
        return 1
    fi

    return 0
}

# Parse une ligne de sortie du deploiement
parse_deploy_step() {
    local line="$1"

    # Detecter les differentes etapes
    case "$line" in
        *"Deploiement des scripts"*)
            echo "scripts"
            ;;
        *"Deploiement des terraform.tfvars"*)
            echo "tfvars"
            ;;
        *"Deploiement des fichiers systemd"*)
            echo "systemd"
            ;;
        *"Activation des timers"*)
            echo "timers"
            ;;
        *"Verification du deploiement"*)
            echo "verify"
            ;;
        *"deploye"*|*"active"*)
            echo "success"
            ;;
        *"[ERROR]"*|*"Erreur"*|*"error"*)
            echo "error"
            ;;
        *)
            echo "info"
            ;;
    esac
}

# Formate la sortie du deploiement
format_deploy_output() {
    local line="$1"
    local step
    step=$(parse_deploy_step "$line")

    case "$step" in
        "success")
            echo -e "${TUI_COLOR_SUCCESS}${line}${TUI_COLOR_NC}"
            ;;
        "error")
            echo -e "${TUI_COLOR_ERROR}${line}${TUI_COLOR_NC}"
            ;;
        "scripts"|"tfvars"|"systemd"|"timers"|"verify")
            echo -e "${TUI_COLOR_PRIMARY}${line}${TUI_COLOR_NC}"
            ;;
        *)
            echo "$line"
            ;;
    esac
}

# Execute le deploiement en mode dry-run
run_deploy_dry_run() {
    tui_banner "Deploiement (simulation)"

    if ! check_deploy_prerequisites; then
        return 1
    fi

    tui_log_info "Execution en mode dry-run..."
    echo ""

    # Executer avec --dry-run
    local output
    output=$("$DEPLOY_SCRIPT" --dry-run 2>&1) || {
        tui_log_error "Echec de la simulation"
        echo "$output"
        return 1
    }

    # Afficher la sortie formatee
    while IFS= read -r line; do
        format_deploy_output "$line"
    done <<< "$output"

    echo ""
    tui_log_success "Simulation terminee (aucune modification)"

    return 0
}

# Execute le deploiement reel
run_deploy() {
    tui_banner "Deploiement"

    if ! check_deploy_prerequisites; then
        return 1
    fi

    # Afficher l'apercu
    show_deploy_preview
    echo ""

    # Demander confirmation
    if ! tui_confirm "Confirmer le deploiement sur la VM monitoring ?"; then
        tui_log_warn "Deploiement annule"
        return 1
    fi

    tui_log_info "Deploiement en cours..."
    echo ""

    # Executer le deploiement avec spinner
    local output
    local exit_code=0

    output=$(tui_spin "Deploiement des scripts et timers..." "$DEPLOY_SCRIPT" 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        handle_deploy_error "$output"
        return 1
    fi

    # Afficher les resultats
    show_deploy_results "$output"

    return 0
}

# =============================================================================
# Fonctions de resultats (T034)
# =============================================================================

# Retourne l'icone de statut
get_deploy_status_icon() {
    local status="$1"

    case "$status" in
        "success"|"ok"|"deployed")
            echo -e "${TUI_COLOR_SUCCESS}[OK]${TUI_COLOR_NC}"
            ;;
        "error"|"fail"|"failed")
            echo -e "${TUI_COLOR_ERROR}[FAIL]${TUI_COLOR_NC}"
            ;;
        "warning"|"warn"|"skip")
            echo -e "${TUI_COLOR_WARNING}[WARN]${TUI_COLOR_NC}"
            ;;
        *)
            echo -e "${TUI_COLOR_MUTED}[--]${TUI_COLOR_NC}"
            ;;
    esac
}

# Formate un statut de deploiement
format_deploy_status() {
    local status="$1"
    local message="$2"

    local icon
    icon=$(get_deploy_status_icon "$status")

    echo -e "${icon} ${message}"
}

# Affiche les resultats du deploiement
show_deploy_results() {
    local output="$1"

    echo ""
    tui_banner "Resultats du deploiement"

    # Parser la sortie pour extraire les resultats
    local scripts_ok=0
    local tfvars_ok=0
    local timers_ok=0
    local errors=0

    while IFS= read -r line; do
        case "$line" in
            *"scripts/"*"deploye"*)
                ((scripts_ok++))
                ;;
            *"terraform.tfvars deploye"*)
                ((tfvars_ok++))
                ;;
            *".timer active"*)
                ((timers_ok++))
                ;;
            *"[ERROR]"*|*"Erreur"*)
                ((errors++))
                ;;
        esac
    done <<< "$output"

    # Afficher le resume
    if [[ $errors -eq 0 ]]; then
        format_deploy_status "success" "Deploiement termine avec succes"
    else
        format_deploy_status "error" "Deploiement termine avec ${errors} erreur(s)"
    fi

    echo ""
    echo "Details :"
    format_deploy_status "success" "${scripts_ok} dossiers de scripts deployes"
    format_deploy_status "success" "${tfvars_ok} fichiers tfvars deployes"
    format_deploy_status "success" "${timers_ok} timers systemd actives"

    if [[ $errors -gt 0 ]]; then
        echo ""
        tui_log_error "Erreurs rencontrees :"
        while IFS= read -r line; do
            if [[ "$line" == *"[ERROR]"* ]] || [[ "$line" == *"Erreur"* ]]; then
                echo "  - ${line}"
            fi
        done <<< "$output"
    fi
}

# Gere les erreurs de deploiement
handle_deploy_error() {
    local error_output="$1"

    echo ""
    tui_log_error "Erreur lors du deploiement"
    echo ""

    # Analyser l'erreur
    if [[ "$error_output" == *"Connection refused"* ]] || [[ "$error_output" == *"connect to host"* ]]; then
        tui_log_error "Impossible de se connecter a la VM monitoring"
        tui_log_info "Verifiez que la VM est demarree et accessible en SSH"
    elif [[ "$error_output" == *"Permission denied"* ]]; then
        tui_log_error "Permission refusee"
        tui_log_info "Verifiez vos cles SSH et les permissions"
    elif [[ "$error_output" == *"terraform.tfvars"* ]]; then
        tui_log_error "Fichier terraform.tfvars introuvable"
        tui_log_info "Verifiez que les environnements sont configures"
    else
        tui_log_error "Erreur inconnue"
        echo ""
        echo "Sortie complete :"
        echo "$error_output"
    fi
}

# =============================================================================
# Actions du menu
# =============================================================================

# Retourne les actions disponibles
get_deploy_actions() {
    echo "1. 🚀 Deployer - Deployer sur la VM monitoring"
    echo "2. 🔍 Simuler (dry-run) - Voir ce qui serait deploye"
    echo "3. 📋 Apercu - Voir le resume des elements"
    echo "4. ↩️  Retour - Revenir au menu principal"
}

# Selection d'action
select_deploy_action() {
    local options=(
        "1. 🚀 Deployer - Deployer sur la VM monitoring"
        "2. 🔍 Simuler (dry-run) - Voir ce qui serait deploye"
        "3. 📋 Apercu - Voir le resume des elements"
        "$(tui_back_option)"
    )

    tui_menu "Que voulez-vous faire ?" "${options[@]}"
}

# Menu d'action deploiement
menu_deploy_action() {
    local choice="$1"

    case "$choice" in
        "1."*|*"Deployer"*)
            run_deploy
            ;;
        "2."*|*"Simuler"*|*"dry-run"*)
            run_deploy_dry_run
            ;;
        "3."*|*"Apercu"*)
            show_deploy_preview
            ;;
        *)
            return 1
            ;;
    esac

    echo ""
    tui_log_info "Appuyez sur Entree pour continuer..."
    read -r

    return 0
}

# =============================================================================
# Menu principal deploiement
# =============================================================================

menu_deploy() {
    local running=true

    while $running; do
        tui_banner "Deploiement"

        # Afficher l'etat de la VM monitoring
        local monitoring_ip
        monitoring_ip=$(get_monitoring_ip 2>/dev/null) || monitoring_ip=""

        if [[ -n "$monitoring_ip" ]]; then
            echo -e "${TUI_COLOR_MUTED}VM monitoring: ${monitoring_ip}${TUI_COLOR_NC}"

            if check_monitoring_reachable "$monitoring_ip" 2>/dev/null; then
                echo -e "${TUI_COLOR_SUCCESS}Etat: Accessible${TUI_COLOR_NC}"
            else
                echo -e "${TUI_COLOR_WARNING}Etat: Non joignable${TUI_COLOR_NC}"
            fi
        else
            echo -e "${TUI_COLOR_WARNING}VM monitoring: Non configuree${TUI_COLOR_NC}"
        fi
        echo ""

        # Selection action
        local choice
        choice=$(select_deploy_action)

        case "$choice" in
            "1."*|*"Deployer"*)
                run_deploy
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "2."*|*"Simuler"*|*"dry-run"*)
                run_deploy_dry_run
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "3."*|*"Apercu"*)
                show_deploy_preview
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

export -f menu_deploy
export -f get_deploy_script_path get_monitoring_ip
export -f check_monitoring_reachable check_ssh_connectivity
export -f get_scripts_to_deploy get_tfvars_to_deploy get_timers_to_deploy
export -f get_deploy_items get_deploy_summary show_deploy_preview
export -f check_deploy_prerequisites parse_deploy_step format_deploy_output
export -f run_deploy_dry_run run_deploy
export -f get_deploy_status_icon format_deploy_status
export -f show_deploy_results handle_deploy_error
export -f get_deploy_actions select_deploy_action menu_deploy_action
