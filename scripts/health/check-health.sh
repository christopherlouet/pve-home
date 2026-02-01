#!/bin/bash
# =============================================================================
# Health check automatise infrastructure PVE
# =============================================================================
# Usage: ./check-health.sh [--env ENV] [--all] [--component TYPE] [--exclude LIST]
#                          [--timeout SEC] [--dry-run] [--help]
#
# Verifie la sante des VMs, LXC, stack monitoring, et backend Minio.
# Genere un rapport console et des metriques Prometheus.
#
# Options:
#   --env ENV          Environnement a verifier (prod, lab, monitoring)
#   --all              Verifier tous les environnements
#   --component TYPE   Filtrer par type (vm, lxc, monitoring, minio)
#   --exclude LIST     Exclure des composants (separes par virgule)
#   --timeout SEC      Timeout par verification en secondes (defaut: 10)
#   --dry-run          Afficher les verifications sans les executer
#   --force            Mode non-interactif
#   -h, --help         Afficher cette aide
#
# Examples:
#   ./check-health.sh --env prod
#   ./check-health.sh --all
#   ./check-health.sh --env monitoring --component monitoring
#   ./check-health.sh --all --exclude "dev-server,test-vm"
#
# Metriques Prometheus generees:
#   pve_health_status{env,component,type}       0=ok, 1=failed
#   pve_health_check_duration_seconds{env}      Duree du check
#   pve_health_last_check_timestamp{env}        Timestamp du dernier check
#   pve_health_components_total{env}            Nombre total de composants
#   pve_health_components_healthy{env}          Nombre de composants sains
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

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_ROOT
readonly ENVS_DIR="${PROJECT_ROOT}/infrastructure/proxmox/environments"
readonly METRICS_DIR="/var/lib/prometheus/node-exporter"
readonly METRICS_FILE="${METRICS_DIR}/pve_health.prom"
readonly VALID_ENVS=("prod" "lab" "monitoring")
readonly VALID_COMPONENTS=("vm" "lxc" "monitoring" "minio")

TARGET_ENV=""
CHECK_ALL=false
COMPONENT_FILTER=""
EXCLUDE_LIST=""
TIMEOUT=10

# =============================================================================
# Fonctions
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: check-health.sh [options]

Health check automatise infrastructure PVE.

Options:
  --env ENV          Environnement a verifier (prod, lab, monitoring)
  --all              Verifier tous les environnements
  --component TYPE   Filtrer par type (vm, lxc, monitoring, minio)
  --exclude LIST     Exclure des composants (separes par virgule)
  --timeout SEC      Timeout par verification en secondes (defaut: 10)
  --dry-run          Afficher les verifications sans les executer
  --force            Mode non-interactif
  -h, --help         Afficher cette aide

Examples:
  ./check-health.sh --env prod
  ./check-health.sh --all
  ./check-health.sh --env monitoring --component monitoring
HELPEOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                TARGET_ENV="$2"
                shift 2
                ;;
            --all)
                CHECK_ALL=true
                shift
                ;;
            --component)
                COMPONENT_FILTER="$2"
                shift 2
                ;;
            --exclude)
                EXCLUDE_LIST="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
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

    if [[ "$CHECK_ALL" == false && -z "$TARGET_ENV" ]]; then
        log_error "Specifiez --env ENV ou --all"
        show_help
        exit 1
    fi

    if [[ -n "$TARGET_ENV" ]]; then
        local valid=false
        for env in "${VALID_ENVS[@]}"; do
            if [[ "$env" == "$TARGET_ENV" ]]; then
                valid=true
                break
            fi
        done
        if [[ "$valid" == false ]]; then
            log_error "Environnement invalide: ${TARGET_ENV} (valides: ${VALID_ENVS[*]})"
            exit 1
        fi
    fi

    if [[ -n "$COMPONENT_FILTER" ]]; then
        local valid=false
        for comp in "${VALID_COMPONENTS[@]}"; do
            if [[ "$comp" == "$COMPONENT_FILTER" ]]; then
                valid=true
                break
            fi
        done
        if [[ "$valid" == false ]]; then
            log_error "Composant invalide: ${COMPONENT_FILTER} (valides: ${VALID_COMPONENTS[*]})"
            exit 1
        fi
    fi
}

is_excluded() {
    local name="$1"
    if [[ -z "$EXCLUDE_LIST" ]]; then
        return 1
    fi
    echo "$EXCLUDE_LIST" | tr ',' '\n' | grep -qx "$name"
}

# =============================================================================
# Verifications
# =============================================================================

check_ping() {
    local ip="$1"
    local name="$2"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ping -c1 -W${TIMEOUT} ${ip}"
        return 0
    fi

    if ping -c1 -W"${TIMEOUT}" "$ip" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_ssh() {
    local ip="$1"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh -o ConnectTimeout=${TIMEOUT} root@${ip} exit"
        return 0
    fi

    if ssh -o ConnectTimeout="${TIMEOUT}" -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
           "root@${ip}" "exit" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_http() {
    local url="$1"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] curl -sf --connect-timeout ${TIMEOUT} ${url}"
        return 0
    fi

    if curl -sf --connect-timeout "${TIMEOUT}" "$url" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_docker_service() {
    local ip="$1"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] ssh root@${ip} systemctl is-active docker"
        return 0
    fi

    local result
    result=$(ssh -o ConnectTimeout="${TIMEOUT}" -o StrictHostKeyChecking=no \
                 -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
                 "root@${ip}" "systemctl is-active docker" 2>/dev/null || echo "inactive")

    [[ "$result" == "active" ]]
}

# =============================================================================
# Checks par type
# =============================================================================

check_vm_health() {
    local env="$1"
    local env_dir="${ENVS_DIR}/${env}"
    # shellcheck disable=SC2178
    local -n results_ref=$2

    if [[ -n "$COMPONENT_FILTER" && "$COMPONENT_FILTER" != "vm" ]]; then
        return 0
    fi

    log_info "Verification des VMs (${env})..."

    # Lire les IPs depuis terraform output ou tfvars
    local tfvars="${env_dir}/terraform.tfvars"
    if [[ ! -f "$tfvars" ]]; then
        log_warn "Pas de terraform.tfvars pour ${env}, skip VMs"
        return 0
    fi

    # Extraire les IPs des VMs depuis le tfvars (format simplifie)
    local ips
    ips=$(grep -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$tfvars" 2>/dev/null | sort -u || echo "")

    for ip in $ips; do
        local name="vm-${ip}"
        if is_excluded "$name" || is_excluded "$ip"; then
            continue
        fi

        local status="OK"
        local detail=""
        local start_time
        start_time=$(date +%s%N)

        if ! check_ping "$ip" "$name"; then
            status="FAIL"
            detail="ping failed"
        elif ! check_ssh "$ip"; then
            status="WARN"
            detail="SSH unreachable"
        fi

        local end_time
        end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))

        results_ref+=("${env}|${name}|vm|${status}|${detail}|${duration_ms}ms")

        if [[ "$status" == "OK" ]]; then
            log_success "  ${name} (${ip}): OK"
        elif [[ "$status" == "WARN" ]]; then
            log_warn "  ${name} (${ip}): ${detail}"
        else
            log_error "  ${name} (${ip}): ${detail}"
        fi
    done
}

check_monitoring_health() {
    local env="$1"
    # shellcheck disable=SC2178
    local -n results_ref=$2

    if [[ -n "$COMPONENT_FILTER" && "$COMPONENT_FILTER" != "monitoring" ]]; then
        return 0
    fi

    if [[ "$env" != "monitoring" ]]; then
        return 0
    fi

    log_info "Verification de la stack monitoring..."

    local tfvars="${ENVS_DIR}/monitoring/terraform.tfvars"
    local monitoring_ip=""
    if [[ -f "$tfvars" ]]; then
        monitoring_ip=$(grep -oP '(?<=monitoring_ip\s*=\s*")\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$tfvars" 2>/dev/null || echo "")
    fi

    if [[ -z "$monitoring_ip" ]]; then
        log_warn "IP monitoring non trouvee, skip"
        return 0
    fi

    # Prometheus
    local status="OK" detail=""
    if ! check_http "http://${monitoring_ip}:9090/-/ready"; then
        status="FAIL"
        detail="Prometheus unreachable"
    fi
    results_ref+=("${env}|prometheus|monitoring|${status}|${detail}|")
    [[ "$status" == "OK" ]] && log_success "  Prometheus: OK" || log_error "  Prometheus: ${detail}"

    # Grafana
    status="OK" detail=""
    if ! check_http "http://${monitoring_ip}:3000/api/health"; then
        status="FAIL"
        detail="Grafana unreachable"
    fi
    results_ref+=("${env}|grafana|monitoring|${status}|${detail}|")
    [[ "$status" == "OK" ]] && log_success "  Grafana: OK" || log_error "  Grafana: ${detail}"

    # Alertmanager
    status="OK" detail=""
    if ! check_http "http://${monitoring_ip}:9093/-/ready"; then
        status="FAIL"
        detail="Alertmanager unreachable"
    fi
    results_ref+=("${env}|alertmanager|monitoring|${status}|${detail}|")
    [[ "$status" == "OK" ]] && log_success "  Alertmanager: OK" || log_error "  Alertmanager: ${detail}"
}

check_minio_health() {
    local env="$1"
    # shellcheck disable=SC2178
    local -n results_ref=$2

    if [[ -n "$COMPONENT_FILTER" && "$COMPONENT_FILTER" != "minio" ]]; then
        return 0
    fi

    if [[ "$env" != "monitoring" ]]; then
        return 0
    fi

    log_info "Verification de Minio S3..."

    local tfvars="${ENVS_DIR}/monitoring/terraform.tfvars"
    local minio_ip=""
    if [[ -f "$tfvars" ]]; then
        minio_ip=$(grep -oP '(?<=minio_ip\s*=\s*")\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$tfvars" 2>/dev/null || echo "")
    fi

    if [[ -z "$minio_ip" ]]; then
        log_warn "IP Minio non trouvee, skip"
        return 0
    fi

    local status="OK" detail=""
    if ! check_http "http://${minio_ip}:9000/minio/health/live"; then
        status="FAIL"
        detail="Minio health endpoint unreachable"
    fi
    results_ref+=("${env}|minio|minio|${status}|${detail}|")
    [[ "$status" == "OK" ]] && log_success "  Minio: OK" || log_error "  Minio: ${detail}"
}

# =============================================================================
# Rapport et metriques
# =============================================================================

print_report() {
    # shellcheck disable=SC2178
    local -n results_ref=$1

    echo ""
    echo "============================================="
    echo "  Rapport de sante infrastructure"
    echo "============================================="
    printf "%-12s %-20s %-12s %-8s %s\n" "Env" "Composant" "Type" "Statut" "Detail"
    echo "---------------------------------------------"

    local total=0
    local healthy=0

    for entry in "${results_ref[@]}"; do
        local env comp type status detail duration
        env=$(echo "$entry" | cut -d'|' -f1)
        comp=$(echo "$entry" | cut -d'|' -f2)
        type=$(echo "$entry" | cut -d'|' -f3)
        status=$(echo "$entry" | cut -d'|' -f4)
        detail=$(echo "$entry" | cut -d'|' -f5)
        duration=$(echo "$entry" | cut -d'|' -f6)

        total=$((total + 1))

        case "$status" in
            OK)   printf "%-12s %-20s %-12s ${GREEN}%-8s${NC} %s\n" "$env" "$comp" "$type" "OK" "$duration"
                  healthy=$((healthy + 1)) ;;
            WARN) printf "%-12s %-20s %-12s ${YELLOW}%-8s${NC} %s\n" "$env" "$comp" "$type" "WARN" "$detail" ;;
            FAIL) printf "%-12s %-20s %-12s ${RED}%-8s${NC} %s\n" "$env" "$comp" "$type" "FAIL" "$detail" ;;
        esac
    done

    echo "============================================="
    echo "Total: ${healthy}/${total} composants sains"
    echo "============================================="
}

write_health_metrics() {
    # shellcheck disable=SC2178
    local -n results_ref=$1
    local timestamp
    timestamp=$(date +%s)

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Ecriture metriques sante"
        return 0
    fi

    mkdir -p "$METRICS_DIR" 2>/dev/null || true

    local tmp_file
    tmp_file=$(mktemp "${METRICS_FILE}.XXXXXX" 2>/dev/null || echo "")
    if [[ -z "$tmp_file" ]]; then
        log_warn "Impossible de creer le fichier metriques"
        return 0
    fi

    {
        echo "# HELP pve_health_status Component health status (0=ok, 1=failed)"
        echo "# TYPE pve_health_status gauge"
        echo "# HELP pve_health_last_check_timestamp Timestamp of last health check"
        echo "# TYPE pve_health_last_check_timestamp gauge"
        echo "# HELP pve_health_components_total Total number of checked components"
        echo "# TYPE pve_health_components_total gauge"
        echo "# HELP pve_health_components_healthy Number of healthy components"
        echo "# TYPE pve_health_components_healthy gauge"
    } > "$tmp_file"

    # Compteurs par env
    declare -A env_total
    declare -A env_healthy

    for entry in "${results_ref[@]}"; do
        local env comp type status
        env=$(echo "$entry" | cut -d'|' -f1)
        comp=$(echo "$entry" | cut -d'|' -f2)
        type=$(echo "$entry" | cut -d'|' -f3)
        status=$(echo "$entry" | cut -d'|' -f4)

        local metric_val=0
        [[ "$status" != "OK" ]] && metric_val=1

        echo "pve_health_status{env=\"${env}\",component=\"${comp}\",type=\"${type}\"} ${metric_val}" >> "$tmp_file"

        env_total[$env]=$(( ${env_total[$env]:-0} + 1 ))
        [[ "$status" == "OK" ]] && env_healthy[$env]=$(( ${env_healthy[$env]:-0} + 1 ))
    done

    for env in "${!env_total[@]}"; do
        echo "pve_health_last_check_timestamp{env=\"${env}\"} ${timestamp}" >> "$tmp_file"
        echo "pve_health_components_total{env=\"${env}\"} ${env_total[$env]}" >> "$tmp_file"
        echo "pve_health_components_healthy{env=\"${env}\"} ${env_healthy[$env]:-0}" >> "$tmp_file"
    done

    mv "$tmp_file" "$METRICS_FILE" 2>/dev/null || true
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    log_info "Health check infrastructure - $(date)"

    local envs_to_check=()
    if [[ "$CHECK_ALL" == true ]]; then
        envs_to_check=("${VALID_ENVS[@]}")
    else
        envs_to_check=("$TARGET_ENV")
    fi

    local results=()
    local start_time
    start_time=$(date +%s)

    for env in "${envs_to_check[@]}"; do
        check_vm_health "$env" results
        check_monitoring_health "$env" results
        check_minio_health "$env" results
    done

    print_report results
    write_health_metrics results

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "Duree totale: ${duration}s"

    # Code de retour: 1 si au moins un composant en echec
    for entry in "${results[@]}"; do
        local status
        status=$(echo "$entry" | cut -d'|' -f4)
        if [[ "$status" == "FAIL" ]]; then
            exit 1
        fi
    done

    exit 0
}

main "$@"
