#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Menu Lifecycle/Snapshots (T016-T021 - US2)
# =============================================================================
# Usage: source scripts/menus/lifecycle.sh && menu_lifecycle
#
# Gestion des snapshots VM/LXC :
# - Selection de VM depuis les tfvars ou saisie manuelle du VMID
# - Creation, listing, restauration et suppression de snapshots
# - Confirmations explicites pour les operations destructives
# =============================================================================

# Charger les dependances si pas deja fait
SCRIPT_DIR_LIFECYCLE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUI_LIB_DIR_LIFECYCLE="$(cd "${SCRIPT_DIR_LIFECYCLE}/../lib" && pwd)"

if [[ -z "${TUI_COLOR_PRIMARY:-}" ]]; then
    source "${TUI_LIB_DIR_LIFECYCLE}/colors.sh"
fi
if [[ -z "${TUI_CONTEXT:-}" ]]; then
    source "${TUI_LIB_DIR_LIFECYCLE}/config.sh"
fi
if ! declare -f tui_menu &>/dev/null; then
    source "${TUI_LIB_DIR_LIFECYCLE}/common.sh"
fi

# =============================================================================
# Variables locales au module
# =============================================================================

LIFECYCLE_CURRENT_VMID=""
LIFECYCLE_CURRENT_VM_NAME=""
# shellcheck disable=SC2034
LIFECYCLE_CURRENT_ENV=""

# =============================================================================
# Fonctions utilitaires (T017)
# =============================================================================

# Retourne le chemin du script snapshot-vm.sh
get_snapshot_script_path() {
    echo "${TUI_SCRIPTS_DIR}/lifecycle/snapshot-vm.sh"
}

# Genere un nom de snapshot automatique
generate_snapshot_name() {
    echo "auto-$(date +%Y%m%d-%H%M%S)"
}

# Valide un VMID (doit etre numerique)
validate_vmid() {
    local vmid="$1"

    if [[ -z "$vmid" ]]; then
        return 1
    fi

    if [[ "$vmid" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    return 1
}

# Valide un nom de snapshot (alphanumerique, tirets, underscores)
validate_snapshot_name() {
    local name="$1"

    if [[ -z "$name" ]]; then
        return 1
    fi

    # Accepter uniquement alphanumerique, tirets et underscores
    if [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 0
    fi

    return 1
}

# Formate une option VM pour le menu
format_vm_option() {
    local name="$1"
    local ip="$2"
    echo "${name} (${ip})"
}

# =============================================================================
# Extraction des VMs depuis tfvars (T017)
# =============================================================================

# Extrait les VMs depuis un fichier tfvars
# Format de sortie: nom|ip (une ligne par VM)
get_vms_from_tfvars() {
    local tfvars="$1"

    if [[ ! -f "$tfvars" ]]; then
        return 1
    fi

    # Parser le bloc vms = { ... }
    awk '/^vms\s*=\s*\{/,/^\}/' "$tfvars" | \
        grep -E '^\s*"[^"]+"' | \
        while read -r line; do
            # Extraire le nom de la VM
            local name
            name=$(echo "$line" | grep -oP '^\s*"\K[^"]+')

            # Chercher l'IP dans les lignes suivantes (meme bloc)
            local ip
            ip=$(awk "/\"${name}\"/,/\}/" "$tfvars" | grep -oP 'ip\s*=\s*"\K[0-9.]+' | head -1)

            if [[ -n "$name" ]] && [[ -n "$ip" ]]; then
                echo "${name}|${ip}"
            fi
        done
}

# Extrait les conteneurs LXC depuis un fichier tfvars
get_containers_from_tfvars() {
    local tfvars="$1"

    if [[ ! -f "$tfvars" ]]; then
        return 1
    fi

    # Parser le bloc containers = { ... }
    awk '/^containers\s*=\s*\{/,/^\}/' "$tfvars" | \
        grep -E '^\s*"[^"]+"' | \
        while read -r line; do
            local name
            name=$(echo "$line" | grep -oP '^\s*"\K[^"]+')

            local ip
            ip=$(awk "/\"${name}\"/,/\}/" "$tfvars" | grep -oP 'ip\s*=\s*"\K[0-9.]+' | head -1)

            if [[ -n "$name" ]] && [[ -n "$ip" ]]; then
                echo "${name}|${ip}"
            fi
        done
}

# Extrait la VM monitoring depuis un fichier tfvars
# Format monitoring stack: monitoring = { vm = { ip = "..." } }
get_monitoring_vm_from_tfvars() {
    local tfvars="$1"

    if [[ ! -f "$tfvars" ]]; then
        return 1
    fi

    # Chercher le bloc monitoring = { vm = { ip = "..." } }
    local ip
    ip=$(awk '/^monitoring\s*=\s*\{/,/^\}/' "$tfvars" | \
         grep -oP 'ip\s*=\s*"\K[0-9.]+' | head -1)

    if [[ -n "$ip" ]]; then
        echo "monitoring-vm|${ip}"
    fi
}

# Retourne les environnements avec des VMs definies
get_env_with_vms() {
    local envs=()

    for env in "${TUI_ENVIRONMENTS[@]}"; do
        local tfvars
        tfvars=$(get_tfvars_path "$env")
        if [[ -f "$tfvars" ]]; then
            local vms
            vms=$(get_vms_from_tfvars "$tfvars")
            local containers
            containers=$(get_containers_from_tfvars "$tfvars")
            local monitoring_vm
            monitoring_vm=$(get_monitoring_vm_from_tfvars "$tfvars")

            if [[ -n "$vms" ]] || [[ -n "$containers" ]] || [[ -n "$monitoring_vm" ]]; then
                envs+=("$env")
            fi
        fi
    done

    printf '%s\n' "${envs[@]}"
}

# Selection d'environnement
select_environment() {
    local envs
    mapfile -t envs < <(get_env_with_vms)

    if [[ ${#envs[@]} -eq 0 ]]; then
        tui_log_warn "Aucun environnement avec VMs trouve"
        return 1
    fi

    local options=("${envs[@]}")
    options+=("$(tui_back_option)")

    local choice
    choice=$(tui_menu "Selectionner l'environnement:" "${options[@]}")

    if [[ "$choice" == *"Retour"* ]] || [[ -z "$choice" ]]; then
        echo "back"
        return 0
    fi

    echo "$choice"
}

# Selection de VM depuis un environnement
select_vm() {
    local env="$1"

    local tfvars
    tfvars=$(get_tfvars_path "$env")

    if [[ ! -f "$tfvars" ]]; then
        tui_log_error "Fichier tfvars non trouve: $tfvars"
        return 1
    fi

    # Collecter VMs et LXC
    local options=()

    while IFS='|' read -r name ip; do
        if [[ -n "$name" ]]; then
            options+=("🖥️  $(format_vm_option "$name" "$ip")")
        fi
    done < <(get_vms_from_tfvars "$tfvars")

    while IFS='|' read -r name ip; do
        if [[ -n "$name" ]]; then
            options+=("📦 $(format_vm_option "$name" "$ip") [LXC]")
        fi
    done < <(get_containers_from_tfvars "$tfvars")

    # VM Monitoring (format special monitoring stack)
    while IFS='|' read -r name ip; do
        if [[ -n "$name" ]]; then
            options+=("📊 $(format_vm_option "$name" "$ip") [Monitoring]")
        fi
    done < <(get_monitoring_vm_from_tfvars "$tfvars")

    if [[ ${#options[@]} -eq 0 ]]; then
        tui_log_warn "Aucune VM/LXC dans cet environnement"
        return 1
    fi

    options+=("✏️  Entrer un VMID manuellement")
    options+=("$(tui_back_option)")

    local choice
    choice=$(tui_menu "Selectionner la VM/LXC:" "${options[@]}")

    if [[ "$choice" == *"Retour"* ]] || [[ -z "$choice" ]]; then
        echo "back"
        return 0
    fi

    if [[ "$choice" == *"manuellement"* ]]; then
        echo "manual"
        return 0
    fi

    # Extraire le nom et l'IP du choix
    local vm_name
    vm_name=$(echo "$choice" | sed -E 's/^[^ ]+ ([^ ]+) .*/\1/')
    echo "$vm_name"
}

# Saisie manuelle du VMID
enter_vmid_manually() {
    local vmid
    vmid=$(tui_input "VMID (numero)" "" "Entrer le VMID de la VM/LXC:")

    if validate_vmid "$vmid"; then
        echo "$vmid"
        return 0
    else
        tui_log_error "VMID invalide: $vmid (doit etre numerique)"
        return 1
    fi
}

# Selection VM ou saisie manuelle
select_vm_or_enter_vmid() {
    local env="$1"

    local result
    result=$(select_vm "$env")

    if [[ "$result" == "back" ]]; then
        echo "back"
        return 0
    fi

    if [[ "$result" == "manual" ]]; then
        local vmid
        vmid=$(enter_vmid_manually) || return 1
        LIFECYCLE_CURRENT_VMID="$vmid"
        LIFECYCLE_CURRENT_VM_NAME="VM-$vmid"
        return 0
    fi

    # On a un nom de VM - demander le VMID
    LIFECYCLE_CURRENT_VM_NAME="$result"
    tui_log_info "VM selectionnee: $result"
    tui_log_info "Le VMID est necessaire pour les operations de snapshot."

    local vmid
    vmid=$(tui_input "VMID pour $result" "" "Entrer le VMID:")

    if validate_vmid "$vmid"; then
        LIFECYCLE_CURRENT_VMID="$vmid"
        return 0
    else
        tui_log_error "VMID invalide"
        return 1
    fi
}

# =============================================================================
# Operations sur les snapshots (T018-T021)
# =============================================================================

# Retourne les actions disponibles pour les snapshots
get_snapshot_actions() {
    echo "📸 Creer un snapshot"
    echo "📋 Lister les snapshots"
    echo "🔄 Restaurer un snapshot"
    echo "🗑️  Supprimer un snapshot"
}

# Parse le JSON des snapshots Proxmox
# Filtre "current" qui n'est pas un vrai snapshot
# shellcheck disable=SC2120
parse_snapshots_json() {
# shellcheck disable=SC2120
    local json_file="$1"

    if [[ ! -f "$json_file" ]]; then
        cat  # Lire depuis stdin
    else
        cat "$json_file"
    fi | jq -r '.[] | select(.name != "current") | "\(.name)|\(.description // "")|\(.snaptime // 0)"' 2>/dev/null || true
}

# Formate les snapshots en tableau
format_snapshot_table() {
    local snapshots="$1"

    echo -e "${TUI_COLOR_TITLE}╔═══════════════════════════════════════════════════════════════╗${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}║                    Snapshots disponibles                      ║${TUI_COLOR_NC}"
    echo -e "${TUI_COLOR_TITLE}╠═══════════════════════════════════════════════════════════════╣${TUI_COLOR_NC}"
    printf "${TUI_COLOR_TITLE}║${TUI_COLOR_NC} %-25s %-25s %-10s ${TUI_COLOR_TITLE}║${TUI_COLOR_NC}\n" \
           "Nom" "Description" "Date"
    echo -e "${TUI_COLOR_TITLE}╠═══════════════════════════════════════════════════════════════╣${TUI_COLOR_NC}"

    if [[ -z "$snapshots" ]]; then
        printf "${TUI_COLOR_TITLE}║${TUI_COLOR_NC} %-61s ${TUI_COLOR_TITLE}║${TUI_COLOR_NC}\n" "Aucun snapshot trouve"
    else
        while IFS='|' read -r name desc snaptime; do
            local date_str=""
            if [[ "$snaptime" -gt 0 ]]; then
                date_str=$(date -d "@$snaptime" "+%Y-%m-%d" 2>/dev/null || echo "")
            fi
            printf "${TUI_COLOR_TITLE}║${TUI_COLOR_NC} %-25s %-25s %-10s ${TUI_COLOR_TITLE}║${TUI_COLOR_NC}\n" \
                   "${name:0:25}" "${desc:0:25}" "$date_str"
        done <<< "$snapshots"
    fi

    echo -e "${TUI_COLOR_TITLE}╚═══════════════════════════════════════════════════════════════╝${TUI_COLOR_NC}"
}

# T018 - Creer un snapshot
create_snapshot() {
    local vmid="$1"
    local name="${2:-}"

    if [[ -z "$name" ]]; then
        name=$(tui_input "Nom du snapshot" "$(generate_snapshot_name)" "Nom du snapshot:")
    fi

    if ! validate_snapshot_name "$name"; then
        tui_log_error "Nom de snapshot invalide: $name"
        tui_log_info "Utilisez uniquement lettres, chiffres, tirets et underscores"
        return 1
    fi

    local script
    script=$(get_snapshot_script_path)

    if [[ ! -f "$script" ]]; then
        tui_log_error "Script snapshot-vm.sh non trouve"
        return 1
    fi

    tui_log_info "Creation du snapshot '$name' pour VMID $vmid..."

    local output exit_code=0
    if tui_check_gum; then
        output=$(gum spin --spinner dot \
            --title "Creation du snapshot..." \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- bash "$script" create "$vmid" --name "$name" --force 2>&1) || exit_code=$?
    else
        output=$(bash "$script" create "$vmid" --name "$name" --force 2>&1) || exit_code=$?
    fi

    echo "$output"

    if [[ $exit_code -eq 0 ]]; then
        tui_log_success "Snapshot '$name' cree avec succes"
    else
        tui_log_error "Echec de la creation du snapshot"
    fi

    return $exit_code
}

# T019 - Lister les snapshots
list_snapshots() {
    local vmid="$1"

    local script
    script=$(get_snapshot_script_path)

    if [[ ! -f "$script" ]]; then
        tui_log_error "Script snapshot-vm.sh non trouve"
        return 0  # Ne pas faire echouer avec set -e
    fi

    tui_log_info "Recuperation des snapshots pour VMID $vmid..."

    local output exit_code=0
    if tui_check_gum; then
        output=$(gum spin --spinner dot \
            --title "Chargement des snapshots..." \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- bash "$script" list "$vmid" --force 2>&1) || exit_code=$?
    else
        output=$(bash "$script" list "$vmid" --force 2>&1) || exit_code=$?
    fi

    if [[ $exit_code -ne 0 ]]; then
        tui_log_error "Echec de la recuperation des snapshots"
        echo "$output"
        return 0  # Ne pas faire echouer le script avec set -e
    fi

    # Parser et afficher
    local parsed
    parsed=$(echo "$output" | parse_snapshots_json)
    format_snapshot_table "$parsed"

    echo "$parsed"  # Retourner pour utilisation ulterieure
}

# Selectionner un snapshot depuis la liste
select_snapshot() {
    local vmid="$1"
    local action_label="$2"

    local script
    script=$(get_snapshot_script_path)

    # Recuperer les snapshots
    local output
    output=$(bash "$script" list "$vmid" --force 2>&1) || {
        tui_log_error "Impossible de recuperer les snapshots"
        return 1
    }

    local parsed
    parsed=$(echo "$output" | parse_snapshots_json)

    if [[ -z "$parsed" ]]; then
        tui_log_warn "Aucun snapshot disponible"
        return 1
    fi

    # Construire les options
    local options=()
    while IFS='|' read -r name desc snaptime; do
        local date_str=""
        if [[ "$snaptime" -gt 0 ]]; then
            date_str=$(date -d "@$snaptime" "+%Y-%m-%d" 2>/dev/null || echo "")
        fi
        options+=("${name} (${date_str}) - ${desc:0:30}")
    done <<< "$parsed"

    options+=("$(tui_back_option)")

    local choice
    choice=$(tui_menu "Selectionner le snapshot a ${action_label}:" "${options[@]}")

    if [[ "$choice" == *"Retour"* ]] || [[ -z "$choice" ]]; then
        echo ""
        return 1
    fi

    # Extraire le nom du snapshot
    local snap_name
    snap_name=$(echo "$choice" | awk '{print $1}')
    echo "$snap_name"
}

# T020 - Restaurer un snapshot
rollback_snapshot() {
    local vmid="$1"
    local snap_name="${2:-}"

    if [[ -z "$snap_name" ]]; then
        snap_name=$(select_snapshot "$vmid" "restaurer") || return 1
        if [[ -z "$snap_name" ]]; then
            return 1
        fi
    fi

    echo ""
    tui_log_warn "ATTENTION: Cette operation va restaurer la VM a l'etat du snapshot '$snap_name'"
    tui_log_warn "Toutes les modifications depuis ce snapshot seront PERDUES!"
    echo ""

    if ! tui_confirm "Confirmer la restauration vers '$snap_name' ?"; then
        tui_log_info "Restauration annulee"
        return 0
    fi

    local script
    script=$(get_snapshot_script_path)

    tui_log_info "Restauration vers '$snap_name'..."

    local output exit_code=0
    if tui_check_gum; then
        output=$(gum spin --spinner dot \
            --title "Restauration en cours..." \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- bash "$script" rollback "$vmid" --name "$snap_name" --force 2>&1) || exit_code=$?
    else
        output=$(bash "$script" rollback "$vmid" --name "$snap_name" --force 2>&1) || exit_code=$?
    fi

    echo "$output"

    if [[ $exit_code -eq 0 ]]; then
        tui_log_success "Restauration vers '$snap_name' effectuee"
    else
        tui_log_error "Echec de la restauration"
    fi

    return $exit_code
}

# T021 - Supprimer un snapshot
delete_snapshot() {
    local vmid="$1"
    local snap_name="${2:-}"

    if [[ -z "$snap_name" ]]; then
        snap_name=$(select_snapshot "$vmid" "supprimer") || return 1
        if [[ -z "$snap_name" ]]; then
            return 1
        fi
    fi

    echo ""
    tui_log_warn "ATTENTION: Cette operation va SUPPRIMER definitivement le snapshot '$snap_name'"
    echo ""

    if ! tui_confirm "Confirmer la suppression de '$snap_name' ?"; then
        tui_log_info "Suppression annulee"
        return 0
    fi

    local script
    script=$(get_snapshot_script_path)

    tui_log_info "Suppression de '$snap_name'..."

    local output exit_code=0
    if tui_check_gum; then
        output=$(gum spin --spinner dot \
            --title "Suppression en cours..." \
            --spinner.foreground "${GUM_COLOR_PRIMARY}" \
            -- bash "$script" delete "$vmid" --name "$snap_name" --force 2>&1) || exit_code=$?
    else
        output=$(bash "$script" delete "$vmid" --name "$snap_name" --force 2>&1) || exit_code=$?
    fi

    echo "$output"

    if [[ $exit_code -eq 0 ]]; then
        tui_log_success "Snapshot '$snap_name' supprime"
    else
        tui_log_error "Echec de la suppression"
    fi

    return $exit_code
}

# =============================================================================
# Menus (T016)
# =============================================================================

# Menu des actions sur les snapshots
menu_snapshots() {
    local vmid="$1"
    local vm_name="${2:-VM-$vmid}"
    local running=true

    while $running; do
        tui_banner "Snapshots: $vm_name (VMID: $vmid)"

        local options=(
            "📸 Creer un snapshot"
            "📋 Lister les snapshots"
            "🔄 Restaurer un snapshot"
            "🗑️  Supprimer un snapshot"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Action:" "${options[@]}")

        case "$choice" in
            *"Creer"*)
                create_snapshot "$vmid" || true
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Lister"*)
                list_snapshots "$vmid" || true
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Restaurer"*)
                rollback_snapshot "$vmid" || true
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            *"Supprimer"*)
                delete_snapshot "$vmid" || true
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
# Gestion des cles SSH (US9)
# =============================================================================

# Fichier known_hosts dedie au homelab
LIFECYCLE_KNOWN_HOSTS="${HOMELAB_KNOWN_HOSTS:-${HOME}/.ssh/homelab_known_hosts}"

# Liste les hotes connus
list_known_hosts() {
    if [[ ! -f "$LIFECYCLE_KNOWN_HOSTS" ]]; then
        tui_log_warn "Fichier known_hosts non trouve: ${LIFECYCLE_KNOWN_HOSTS}"
        return 0
    fi

    local count
    count=$(wc -l < "$LIFECYCLE_KNOWN_HOSTS" 2>/dev/null) || count=0

    tui_log_info "Fichier: ${LIFECYCLE_KNOWN_HOSTS}"
    tui_log_info "Nombre d'entrees: ${count}"
    echo ""

    # Afficher les hotes (les IPs sont hashees, donc on montre juste le nombre)
    if [[ "$count" -gt 0 ]]; then
        echo -e "${TUI_COLOR_INFO}Entrees (hashees pour securite):${TUI_COLOR_NC}"
        head -5 "$LIFECYCLE_KNOWN_HOSTS" | while read -r line; do
            echo "  ${line:0:60}..."
        done
        if [[ "$count" -gt 5 ]]; then
            echo "  ... et $((count - 5)) autres entrees"
        fi
    fi
}

# Decouvre les hotes depuis les tfvars
discover_hosts_from_tfvars() {
    local hosts=()
    local envs_dir="${TUI_PROJECT_ROOT}/infrastructure/proxmox/environments"

    for env_dir in "$envs_dir"/*/; do
        local tfvars="${env_dir}terraform.tfvars"
        if [[ -f "$tfvars" ]]; then
            # Extraire proxmox_endpoint
            local endpoint
            endpoint=$(grep -E "^proxmox_endpoint\s*=" "$tfvars" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1) || true
            if [[ -n "$endpoint" ]]; then
                local ip
                ip=$(echo "$endpoint" | sed -E 's|https?://([0-9.]+).*|\1|') || true
                if [[ -n "$ip" ]] && [[ ! " ${hosts[*]} " =~ " ${ip} " ]]; then
                    hosts+=("$ip")
                fi
            fi

            # Extraire les IPs des VMs (ignorer les lignes commentees)
            local vm_ips
            vm_ips=$(grep -v '^\s*#' "$tfvars" 2>/dev/null | grep -oP 'ip\s*=\s*"\K[0-9.]+' | sort -u) || true
            for ip in $vm_ips; do
                if [[ -n "$ip" ]] && [[ ! " ${hosts[*]} " =~ " ${ip} " ]]; then
                    hosts+=("$ip")
                fi
            done
        fi
    done

    printf '%s\n' "${hosts[@]}"
}

# Ajoute un hote au known_hosts
add_host_to_known_hosts() {
    local host="$1"

    if [[ -z "$host" ]]; then
        tui_log_error "Hote non specifie"
        return 0
    fi

    mkdir -p "$(dirname "$LIFECYCLE_KNOWN_HOSTS")"

    tui_log_info "Scan de la cle SSH pour ${host}..."

    if ssh-keyscan -H "$host" >> "$LIFECYCLE_KNOWN_HOSTS" 2>/dev/null; then
        sort -u "$LIFECYCLE_KNOWN_HOSTS" -o "$LIFECYCLE_KNOWN_HOSTS"
        tui_log_success "Cle ajoutee pour ${host}"
    else
        tui_log_error "Impossible de scanner ${host} (hote inaccessible?)"
    fi
}

# Supprime toutes les entrees pour un hote
remove_host_from_known_hosts() {
    local host="$1"

    if [[ -z "$host" ]]; then
        tui_log_error "Hote non specifie"
        return 0
    fi

    if [[ ! -f "$LIFECYCLE_KNOWN_HOSTS" ]]; then
        tui_log_warn "Fichier known_hosts non trouve"
        return 0
    fi

    if ssh-keygen -R "$host" -f "$LIFECYCLE_KNOWN_HOSTS" &>/dev/null; then
        tui_log_success "Entrees supprimees pour ${host}"
    else
        tui_log_warn "Aucune entree trouvee pour ${host}"
    fi
}

# Teste la connectivite SSH vers un hote
test_host_connectivity() {
    local host="$1"
    local user="${2:-root}"

    tui_log_info "Test SSH vers ${user}@${host}..."

    if ssh -n -o ConnectTimeout=5 -o BatchMode=yes "${user}@${host}" "echo OK" &>/dev/null; then
        tui_log_success "Connexion OK"
        return 0
    else
        tui_log_error "Echec de connexion"
        return 0
    fi
}

# Initialise known_hosts avec tous les hotes decouverts
init_all_known_hosts() {
    local hosts
    hosts=$(discover_hosts_from_tfvars)

    if [[ -z "$hosts" ]]; then
        tui_log_warn "Aucun hote decouvert depuis les tfvars"
        return 0
    fi

    tui_log_info "Hotes decouverts:"
    echo "$hosts" | while read -r h; do
        echo "  - ${h}"
    done
    echo ""

    if ! tui_confirm "Ajouter tous ces hotes au known_hosts?"; then
        tui_log_info "Operation annulee"
        return 0
    fi

    mkdir -p "$(dirname "$LIFECYCLE_KNOWN_HOSTS")"

    echo "$hosts" | while read -r host; do
        if [[ -n "$host" ]]; then
            tui_log_info "Scan de ${host}..."
            ssh-keyscan -H "$host" >> "$LIFECYCLE_KNOWN_HOSTS" 2>/dev/null || true
        fi
    done

    sort -u "$LIFECYCLE_KNOWN_HOSTS" -o "$LIFECYCLE_KNOWN_HOSTS"
    local count
    count=$(wc -l < "$LIFECYCLE_KNOWN_HOSTS" 2>/dev/null) || count=0
    tui_log_success "Known_hosts initialise avec ${count} entrees"
}

# Menu gestion des cles SSH
menu_ssh_keys() {
    local running=true

    while $running; do
        clear
        tui_banner "Gestion des cles SSH"

        # Afficher le statut du fichier known_hosts
        if [[ -f "$LIFECYCLE_KNOWN_HOSTS" ]]; then
            local count
            count=$(wc -l < "$LIFECYCLE_KNOWN_HOSTS" 2>/dev/null) || count=0
            echo -e "${TUI_COLOR_WHITE}Fichier: ${LIFECYCLE_KNOWN_HOSTS}${TUI_COLOR_NC}"
            echo -e "${TUI_COLOR_SUCCESS}Entrees: ${count}${TUI_COLOR_NC}"
        else
            echo -e "${TUI_COLOR_WARN}Fichier known_hosts non initialise${TUI_COLOR_NC}"
        fi
        echo ""

        local options=(
            "1. 📋 Voir les hotes connus"
            "2. 🔍 Decouvrir les hotes (depuis tfvars)"
            "3. ➕ Ajouter un hote manuellement"
            "4. ➖ Supprimer un hote"
            "5. 🔄 Initialiser avec tous les hotes"
            "6. 🧪 Tester la connectivite"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Que voulez-vous faire?" "${options[@]}")

        case "$choice" in
            "1."*|*"Voir"*)
                clear
                tui_banner "Hotes connus"
                list_known_hosts
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "2."*|*"Decouvrir"*)
                clear
                tui_banner "Decouverte des hotes"
                local hosts
                hosts=$(discover_hosts_from_tfvars)
                if [[ -n "$hosts" ]]; then
                    tui_log_success "Hotes decouverts depuis tfvars:"
                    echo "$hosts" | while read -r h; do
                        # Verifier si deja connu
                        if ssh-keygen -F "$h" -f "$LIFECYCLE_KNOWN_HOSTS" &>/dev/null 2>&1; then
                            echo -e "  ${TUI_COLOR_SUCCESS}●${TUI_COLOR_NC} ${h} (connu)"
                        else
                            echo -e "  ${TUI_COLOR_WARN}○${TUI_COLOR_NC} ${h} (non connu)"
                        fi
                    done
                else
                    tui_log_warn "Aucun hote decouvert"
                fi
                echo ""
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "3."*|*"Ajouter"*)
                local new_host
                new_host=$(tui_input "Adresse IP ou hostname de l'hote" "")
                if [[ -n "$new_host" ]]; then
                    add_host_to_known_hosts "$new_host"
                fi
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "4."*|*"Supprimer"*)
                local del_host
                del_host=$(tui_input "Adresse IP ou hostname a supprimer" "")
                if [[ -n "$del_host" ]]; then
                    remove_host_from_known_hosts "$del_host"
                fi
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "5."*|*"Initialiser"*)
                init_all_known_hosts
                tui_log_info "Appuyez sur Entree pour continuer..."
                read -r
                ;;
            "6."*|*"Tester"*)
                clear
                tui_banner "Test de connectivite"
                local hosts
                hosts=$(discover_hosts_from_tfvars)
                if [[ -n "$hosts" ]]; then
                    echo "$hosts" | while read -r h; do
                        # Determiner le user (root pour .50/.100, ubuntu pour autres)
                        local user="root"
                        if [[ "$h" =~ \.(51|101|102|103)$ ]]; then
                            user="ubuntu"
                        fi
                        test_host_connectivity "$h" "$user"
                    done
                else
                    tui_log_warn "Aucun hote a tester"
                fi
                echo ""
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

# Menu principal lifecycle
menu_lifecycle() {
    local running=true

    while $running; do
        clear
        tui_banner "Lifecycle - Snapshots & VMs"

        local options=(
            "1. 📸 Gerer les snapshots d'une VM/LXC"
            "2. 🔑 Gerer les cles SSH (US9)"
            "$(tui_back_option)"
        )

        local choice
        choice=$(tui_menu "Que voulez-vous faire?" "${options[@]}")

        case "$choice" in
            "1."*|*"snapshots"*|*"Snapshots"*)
                # Selectionner environnement
                local env
                env=$(select_environment)

                if [[ "$env" != "back" ]] && [[ -n "$env" ]]; then
                    # shellcheck disable=SC2034
                    LIFECYCLE_CURRENT_ENV="$env"

                    # Selectionner VM
                    if select_vm_or_enter_vmid "$env"; then
                        if [[ "$LIFECYCLE_CURRENT_VMID" != "back" ]] && [[ -n "$LIFECYCLE_CURRENT_VMID" ]]; then
                            menu_snapshots "$LIFECYCLE_CURRENT_VMID" "$LIFECYCLE_CURRENT_VM_NAME"
                        fi
                    fi
                fi
                ;;
            "2."*|*"SSH"*|*"cles"*)
                menu_ssh_keys
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

export -f menu_lifecycle menu_snapshots menu_ssh_keys
export -f get_snapshot_script_path generate_snapshot_name
export -f validate_vmid validate_snapshot_name format_vm_option
export -f get_vms_from_tfvars get_containers_from_tfvars get_monitoring_vm_from_tfvars get_env_with_vms
export -f select_environment select_vm enter_vmid_manually select_vm_or_enter_vmid
export -f get_snapshot_actions parse_snapshots_json format_snapshot_table
export -f create_snapshot list_snapshots select_snapshot rollback_snapshot delete_snapshot
export -f list_known_hosts discover_hosts_from_tfvars add_host_to_known_hosts
export -f remove_host_from_known_hosts test_host_connectivity init_all_known_hosts
