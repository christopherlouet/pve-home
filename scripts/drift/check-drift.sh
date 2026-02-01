#!/bin/bash
# =============================================================================
# Detection de drift infrastructure Terraform
# =============================================================================
# Usage: ./check-drift.sh [--env ENV] [--all] [--dry-run] [--help]
#
# Detecte les changements non planifies (drift) entre l'etat Terraform et
# l'infrastructure Proxmox reelle. Genere un rapport console et des metriques
# Prometheus pour le monitoring.
#
# Options:
#   --env ENV    Environnement a verifier (prod, lab, monitoring)
#   --all        Verifier tous les environnements
#   --dry-run    Afficher les commandes sans les executer
#   --force      Mode non-interactif
#   -h, --help   Afficher cette aide
#
# Examples:
#   ./check-drift.sh --env prod
#   ./check-drift.sh --all
#   ./check-drift.sh --all --dry-run
#
# Metriques Prometheus generees:
#   pve_drift_status{env}                  0=conforme, 1=drift, 2=erreur
#   pve_drift_resources_changed{env}       Nombre de ressources en drift
#   pve_drift_last_check_timestamp{env}    Timestamp du dernier check
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
readonly LOG_DIR="/var/log/pve-drift"
readonly METRICS_DIR="/var/lib/prometheus/node-exporter"
readonly METRICS_FILE="${METRICS_DIR}/pve_drift.prom"
readonly VALID_ENVS=("prod" "lab" "monitoring")

TARGET_ENV=""
CHECK_ALL=false

# =============================================================================
# Fonctions
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: check-drift.sh [options]

Detection de drift infrastructure Terraform.

Options:
  --env ENV    Environnement a verifier (prod, lab, monitoring)
  --all        Verifier tous les environnements
  --dry-run    Afficher les commandes sans les executer
  --force      Mode non-interactif
  -h, --help   Afficher cette aide

Examples:
  ./check-drift.sh --env prod
  ./check-drift.sh --all
  ./check-drift.sh --all --dry-run
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

    # Validation
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
}

validate_env_dir() {
    local env="$1"
    local env_dir="${ENVS_DIR}/${env}"

    if [[ ! -d "$env_dir" ]]; then
        log_error "Repertoire environnement introuvable: ${env_dir}"
        return 1
    fi

    if [[ ! -f "${env_dir}/versions.tf" ]]; then
        log_error "Fichier versions.tf introuvable dans ${env_dir}"
        return 1
    fi

    return 0
}

check_drift_for_env() {
    local env="$1"
    local env_dir="${ENVS_DIR}/${env}"
    local timestamp
    timestamp=$(date +%s)
    local date_str
    date_str=$(date +%Y-%m-%d)

    log_info "Verification du drift pour l'environnement: ${env}"
    echo "---"

    if ! validate_env_dir "$env"; then
        write_metrics "$env" 2 0 "$timestamp"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] terraform -chdir=${env_dir} init -backend=false"
        log_info "[DRY-RUN] terraform -chdir=${env_dir} plan -detailed-exitcode -no-color"
        write_metrics "$env" 0 0 "$timestamp"
        return 0
    fi

    # Initialiser Terraform
    log_info "Initialisation Terraform pour ${env}..."
    if ! terraform -chdir="${env_dir}" init -backend=false -input=false -no-color > /dev/null 2>&1; then
        log_error "Echec de l'initialisation Terraform pour ${env}"
        write_metrics "$env" 2 0 "$timestamp"
        write_log "$env" "$date_str" "ERROR" "Init failed"
        return 1
    fi

    # Executer terraform plan avec -detailed-exitcode
    local plan_output
    local exit_code=0
    plan_output=$(terraform -chdir="${env_dir}" plan -detailed-exitcode -no-color 2>&1) || exit_code=$?

    case "$exit_code" in
        0)
            # Pas de changements = pas de drift
            log_success "[${env}] Conforme - aucun drift detecte"
            write_metrics "$env" 0 0 "$timestamp"
            write_log "$env" "$date_str" "OK" "No drift"
            ;;
        1)
            # Erreur Terraform
            log_error "[${env}] Erreur lors de l'execution du plan"
            echo "$plan_output" | tail -20
            write_metrics "$env" 2 0 "$timestamp"
            write_log "$env" "$date_str" "ERROR" "$plan_output"
            return 1
            ;;
        2)
            # Drift detecte
            local changed_count
            changed_count=$(parse_drift_count "$plan_output")
            log_warn "[${env}] DRIFT DETECTE - ${changed_count} ressource(s) changee(s)"
            echo ""
            parse_drift_details "$plan_output"
            echo ""
            write_metrics "$env" 1 "$changed_count" "$timestamp"
            write_log "$env" "$date_str" "DRIFT" "$plan_output"
            ;;
    esac

    return 0
}

parse_drift_count() {
    local plan_output="$1"

    # Extraire le nombre de changements du plan summary
    # Format: "Plan: X to add, Y to change, Z to destroy."
    local add change destroy
    add=$(echo "$plan_output" | grep -oP '\d+(?= to add)' || echo "0")
    change=$(echo "$plan_output" | grep -oP '\d+(?= to change)' || echo "0")
    destroy=$(echo "$plan_output" | grep -oP '\d+(?= to destroy)' || echo "0")

    echo $(( add + change + destroy ))
}

parse_drift_details() {
    local plan_output="$1"

    # Afficher les ressources modifiees
    echo "$plan_output" | grep -E '^\s*(~|\+|-|<=)' | head -30 || true
}

write_metrics() {
    local env="$1"
    local status="$2"
    local resources_changed="$3"
    local timestamp="$4"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Ecriture metriques: status=${status}, changed=${resources_changed}"
        return 0
    fi

    # Creer le repertoire si necessaire
    mkdir -p "$METRICS_DIR" 2>/dev/null || true

    # Ecrire dans un fichier temporaire puis renommer (atomique)
    local tmp_file
    tmp_file=$(mktemp "${METRICS_FILE}.XXXXXX" 2>/dev/null || echo "")

    if [[ -z "$tmp_file" ]]; then
        log_warn "Impossible de creer le fichier metriques (${METRICS_FILE})"
        return 0
    fi

    {
        echo "# HELP pve_drift_status Infrastructure drift status (0=ok, 1=drift, 2=error)"
        echo "# TYPE pve_drift_status gauge"
        echo "# HELP pve_drift_resources_changed Number of resources with drift"
        echo "# TYPE pve_drift_resources_changed gauge"
        echo "# HELP pve_drift_last_check_timestamp Timestamp of last drift check"
        echo "# TYPE pve_drift_last_check_timestamp gauge"
    } > "$tmp_file"

    # Lire les metriques existantes des autres envs si le fichier existe
    for e in "${VALID_ENVS[@]}"; do
        if [[ "$e" == "$env" ]]; then
            {
                echo "pve_drift_status{env=\"${env}\"} ${status}"
                echo "pve_drift_resources_changed{env=\"${env}\"} ${resources_changed}"
                echo "pve_drift_last_check_timestamp{env=\"${env}\"} ${timestamp}"
            } >> "$tmp_file"
        elif [[ -f "$METRICS_FILE" ]]; then
            grep "env=\"${e}\"" "$METRICS_FILE" >> "$tmp_file" 2>/dev/null || true
        fi
    done

    mv "$tmp_file" "$METRICS_FILE" 2>/dev/null || true
}

write_log() {
    local env="$1"
    local date_str="$2"
    local status="$3"
    local details="$4"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    mkdir -p "$LOG_DIR" 2>/dev/null || true

    local log_file="${LOG_DIR}/drift-${date_str}-${env}.log"
    {
        echo "=== Drift Check Report ==="
        echo "Environment: ${env}"
        echo "Date: $(date)"
        echo "Status: ${status}"
        echo "=== Details ==="
        echo "$details"
    } > "$log_file" 2>/dev/null || log_warn "Impossible d'ecrire le log: ${log_file}"

    # Rotation : supprimer les logs de plus de 30 jours
    find "$LOG_DIR" -name "drift-*.log" -mtime +30 -delete 2>/dev/null || true
}

print_summary() {
    local -n results_ref=$1

    echo ""
    echo "============================================="
    echo "  Resume de la detection de drift"
    echo "============================================="
    printf "%-15s %-10s %s\n" "Environnement" "Statut" "Details"
    echo "---------------------------------------------"

    for entry in "${results_ref[@]}"; do
        local env status detail
        env=$(echo "$entry" | cut -d'|' -f1)
        status=$(echo "$entry" | cut -d'|' -f2)
        detail=$(echo "$entry" | cut -d'|' -f3)

        case "$status" in
            OK)      printf "%-15s ${GREEN}%-10s${NC} %s\n" "$env" "Conforme" "$detail" ;;
            DRIFT)   printf "%-15s ${YELLOW}%-10s${NC} %s\n" "$env" "DRIFT" "$detail" ;;
            ERROR)   printf "%-15s ${RED}%-10s${NC} %s\n" "$env" "ERREUR" "$detail" ;;
        esac
    done

    echo "============================================="
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    log_info "Detection de drift infrastructure - $(date)"

    # Verifier prerequis
    if ! check_command terraform; then
        log_error "Terraform n'est pas installe"
        exit 1
    fi

    local envs_to_check=()
    if [[ "$CHECK_ALL" == true ]]; then
        envs_to_check=("${VALID_ENVS[@]}")
    else
        envs_to_check=("$TARGET_ENV")
    fi

    local results=()
    local has_drift=false
    local has_error=false

    for env in "${envs_to_check[@]}"; do
        local exit_code=0
        check_drift_for_env "$env" || exit_code=$?

        if [[ "$exit_code" -ne 0 ]]; then
            results+=("${env}|ERROR|Echec du check")
            has_error=true
        else
            # Lire le statut depuis les metriques
            if [[ "$DRY_RUN" == true ]]; then
                results+=("${env}|OK|dry-run")
            elif grep -q "pve_drift_status{env=\"${env}\"} 1" "$METRICS_FILE" 2>/dev/null; then
                local count
                count=$(grep "pve_drift_resources_changed{env=\"${env}\"}" "$METRICS_FILE" 2>/dev/null | awk '{print $2}' || echo "?")
                results+=("${env}|DRIFT|${count} ressource(s)")
                has_drift=true
            elif grep -q "pve_drift_status{env=\"${env}\"} 2" "$METRICS_FILE" 2>/dev/null; then
                results+=("${env}|ERROR|Erreur Terraform")
                has_error=true
            else
                results+=("${env}|OK|Aucun drift")
            fi
        fi
    done

    print_summary results

    # Code de retour
    if [[ "$has_error" == true ]]; then
        exit 2
    elif [[ "$has_drift" == true ]]; then
        exit 1
    fi

    exit 0
}

main "$@"
