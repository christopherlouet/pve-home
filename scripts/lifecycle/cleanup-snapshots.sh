#!/bin/bash
# =============================================================================
# Nettoyage automatique des snapshots anciens
# =============================================================================
# Usage: ./cleanup-snapshots.sh [--node NODE] [--max-age DAYS] [--dry-run] [--help]
#
# Supprime les snapshots auto-generes de plus de N jours.
# Par defaut, supprime les snapshots prefixes par "auto-" de plus de 7 jours.
#
# Options:
#   --node NODE      Node Proxmox (defaut: detecte depuis tfvars)
#   --max-age DAYS   Age max en jours (defaut: 7)
#   --dry-run        Afficher les suppressions sans executer
#   --force          Mode non-interactif
#   -h, --help       Afficher cette aide
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
# shellcheck source=../lib/common.sh
source "${LIB_DIR}/common.sh"

# =============================================================================
# Variables globales
# =============================================================================

PVE_NODE=""
MAX_AGE_DAYS=7
readonly METRICS_DIR="/var/lib/prometheus/node-exporter"

# =============================================================================
# Fonctions
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: cleanup-snapshots.sh [options]

Nettoyage automatique des snapshots anciens.

Options:
  --node NODE      Node Proxmox
  --max-age DAYS   Age max en jours (defaut: 7)
  --dry-run        Mode simulation
  --force          Mode non-interactif
  -h, --help       Afficher cette aide
HELPEOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --node)
                PVE_NODE="$2"
                shift 2
                ;;
            --max-age)
                MAX_AGE_DAYS="$2"
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

    if [[ -z "$PVE_NODE" ]]; then
        local project_root
        project_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
        for env in prod lab monitoring; do
            local tfvars="${project_root}/infrastructure/proxmox/environments/${env}/terraform.tfvars"
            if [[ -f "$tfvars" ]]; then
                PVE_NODE=$(grep -oP '(?<=pve_ip\s*=\s*")\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$tfvars" 2>/dev/null || echo "")
                [[ -n "$PVE_NODE" ]] && break
            fi
        done

        if [[ -z "$PVE_NODE" ]]; then
            log_error "Impossible de detecter le node Proxmox. Utilisez --node."
            exit 1
        fi
    fi
}

cleanup_snapshots() {
    log_info "Nettoyage des snapshots de plus de ${MAX_AGE_DAYS} jours..."

    local cutoff_date
    cutoff_date=$(date -d "-${MAX_AGE_DAYS} days" +%Y%m%d 2>/dev/null || date -v-"${MAX_AGE_DAYS}"d +%Y%m%d 2>/dev/null || echo "")

    if [[ -z "$cutoff_date" ]]; then
        log_error "Impossible de calculer la date limite"
        return 1
    fi

    # Lister toutes les VMs et LXC
    local vmids
    vmids=$(ssh_exec "$PVE_NODE" "pvesh get /cluster/resources --type vm --output-format json 2>/dev/null" | \
            python3 -c "import sys,json; [print(r['vmid']) for r in json.load(sys.stdin)]" 2>/dev/null || echo "")

    if [[ -z "$vmids" ]]; then
        log_info "Aucune VM/LXC trouvee"
        return 0
    fi

    local deleted=0
    local checked=0

    for vmid in $vmids; do
        # Lister les snapshots
        local snapshots
        snapshots=$(ssh_exec "$PVE_NODE" "pvesh get /nodes/localhost/qemu/${vmid}/snapshot --output-format json 2>/dev/null || pvesh get /nodes/localhost/lxc/${vmid}/snapshot --output-format json 2>/dev/null || echo '[]'")

        echo "$snapshots" | python3 -c "
import sys, json
snaps = json.load(sys.stdin)
for s in snaps:
    name = s.get('name', '')
    if name.startswith('auto-') and name != 'current':
        print(name)
" 2>/dev/null | while read -r snap_name; do
            checked=$((checked + 1))

            # Extraire la date du nom (format: auto-YYYYMMDD-HHMMSS)
            local snap_date
            snap_date=$(echo "$snap_name" | grep -oP 'auto-\K\d{8}' || echo "")

            if [[ -z "$snap_date" ]]; then
                continue
            fi

            if [[ "$snap_date" < "$cutoff_date" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    log_info "[DRY-RUN] Supprimerait snapshot '${snap_name}' de VMID ${vmid}"
                else
                    log_info "Suppression de '${snap_name}' (VMID ${vmid})..."
                    ssh_exec "$PVE_NODE" "pvesh delete /nodes/localhost/qemu/${vmid}/snapshot/${snap_name} 2>/dev/null || pvesh delete /nodes/localhost/lxc/${vmid}/snapshot/${snap_name} 2>/dev/null || true"
                    deleted=$((deleted + 1))
                fi
            fi
        done
    done

    log_success "Nettoyage termine: ${deleted} snapshot(s) supprime(s)"

    # Ecrire metrique
    if [[ "$DRY_RUN" != true ]]; then
        mkdir -p "$METRICS_DIR" 2>/dev/null || true
        local prom_file="${METRICS_DIR}/pve_snapshot_cleanup.prom"
        {
            echo "# HELP pve_snapshot_cleanup_deleted_total Snapshots deleted in last cleanup"
            echo "# TYPE pve_snapshot_cleanup_deleted_total gauge"
            echo "pve_snapshot_cleanup_deleted_total ${deleted}"
            echo "# HELP pve_snapshot_cleanup_last_timestamp Last cleanup timestamp"
            echo "# TYPE pve_snapshot_cleanup_last_timestamp gauge"
            echo "pve_snapshot_cleanup_last_timestamp $(date +%s)"
        } > "$prom_file" 2>/dev/null || true
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"
    cleanup_snapshots
}

main "$@"
