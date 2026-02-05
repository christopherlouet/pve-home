#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Menu Status & Health (T009-T014 - US1)
# =============================================================================
# Usage: source scripts/tui/menus/status.sh && menu_status
#
# Affiche l'etat de sante de l'infrastructure avec:
# - Selection de l'environnement (prod/lab/monitoring/tous)
# - Execution du health check avec spinner
# - Affichage des resultats en tableau colore
# - Drill-down sur les composants en erreur
# - Resume persistant "X/Y composants sains"
# =============================================================================

# Charger les dependances si pas deja fait
SCRIPT_DIR_STATUS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUI_LIB_DIR_STATUS="$(cd "${SCRIPT_DIR_STATUS}/../lib" && pwd)"

if [[ -z "${TUI_COLOR_PRIMARY:-}" ]]; then
    source "${TUI_LIB_DIR_STATUS}/tui-colors.sh"
fi
if [[ -z "${TUI_CONTEXT:-}" ]]; then
    source "${TUI_LIB_DIR_STATUS}/tui-config.sh"
fi
if ! declare -f tui_menu &>/dev/null; then
    source "${TUI_LIB_DIR_STATUS}/tui-common.sh"
fi

# =============================================================================
# Variables locales au module
# =============================================================================

# Cache des derniers resultats
STATUS_RESULTS_FILE=""
STATUS_LAST_ENV=""

# =============================================================================
# Fonctions utilitaires (T010, T012)
# =============================================================================

# Retourne le chemin du script health check
get_health_script_path() {
    echo "${TUI_SCRIPTS_DIR}/health/check-health.sh"
}

# Retourne les options d'environnement disponibles
get_env_options() {
    echo "prod"
    echo "lab"
    echo "monitoring"
    echo "Tous les environnements"
}

# Selection de l'environnement
select_environment() {
    local options
    mapfile -t options < <(get_env_options)
    options+=("$(tui_back_option)")

    local choice
    choice=$(tui_menu "Quel environnement verifier?" "${options[@]}")

    case "$choice" in
        "prod"|"lab"|"monitoring")
            echo "$choice"
            ;;
        "Tous"*|"tous"*)
            echo "all"
            ;;
        *)
            echo "back"
            ;;
    esac
}

# =============================================================================
# Fonctions de parsing des resultats (T012)
# =============================================================================

# Extrait un champ d'une ligne de resultat
# Usage: parse_result_field "line" field_number (1-based)
parse_result_field() {
    local line="$1"
    local field="$2"
    echo "$line" | cut -d'|' -f"$field"
}

# Parse tous les resultats et les stocke dans un fichier temporaire
parse_health_results() {
    local output="$1"
    local results_file="$2"

    # Le script check-health.sh produit un format tabulaire avec espaces:
    # monitoring   prometheus           monitoring   FAIL     Prometheus unreachable
    #
    # On doit:
    # 1. Supprimer les codes couleur ANSI
    # 2. Extraire les lignes de donnees (format: env  component  type  status  detail)
    # 3. Convertir en format pipe-separated

    # Supprimer les codes ANSI et extraire les lignes de resultats
    # Pattern: ligne commencant par un env suivi de colonnes avec OK/FAIL/WARN
    echo "$output" | \
        sed 's/\x1b\[[0-9;]*m//g' | \
        grep -E '^(prod|lab|monitoring) +[a-z]+ +[a-z]+ +(OK|FAIL|WARN)' | \
        while read -r line; do
            # Parser la ligne tabulaire en colonnes
            # Format: env  component  type  status  detail
            # Note: eviter 'status' car reserve en zsh
            local hc_env hc_comp hc_type hc_status hc_detail
            hc_env=$(echo "$line" | awk '{print $1}')
            hc_comp=$(echo "$line" | awk '{print $2}')
            hc_type=$(echo "$line" | awk '{print $3}')
            hc_status=$(echo "$line" | awk '{print $4}')
            # Le detail est tout ce qui reste apres le statut
            hc_detail=$(echo "$line" | awk '{$1=$2=$3=$4=""; print $0}' | sed 's/^ *//')

            # Ecrire au format pipe-separated
            echo "${hc_env}|${hc_comp}|${hc_type}|${hc_status}|${hc_detail}|"
        done > "$results_file" || true
}

# Formate le statut avec la couleur appropriee
format_status_color() {
    local status="$1"

    case "$status" in
        OK)
            echo -e "${TUI_COLOR_SUCCESS}${status}${TUI_COLOR_NC}"
            ;;
        WARN)
            echo -e "${TUI_COLOR_WARNING}${status}${TUI_COLOR_NC}"
            ;;
        FAIL)
            echo -e "${TUI_COLOR_ERROR}${status}${TUI_COLOR_NC}"
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# Affiche les resultats dans un tableau formate
display_results_table() {
    local results_file="$1"

    if [[ ! -f "$results_file" ]] || [[ ! -s "$results_file" ]]; then
        tui_log_warn "Aucun resultat a afficher"
        return 1
    fi

    echo ""
    echo -e "${TUI_COLOR_TITLE}╔═══════════════════════════════════════════════════════════════╗${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}║              Rapport de sante infrastructure                  ║${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}╠═══════════════════════════════════════════════════════════════╣${TUI_COLOR_NC}"
    printf "${TUI_COLOR_TITLE}║${TUI_COLOR_NC} %-10s %-22s %-10s %-8s %-10s ${TUI_COLOR_TITLE}║${TUI_COLOR_NC}\n" \
           "Env" "Composant" "Type" "Statut" "Duree"
    echo -e "${TUI_COLOR_TITLE}╠═══════════════════════════════════════════════════════════════╣${TUI_COLOR_NC}"

    while IFS='|' read -r env component type status detail duration; do
        local colored_status
        colored_status=$(format_status_color "$status")

        printf "${TUI_COLOR_TITLE}║${TUI_COLOR_NC} %-10s %-22s %-10s %-17s %-10s ${TUI_COLOR_TITLE}║${TUI_COLOR_NC}\n" \
               "$env" "${component:0:22}" "$type" "$colored_status" "${duration:-}"
    done < "$results_file"

    echo -e "${TUI_COLOR_TITLE}╚═══════════════════════════════════════════════════════════════╝${TUI_COLOR_NC}"
}

# =============================================================================
# Fonctions de statistiques (T014)
# =============================================================================

# Compte les resultats par statut
count_by_status() {
    local results_file="$1"
    local target_status="$2"

    if [[ ! -f "$results_file" ]]; then
        echo "0"
        return 0
    fi

    # grep -c retourne le nombre de lignes, mais exit code 1 si 0 match
    # On capture la sortie et on la renvoie, en gerant le cas 0
    local count
    count=$(grep -c "|${target_status}|" "$results_file" 2>/dev/null) || count="0"
    echo "$count"
}

# Calcule le resume de sante
# Retourne: "X/Y" (sains/total)
calculate_health_summary() {
    local results_file="$1"

    if [[ ! -f "$results_file" ]] || [[ ! -s "$results_file" ]]; then
        echo "0/0"
        return
    fi

    local total ok_count
    total=$(wc -l < "$results_file" | tr -d ' ')
    ok_count=$(count_by_status "$results_file" "OK")

    echo "${ok_count}/${total}"
}

# Verifie si tous les composants sont OK
is_health_ok() {
    local results_file="$1"

    if [[ ! -f "$results_file" ]] || [[ ! -s "$results_file" ]]; then
        return 1
    fi

    local fail_count warn_count
    fail_count=$(count_by_status "$results_file" "FAIL")

    [[ "$fail_count" -eq 0 ]]
}

# Affiche la banniere avec le resume
display_health_banner() {
    local summary="$1"
    local healthy="${summary%/*}"
    local total="${summary#*/}"

    local status_color="$TUI_COLOR_SUCCESS"
    local status_icon="$TUI_ICON_SUCCESS"

    if [[ "$healthy" != "$total" ]]; then
        status_color="$TUI_COLOR_WARNING"
        status_icon="$TUI_ICON_WARNING"
    fi

    if [[ "$healthy" -eq 0 ]] && [[ "$total" -gt 0 ]]; then
        status_color="$TUI_COLOR_ERROR"
        status_icon="$TUI_ICON_ERROR"
    fi

    echo ""
    echo -e "${status_color}${status_icon} ${summary} composants sains${TUI_COLOR_NC}"
}

# =============================================================================
# Fonctions drill-down (T013)
# =============================================================================

# Retourne les composants en erreur (WARN ou FAIL)
get_failed_components() {
    local results_file="$1"

    if [[ ! -f "$results_file" ]]; then
        return
    fi

    grep -E '\|(WARN|FAIL)\|' "$results_file" || true
}

# Affiche les details d'un composant specifique
show_component_details() {
    local component="$1"
    local results_file="$2"

    if [[ ! -f "$results_file" ]]; then
        tui_log_error "Fichier de resultats non trouve"
        return 1
    fi

    local line
    line=$(grep "|${component}|" "$results_file" | head -1)

    if [[ -z "$line" ]]; then
        tui_log_error "Composant non trouve: $component"
        return 1
    fi

    local env comp type status detail duration
    env=$(parse_result_field "$line" 1)
    comp=$(parse_result_field "$line" 2)
    type=$(parse_result_field "$line" 3)
    status=$(parse_result_field "$line" 4)
    detail=$(parse_result_field "$line" 5)
    duration=$(parse_result_field "$line" 6)

    tui_banner "Details: $comp"

    echo ""
    echo -e "${TUI_COLOR_INFO}Environnement:${TUI_COLOR_NC} $env"
    echo -e "${TUI_COLOR_INFO}Type:${TUI_COLOR_NC} $type"
    echo -e "${TUI_COLOR_INFO}Statut:${TUI_COLOR_NC} $(format_status_color "$status")"
    if [[ -n "$detail" ]]; then
        echo -e "${TUI_COLOR_INFO}Detail:${TUI_COLOR_NC} $detail"
    fi
    if [[ -n "$duration" ]]; then
        echo -e "${TUI_COLOR_INFO}Duree:${TUI_COLOR_NC} $duration"
    fi

    # Suggestions de diagnostic
    echo ""
    echo -e "${TUI_COLOR_TITLE}Suggestions de diagnostic:${TUI_COLOR_NC}"
    case "$type" in
        vm)
            echo "  ${TUI_ICON_BULLET} Verifier que la VM est demarree dans Proxmox"
            echo "  ${TUI_ICON_BULLET} Tester le ping: ping <ip>"
            echo "  ${TUI_ICON_BULLET} Verifier l'acces SSH: ssh ubuntu@<ip>"
            ;;
        monitoring)
            echo "  ${TUI_ICON_BULLET} Verifier les conteneurs Docker: docker ps"
            echo "  ${TUI_ICON_BULLET} Verifier les logs: docker logs <container>"
            echo "  ${TUI_ICON_BULLET} Redemarrer le service: docker compose restart"
            ;;
        minio)
            echo "  ${TUI_ICON_BULLET} Verifier que le conteneur LXC est demarre"
            echo "  ${TUI_ICON_BULLET} Tester l'endpoint: curl http://<ip>:9000/minio/health/live"
            echo "  ${TUI_ICON_BULLET} Verifier les logs Minio"
            ;;
    esac
    echo ""
}

# Menu drill-down pour les erreurs
show_error_details() {
    local results_file="$1"

    local failed
    failed=$(get_failed_components "$results_file")

    if [[ -z "$failed" ]]; then
        tui_log_success "Aucun composant en erreur!"
        return 0
    fi

    # Construire la liste des composants en erreur
    local options=()
    while IFS='|' read -r env component type status detail duration; do
        local status_icon
        case "$status" in
            WARN) status_icon="${TUI_ICON_WARNING}" ;;
            FAIL) status_icon="${TUI_ICON_ERROR}" ;;
            *) status_icon="" ;;
        esac
        options+=("${status_icon} ${component} (${env}) - ${status}")
    done <<< "$failed"

    options+=("$(tui_back_option)")

    while true; do
        local choice
        choice=$(tui_menu "Composants en erreur - Details:" "${options[@]}")

        if [[ "$choice" == *"Retour"* ]] || [[ -z "$choice" ]]; then
            break
        fi

        # Extraire le nom du composant du choix
        local comp_name
        comp_name=$(echo "$choice" | sed -E 's/^[^ ]+ ([^ ]+) .*/\1/')

        show_component_details "$comp_name" "$results_file"

        tui_log_info "Appuyez sur Entree pour continuer..."
        read -r
    done
}

# =============================================================================
# Execution du health check (T011)
# =============================================================================

# Execute le health check pour un environnement
run_health_check() {
    local env="$1"
    local results_file="$2"

    local health_script
    health_script=$(get_health_script_path)

    if [[ ! -f "$health_script" ]]; then
        tui_log_error "Script health check non trouve: $health_script"
        return 1
    fi

    local args=()
    if [[ "$env" == "all" ]]; then
        args+=("--all")
    else
        args+=("--env" "$env")
    fi
    args+=("--force")

    local output
    local exit_code=0

    tui_log_info "Lancement du health check..."

    if tui_check_gum; then
        output=$(gum spin --spinner dot \
            --title "Verification en cours..." \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- bash "$health_script" "${args[@]}" 2>&1) || exit_code=$?
    else
        echo -e "${TUI_COLOR_INFO}${TUI_ICON_SPINNER} Verification en cours...${TUI_COLOR_NC}"
        output=$(bash "$health_script" "${args[@]}" 2>&1) || exit_code=$?
    fi

    # Parser les resultats
    parse_health_results "$output" "$results_file"

    return $exit_code
}

# =============================================================================
# Menu principal status (T009)
# =============================================================================

menu_status() {
    local running=true

    while $running; do
        tui_banner "Status & Health"

        # Afficher le dernier resume si disponible
        if [[ -n "$STATUS_RESULTS_FILE" ]] && [[ -f "$STATUS_RESULTS_FILE" ]]; then
            local summary
            summary=$(calculate_health_summary "$STATUS_RESULTS_FILE")
            display_health_banner "$summary"
            echo -e "${TUI_COLOR_MUTED}Dernier check: ${STATUS_LAST_ENV}${TUI_COLOR_NC}"
        fi
        echo ""

        local options=(
            "1. 🔍 Verifier un environnement"
            "2. 🌐 Verifier tous les environnements"
            "3. 📋 Voir les derniers resultats"
            "4. ⚠️  Details des erreurs"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Que voulez-vous faire?" "${options[@]}")

        case "$choice" in
            "1."*|*"Verifier un env"*)
                local env
                env=$(select_environment)
                if [[ "$env" != "back" ]]; then
                    # Creer un fichier temporaire pour les resultats
                    STATUS_RESULTS_FILE=$(mktemp /tmp/tui_health_XXXXXX.txt)
                    STATUS_LAST_ENV="$env"

                    if run_health_check "$env" "$STATUS_RESULTS_FILE"; then
                        display_results_table "$STATUS_RESULTS_FILE"
                        local summary
                        summary=$(calculate_health_summary "$STATUS_RESULTS_FILE")
                        display_health_banner "$summary"
                    else
                        display_results_table "$STATUS_RESULTS_FILE"
                        tui_log_warn "Certains composants sont en erreur"
                    fi

                    tui_log_info "Appuyez sur Entree pour continuer..."
                    read -r
                fi
                ;;
            "2."*|*"tous les env"*)
                STATUS_RESULTS_FILE=$(mktemp /tmp/tui_health_XXXXXX.txt)
                STATUS_LAST_ENV="all"

                if run_health_check "all" "$STATUS_RESULTS_FILE"; then
                    display_results_table "$STATUS_RESULTS_FILE"
                    local summary
                    summary=$(calculate_health_summary "$STATUS_RESULTS_FILE")
                    display_health_banner "$summary"
                else
                    display_results_table "$STATUS_RESULTS_FILE"
                    tui_log_warn "Certains composants sont en erreur"
                fi

                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "3."*|*"derniers resultats"*)
                if [[ -n "$STATUS_RESULTS_FILE" ]] && [[ -f "$STATUS_RESULTS_FILE" ]]; then
                    display_results_table "$STATUS_RESULTS_FILE"
                    local summary
                    summary=$(calculate_health_summary "$STATUS_RESULTS_FILE")
                    display_health_banner "$summary"
                else
                    tui_log_warn "Aucun resultat disponible. Lancez d'abord une verification."
                fi
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "4."*|*"Details"*|*"erreurs"*)
                if [[ -n "$STATUS_RESULTS_FILE" ]] && [[ -f "$STATUS_RESULTS_FILE" ]]; then
                    show_error_details "$STATUS_RESULTS_FILE"
                else
                    tui_log_warn "Aucun resultat disponible. Lancez d'abord une verification."
                    tui_log_info "Appuyez sur Entree pour continuer..."
                    read -r
                fi
                ;;
            *"Retour"*|"")
                running=false
                ;;
            *)
                tui_log_warn "Option non reconnue"
                ;;
        esac
    done

    # Nettoyer le fichier temporaire
    if [[ -n "$STATUS_RESULTS_FILE" ]] && [[ -f "$STATUS_RESULTS_FILE" ]]; then
        rm -f "$STATUS_RESULTS_FILE"
    fi
}

# Fonction drill_down_menu comme alias
drill_down_menu() {
    show_error_details "$@"
}

# =============================================================================
# Export des fonctions
# =============================================================================

export -f menu_status
export -f get_health_script_path get_env_options select_environment
export -f parse_result_field parse_health_results format_status_color display_results_table
export -f count_by_status calculate_health_summary is_health_ok display_health_banner
export -f get_failed_components show_component_details show_error_details drill_down_menu
export -f run_health_check
