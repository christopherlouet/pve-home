#!/usr/bin/env bash
# =============================================================================
# Configure Authentik SSO Providers
# =============================================================================
# Sets up OAuth2/OIDC providers for Grafana and Harbor
# Usage: ./configure-sso.sh [--grafana] [--harbor] [--all]
# =============================================================================

set -euo pipefail

# Configuration
AUTHENTIK_HOST="${AUTHENTIK_HOST:-auth.home.arpa}"
AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:-}"
GRAFANA_HOST="${GRAFANA_HOST:-grafana.home.arpa}"
HARBOR_HOST="${HARBOR_HOST:-registry.home.arpa}"
DOMAIN_SUFFIX="${DOMAIN_SUFFIX:-home.arpa}"

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
Configure Authentik SSO Providers

Usage: $(basename "$0") [OPTIONS]

Options:
    --grafana       Configure Grafana OAuth2 provider
    --harbor        Configure Harbor OIDC provider
    --all           Configure all providers
    --list          List existing providers
    --generate-secrets Generate client secrets
    -h, --help      Show this help message

Environment Variables:
    AUTHENTIK_HOST   Authentik hostname (default: auth.home.arpa)
    AUTHENTIK_TOKEN  Authentik API token (required)
    GRAFANA_HOST     Grafana hostname (default: grafana.home.arpa)
    HARBOR_HOST      Harbor hostname (default: registry.home.arpa)
    DOMAIN_SUFFIX    Domain suffix (default: home.arpa)

Examples:
    $(basename "$0") --all
    AUTHENTIK_TOKEN=xxx $(basename "$0") --grafana
    $(basename "$0") --list

Prerequisites:
    1. Authentik must be running and accessible
    2. Create an API token in Authentik Admin > System > Tokens
    3. Set AUTHENTIK_TOKEN environment variable
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

check_authentik_token() {
    if [[ -z "$AUTHENTIK_TOKEN" ]]; then
        log_error "AUTHENTIK_TOKEN environment variable is required"
        log_info "Create a token in Authentik Admin > System > Tokens"
        exit 1
    fi
}

authentik_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    local url="https://${AUTHENTIK_HOST}/api/v3/${endpoint}"
    local args=(-sS -k -X "$method" -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" -H "Content-Type: application/json")

    if [[ -n "$data" ]]; then
        args+=(-d "$data")
    fi

    curl "${args[@]}" "$url"
}

check_authentik_health() {
    log_info "Checking Authentik health..."

    local response
    response=$(curl -sS -k "https://${AUTHENTIK_HOST}/-/health/ready/" 2>/dev/null || echo "error")

    if [[ "$response" == "error" ]]; then
        log_error "Cannot connect to Authentik at ${AUTHENTIK_HOST}"
        exit 1
    fi

    log_info "Authentik is healthy"
}

generate_secret() {
    openssl rand -base64 32 | tr -d '=/+'
}

list_providers() {
    log_info "Listing existing OAuth2 providers..."

    local response
    response=$(authentik_api GET "providers/oauth2/")

    echo "$response" | jq -r '.results[] | "  - \(.name) (client_id: \(.client_id))"'
}

list_applications() {
    log_info "Listing existing applications..."

    local response
    response=$(authentik_api GET "core/applications/")

    echo "$response" | jq -r '.results[] | "  - \(.name) (slug: \(.slug))"'
}

get_signing_key() {
    log_info "Getting default signing key..."

    local response
    response=$(authentik_api GET "crypto/certificatekeypairs/?name=authentik%20Self-signed%20Certificate")

    echo "$response" | jq -r '.results[0].pk'
}

get_authorization_flow() {
    log_info "Getting authorization flow..."

    local response
    response=$(authentik_api GET "flows/instances/?slug=default-provider-authorization-implicit-consent")

    echo "$response" | jq -r '.results[0].pk'
}

create_grafana_provider() {
    log_info "Creating Grafana OAuth2 provider..."

    local signing_key
    signing_key=$(get_signing_key)

    local auth_flow
    auth_flow=$(get_authorization_flow)

    local client_secret
    client_secret=$(generate_secret)

    local redirect_uri="https://${GRAFANA_HOST}/login/generic_oauth"

    local data
    data=$(cat << EOF
{
    "name": "grafana",
    "authorization_flow": "${auth_flow}",
    "client_type": "confidential",
    "client_id": "grafana",
    "client_secret": "${client_secret}",
    "redirect_uris": "${redirect_uri}",
    "signing_key": "${signing_key}",
    "sub_mode": "hashed_user_id",
    "include_claims_in_id_token": true,
    "issuer_mode": "per_provider",
    "access_token_validity": "hours=1",
    "refresh_token_validity": "days=30"
}
EOF
)

    local response
    response=$(authentik_api POST "providers/oauth2/" "$data")

    local provider_pk
    provider_pk=$(echo "$response" | jq -r '.pk // empty')

    if [[ -z "$provider_pk" ]]; then
        log_error "Failed to create Grafana provider"
        echo "$response" | jq .
        return 1
    fi

    log_info "Grafana provider created (pk: $provider_pk)"

    # Create application
    log_info "Creating Grafana application..."

    data=$(cat << EOF
{
    "name": "Grafana",
    "slug": "grafana",
    "provider": ${provider_pk},
    "meta_launch_url": "https://${GRAFANA_HOST}",
    "meta_description": "Grafana Monitoring Dashboard",
    "policy_engine_mode": "any",
    "open_in_new_tab": true
}
EOF
)

    response=$(authentik_api POST "core/applications/" "$data")

    echo ""
    log_info "=== Grafana OAuth2 Configuration ==="
    echo "Client ID: grafana"
    echo "Client Secret: ${client_secret}"
    echo "Auth URL: https://${AUTHENTIK_HOST}/application/o/authorize/"
    echo "Token URL: https://${AUTHENTIK_HOST}/application/o/token/"
    echo "Userinfo URL: https://${AUTHENTIK_HOST}/application/o/userinfo/"
    echo "Redirect URI: ${redirect_uri}"
    echo ""
    log_warn "Save the client secret - it won't be shown again!"
}

create_harbor_provider() {
    log_info "Creating Harbor OIDC provider..."

    local signing_key
    signing_key=$(get_signing_key)

    local auth_flow
    auth_flow=$(get_authorization_flow)

    local client_secret
    client_secret=$(generate_secret)

    local redirect_uri="https://${HARBOR_HOST}/c/oidc/callback"

    local data
    data=$(cat << EOF
{
    "name": "harbor",
    "authorization_flow": "${auth_flow}",
    "client_type": "confidential",
    "client_id": "harbor",
    "client_secret": "${client_secret}",
    "redirect_uris": "${redirect_uri}",
    "signing_key": "${signing_key}",
    "sub_mode": "hashed_user_id",
    "include_claims_in_id_token": true,
    "issuer_mode": "per_provider",
    "access_token_validity": "hours=1",
    "refresh_token_validity": "days=30"
}
EOF
)

    local response
    response=$(authentik_api POST "providers/oauth2/" "$data")

    local provider_pk
    provider_pk=$(echo "$response" | jq -r '.pk // empty')

    if [[ -z "$provider_pk" ]]; then
        log_error "Failed to create Harbor provider"
        echo "$response" | jq .
        return 1
    fi

    log_info "Harbor provider created (pk: $provider_pk)"

    # Create application
    log_info "Creating Harbor application..."

    data=$(cat << EOF
{
    "name": "Harbor Registry",
    "slug": "harbor",
    "provider": ${provider_pk},
    "meta_launch_url": "https://${HARBOR_HOST}",
    "meta_description": "Private Docker Container Registry",
    "policy_engine_mode": "any",
    "open_in_new_tab": true
}
EOF
)

    response=$(authentik_api POST "core/applications/" "$data")

    echo ""
    log_info "=== Harbor OIDC Configuration ==="
    echo "OIDC Endpoint: https://${AUTHENTIK_HOST}/application/o/harbor/"
    echo "Client ID: harbor"
    echo "Client Secret: ${client_secret}"
    echo "Scope: openid profile email groups"
    echo "Redirect URI: ${redirect_uri}"
    echo ""
    log_warn "Save the client secret - it won't be shown again!"
    echo ""
    log_info "Configure in Harbor:"
    echo "  1. Go to Administration > Configuration > Authentication"
    echo "  2. Set Auth Mode to 'OIDC'"
    echo "  3. Enter the OIDC settings above"
}

create_groups() {
    log_info "Creating SSO groups..."

    local groups=("Grafana Admins" "Grafana Editors" "Grafana Viewers" "Harbor Admins" "Harbor Developers" "Harbor Guests")

    for group in "${groups[@]}"; do
        local data
        data=$(cat << EOF
{
    "name": "${group}",
    "is_superuser": false
}
EOF
)
        authentik_api POST "core/groups/" "$data" > /dev/null 2>&1 || true
        log_info "  Created group: ${group}"
    done
}

main() {
    local configure_grafana=false
    local configure_harbor=false
    local list_only=false
    local generate_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --grafana)
                configure_grafana=true
                shift
                ;;
            --harbor)
                configure_harbor=true
                shift
                ;;
            --all)
                configure_grafana=true
                configure_harbor=true
                shift
                ;;
            --list)
                list_only=true
                shift
                ;;
            --generate-secrets)
                generate_only=true
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

    if $generate_only; then
        echo "Grafana Client Secret: $(generate_secret)"
        echo "Harbor Client Secret: $(generate_secret)"
        exit 0
    fi

    check_authentik_token
    check_authentik_health

    if $list_only; then
        list_providers
        echo ""
        list_applications
        exit 0
    fi

    if ! $configure_grafana && ! $configure_harbor; then
        log_error "No provider specified. Use --grafana, --harbor, or --all"
        show_help
        exit 1
    fi

    echo "=========================================="
    echo "  Authentik SSO Configuration"
    echo "=========================================="
    echo "  Authentik: ${AUTHENTIK_HOST}"
    echo "  Grafana:   ${GRAFANA_HOST}"
    echo "  Harbor:    ${HARBOR_HOST}"
    echo "=========================================="

    # Create groups first
    create_groups

    if $configure_grafana; then
        create_grafana_provider
    fi

    if $configure_harbor; then
        create_harbor_provider
    fi

    log_info "SSO configuration complete!"
}

main "$@"
