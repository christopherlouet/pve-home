#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Menu Disaster Recovery (T041-T047 - US6)
# =============================================================================
# Usage: source scripts/tui/menus/disaster.sh && menu_disaster
#
# Menu de disaster recovery : restauration VMs, tfstate, verification backups.
# =============================================================================

# =============================================================================
# Variables
# =============================================================================

DISASTER_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISASTER_TUI_DIR="$(cd "${DISASTER_MENU_DIR}/.." && pwd)"

# Charger les libs TUI si pas deja fait
if [[ -z "${TUI_COLOR_NC:-}" ]]; then
    source "${DISASTER_TUI_DIR}/lib/tui-colors.sh"
fi
if [[ -z "${TUI_PROJECT_ROOT:-}" ]]; then
    source "${DISASTER_TUI_DIR}/lib/tui-config.sh"
fi
if ! declare -f tui_menu &>/dev/null; then
    source "${DISASTER_TUI_DIR}/lib/tui-common.sh"
fi

# Chemins des scripts
RESTORE_VM_SCRIPT="${TUI_PROJECT_ROOT}/scripts/restore/restore-vm.sh"
RESTORE_TFSTATE_SCRIPT="${TUI_PROJECT_ROOT}/scripts/restore/restore-tfstate.sh"
VERIFY_BACKUPS_SCRIPT="${TUI_PROJECT_ROOT}/scripts/restore/verify-backups.sh"

# Environnements valides
readonly DR_VALID_ENVS=("prod" "lab" "monitoring")

# =============================================================================
# Fonctions utilitaires
# =============================================================================

# Retourne les chemins des scripts
get_restore_vm_script_path() {
    echo "${RESTORE_VM_SCRIPT}"
}

get_restore_tfstate_script_path() {
    echo "${RESTORE_TFSTATE_SCRIPT}"
}

get_verify_script_path() {
    echo "${VERIFY_BACKUPS_SCRIPT}"
}

# Verifie les prerequis
check_disaster_prerequisites() {
    local missing=()

    for cmd in ssh jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        tui_log_error "Commandes manquantes: ${missing[*]}"
        return 1
    fi

    return 0
}

# Calcule l'age d'un backup en heures
get_backup_age() {
    local ctime="$1"
    local now_ts
    now_ts=$(date +%s)
    local age_hours=$(( (now_ts - ctime) / 3600 ))
    echo "${age_hours}h"
}

# =============================================================================
# Fonctions VM Backups (T042-T043)
# =============================================================================

# Liste les environnements tfstate
get_tfstate_environments() {
    for env in "${DR_VALID_ENVS[@]}"; do
        echo "$env"
    done
}

# Parse la liste JSON des backups
parse_backup_list() {
    local json="$1"

    echo "$json" | jq -r '.[] | "\(.vmid)|\(.volid)|\(.size)|\(.ctime)"' 2>/dev/null || echo ""
}

# Formate une entree de backup pour affichage
format_backup_entry() {
    local vmid="$1"
    local date="$2"
    local size="$3"
    local filename="$4"

    echo "VMID ${vmid} | ${date} | ${size} | ${filename}"
}

# Liste les sauvegardes VM disponibles
list_vm_backups() {
    tui_banner "Sauvegardes VM disponibles"

    if ! check_disaster_prerequisites; then
        return 1
    fi

    tui_log_info "Recuperation de la liste des sauvegardes..."

    # En mode local, on ne peut pas lister directement
    # On affiche les instructions pour utiliser le script
    if [[ "${TUI_CONTEXT}" == "local" ]]; then
        tui_log_warn "Mode local: impossible de lister les backups directement"
        echo ""
        echo "Pour lister les backups, executez sur le serveur Proxmox :"
        echo "  pvesh get /nodes/<NODE>/storage/local/content --content backup"
        echo ""
        echo "Ou utilisez le script restore-vm.sh :"
        echo "  ${RESTORE_VM_SCRIPT} <VMID> --dry-run"
        return 0
    fi

    # En mode remote, essayer de lister
    local node
    node=$(get_pve_node 2>/dev/null || echo "")

    if [[ -z "$node" ]]; then
        tui_log_error "Impossible de detecter le noeud Proxmox"
        return 1
    fi

    local backups_json
    backups_json=$(ssh "${node}" "pvesh get /nodes/${node}/storage/local/content --content backup --output-format json" 2>/dev/null || echo "[]")

    local count
    count=$(echo "$backups_json" | jq '. | length' 2>/dev/null || echo "0")

    if [[ "$count" -eq 0 ]]; then
        tui_log_warn "Aucune sauvegarde trouvee"
        return 0
    fi

    tui_log_success "${count} sauvegarde(s) trouvee(s)"
    echo ""

    # Afficher le tableau
    echo -e "${TUI_COLOR_PRIMARY}VMID\t\tDate\t\t\tTaille\t\tFichier${TUI_COLOR_NC}"
    echo "--------------------------------------------------------------------------------"

    while IFS='|' read -r vmid volid size ctime; do
        local filename
        filename=$(echo "$volid" | sed 's/.*backup\///')
        local date_str
        date_str=$(date -d "@${ctime}" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "inconnu")
        local size_mb=$((size / 1024 / 1024))
        local age
        age=$(get_backup_age "$ctime")

        echo -e "${vmid}\t\t${date_str}\t${size_mb}MB\t\t${filename} (${age})"
    done < <(parse_backup_list "$backups_json")
}

# Selection d'un backup VM a restaurer
select_vm_backup() {
    local vmid
    vmid=$(tui_input "VMID a restaurer" "ex: 100")

    if [[ -z "$vmid" ]]; then
        return 1
    fi

    echo "$vmid"
}

# Restaure une VM
restore_vm() {
    tui_banner "Restauration VM"

    if ! check_disaster_prerequisites; then
        return 1
    fi

    if [[ ! -f "$RESTORE_VM_SCRIPT" ]]; then
        tui_log_error "Script restore-vm.sh introuvable"
        show_manual_instructions "vm"
        return 1
    fi

    # Demander le VMID
    local vmid
    vmid=$(select_vm_backup)

    if [[ -z "$vmid" ]]; then
        tui_log_warn "Restauration annulee"
        return 1
    fi

    # Confirmation
    if ! tui_confirm "Restaurer la VM ${vmid} depuis le dernier backup ?"; then
        tui_log_warn "Restauration annulee"
        return 1
    fi

    tui_log_info "Lancement de la restauration..."
    echo ""

    # Executer le script
    local output
    local exit_code=0
    output=$("$RESTORE_VM_SCRIPT" "$vmid" 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        handle_restore_error "$output" "vm"
        return 1
    fi

    echo "$output"
    tui_log_success "Restauration terminee"
}

# Restauration VM en dry-run
run_restore_vm_dry_run() {
    local vmid="${1:-100}"

    tui_banner "Restauration VM (simulation)"

    if [[ ! -f "$RESTORE_VM_SCRIPT" ]]; then
        tui_log_error "Script restore-vm.sh introuvable"
        return 1
    fi

    tui_log_info "Simulation de restauration pour VMID ${vmid}..."
    echo ""

    "$RESTORE_VM_SCRIPT" "$vmid" --dry-run 2>&1

    echo ""
    tui_log_success "Simulation terminee (aucune modification)"
}

# =============================================================================
# Fonctions tfstate Backups (T044-T045)
# =============================================================================

# Parse les versions tfstate
parse_tfstate_versions() {
    local output="$1"
    echo "$output"
}

# Liste les backups tfstate
list_tfstate_backups() {
    local env="${1:-}"

    tui_banner "Versions tfstate disponibles"

    if [[ ! -f "$RESTORE_TFSTATE_SCRIPT" ]]; then
        tui_log_error "Script restore-tfstate.sh introuvable"
        return 1
    fi

    # Si pas d'env specifie, demander
    if [[ -z "$env" ]]; then
        local options=()
        for e in "${DR_VALID_ENVS[@]}"; do
            options+=("$e")
        done
        options+=("$(tui_back_option)")

        env=$(tui_menu "Selectionner l'environnement" "${options[@]}")

        if [[ -z "$env" ]] || [[ "$env" == *"Retour"* ]]; then
            return 1
        fi
    fi

    tui_log_info "Liste des versions pour l'environnement ${env}..."
    echo ""

    # Executer le script avec --list
    "$RESTORE_TFSTATE_SCRIPT" --env "$env" --list 2>&1
}

# Selection d'une version tfstate
select_tfstate_version() {
    local env="$1"

    local version
    version=$(tui_input "Version ID a restaurer" "ex: abc123")

    if [[ -z "$version" ]]; then
        return 1
    fi

    echo "$version"
}

# Restaure un tfstate
restore_tfstate() {
    tui_banner "Restauration tfstate"

    if [[ ! -f "$RESTORE_TFSTATE_SCRIPT" ]]; then
        tui_log_error "Script restore-tfstate.sh introuvable"
        show_manual_instructions "tfstate"
        return 1
    fi

    # Selection environnement
    local options=()
    for e in "${DR_VALID_ENVS[@]}"; do
        options+=("$e")
    done
    options+=("$(tui_back_option)")

    local env
    env=$(tui_menu "Selectionner l'environnement" "${options[@]}")

    if [[ -z "$env" ]] || [[ "$env" == *"Retour"* ]]; then
        return 1
    fi

    # Lister les versions disponibles
    tui_log_info "Versions disponibles pour ${env}:"
    echo ""
    "$RESTORE_TFSTATE_SCRIPT" --env "$env" --list 2>&1
    echo ""

    # Demander la version
    local version
    version=$(select_tfstate_version "$env")

    if [[ -z "$version" ]]; then
        tui_log_warn "Restauration annulee"
        return 1
    fi

    # Confirmation
    if ! tui_confirm "Restaurer la version ${version} pour l'environnement ${env} ?"; then
        tui_log_warn "Restauration annulee"
        return 1
    fi

    tui_log_info "Lancement de la restauration..."
    echo ""

    # Executer le script
    local output
    local exit_code=0
    output=$("$RESTORE_TFSTATE_SCRIPT" --env "$env" --restore "$version" --force 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        handle_restore_error "$output" "tfstate"
        return 1
    fi

    echo "$output"
    tui_log_success "Restauration tfstate terminee"
}

# =============================================================================
# Fonctions verification (T046)
# =============================================================================

# Parse le statut de verification
parse_verify_status() {
    local output="$1"

    # Extraire les compteurs avec grep
    local error_count warn_count
    error_count=$(echo "$output" | grep -oP 'Erreurs:\s*\K\d+' | head -1 || echo "")
    warn_count=$(echo "$output" | grep -oP 'Warnings:\s*\K\d+' | head -1 || echo "")

    # Si pas de compteurs trouves, chercher les mots-cles
    if [[ -z "$error_count" ]] && [[ -z "$warn_count" ]]; then
        if [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"Erreur"* ]]; then
            echo "ERROR"
        elif [[ "$output" == *"WARNING"* ]] || [[ "$output" == *"Warning"* ]]; then
            echo "WARNING"
        else
            echo "OK"
        fi
        return
    fi

    # Analyser les compteurs
    if [[ "${error_count:-0}" -gt 0 ]]; then
        echo "ERROR (${error_count})"
    elif [[ "${warn_count:-0}" -gt 0 ]]; then
        echo "WARNING (${warn_count})"
    else
        echo "OK"
    fi
}

# Affiche le rapport de verification
show_verify_report() {
    local output="$1"
    echo "$output"
}

# Verifie l'integrite des backups
verify_backups() {
    local full="${1:-false}"

    tui_banner "Verification des sauvegardes"

    if [[ ! -f "$VERIFY_BACKUPS_SCRIPT" ]]; then
        tui_log_error "Script verify-backups.sh introuvable"
        return 1
    fi

    tui_log_info "Verification en cours..."
    echo ""

    local args=()
    if [[ "$full" == "true" ]]; then
        args+=("--full")
    fi

    # Executer le script
    local output
    local exit_code=0
    output=$("$VERIFY_BACKUPS_SCRIPT" "${args[@]}" 2>&1) || exit_code=$?

    show_verify_report "$output"

    case "$exit_code" in
        0)
            tui_log_success "Toutes les sauvegardes sont OK"
            ;;
        1)
            tui_log_warn "Des avertissements ont ete detectes"
            ;;
        2)
            tui_log_error "Des erreurs critiques ont ete detectees"
            ;;
    esac

    return $exit_code
}

# Verification en dry-run
verify_backups_dry_run() {
    tui_banner "Verification des sauvegardes (simulation)"

    if [[ ! -f "$VERIFY_BACKUPS_SCRIPT" ]]; then
        tui_log_error "Script verify-backups.sh introuvable"
        return 1
    fi

    tui_log_info "Simulation de verification..."
    echo ""

    "$VERIFY_BACKUPS_SCRIPT" --dry-run 2>&1

    echo ""
    tui_log_success "Simulation terminee"
}

# =============================================================================
# Instructions manuelles (T047)
# =============================================================================

# Retourne les instructions de secours
get_fallback_instructions() {
    local type="$1"

    case "$type" in
        "vm")
            cat << 'EOF'
=== Instructions manuelles de restauration VM ===

1. Connectez-vous au serveur Proxmox via SSH

2. Listez les backups disponibles:
   pvesh get /nodes/<NODE>/storage/local/content --content backup

3. Restaurez la VM:
   - Pour une VM (qemu):
     qmrestore <backup-file> <vmid>

   - Pour un conteneur LXC:
     pct restore <ctid> <backup-file>

4. Demarrez la VM/LXC:
   qm start <vmid>   # ou pct start <ctid>

5. Verifiez l'etat:
   qm status <vmid>  # ou pct status <ctid>
EOF
            ;;
        "tfstate")
            cat << 'EOF'
=== Instructions manuelles de restauration tfstate ===

1. Listez les versions disponibles dans Minio:
   mc ls --versions homelab/tfstate-<env>/terraform.tfstate

2. Telechargez la version souhaitee:
   mc cp --version-id <version-id> homelab/tfstate-<env>/terraform.tfstate ./terraform.tfstate.restore

3. Uploadez comme version courante:
   mc cp ./terraform.tfstate.restore homelab/tfstate-<env>/terraform.tfstate

4. Reininitialisez Terraform:
   cd infrastructure/proxmox/environments/<env>
   terraform init -reconfigure

5. Verifiez avec terraform plan:
   terraform plan
EOF
            ;;
        *)
            echo "Consultez la documentation dans docs/ pour les procedures de restauration."
            ;;
    esac
}

# Affiche les instructions manuelles
show_manual_instructions() {
    local type="${1:-}"

    tui_banner "Instructions de recuperation"

    echo ""
    get_fallback_instructions "$type"
    echo ""
}

# Affiche les instructions en cas d'echec
show_recovery_instructions() {
    show_manual_instructions "$1"
}

# Gere les erreurs de restauration
handle_restore_error() {
    local error_output="$1"
    local type="${2:-unknown}"

    echo ""
    tui_log_error "Erreur lors de la restauration"
    echo ""

    # Analyser l'erreur
    if [[ "$error_output" == *"Connection refused"* ]] || [[ "$error_output" == *"connect to host"* ]]; then
        tui_log_error "Impossible de se connecter au serveur"
        tui_log_info "Verifiez la connectivite reseau et SSH"
    elif [[ "$error_output" == *"Permission denied"* ]]; then
        tui_log_error "Permission refusee"
        tui_log_info "Verifiez vos cles SSH et les permissions"
    elif [[ "$error_output" == *"not found"* ]] || [[ "$error_output" == *"introuvable"* ]]; then
        tui_log_error "Ressource introuvable"
        tui_log_info "Verifiez que le backup/version existe"
    else
        echo "Details de l'erreur:"
        echo "$error_output"
    fi

    echo ""
    tui_log_info "Instructions manuelles de secours:"
    echo ""
    get_fallback_instructions "$type"
}

# Alias pour compatibilite
handle_disaster_error() {
    handle_restore_error "$@"
}

# =============================================================================
# Actions du menu
# =============================================================================

# Retourne les actions disponibles
get_disaster_actions() {
    echo "1. 📋 Lister sauvegardes VM"
    echo "2. 🔄 Restaurer une VM"
    echo "3. 📋 Lister versions tfstate"
    echo "4. 🔄 Restaurer un tfstate"
    echo "5. ✅ Verifier integrite des backups"
    echo "6. ✅ Verification complete (--full)"
    echo "7. 📖 Instructions manuelles"
    echo "8. ↩️  Retour - Revenir au menu principal"
}

# Selection d'action
select_disaster_action() {
    local options=(
        "1. 📋 Lister sauvegardes VM"
        "2. 🔄 Restaurer une VM"
        "3. 📋 Lister versions tfstate"
        "4. 🔄 Restaurer un tfstate"
        "5. ✅ Verifier integrite des backups"
        "6. ✅ Verification complete (--full)"
        "7. 📖 Instructions manuelles"
        "$(tui_back_option)"
    )

    tui_menu "Que voulez-vous faire ?" "${options[@]}"
}

# Menu d'action disaster
menu_disaster_action() {
    local choice="$1"

    case "$choice" in
        "1."*|*"Lister sauvegardes VM"*)
            list_vm_backups
            ;;
        "2."*|*"Restaurer une VM"*)
            restore_vm
            ;;
        "3."*|*"Lister versions tfstate"*)
            list_tfstate_backups
            ;;
        "4."*|*"Restaurer un tfstate"*)
            restore_tfstate
            ;;
        "5."*|*"Verifier integrite"*)
            verify_backups "false"
            ;;
        "6."*|*"Verification complete"*)
            verify_backups "true"
            ;;
        "7."*|*"Instructions"*)
            show_manual_instructions "vm"
            echo ""
            show_manual_instructions "tfstate"
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
# Menu principal disaster recovery
# =============================================================================

menu_disaster() {
    local running=true

    while $running; do
        tui_banner "Disaster Recovery"

        echo -e "${TUI_COLOR_MUTED}Restauration de VMs et states Terraform${TUI_COLOR_NC}"
        echo ""

        # Selection action
        local choice
        choice=$(select_disaster_action)

        case "$choice" in
            "1."*|*"Lister sauvegardes VM"*)
                list_vm_backups
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "2."*|*"Restaurer une VM"*)
                restore_vm
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "3."*|*"Lister versions tfstate"*)
                list_tfstate_backups
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "4."*|*"Restaurer un tfstate"*)
                restore_tfstate
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "5."*|*"Verifier integrite"*)
                verify_backups "false"
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "6."*|*"Verification complete"*)
                verify_backups "true"
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "7."*|*"Instructions"*)
                show_manual_instructions "vm"
                echo ""
                show_manual_instructions "tfstate"
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

export -f menu_disaster
export -f get_restore_vm_script_path get_restore_tfstate_script_path get_verify_script_path
export -f check_disaster_prerequisites get_backup_age
export -f get_tfstate_environments parse_backup_list format_backup_entry
export -f list_vm_backups select_vm_backup restore_vm run_restore_vm_dry_run
export -f parse_tfstate_versions list_tfstate_backups select_tfstate_version restore_tfstate
export -f parse_verify_status show_verify_report verify_backups verify_backups_dry_run
export -f get_fallback_instructions show_manual_instructions show_recovery_instructions
export -f handle_restore_error handle_disaster_error
export -f get_disaster_actions select_disaster_action menu_disaster_action
