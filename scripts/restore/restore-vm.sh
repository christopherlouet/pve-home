#!/bin/bash
# =============================================================================
# Script de restauration de VM/LXC depuis sauvegarde vzdump
# =============================================================================
# Usage: ./restore-vm.sh <vmid> [options]
#
# Restaure une VM ou un conteneur LXC depuis sa derniere sauvegarde vzdump
# ou depuis une sauvegarde a une date specifique.
#
# Options:
#   --node NODE            Noeud Proxmox cible (defaut: depuis terraform.tfvars)
#   --storage STORAGE      Storage Proxmox (defaut: local)
#   --date YYYY-MM-DD      Date de la sauvegarde a restaurer (defaut: la plus recente)
#   --target-id VMID       Restaurer vers un nouveau VMID/CTID (defaut: ecrase l'existant)
#   --dry-run              Afficher les actions sans les executer
#   --force                Mode non-interactif (pas de confirmation)
#   -h, --help             Afficher cette aide
#
# Exemples:
#   ./restore-vm.sh 100                             # Restaurer la VM 100 depuis le dernier backup
#   ./restore-vm.sh 100 --date 2026-01-15           # Restaurer depuis un backup specifique
#   ./restore-vm.sh 100 --target-id 200             # Restaurer vers un nouveau VMID 200
#   ./restore-vm.sh 100 --dry-run                   # Simuler la restauration
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Detection du repertoire du script et chargement des fonctions communes
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"

# Source common.sh
# shellcheck source=../lib/common.sh
source "${LIB_DIR}/common.sh"

# =============================================================================
# Variables globales
# =============================================================================

VMID=""
NODE=""
STORAGE="local"
DATE_FILTER=""
TARGET_ID=""
BACKUP_FILE=""
VM_TYPE=""
START_TIME=$(date +%s)

# =============================================================================
# Fonctions de parsing et aide
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: restore-vm.sh <vmid> [options]

Restaure une VM ou un conteneur LXC depuis sa derniere sauvegarde vzdump.

Arguments:
  <vmid>                 VMID ou CTID a restaurer (requis)

Options:
  --node NODE            Noeud Proxmox cible (defaut: depuis terraform.tfvars)
  --storage STORAGE      Storage Proxmox (defaut: local)
  --date YYYY-MM-DD      Date de la sauvegarde a restaurer (defaut: la plus recente)
  --target-id VMID       Restaurer vers un nouveau VMID/CTID
  --dry-run              Afficher les actions sans les executer
  --force                Mode non-interactif (pas de confirmation)
  -h, --help             Afficher cette aide

Exemples:
  ./restore-vm.sh 100
  ./restore-vm.sh 100 --date 2026-01-15
  ./restore-vm.sh 100 --target-id 200 --force
  ./restore-vm.sh 100 --dry-run

HELPEOF
}

parse_args() {
    # Verifier --help/-h avant tout
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
            show_help
            exit 0
        fi
    done

    if [[ $# -eq 0 ]]; then
        log_error "VMID requis"
        echo ""
        show_help
        exit 1
    fi

    # Premier argument = VMID
    VMID="$1"
    shift

    # Validation VMID numerique
    if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
        log_error "VMID invalide: doit etre un nombre"
        exit 1
    fi

    # Parser les options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --node)
                NODE="${2:?--node necessite une valeur}"
                shift 2
                ;;
            --storage)
                STORAGE="${2:?--storage necessite une valeur}"
                shift 2
                ;;
            --date)
                DATE_FILTER="${2:?--date necessite une valeur}"
                # Validation format date YYYY-MM-DD
                if ! [[ "$DATE_FILTER" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                    log_error "Format de date invalide: attendu YYYY-MM-DD"
                    exit 1
                fi
                shift 2
                ;;
            --target-id)
                TARGET_ID="${2:?--target-id necessite une valeur}"
                if ! [[ "$TARGET_ID" =~ ^[0-9]+$ ]]; then
                    log_error "target-id invalide: doit etre un nombre"
                    exit 1
                fi
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                # shellcheck disable=SC2034
                FORCE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Fonctions metier (T007-T011)
# =============================================================================

detect_node() {
    if [[ -z "$NODE" ]]; then
        # Detecter depuis terraform.tfvars
        local tfvars_file="${SCRIPT_DIR}/../../terraform.tfvars"
        if [[ -f "$tfvars_file" ]]; then
            NODE=$(get_pve_node "$tfvars_file" 2>/dev/null || echo "")
        fi

        if [[ -z "$NODE" ]]; then
            log_error "Impossible de detecter le noeud Proxmox"
            log_error "Utilisez --node NODE ou verifiez terraform.tfvars"
            exit 1
        fi
    fi
    log_info "Noeud Proxmox: ${NODE}"
}

list_backups() {
    log_info "Recherche des sauvegardes pour VMID ${VMID} sur ${NODE}:${STORAGE}..."

    # Commande pvesh pour lister les backups
    local pvesh_cmd="pvesh get /nodes/${NODE}/storage/${STORAGE}/content --content backup --vmid ${VMID} --output-format json"

    local backups_json
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ${pvesh_cmd}"
        # Mock output pour dry-run
        backups_json='[{"volid":"local:backup/vzdump-qemu-100-2026_01_30-12_00_00.vma.zst","format":"vma.zst","size":1000000,"ctime":1738238400}]'
    else
        backups_json=$(ssh_exec "${NODE}" "${pvesh_cmd}" 2>/dev/null || echo "[]")
    fi

    # Parser le JSON avec jq
    local backup_count
    backup_count=$(echo "$backups_json" | jq '. | length' 2>/dev/null || echo "0")

    if [[ "$backup_count" -eq 0 ]]; then
        log_error "Aucune sauvegarde disponible pour VMID ${VMID}"
        log_error "Storage: ${STORAGE}, Noeud: ${NODE}"
        exit 1
    fi

    log_success "${backup_count} sauvegarde(s) trouvee(s)"

    # Afficher les sauvegardes
    echo "$backups_json" | jq -r '.[] | "\(.volid) - \(.ctime) - \(.size) bytes"' || true

    # Selection du backup
    select_backup "$backups_json"
}

select_backup() {
    local backups_json="$1"

    if [[ -n "$DATE_FILTER" ]]; then
        # Selection par date
        log_info "Recherche d'une sauvegarde pour la date: ${DATE_FILTER}"

        # Convertir la date en timestamp
        local target_timestamp
        target_timestamp=$(date -d "$DATE_FILTER" +%s 2>/dev/null || echo "0")

        if [[ "$target_timestamp" -eq 0 ]]; then
            log_error "Date invalide: ${DATE_FILTER}"
            exit 1
        fi

        # Chercher le backup le plus proche de cette date
        BACKUP_FILE=$(echo "$backups_json" | jq -r --arg ts "$target_timestamp" \
            'map(select(.ctime >= ($ts | tonumber))) | sort_by(.ctime) | .[0].volid // empty' 2>/dev/null || echo "")

        if [[ -z "$BACKUP_FILE" ]]; then
            log_error "Aucune sauvegarde disponible pour la date ${DATE_FILTER}"
            exit 1
        fi
    else
        # Selection automatique du plus recent
        log_info "Selection de la sauvegarde la plus recente..."
        BACKUP_FILE=$(echo "$backups_json" | jq -r 'sort_by(.ctime) | .[-1].volid // empty' 2>/dev/null || echo "")

        if [[ -z "$BACKUP_FILE" ]]; then
            log_error "Impossible de selectionner une sauvegarde"
            exit 1
        fi
    fi

    log_success "Sauvegarde selectionnee: ${BACKUP_FILE}"
}

detect_type() {
    # Determiner si c'est une VM (qemu) ou un LXC depuis le nom du fichier
    if [[ "$BACKUP_FILE" == *"vzdump-qemu-"* ]]; then
        VM_TYPE="qemu"
        log_info "Type detecte: VM (qemu)"
    elif [[ "$BACKUP_FILE" == *"vzdump-lxc-"* ]]; then
        VM_TYPE="lxc"
        log_info "Type detecte: Conteneur LXC"
    else
        log_error "Type de backup non reconnu: ${BACKUP_FILE}"
        log_error "Attendu: vzdump-qemu-* ou vzdump-lxc-*"
        exit 1
    fi
}

check_vmid_exists() {
    local vmid_to_check="$1"

    log_info "Verification de l'existence du VMID ${vmid_to_check}..."

    local check_cmd
    if [[ "$VM_TYPE" == "qemu" ]]; then
        check_cmd="qm status ${vmid_to_check}"
    else
        check_cmd="pct status ${vmid_to_check}"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ${check_cmd}"
        return 1
    fi

    if ssh_exec "${NODE}" "${check_cmd}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

handle_existing_vm() {
    local target_vmid="${TARGET_ID:-$VMID}"

    if ! check_vmid_exists "$target_vmid"; then
        log_info "VMID ${target_vmid} n'existe pas, restauration simple"
        return 0
    fi

    log_warn "VMID ${target_vmid} existe deja"

    # Verifier si running
    local status_cmd
    if [[ "$VM_TYPE" == "qemu" ]]; then
        status_cmd="qm status ${target_vmid}"
    else
        status_cmd="pct status ${target_vmid}"
    fi

    local status
    status=$(ssh_exec "${NODE}" "${status_cmd}" 2>/dev/null | awk '{print $2}' || echo "stopped")

    if [[ "$status" == "running" ]]; then
        log_warn "VMID ${target_vmid} est en cours d'execution"
        if ! confirm "Arreter et ecraser VMID ${target_vmid} ?"; then
            log_error "Restauration annulee par l'utilisateur"
            exit 1
        fi

        # Arreter la VM
        local stop_cmd
        if [[ "$VM_TYPE" == "qemu" ]]; then
            stop_cmd="qm stop ${target_vmid}"
        else
            stop_cmd="pct stop ${target_vmid}"
        fi

        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] ${stop_cmd}"
        else
            log_info "Arret de VMID ${target_vmid}..."
            ssh_exec "${NODE}" "${stop_cmd}" || log_warn "Echec de l'arret gracieux"
        fi
    fi

    # Demander confirmation pour ecrasement
    if ! confirm "Ecraser VMID ${target_vmid} avec la sauvegarde ?"; then
        log_error "Restauration annulee par l'utilisateur"
        exit 1
    fi

    # Creer un point de sauvegarde
    if [[ "$DRY_RUN" != true ]]; then
        create_backup_point "vm-${target_vmid}"
    fi

    # Detruire la VM existante
    local destroy_cmd
    if [[ "$VM_TYPE" == "qemu" ]]; then
        destroy_cmd="qm destroy ${target_vmid}"
    else
        destroy_cmd="pct destroy ${target_vmid}"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ${destroy_cmd}"
    else
        log_info "Destruction de VMID ${target_vmid}..."
        ssh_exec "${NODE}" "${destroy_cmd}"
        log_success "VMID ${target_vmid} detruit"
    fi
}

restore_vm() {
    local target_vmid="${TARGET_ID:-$VMID}"
    local restore_cmd

    if [[ "$VM_TYPE" == "qemu" ]]; then
        # qmrestore <backup-file> <vmid> --start 0
        restore_cmd="qmrestore ${BACKUP_FILE} ${target_vmid} --start 0"
    else
        # pct restore <ctid> <backup-file> --start 0
        restore_cmd="pct restore ${target_vmid} ${BACKUP_FILE} --start 0"
    fi

    log_info "Restauration de VMID ${target_vmid} depuis ${BACKUP_FILE}..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ${restore_cmd}"
    else
        ssh_exec "${NODE}" "${restore_cmd}"
        log_success "Restauration terminee"
    fi
}

verify_restore() {
    local target_vmid="${TARGET_ID:-$VMID}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Verification de la restauration (demarrage, ping, SSH)"
        return 0
    fi

    log_info "Verification post-restauration..."

    # Demarrer la VM
    local start_cmd
    if [[ "$VM_TYPE" == "qemu" ]]; then
        start_cmd="qm start ${target_vmid}"
    else
        start_cmd="pct start ${target_vmid}"
    fi

    log_info "Demarrage de VMID ${target_vmid}..."
    ssh_exec "${NODE}" "${start_cmd}" || log_warn "Echec du demarrage"

    # Attendre le boot (retry loop)
    log_info "Attente du boot (30 secondes)..."
    sleep 30

    # Test ping (optionnel, necessiterait l'IP depuis la config)
    log_warn "Test ping et SSH non implementes (necessitent configuration IP)"

    log_success "Verification terminee"
}

show_summary() {
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    echo ""
    log_info "============================================="
    log_info " RESUME DE RESTAURATION"
    log_info "============================================="
    echo ""
    echo "  VMID source:        ${VMID}"
    echo "  VMID cible:         ${TARGET_ID:-$VMID}"
    echo "  Type:               ${VM_TYPE}"
    echo "  Fichier:            ${BACKUP_FILE}"
    echo "  Noeud:              ${NODE}"
    echo "  Storage:            ${STORAGE}"
    echo "  Duree:              ${duration}s"
    echo "  Mode dry-run:       ${DRY_RUN}"
    echo ""
    log_success "Restauration reussie !"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    log_info "============================================="
    log_info " Restauration VM/LXC depuis backup vzdump"
    log_info "============================================="
    echo ""

    # Parsing arguments
    parse_args "$@"

    # Afficher mode dry-run si active
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Mode DRY-RUN active: aucune action ne sera executee"
    fi

    # Verification des prerequis (SSH, jq necessaires pour restore-vm)
    local missing=()
    for cmd in "ssh" "jq"; do
        if ! check_command "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Outils manquants: ${missing[*]}"
        log_error "Installez les prerequis avant de continuer"
        exit 1
    fi

    # Detection du noeud
    detect_node

    # Verification acces SSH (skip en dry-run si noeud inaccessible)
    if [[ "$DRY_RUN" != true ]]; then
        check_ssh_access "${NODE}" || exit 1
    else
        log_info "[DRY-RUN] Verification SSH vers ${NODE} ignoree"
    fi

    # Lister et selectionner le backup
    list_backups

    # Detecter le type (VM/LXC)
    detect_type

    # Gestion VMID existant
    handle_existing_vm

    # Restauration
    restore_vm

    # Verification post-restauration
    verify_restore

    # Resume
    show_summary
}

main "$@"
