#!/bin/bash
# =============================================================================
# Expiration automatique des VMs/LXC de lab
# =============================================================================
# Usage: ./expire-lab-vms.sh [--node NODE] [--dry-run] [--force] [--help]
#
# Scanne les tags "expires:YYYY-MM-DD" sur les VMs/LXC et arrete celles
# qui sont expirees. Protection : ne s'applique qu'a l'environnement lab.
#
# Options:
#   --node NODE      Node Proxmox (defaut: detecte depuis tfvars lab)
#   --dry-run        Afficher les actions sans les executer
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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_ROOT
readonly METRICS_DIR="/var/lib/prometheus/node-exporter"

# =============================================================================
# Fonctions
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: expire-lab-vms.sh [options]

Expiration automatique des VMs/LXC de lab.

Options:
  --node NODE      Node Proxmox du lab
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
        local tfvars="${PROJECT_ROOT}/infrastructure/proxmox/environments/lab/terraform.tfvars"
        if [[ -f "$tfvars" ]]; then
            PVE_NODE=$(grep -oP '(?<=pve_ip\s*=\s*")\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$tfvars" 2>/dev/null || echo "")
        fi

        if [[ -z "$PVE_NODE" ]]; then
            log_error "Impossible de detecter le node lab. Utilisez --node."
            exit 1
        fi
    fi
}

check_expiration() {
    log_info "Verification des expirations sur le lab ($(date))..."

    local today
    today=$(date +%Y-%m-%d)

    # Lister les VMs/LXC avec leurs tags
    local resources
    resources=$(ssh_exec "$PVE_NODE" "pvesh get /cluster/resources --type vm --output-format json 2>/dev/null" || echo "[]")

    if [[ "$resources" == "[]" || -z "$resources" ]]; then
        log_info "Aucune VM/LXC trouvee"
        return 0
    fi

    local expired=0
    local checked=0

    echo "$resources" | python3 -c "
import sys, json
resources = json.load(sys.stdin)
for r in resources:
    vmid = r.get('vmid', '')
    name = r.get('name', '')
    status = r.get('status', '')
    tags = r.get('tags', '')
    # Chercher le tag expires:YYYY-MM-DD
    for tag in tags.split(';'):
        if tag.startswith('expires:'):
            expire_date = tag.split(':')[1]
            print(f'{vmid}|{name}|{status}|{expire_date}')
            break
" 2>/dev/null | while IFS='|' read -r vmid name status expire_date; do
        checked=$((checked + 1))

        if [[ "$expire_date" < "$today" || "$expire_date" == "$today" ]]; then
            if [[ "$status" == "running" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    log_warn "[DRY-RUN] Arreterait VMID ${vmid} (${name}) - expire le ${expire_date}"
                else
                    log_warn "Arret de VMID ${vmid} (${name}) - expire le ${expire_date}"
                    ssh_exec "$PVE_NODE" "pvesh create /nodes/localhost/qemu/${vmid}/status/shutdown 2>/dev/null || pvesh create /nodes/localhost/lxc/${vmid}/status/shutdown 2>/dev/null || true"
                    expired=$((expired + 1))
                fi
            else
                log_info "VMID ${vmid} (${name}) expire mais deja arretee"
            fi
        else
            log_info "VMID ${vmid} (${name}) expire le ${expire_date} (valide)"
        fi
    done

    log_success "Verification terminee: ${expired} VM(s) arretee(s)"

    # Ecrire metriques
    if [[ "$DRY_RUN" != true ]]; then
        mkdir -p "$METRICS_DIR" 2>/dev/null || true
        local prom_file="${METRICS_DIR}/pve_lab_expiration.prom"
        {
            echo "# HELP pve_lab_expired_total VMs/LXC expired and stopped"
            echo "# TYPE pve_lab_expired_total gauge"
            echo "pve_lab_expired_total ${expired}"
            echo "# HELP pve_lab_expiration_last_check Last expiration check timestamp"
            echo "# TYPE pve_lab_expiration_last_check gauge"
            echo "pve_lab_expiration_last_check $(date +%s)"
        } > "$prom_file" 2>/dev/null || true
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"
    check_expiration
}

main "$@"
