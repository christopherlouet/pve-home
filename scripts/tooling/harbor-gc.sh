#!/usr/bin/env bash
# =============================================================================
# Harbor Garbage Collection Script
# =============================================================================
# Runs garbage collection on Harbor registry to reclaim disk space
# Usage: ./harbor-gc.sh [--dry-run] [--delete-untagged]
# =============================================================================

set -euo pipefail

# Configuration
HARBOR_HOST="${HARBOR_HOST:-registry.home.arpa}"
HARBOR_USER="${HARBOR_USER:-admin}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-}"
HARBOR_COMPOSE_DIR="${HARBOR_COMPOSE_DIR:-/data/tooling}"
DRY_RUN=false
DELETE_UNTAGGED=false
GC_WORKERS=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

show_help() {
    cat << EOF
Harbor Garbage Collection Script

Usage: $(basename "$0") [OPTIONS]

Options:
    --dry-run           Simulate GC without deleting anything
    --delete-untagged   Also delete untagged manifests
    --workers N         Number of GC workers (default: 1)
    -h, --help          Show this help message

Environment Variables:
    HARBOR_HOST         Harbor hostname (default: registry.home.arpa)
    HARBOR_USER         Harbor admin username (default: admin)
    HARBOR_PASSWORD     Harbor admin password (required)
    HARBOR_COMPOSE_DIR  Path to Harbor Docker Compose directory

Examples:
    $(basename "$0") --dry-run
    $(basename "$0") --delete-untagged
    HARBOR_PASSWORD=secret $(basename "$0")

Note: This script must be run on the Harbor host or via SSH.
EOF
}

check_dependencies() {
    local deps=("curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' not found"
            exit 1
        fi
    done
}

check_harbor_password() {
    if [[ -z "$HARBOR_PASSWORD" ]]; then
        log_error "HARBOR_PASSWORD environment variable is required"
        log_info "Set it with: export HARBOR_PASSWORD='your-password'"
        exit 1
    fi
}

get_harbor_status() {
    log_info "Checking Harbor status..."

    local response
    response=$(curl -sS -k -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/health" 2>/dev/null || echo '{"status":"error"}')

    local status
    status=$(echo "$response" | jq -r '.status // "unknown"')

    if [[ "$status" != "healthy" ]]; then
        log_error "Harbor is not healthy. Status: $status"
        echo "$response" | jq .
        exit 1
    fi

    log_info "Harbor is healthy"
}

get_storage_stats() {
    log_info "Getting storage statistics..."

    local response
    response=$(curl -sS -k -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/statistics" 2>/dev/null)

    local total_storage
    total_storage=$(echo "$response" | jq -r '.total_storage_consumption // 0')

    log_info "Total storage consumption: $(numfmt --to=iec-i --suffix=B "$total_storage" 2>/dev/null || echo "${total_storage} bytes")"
}

list_gc_history() {
    log_info "Last 5 GC runs:"

    local response
    response=$(curl -sS -k -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/system/gc?page=1&page_size=5" 2>/dev/null)

    echo "$response" | jq -r '.[] | "  - \(.creation_time): \(.job_status) (deleted: \(.job_parameters.delete_untagged // false))"' 2>/dev/null || \
        log_warn "No GC history available"
}

trigger_gc_api() {
    log_info "Triggering GC via Harbor API..."

    local gc_config
    gc_config=$(cat << EOF
{
    "parameters": {
        "delete_untagged": $DELETE_UNTAGGED,
        "dry_run": $DRY_RUN,
        "workers": $GC_WORKERS
    },
    "schedule": {
        "type": "Manual"
    }
}
EOF
)

    local response
    local http_code
    http_code=$(curl -sS -k -w "%{http_code}" -o /tmp/harbor_gc_response.json \
        -X POST \
        -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "$gc_config" \
        "https://${HARBOR_HOST}/api/v2.0/system/gc/schedule" 2>/dev/null)

    if [[ "$http_code" == "201" || "$http_code" == "200" ]]; then
        log_info "GC triggered successfully"
        if $DRY_RUN; then
            log_warn "DRY RUN mode - no actual deletion"
        fi
    elif [[ "$http_code" == "409" ]]; then
        log_warn "GC is already running"
    else
        log_error "Failed to trigger GC. HTTP code: $http_code"
        cat /tmp/harbor_gc_response.json
        exit 1
    fi
}

trigger_gc_docker() {
    log_info "Triggering GC via Docker Compose..."

    if [[ ! -d "$HARBOR_COMPOSE_DIR" ]]; then
        log_error "Harbor Compose directory not found: $HARBOR_COMPOSE_DIR"
        exit 1
    fi

    cd "$HARBOR_COMPOSE_DIR"

    local gc_args=""
    if $DRY_RUN; then
        gc_args="--dry-run"
    fi
    if $DELETE_UNTAGGED; then
        gc_args="$gc_args --delete-untagged"
    fi

    log_info "Running: docker compose exec harbor-core harbor-gc $gc_args"

    # Stop Harbor services except DB
    log_info "Stopping Harbor services for GC..."
    docker compose stop harbor-core harbor-jobservice harbor-portal harbor-registry

    # Run GC
    docker compose run --rm harbor-core /harbor/harbor_gc \
        -registry-config /etc/registry/config.yml \
        $gc_args

    # Restart services
    log_info "Restarting Harbor services..."
    docker compose up -d

    log_info "GC completed"
}

monitor_gc() {
    log_info "Monitoring GC progress..."

    local max_attempts=60
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        local response
        response=$(curl -sS -k -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
            "https://${HARBOR_HOST}/api/v2.0/system/gc?page=1&page_size=1" 2>/dev/null)

        local status
        status=$(echo "$response" | jq -r '.[0].job_status // "unknown"')

        case $status in
            "Success")
                log_info "GC completed successfully"
                echo "$response" | jq '.[0]'
                return 0
                ;;
            "Error"|"Stopped")
                log_error "GC failed with status: $status"
                echo "$response" | jq '.[0]'
                return 1
                ;;
            "Running"|"Pending")
                log_debug "GC status: $status (attempt $((attempt+1))/$max_attempts)"
                sleep 10
                ;;
            *)
                log_debug "Unknown status: $status"
                sleep 10
                ;;
        esac

        ((attempt++))
    done

    log_warn "Timeout waiting for GC to complete"
}

main() {
    local use_docker=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --delete-untagged)
                DELETE_UNTAGGED=true
                shift
                ;;
            --workers)
                GC_WORKERS="$2"
                shift 2
                ;;
            --docker)
                use_docker=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    check_dependencies
    check_harbor_password

    echo "=========================================="
    echo "  Harbor Garbage Collection"
    echo "=========================================="
    echo "  Host: $HARBOR_HOST"
    echo "  Dry Run: $DRY_RUN"
    echo "  Delete Untagged: $DELETE_UNTAGGED"
    echo "=========================================="

    get_harbor_status
    get_storage_stats
    list_gc_history

    echo ""
    if $DRY_RUN; then
        log_warn "DRY RUN mode enabled - no actual deletion will occur"
    fi

    read -rp "Proceed with garbage collection? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi

    if $use_docker; then
        trigger_gc_docker
    else
        trigger_gc_api
        monitor_gc
    fi

    echo ""
    log_info "Getting updated storage stats..."
    get_storage_stats

    log_info "Done!"
}

main "$@"
