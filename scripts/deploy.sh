#!/bin/bash
# =============================================================================
# Deploy scripts and systemd timers to monitoring VM
# =============================================================================
# Usage: ./scripts/deploy.sh [--ssh-user USER] [--dry-run] [--help]
#
# Deploys operational scripts (health check, drift detection, lifecycle) and
# their systemd timers to the monitoring VM via rsync/SSH.
#
# Options:
#   --ssh-user USER    SSH user for connections (default: ubuntu)
#   --dry-run          Show commands without executing
#   -h, --help         Show this help
#
# Examples:
#   ./scripts/deploy.sh
#   ./scripts/deploy.sh --ssh-user root
#   ./scripts/deploy.sh --dry-run
# =============================================================================

set -euo pipefail

# =============================================================================
# Detection du repertoire du script
# =============================================================================

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${DEPLOY_DIR}/lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

# =============================================================================
# Variables globales
# =============================================================================

PROJECT_ROOT="$(cd "${DEPLOY_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly MONITORING_TFVARS="${PROJECT_ROOT}/infrastructure/proxmox/environments/monitoring/terraform.tfvars"
readonly REMOTE_BASE="/opt/pve-home"

SSH_USER="ubuntu"
# Options SSH securisees via common.sh (get_ssh_opts)
SSH_OPTS="$(get_ssh_opts)"

readonly TIMERS=(
    "pve-health-check"
    "pve-drift-check"
    "pve-cleanup-snapshots"
    "pve-expire-lab"
)

# =============================================================================
# Fonctions
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: deploy.sh [options]

Deploy scripts and systemd timers to monitoring VM.

Options:
  --ssh-user USER    SSH user for connections (default: ubuntu)
  --dry-run          Show commands without executing
  -h, --help         Show this help

Examples:
  ./scripts/deploy.sh
  ./scripts/deploy.sh --ssh-user root
  ./scripts/deploy.sh --dry-run
HELPEOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssh-user)
                SSH_USER="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
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
}

get_monitoring_ip() {
    if [[ ! -f "$MONITORING_TFVARS" ]]; then
        log_error "Fichier terraform.tfvars introuvable: ${MONITORING_TFVARS}"
        return 1
    fi

    local ip
    ip=$(awk '/^monitoring\s*=\s*\{/,/^\}/' "$MONITORING_TFVARS" \
        | grep -oP 'ip\s*=\s*"\K\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' \
        | head -1 || echo "")

    if [[ -z "$ip" ]]; then
        log_error "IP monitoring non trouvee dans ${MONITORING_TFVARS}"
        return 1
    fi

    echo "$ip"
}

check_ssh_connectivity() {
    local ip="$1"

    log_info "Test de connectivite SSH vers ${SSH_USER}@${ip}..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh ${SSH_OPTS} -o ConnectTimeout=5 ${SSH_USER}@${ip} exit"
        return 0
    fi

    # shellcheck disable=SC2086
    if ! ssh ${SSH_OPTS} -o ConnectTimeout=5 "${SSH_USER}@${ip}" "exit" &>/dev/null; then
        log_error "Impossible de se connecter en SSH a ${SSH_USER}@${ip}"
        return 1
    fi

    log_success "Connexion SSH OK"
}

remote_exec() {
    local ip="$1"
    local command="$2"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh ${SSH_USER}@${ip}: ${command}"
        return 0
    fi

    # shellcheck disable=SC2086
    ssh ${SSH_OPTS} "${SSH_USER}@${ip}" "${command}"
}

remote_exec_sudo() {
    local ip="$1"
    local command="$2"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh ${SSH_USER}@${ip}: sudo ${command}"
        return 0
    fi

    # shellcheck disable=SC2086
    ssh ${SSH_OPTS} "${SSH_USER}@${ip}" "sudo ${command}"
}

rsync_to_remote() {
    local ip="$1"
    local src="$2"
    local dest="$3"
    local extra_opts="${4:-}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] rsync ${extra_opts} ${src} -> ${SSH_USER}@${ip}:${dest}"
        return 0
    fi

    # shellcheck disable=SC2086
    rsync -avz --delete \
        -e "ssh ${SSH_OPTS}" \
        ${extra_opts} \
        "${src}" "${SSH_USER}@${ip}:${dest}"
}

create_remote_dirs() {
    local ip="$1"

    log_info "Creation des repertoires distants..."

    remote_exec_sudo "$ip" "mkdir -p \
        ${REMOTE_BASE}/scripts/{lib,drift,health,lifecycle,restore,systemd} \
        ${REMOTE_BASE}/infrastructure/proxmox/environments/{prod,lab,monitoring} \
        /var/log/pve-drift \
        /var/lib/prometheus/node-exporter"

    remote_exec_sudo "$ip" "chown -R ${SSH_USER}:${SSH_USER} ${REMOTE_BASE}"

    log_success "Repertoires crees"
}

deploy_scripts() {
    local ip="$1"

    log_info "Deploiement des scripts..."

    local dirs=("lib" "drift" "health" "lifecycle" "restore")
    for dir in "${dirs[@]}"; do
        local src="${PROJECT_ROOT}/scripts/${dir}/"
        if [[ -d "$src" ]]; then
            rsync_to_remote "$ip" "$src" "${REMOTE_BASE}/scripts/${dir}/" "--chmod=D755,F755"
            log_success "  scripts/${dir}/ deploye"
        else
            log_warn "  scripts/${dir}/ introuvable, skip"
        fi
    done
}

deploy_tfvars() {
    local ip="$1"

    log_info "Deploiement des terraform.tfvars..."

    local envs=("prod" "lab" "monitoring")
    for env in "${envs[@]}"; do
        local src="${PROJECT_ROOT}/infrastructure/proxmox/environments/${env}/terraform.tfvars"
        if [[ -f "$src" ]]; then
            rsync_to_remote "$ip" "$src" "${REMOTE_BASE}/infrastructure/proxmox/environments/${env}/terraform.tfvars"
            log_success "  ${env}/terraform.tfvars deploye"
        else
            log_warn "  ${env}/terraform.tfvars introuvable, skip"
        fi
    done
}

deploy_systemd() {
    local ip="$1"

    log_info "Deploiement des fichiers systemd..."

    # Copy systemd files to staging area first
    local systemd_src="${PROJECT_ROOT}/scripts/systemd/"
    if [[ ! -d "$systemd_src" ]]; then
        log_error "Repertoire scripts/systemd/ introuvable"
        return 1
    fi

    rsync_to_remote "$ip" "$systemd_src" "${REMOTE_BASE}/scripts/systemd/"

    # Copy from staging to /etc/systemd/system/ via sudo
    for timer in "${TIMERS[@]}"; do
        remote_exec_sudo "$ip" "cp ${REMOTE_BASE}/scripts/systemd/${timer}.service /etc/systemd/system/"
        remote_exec_sudo "$ip" "cp ${REMOTE_BASE}/scripts/systemd/${timer}.timer /etc/systemd/system/"
    done

    log_success "Fichiers systemd deployes"
}

enable_timers() {
    local ip="$1"

    log_info "Activation des timers systemd..."

    remote_exec_sudo "$ip" "systemctl daemon-reload"

    for timer in "${TIMERS[@]}"; do
        remote_exec_sudo "$ip" "systemctl enable --now ${timer}.timer"
        log_success "  ${timer}.timer active"
    done
}

verify_deployment() {
    local ip="$1"

    log_info "Verification du deploiement..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] systemctl list-timers 'pve-*'"
        return 0
    fi

    echo ""
    remote_exec_sudo "$ip" "systemctl list-timers 'pve-*' --no-pager"
    echo ""

    log_success "Deploiement termine avec succes"
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    log_info "Deploiement sur la VM monitoring - $(date)"

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Mode dry-run active"
    fi

    # Check prerequisites
    for cmd in rsync ssh; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Commande requise non trouvee: ${cmd}"
            exit 1
        fi
    done

    # Get monitoring VM IP
    local monitoring_ip
    monitoring_ip=$(get_monitoring_ip)
    log_info "VM monitoring detectee: ${monitoring_ip}"

    # Test SSH connectivity
    check_ssh_connectivity "$monitoring_ip"

    # Deploy
    create_remote_dirs "$monitoring_ip"
    deploy_scripts "$monitoring_ip"
    deploy_tfvars "$monitoring_ip"
    deploy_systemd "$monitoring_ip"
    enable_timers "$monitoring_ip"
    verify_deployment "$monitoring_ip"
}

main "$@"
