#!/bin/bash
# =============================================================================
# Gestion des snapshots VM/LXC
# =============================================================================
# Usage: ./snapshot-vm.sh <action> <VMID> [options]
#
# Actions:
#   create    Creer un snapshot
#   list      Lister les snapshots
#   rollback  Restaurer un snapshot
#   delete    Supprimer un snapshot
#
# Options:
#   --node NODE      Node Proxmox (defaut: detecte depuis tfvars)
#   --name NAME      Nom du snapshot (defaut: auto-YYYYMMDD-HHMMSS)
#   --description    Description du snapshot
#   --dry-run        Afficher les commandes sans les executer
#   --force          Mode non-interactif
#   -h, --help       Afficher cette aide
#
# Examples:
#   ./snapshot-vm.sh create 100
#   ./snapshot-vm.sh create 100 --name "pre-upgrade"
#   ./snapshot-vm.sh list 100
#   ./snapshot-vm.sh rollback 100 --name "pre-upgrade"
#   ./snapshot-vm.sh delete 100 --name "pre-upgrade"
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Detection du repertoire du script
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
# shellcheck source=../lib/common.sh
source "${LIB_DIR}/common.sh"

# =============================================================================
# Variables globales
# =============================================================================

ACTION=""
VMID=""
PVE_NODE=""
SNAP_NAME=""
SNAP_DESC="Snapshot via pve-home"

# =============================================================================
# Fonctions
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: snapshot-vm.sh <action> <VMID> [options]

Gestion des snapshots VM/LXC.

Actions:
  create    Creer un snapshot
  list      Lister les snapshots
  rollback  Restaurer un snapshot
  delete    Supprimer un snapshot

Options:
  --node NODE      Node Proxmox
  --name NAME      Nom du snapshot
  --description D  Description du snapshot
  --dry-run        Afficher les commandes sans executer
  --force          Mode non-interactif
  -h, --help       Afficher cette aide

Examples:
  ./snapshot-vm.sh create 100
  ./snapshot-vm.sh list 100
  ./snapshot-vm.sh rollback 100 --name "pre-upgrade"
HELPEOF
}

parse_args() {
    if [[ $# -lt 1 ]]; then
        log_error "Action requise (create, list, rollback, delete)"
        show_help
        exit 1
    fi

    ACTION="$1"
    shift

    case "$ACTION" in
        create|list|rollback|delete) ;;
        --help|-h) show_help; exit 0 ;;
        *)
            log_error "Action invalide: ${ACTION}"
            show_help
            exit 1
            ;;
    esac

    if [[ $# -lt 1 ]]; then
        log_error "VMID requis"
        show_help
        exit 1
    fi

    VMID="$1"
    shift

    # Valider que VMID est numerique
    if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
        log_error "VMID doit etre numerique: ${VMID}"
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --node)
                PVE_NODE="$2"
                shift 2
                ;;
            --name)
                SNAP_NAME="$2"
                shift 2
                ;;
            --description)
                SNAP_DESC="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                export FORCE_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Nom par defaut pour create
    if [[ "$ACTION" == "create" && -z "$SNAP_NAME" ]]; then
        SNAP_NAME="auto-$(date +%Y%m%d-%H%M%S)"
    fi

    # Nom obligatoire pour rollback et delete
    if [[ ("$ACTION" == "rollback" || "$ACTION" == "delete") && -z "$SNAP_NAME" ]]; then
        log_error "Le nom du snapshot est requis pour ${ACTION} (--name)"
        exit 1
    fi
}

detect_node() {
    if [[ -n "$PVE_NODE" ]]; then
        return 0
    fi

    # Essayer de detecter depuis les tfvars
    local project_root
    project_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"

    for env in monitoring prod lab; do
        local tfvars="${project_root}/infrastructure/proxmox/environments/${env}/terraform.tfvars"
        if [[ -f "$tfvars" ]]; then
            # Essayer proxmox_endpoint d'abord (format: https://IP:8006)
            local endpoint
            endpoint=$(grep -E "^proxmox_endpoint\s*=" "$tfvars" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1) || true
            if [[ -n "$endpoint" ]]; then
                PVE_NODE=$(echo "$endpoint" | sed -E 's|https?://([0-9.]+).*|\1|') || true
                if [[ -n "$PVE_NODE" ]]; then
                    log_info "Node detecte depuis ${env}: ${PVE_NODE}"
                    return 0
                fi
            fi
            # Fallback sur pve_ip
            PVE_NODE=$(grep -oP '(?<=pve_ip\s*=\s*")\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$tfvars" 2>/dev/null || echo "")
            if [[ -n "$PVE_NODE" ]]; then
                log_info "Node detecte: ${PVE_NODE}"
                return 0
            fi
        fi
    done

    log_error "Impossible de detecter le node Proxmox. Utilisez --node."
    exit 1
}

do_create() {
    log_info "Creation du snapshot '${SNAP_NAME}' pour VMID ${VMID}..."

    local cmd="pvesh create /nodes/localhost/qemu/${VMID}/snapshot --snapname '${SNAP_NAME}' --description '${SNAP_DESC}'"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh root@${PVE_NODE} ${cmd}"
        return 0
    fi

    if ssh_exec "$PVE_NODE" "$cmd"; then
        log_success "Snapshot '${SNAP_NAME}' cree pour VMID ${VMID}"
    else
        # Essayer en tant que LXC
        cmd="pvesh create /nodes/localhost/lxc/${VMID}/snapshot --snapname '${SNAP_NAME}' --description '${SNAP_DESC}'"
        if ssh_exec "$PVE_NODE" "$cmd"; then
            log_success "Snapshot '${SNAP_NAME}' cree pour LXC ${VMID}"
        else
            log_error "Echec de la creation du snapshot"
            return 1
        fi
    fi
}

do_list() {
    log_info "Snapshots pour VMID ${VMID}:"

    local cmd="pvesh get /nodes/localhost/qemu/${VMID}/snapshot --output-format json-pretty 2>/dev/null || pvesh get /nodes/localhost/lxc/${VMID}/snapshot --output-format json-pretty 2>/dev/null || echo '[]'"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh root@${PVE_NODE} ${cmd}"
        return 0
    fi

    ssh_exec "$PVE_NODE" "$cmd"
}

do_rollback() {
    log_info "Rollback vers snapshot '${SNAP_NAME}' pour VMID ${VMID}..."

    if ! confirm "Confirmer le rollback vers '${SNAP_NAME}' ?"; then
        log_info "Rollback annule"
        return 0
    fi

    local cmd="pvesh create /nodes/localhost/qemu/${VMID}/snapshot/${SNAP_NAME}/rollback"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh root@${PVE_NODE} ${cmd}"
        return 0
    fi

    if ssh_exec "$PVE_NODE" "$cmd"; then
        log_success "Rollback vers '${SNAP_NAME}' effectue pour VMID ${VMID}"
    else
        cmd="pvesh create /nodes/localhost/lxc/${VMID}/snapshot/${SNAP_NAME}/rollback"
        if ssh_exec "$PVE_NODE" "$cmd"; then
            log_success "Rollback vers '${SNAP_NAME}' effectue pour LXC ${VMID}"
        else
            log_error "Echec du rollback"
            return 1
        fi
    fi
}

do_delete() {
    log_info "Suppression du snapshot '${SNAP_NAME}' pour VMID ${VMID}..."

    local cmd="pvesh delete /nodes/localhost/qemu/${VMID}/snapshot/${SNAP_NAME}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh root@${PVE_NODE} ${cmd}"
        return 0
    fi

    if ssh_exec "$PVE_NODE" "$cmd"; then
        log_success "Snapshot '${SNAP_NAME}' supprime pour VMID ${VMID}"
    else
        cmd="pvesh delete /nodes/localhost/lxc/${VMID}/snapshot/${SNAP_NAME}"
        if ssh_exec "$PVE_NODE" "$cmd"; then
            log_success "Snapshot '${SNAP_NAME}' supprime pour LXC ${VMID}"
        else
            log_error "Echec de la suppression"
            return 1
        fi
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"
    detect_node

    case "$ACTION" in
        create)   do_create ;;
        list)     do_list ;;
        rollback) do_rollback ;;
        delete)   do_delete ;;
    esac
}

main "$@"
