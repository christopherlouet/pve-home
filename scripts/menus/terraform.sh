#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Menu Terraform (T023-T029 - US3)
# =============================================================================
# Usage: source scripts/menus/terraform.sh && menu_terraform
#
# Operations Terraform par environnement :
# - Selection environnement avec etat (initialise/configure)
# - Plan avec affichage diff colore
# - Apply avec confirmation explicite
# - Output formate
# - Init si necessaire
# =============================================================================

# Charger les dependances si pas deja fait
SCRIPT_DIR_TERRAFORM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUI_LIB_DIR_TERRAFORM="$(cd "${SCRIPT_DIR_TERRAFORM}/../lib" && pwd)"

if [[ -z "${TUI_COLOR_PRIMARY:-}" ]]; then
    source "${TUI_LIB_DIR_TERRAFORM}/colors.sh"
fi
if [[ -z "${TUI_CONTEXT:-}" ]]; then
    source "${TUI_LIB_DIR_TERRAFORM}/config.sh"
fi
if ! declare -f tui_menu &>/dev/null; then
    source "${TUI_LIB_DIR_TERRAFORM}/common.sh"
fi

# =============================================================================
# Variables locales au module
# =============================================================================

# shellcheck disable=SC2034
TERRAFORM_CURRENT_ENV=""
# shellcheck disable=SC2034
TERRAFORM_CURRENT_PATH=""
# shellcheck disable=SC2034
TERRAFORM_LAST_PLAN_FILE=""

# =============================================================================
# Fonctions utilitaires (T024)
# =============================================================================

# Verifie si terraform est installe
is_terraform_installed() {
    command -v terraform &>/dev/null
}

# Retourne le chemin de base des environnements Terraform
get_terraform_base_path() {
    echo "${TUI_PROJECT_ROOT}/infrastructure/proxmox/environments"
}

# Retourne le chemin d'un environnement
get_env_path() {
    local env="$1"
    echo "$(get_terraform_base_path)/${env}"
}

# Liste les environnements disponibles
get_terraform_envs() {
    for env in "${TUI_ENVIRONMENTS[@]}"; do
        local env_path
        env_path=$(get_env_path "$env")
        if [[ -d "$env_path" ]] && [[ -f "${env_path}/main.tf" ]]; then
            echo "$env"
        fi
    done
}

# Verifie si terraform est initialise (presence du dossier .terraform)
is_terraform_initialized() {
    local env_path="$1"
    [[ -d "${env_path}/.terraform" ]]
}

# Verifie si terraform.tfvars existe
has_tfvars() {
    local env_path="$1"
    [[ -f "${env_path}/terraform.tfvars" ]]
}

# Verifie si l'init est necessaire
check_needs_init() {
    local env_path="$1"
    ! is_terraform_initialized "$env_path"
}

# Retourne l'etat d'un environnement
get_env_status() {
    local env_path="$1"

    local status_parts=()

    if is_terraform_initialized "$env_path"; then
        status_parts+=("${TUI_ICON_SUCCESS} init")
    else
        status_parts+=("${TUI_ICON_WARNING} non init")
    fi

    if has_tfvars "$env_path"; then
        status_parts+=("${TUI_ICON_SUCCESS} tfvars")
    else
        status_parts+=("${TUI_ICON_ERROR} pas de tfvars")
    fi

    echo "${status_parts[*]}"
}

# Selection d'environnement Terraform
select_terraform_env() {
    local envs
    mapfile -t envs < <(get_terraform_envs)

    if [[ ${#envs[@]} -eq 0 ]]; then
        tui_log_error "Aucun environnement Terraform trouve"
        return 1
    fi

    # Construire les options avec l'etat
    local options=()
    for env in "${envs[@]}"; do
        local env_path
        env_path=$(get_env_path "$env")
        local status
        status=$(get_env_status "$env_path")
        options+=("${env} [${status}]")
    done
    options+=("$(tui_back_option)")

    local choice
    choice=$(tui_menu "Selectionner l'environnement Terraform:" "${options[@]}")

    if [[ "$choice" == *"Retour"* ]] || [[ -z "$choice" ]]; then
        echo "back"
        return 0
    fi

    # Extraire le nom de l'environnement
    local env_name
    env_name=$(echo "$choice" | awk '{print $1}')
    echo "$env_name"
}

# =============================================================================
# Fonctions Terraform (T025-T028)
# =============================================================================

# Retourne les actions Terraform disponibles
get_terraform_actions() {
    echo "📋 Plan - Voir les changements prevus"
    echo "🚀 Apply - Appliquer les changements"
    echo "📤 Output - Voir les outputs"
    echo "🔧 Init - Initialiser Terraform"
    echo "🔄 Refresh - Rafraichir l'etat"
    echo "📊 State - Voir l'etat actuel"
}

# Execute une commande Terraform dans un environnement
run_terraform_command() {
    local env_path="$1"
    local command="$2"
    shift 2
    local args=("$@")

    if ! is_terraform_installed; then
        tui_log_error "Terraform n'est pas installe"
        return 1
    fi

    # Changer vers le repertoire de l'environnement
    pushd "$env_path" > /dev/null || return 1

    local output exit_code=0
    terraform "$command" "${args[@]}" 2>&1 || exit_code=$?

    popd > /dev/null || true

    return $exit_code
}

# T028 - Terraform Init
run_terraform_init() {
    local env_path="$1"

    tui_log_info "Initialisation de Terraform..."

    local output exit_code=0

    if tui_check_gum; then
        output=$(gum spin --spinner dot \
            --title "terraform init..." \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- bash -c "cd '$env_path' && terraform init -input=false 2>&1") || exit_code=$?
    else
        echo -e "${TUI_COLOR_INFO}${TUI_ICON_SPINNER} terraform init...${TUI_COLOR_NC}"
        pushd "$env_path" > /dev/null || return 1
        output=$(terraform init -input=false 2>&1) || exit_code=$?
        popd > /dev/null || true
    fi

    if [[ $exit_code -eq 0 ]]; then
        tui_log_success "Terraform initialise avec succes"
    else
        handle_terraform_error "$output"
    fi

    echo "$output"
    return $exit_code
}

# T025 - Terraform Plan
run_terraform_plan() {
    local env_path="$1"
    local plan_file="${env_path}/tfplan"

    # Verifier l'init
    if check_needs_init "$env_path"; then
        tui_log_warn "Terraform n'est pas initialise. Lancement de terraform init..."
        run_terraform_init "$env_path" || return 1
    fi

    # Verifier tfvars
    if ! has_tfvars "$env_path"; then
        tui_log_error "Fichier terraform.tfvars manquant dans $env_path"
        return 1
    fi

    tui_log_info "Execution de terraform plan..."

    local output exit_code=0

    if tui_check_gum; then
        output=$(gum spin --spinner dot \
            --title "terraform plan..." \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- bash -c "cd '$env_path' && terraform plan -input=false -out=tfplan 2>&1") || exit_code=$?
    else
        echo -e "${TUI_COLOR_INFO}${TUI_ICON_SPINNER} terraform plan...${TUI_COLOR_NC}"
        pushd "$env_path" > /dev/null || return 1
        output=$(terraform plan -input=false -out=tfplan 2>&1) || exit_code=$?
        popd > /dev/null || true
    fi

        # shellcheck disable=SC2034
    if [[ $exit_code -eq 0 ]]; then
        TERRAFORM_LAST_PLAN_FILE="$plan_file"
        tui_log_success "Plan genere avec succes"
        echo ""
        format_plan_output "$output"
        echo ""
        parse_plan_summary "$output"
    else
        handle_terraform_error "$output"
    fi

    return $exit_code
}

# Formate la sortie du plan avec couleurs
format_plan_output() {
    local output="$1"

    echo -e "${TUI_COLOR_TITLE}╔═══════════════════════════════════════════════════════════════╗${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}║                    Terraform Plan                             ║${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}╚═══════════════════════════════════════════════════════════════╝${TUI_COLOR_NC}"
    echo ""

    # Colorier la sortie
    echo "$output" | while IFS= read -r line; do
        if [[ "$line" == *"+ resource"* ]] || [[ "$line" == *"# "* && "$line" == *"will be created"* ]]; then
            echo -e "${TUI_COLOR_SUCCESS}${line}${TUI_COLOR_NC}"
        elif [[ "$line" == *"- resource"* ]] || [[ "$line" == *"will be destroyed"* ]]; then
            echo -e "${TUI_COLOR_ERROR}${line}${TUI_COLOR_NC}"
        elif [[ "$line" == *"~ resource"* ]] || [[ "$line" == *"will be updated"* ]]; then
            echo -e "${TUI_COLOR_WARNING}${line}${TUI_COLOR_NC}"
        elif [[ "$line" == *"Plan:"* ]]; then
            echo -e "${TUI_COLOR_PRIMARY}${line}${TUI_COLOR_NC}"
        elif [[ "$line" == *"+"* ]] && [[ "$line" != *"~"* ]]; then
            echo -e "${TUI_COLOR_SUCCESS}${line}${TUI_COLOR_NC}"
        elif [[ "$line" == *"-"* ]] && [[ "$line" != *"~"* ]] && [[ "$line" != *"--"* ]]; then
            echo -e "${TUI_COLOR_ERROR}${line}${TUI_COLOR_NC}"
        elif [[ "$line" == *"~"* ]]; then
            echo -e "${TUI_COLOR_WARNING}${line}${TUI_COLOR_NC}"
        else
            echo "$line"
        fi
    done
}

# Parse le resume du plan
parse_plan_summary() {
    local output="$1"

    local summary
    summary=$(echo "$output" | grep -E "Plan:|No changes|Your infrastructure matches")

    if [[ -z "$summary" ]]; then
        echo "Resume non disponible"
        return
    fi

    echo -e "${TUI_COLOR_TITLE}Resume:${TUI_COLOR_NC}"

    if [[ "$summary" == *"No changes"* ]] || [[ "$summary" == *"infrastructure matches"* ]]; then
        echo -e "  ${TUI_COLOR_SUCCESS}${TUI_ICON_SUCCESS} Aucun changement necessaire${TUI_COLOR_NC}"
    else
        # Extraire les nombres
        local add change destroy
        add=$(echo "$summary" | grep -oP '\d+(?= to add)' || echo "0")
        change=$(echo "$summary" | grep -oP '\d+(?= to change)' || echo "0")
        destroy=$(echo "$summary" | grep -oP '\d+(?= to destroy)' || echo "0")

        [[ -n "$add" ]] && [[ "$add" -gt 0 ]] && echo -e "  ${TUI_COLOR_SUCCESS}+ ${add} a ajouter${TUI_COLOR_NC}"
        [[ -n "$change" ]] && [[ "$change" -gt 0 ]] && echo -e "  ${TUI_COLOR_WARNING}~ ${change} a modifier${TUI_COLOR_NC}"
        [[ -n "$destroy" ]] && [[ "$destroy" -gt 0 ]] && echo -e "  ${TUI_COLOR_ERROR}- ${destroy} a supprimer${TUI_COLOR_NC}"
    fi

    return 0
}

# Affiche un apercu avant apply
show_apply_preview() {
    local env_path="$1"
    parse_plan_summary "$(cat "${env_path}/tfplan.txt" 2>/dev/null || echo "")"
}

# Alias pour compatibilite
display_plan_summary() {
    parse_plan_summary "$@"
}

# T026 - Terraform Apply
run_terraform_apply() {
    local env_path="$1"

    # Verifier l'init
    if check_needs_init "$env_path"; then
        tui_log_error "Terraform n'est pas initialise. Lancez d'abord 'Init'."
        return 1
    fi

    # Verifier si un plan existe
    local plan_file="${env_path}/tfplan"
    local use_plan=false

    if [[ -f "$plan_file" ]]; then
        tui_log_info "Un plan existant a ete trouve."
        use_plan=true
    else
        tui_log_warn "Aucun plan existant. Un nouveau plan sera genere."
    fi

    # Confirmation explicite
    echo ""
    tui_log_warn "ATTENTION: Cette operation va modifier l'infrastructure reelle!"
    tui_log_warn "Environnement: $(basename "$env_path")"
    echo ""

    if ! tui_confirm "Confirmer l'application des changements Terraform ?"; then
        tui_log_info "Apply annule"
        return 0
    fi

    tui_log_info "Execution de terraform apply..."

    local output exit_code=0
    local apply_args=("-input=false" "-auto-approve")

    if [[ "$use_plan" == true ]]; then
        apply_args+=("tfplan")
    fi

    if tui_check_gum; then
        output=$(gum spin --spinner dot \
            --title "terraform apply..." \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- bash -c "cd '$env_path' && terraform apply ${apply_args[*]} 2>&1") || exit_code=$?
    else
        echo -e "${TUI_COLOR_INFO}${TUI_ICON_SPINNER} terraform apply...${TUI_COLOR_NC}"
        pushd "$env_path" > /dev/null || return 1
        output=$(terraform apply "${apply_args[@]}" 2>&1) || exit_code=$?
        popd > /dev/null || true
    fi

    echo "$output"

    if [[ $exit_code -eq 0 ]]; then
        tui_log_success "Terraform apply termine avec succes"
        # Supprimer le plan apres apply reussi
        rm -f "$plan_file"
    else
        handle_terraform_error "$output"
    fi

    return $exit_code
}

# T027 - Terraform Output
run_terraform_output() {
    local env_path="$1"

    if check_needs_init "$env_path"; then
        tui_log_error "Terraform n'est pas initialise"
        return 1
    fi

    tui_log_info "Recuperation des outputs Terraform..."

    local output exit_code=0

    pushd "$env_path" > /dev/null || return 1
    output=$(terraform output -json 2>&1) || exit_code=$?
    popd > /dev/null || true

    if [[ $exit_code -eq 0 ]]; then
        format_terraform_output "$output"
    else
        handle_terraform_error "$output"
    fi

    return $exit_code
}

# Formate les outputs Terraform
format_terraform_output() {
    local json_or_file="$1"

    local json
    if [[ -f "$json_or_file" ]]; then
        json=$(cat "$json_or_file")
    else
        json="$json_or_file"
    fi

    echo -e "${TUI_COLOR_TITLE}╔═══════════════════════════════════════════════════════════════╗${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}║                   Terraform Outputs                           ║${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}╚═══════════════════════════════════════════════════════════════╝${TUI_COLOR_NC}"
    echo ""

    # Parser le JSON avec jq si disponible
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r 'to_entries[] | "\(.key): \(.value.value)"' 2>/dev/null | while IFS=: read -r key value; do
            echo -e "  ${TUI_COLOR_INFO}${key}:${TUI_COLOR_NC} ${value}"
        done
    else
        # Fallback sans jq
        echo "$json"
    fi
}

# Parse le JSON des outputs
parse_output_json() {
    local json="$1"

    if command -v jq &>/dev/null; then
        echo "$json" | jq -r 'to_entries[] | "\(.key)=\(.value.value)"' 2>/dev/null
    else
        echo "$json"
    fi
}

# Terraform Refresh
run_terraform_refresh() {
    local env_path="$1"

    if check_needs_init "$env_path"; then
        tui_log_error "Terraform n'est pas initialise"
        return 1
    fi

    tui_log_info "Rafraichissement de l'etat Terraform..."

    local output exit_code=0

    if tui_check_gum; then
        output=$(gum spin --spinner dot \
            --title "terraform refresh..." \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- bash -c "cd '$env_path' && terraform refresh -input=false 2>&1") || exit_code=$?
    else
        pushd "$env_path" > /dev/null || return 1
        output=$(terraform refresh -input=false 2>&1) || exit_code=$?
        popd > /dev/null || true
    fi

    if [[ $exit_code -eq 0 ]]; then
        tui_log_success "Etat rafraichi"
    else
        handle_terraform_error "$output"
    fi

    echo "$output"
    return $exit_code
}

# Terraform State List
run_terraform_state() {
    local env_path="$1"

    if check_needs_init "$env_path"; then
        tui_log_error "Terraform n'est pas initialise"
        return 1
    fi

    tui_log_info "Liste des ressources dans l'etat..."

    pushd "$env_path" > /dev/null || return 1
    terraform state list 2>&1
    local exit_code=$?
    popd > /dev/null || true

    return $exit_code
}

# T029 - Gestion des erreurs Terraform
handle_terraform_error() {
    local error_output="$1"

    echo ""
    tui_log_error "Erreur Terraform detectee"
    echo -e "${TUI_COLOR_TITLE}╔═══════════════════════════════════════════════════════════════╗${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}║                    Message d'erreur                           ║${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}╚═══════════════════════════════════════════════════════════════╝${TUI_COLOR_NC}"
    echo ""
    echo -e "${TUI_COLOR_ERROR}${error_output}${TUI_COLOR_NC}"
    echo ""

    # Suggestions basees sur l'erreur
    echo -e "${TUI_COLOR_TITLE}Suggestions:${TUI_COLOR_NC}"
    if [[ "$error_output" == *"Plugin"* ]] || [[ "$error_output" == *"provider"* ]]; then
        echo "  ${TUI_ICON_BULLET} Essayez: terraform init -upgrade"
    fi
    if [[ "$error_output" == *"state"* ]] || [[ "$error_output" == *"backend"* ]]; then
        echo "  ${TUI_ICON_BULLET} Verifiez la configuration du backend"
        echo "  ${TUI_ICON_BULLET} Verifiez l'acces au stockage d'etat"
    fi
    if [[ "$error_output" == *"401"* ]] || [[ "$error_output" == *"403"* ]] || [[ "$error_output" == *"auth"* ]]; then
        echo "  ${TUI_ICON_BULLET} Verifiez les credentials dans terraform.tfvars"
        echo "  ${TUI_ICON_BULLET} Verifiez le token API Proxmox"
    fi
    if [[ "$error_output" == *"timeout"* ]] || [[ "$error_output" == *"connection"* ]]; then
        echo "  ${TUI_ICON_BULLET} Verifiez la connectivite reseau vers Proxmox"
    fi
}

# =============================================================================
# Menus (T023)
# =============================================================================

# Menu des actions pour un environnement
menu_terraform_env() {
    local env="$1"
    local env_path
    env_path=$(get_env_path "$env")
    local running=true

    while $running; do
        tui_banner "Terraform: $env"

        # Afficher l'etat
        local status
        status=$(get_env_status "$env_path")
        echo -e "${TUI_COLOR_MUTED}Etat: ${status}${TUI_COLOR_NC}"
        echo ""

        local options=(
            "📋 Plan - Voir les changements prevus"
            "🚀 Apply - Appliquer les changements"
            "📤 Output - Voir les outputs"
            "🔧 Init - Initialiser Terraform"
            "🔄 Refresh - Rafraichir l'etat"
            "📊 State - Lister les ressources"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Action Terraform:" "${options[@]}")

        case "$choice" in
            *"Plan"*)
                run_terraform_plan "$env_path"
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Apply"*)
                run_terraform_apply "$env_path"
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Output"*)
                run_terraform_output "$env_path"
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Init"*)
                run_terraform_init "$env_path"
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Refresh"*)
                run_terraform_refresh "$env_path"
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"State"*)
                run_terraform_state "$env_path"
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Retour"*|"")
                running=false
                ;;
            *)
                tui_log_warn "Option non reconnue"
                ;;
        esac
    done
}

# Menu principal Terraform
menu_terraform() {
    local running=true

    while $running; do
        clear
        tui_banner "Terraform"

        # Verifier que terraform est installe
        if ! is_terraform_installed; then
            tui_log_error "Terraform n'est pas installe sur ce systeme"
            tui_log_info "Installez Terraform: https://www.terraform.io/downloads"
            tui_log_info "Appuyez sur Entree pour revenir..."
            read -r
            return 1
        fi

        local options=(
            "1. 📂 Selectionner un environnement"
            "2. 📋 Plan tous les environnements"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Que voulez-vous faire?" "${options[@]}")

        case "$choice" in
            "1."*|*"Selectionner"*)
                local env
                env=$(select_terraform_env)
                    # shellcheck disable=SC2034
                if [[ "$env" != "back" ]] && [[ -n "$env" ]]; then
                    # shellcheck disable=SC2034
                    TERRAFORM_CURRENT_ENV="$env"
                    TERRAFORM_CURRENT_PATH=$(get_env_path "$env")
                    menu_terraform_env "$env"
                fi
                ;;
            "2."*|*"Plan tous"*)
                tui_log_info "Plan de tous les environnements..."
                for env in $(get_terraform_envs); do
                    local env_path
                    env_path=$(get_env_path "$env")
                    echo ""
                    tui_banner "Plan: $env"
                    run_terraform_plan "$env_path" || true
                done
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Retour"*|"")
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

export -f menu_terraform menu_terraform_env
export -f is_terraform_installed get_terraform_base_path get_env_path
export -f get_terraform_envs is_terraform_initialized has_tfvars check_needs_init
export -f get_env_status select_terraform_env
export -f get_terraform_actions run_terraform_command
export -f run_terraform_init run_terraform_plan run_terraform_apply
export -f run_terraform_output run_terraform_refresh run_terraform_state
export -f format_plan_output parse_plan_summary show_apply_preview display_plan_summary
export -f format_terraform_output parse_output_json
export -f handle_terraform_error
