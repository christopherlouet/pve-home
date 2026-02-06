#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Menu Maintenance (T036-T039 - US5)
# =============================================================================
# Usage: source scripts/menus/maintenance.sh && menu_maintenance
#
# Menu de maintenance : drift detection, verifications infrastructure.
# =============================================================================

# Note: pas de set -euo pipefail ici, ce fichier est source par d'autres scripts

# =============================================================================
# Variables
# =============================================================================

MAINTENANCE_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAINTENANCE_TUI_DIR="$(cd "${MAINTENANCE_MENU_DIR}/.." && pwd)"

# Charger les libs TUI si pas deja fait
if [[ -z "${TUI_COLOR_NC:-}" ]]; then
    source "${MAINTENANCE_TUI_DIR}/lib/colors.sh"
fi
if [[ -z "${TUI_PROJECT_ROOT:-}" ]]; then
    source "${MAINTENANCE_TUI_DIR}/lib/config.sh"
fi
if ! declare -f tui_menu &>/dev/null; then
    source "${MAINTENANCE_TUI_DIR}/lib/common.sh"
fi

# Chemin du script check-drift.sh
DRIFT_SCRIPT="${TUI_PROJECT_ROOT}/scripts/drift/check-drift.sh"

# Environnements valides
readonly DRIFT_VALID_ENVS=("prod" "lab" "monitoring")

# Chemin des logs de drift (si accessible)
DRIFT_LOG_DIR="/var/log/pve-drift"

# Chemin des metriques Prometheus (si accessible)
DRIFT_METRICS_FILE="/var/lib/prometheus/node-exporter/pve_drift.prom"

# =============================================================================
# Fonctions utilitaires
# =============================================================================

# Retourne le chemin du script check-drift.sh
get_drift_script_path() {
    echo "${DRIFT_SCRIPT}"
}

# Liste les environnements disponibles pour le drift check
get_drift_environments() {
    echo "1. 🌐 Tous les environnements"
    for env in "${DRIFT_VALID_ENVS[@]}"; do
        local status_icon
        status_icon=$(get_env_drift_status "$env")
        echo "2. ${status_icon} ${env}"
    done
}

# Retourne le statut du dernier drift check pour un environnement
get_env_drift_status() {
    local env="$1"

    # Essayer de lire depuis les metriques Prometheus
    if [[ -f "$DRIFT_METRICS_FILE" ]]; then
        local status
        status=$(grep "pve_drift_status{env=\"${env}\"}" "$DRIFT_METRICS_FILE" 2>/dev/null | awk '{print $2}' || echo "")

        case "$status" in
            "0") echo "✓" ;;
            "1") echo "!" ;;
            "2") echo "✗" ;;
            *)   echo "?" ;;
        esac
    else
        echo "?"
    fi
}

# Retourne le dernier check de drift
get_last_drift_check() {
    local env="${1:-}"

    if [[ -d "$DRIFT_LOG_DIR" ]]; then
        if [[ -n "$env" ]]; then
            ls -t "${DRIFT_LOG_DIR}/drift-"*"-${env}.log" 2>/dev/null | head -1
        else
            ls -t "${DRIFT_LOG_DIR}/drift-"*.log 2>/dev/null | head -1
        fi
    fi
}

# Retourne l'historique des checks de drift
get_drift_history() {
    local env="${1:-}"
    local limit="${2:-5}"

    if [[ -d "$DRIFT_LOG_DIR" ]]; then
        if [[ -n "$env" ]]; then
            ls -t "${DRIFT_LOG_DIR}/drift-"*"-${env}.log" 2>/dev/null | head -"$limit"
        else
            ls -t "${DRIFT_LOG_DIR}/drift-"*.log 2>/dev/null | head -"$limit"
        fi
    fi
}

# =============================================================================
# Fonctions de parsing (T039)
# =============================================================================

# Extrait le statut du drift depuis la sortie
parse_drift_status() {
    local output="$1"

    if [[ "$output" == *"Conforme"* ]] || [[ "$output" == *"aucun drift"* ]]; then
        echo "Conforme"
    elif [[ "$output" == *"DRIFT"* ]] || [[ "$output" == *"drift detecte"* ]]; then
        echo "DRIFT"
    elif [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"Erreur"* ]] || [[ "$output" == *"Echec"* ]]; then
        echo "ERROR"
    else
        echo "UNKNOWN"
    fi
}

# Extrait le nombre de ressources en drift
parse_drift_count() {
    local output="$1"

    # Chercher le pattern "X ressource(s)"
    local count
    count=$(echo "$output" | grep -oP '\d+(?=\s*ressource)' | head -1 || echo "")

    if [[ -n "$count" ]]; then
        echo "$count"
    else
        echo "0"
    fi
}

# Extrait les details des ressources en drift
parse_drift_details() {
    local output="$1"

    # Extraire les lignes avec les modifications
    echo "$output" | grep -E '^\s*(~|\+|-|<=)|proxmox_|cpu|memory|cores|disk' | head -20
}

# Retourne l'icone de statut
get_drift_status_icon() {
    local status="$1"

    case "$status" in
        "ok"|"conforme"|"Conforme"|"0")
            echo -e "${TUI_COLOR_SUCCESS}[OK]${TUI_COLOR_NC}"
            ;;
        "drift"|"DRIFT"|"1")
            echo -e "${TUI_COLOR_WARNING}[DRIFT]${TUI_COLOR_NC}"
            ;;
        "error"|"ERROR"|"erreur"|"2")
            echo -e "${TUI_COLOR_ERROR}[ERROR]${TUI_COLOR_NC}"
            ;;
        *)
            echo -e "${TUI_COLOR_MUTED}[--]${TUI_COLOR_NC}"
            ;;
    esac
}

# Formate un statut de drift
format_drift_status() {
    local status="$1"
    local env="$2"
    local details="${3:-}"

    local icon
    icon=$(get_drift_status_icon "$status")

    if [[ -n "$details" ]]; then
        echo -e "${icon} ${env}: ${details}"
    else
        echo -e "${icon} ${env}"
    fi
}

# =============================================================================
# Fonctions de verification drift (T038)
# =============================================================================

# Verifie les prerequis
check_drift_prerequisites() {
    local missing=()

    if ! command -v terraform &>/dev/null; then
        missing+=("terraform")
    fi

    if [[ ! -f "$DRIFT_SCRIPT" ]]; then
        tui_log_error "Script check-drift.sh introuvable: ${DRIFT_SCRIPT}"
        return 1
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        tui_log_error "Commandes manquantes: ${missing[*]}"
        return 1
    fi

    return 0
}

# Execute le drift check pour un environnement
run_drift_check() {
    local env="${1:-}"
    local dry_run="${2:-false}"

    if ! check_drift_prerequisites; then
        return 1
    fi

    local args=()
    if [[ -n "$env" ]] && [[ "$env" != "all" ]] && [[ "$env" != "tous" ]]; then
        args+=("--env" "$env")
    else
        args+=("--all")
    fi

    if [[ "$dry_run" == "true" ]]; then
        args+=("--dry-run")
    fi

    # Executer le script
    local output
    local exit_code=0

    echo ""
    echo -e "${TUI_COLOR_WARNING}>>> Verification du drift en cours (30-60s)...${TUI_COLOR_NC}"
    echo ""

    output=$("$DRIFT_SCRIPT" "${args[@]}" 2>&1) || exit_code=$?

    # Afficher le rapport
    show_drift_report "$output" "$exit_code"

    return $exit_code
}

# Execute le drift check pour tous les environnements
run_drift_check_all() {
    run_drift_check "all" "false"
}

# Execute le drift check en mode dry-run
run_drift_dry_run() {
    local env="${1:-all}"
    run_drift_check "$env" "true"
}

# =============================================================================
# Fonctions d'affichage (T039)
# =============================================================================

# Affiche le rapport de drift
show_drift_report() {
    local output="$1"
    local exit_code="${2:-0}"

    echo ""
    tui_banner "Rapport de Drift"

    # Afficher la sortie formatee
    while IFS= read -r line; do
        # Colorer selon le contenu
        if [[ "$line" == *"Conforme"* ]] || [[ "$line" == *"aucun drift"* ]]; then
            echo -e "${TUI_COLOR_SUCCESS}${line}${TUI_COLOR_NC}"
        elif [[ "$line" == *"DRIFT"* ]] || [[ "$line" == *"change"* ]]; then
            echo -e "${TUI_COLOR_WARNING}${line}${TUI_COLOR_NC}"
        elif [[ "$line" == *"ERROR"* ]] || [[ "$line" == *"Erreur"* ]] || [[ "$line" == *"Echec"* ]]; then
            echo -e "${TUI_COLOR_ERROR}${line}${TUI_COLOR_NC}"
        elif [[ "$line" == *"==="* ]] || [[ "$line" == *"---"* ]]; then
            echo -e "${TUI_COLOR_MUTED}${line}${TUI_COLOR_NC}"
        else
            echo "$line"
        fi
    done <<< "$output"

    echo ""

    # Resume final
    case "$exit_code" in
        0)
            tui_log_success "Tous les environnements sont conformes"
            ;;
        1)
            tui_log_warn "Drift detecte - des ressources ont change"
            ;;
        2)
            tui_log_error "Erreur lors de la verification"
            ;;
    esac
}

# Affiche le resume du drift
show_drift_summary() {
    tui_banner "Resume Drift"

    echo -e "${TUI_COLOR_INFO}Statut par environnement :${TUI_COLOR_NC}"
    echo ""

    for env in "${DRIFT_VALID_ENVS[@]}"; do
        local status_icon
        status_icon=$(get_env_drift_status "$env")

        local last_check
        last_check=$(get_last_drift_check "$env")

        if [[ -n "$last_check" ]]; then
            local check_date
            check_date=$(stat -c %y "$last_check" 2>/dev/null | cut -d'.' -f1 || echo "inconnu")
            echo -e "  ${status_icon} ${env} - Dernier check: ${check_date}"
        else
            echo -e "  ${status_icon} ${env} - Aucun check recent"
        fi
    done
}

# Affiche les resultats du drift
display_drift_results() {
    local output="$1"
    show_drift_report "$output" "0"
}

# Gere les erreurs de drift
handle_drift_error() {
    local error_output="$1"

    echo ""
    tui_log_error "Erreur lors de la verification du drift"
    echo ""

    # Analyser l'erreur
    if [[ "$error_output" == *"Terraform n'est pas installe"* ]]; then
        tui_log_error "Terraform n'est pas installe"
        tui_log_info "Installez Terraform: https://www.terraform.io/downloads"
    elif [[ "$error_output" == *"init"* ]] || [[ "$error_output" == *"Init"* ]]; then
        tui_log_error "Echec de l'initialisation Terraform"
        tui_log_info "Verifiez la configuration backend et les providers"
    elif [[ "$error_output" == *"versions.tf"* ]]; then
        tui_log_error "Fichier versions.tf introuvable"
        tui_log_info "Verifiez que l'environnement est correctement configure"
    else
        tui_log_error "Erreur inconnue"
        echo ""
        echo "Details :"
        echo "$error_output"
    fi
}

# =============================================================================
# Actions du menu (T037)
# =============================================================================

# Retourne les actions disponibles
get_maintenance_actions() {
    echo "1. 🔍 Verifier drift (tous les environnements)"
    echo "2. 🎯 Verifier drift (un environnement)"
    echo "3. 🧪 Simulation (dry-run)"
    echo "4. 📊 Resume du statut"
    echo "5. ↩️  Retour - Revenir au menu principal"
}

# Selection d'environnement pour le drift
select_drift_environment() {
    local options=()

    for env in "${DRIFT_VALID_ENVS[@]}"; do
        local status_icon
        status_icon=$(get_env_drift_status "$env")
        options+=("${status_icon} ${env}")
    done
    options+=("$(tui_back_option)")

    local choice
    choice=$(tui_menu "Selectionner l'environnement" "${options[@]}")

    # Extraire le nom de l'environnement
    for env in "${DRIFT_VALID_ENVS[@]}"; do
        if [[ "$choice" == *"$env"* ]]; then
            echo "$env"
            return 0
        fi
    done

    return 1
}

# Selection d'action drift
select_drift_action() {
    local options=(
        "1. 🔍 Verifier drift (tous)"
        "2. 🎯 Verifier drift (un env)"
        "3. 🧪 Simulation (dry-run)"
        "4. 📊 Resume du statut"
        "$(tui_back_option)"
    )

    tui_menu "Action:" "${options[@]}"
}

# Menu drift
menu_drift() {
    local choice="$1"

    case "$choice" in
        "1."*|*"tous"*|*"Tous"*)
            run_drift_check_all
            ;;
        "2."*|*"un environnement"*)
            local env
            env=$(select_drift_environment)
            if [[ -n "$env" ]]; then
                run_drift_check "$env"
            fi
            ;;
        "3."*|*"dry-run"*|*"Simulation"*)
            run_drift_dry_run "all"
            ;;
        "4."*|*"Resume"*|*"statut"*)
            show_drift_summary
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
# Menu principal maintenance
# =============================================================================

menu_maintenance() {
    local running=true

    while $running; do
        clear
        tui_banner "Maintenance"

        # Afficher le resume rapide
        echo -e "${TUI_COLOR_WHITE}Verification de l'infrastructure Proxmox${TUI_COLOR_NC}"

        # Statut rapide si disponible
        if [[ -f "$DRIFT_METRICS_FILE" ]]; then
            echo -e "${TUI_COLOR_WHITE}Dernier statut connu :${TUI_COLOR_NC}"
            for env in "${DRIFT_VALID_ENVS[@]}"; do
                local status_icon
                status_icon=$(get_env_drift_status "$env")
                echo -e "  ${status_icon} ${env}"
            done
        fi

        # Selection action
        local choice
        choice=$(select_drift_action)

        case "$choice" in
            "1."*|*"tous"*|*"Tous"*)
                run_drift_check_all
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "2."*|*"un environnement"*)
                local env
                env=$(select_drift_environment)
                if [[ -n "$env" ]]; then
                    run_drift_check "$env"
                    echo ""
                    tui_log_info "Appuyez sur Entree pour continuer..."
                    read -r
                fi
                ;;
            "3."*|*"dry-run"*|*"Simulation"*)
                run_drift_dry_run "all"
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "4."*|*"Resume"*|*"statut"*)
                show_drift_summary
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

export -f menu_maintenance
export -f get_drift_script_path get_drift_environments
export -f get_env_drift_status get_last_drift_check get_drift_history
export -f parse_drift_status parse_drift_count parse_drift_details
export -f get_drift_status_icon format_drift_status
export -f check_drift_prerequisites run_drift_check run_drift_check_all run_drift_dry_run
export -f show_drift_report show_drift_summary display_drift_results handle_drift_error
export -f get_maintenance_actions select_drift_environment select_drift_action menu_drift
