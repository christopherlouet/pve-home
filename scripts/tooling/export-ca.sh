#!/usr/bin/env bash
# =============================================================================
# Export Step-ca Root CA Certificate
# =============================================================================
# Exports the root CA certificate in various formats for distribution
# Usage: ./export-ca.sh [--pem|--der|--p12] [output_dir]
# =============================================================================

set -euo pipefail

# Configuration
STEP_CA_HOST="${STEP_CA_HOST:-pki.home.arpa}"
STEP_CA_PORT="${STEP_CA_PORT:-8443}"
OUTPUT_DIR="${2:-./ca-certs}"
CA_NAME="homelab-ca"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

show_help() {
    cat << EOF
Export Step-ca Root CA Certificate

Usage: $(basename "$0") [OPTIONS] [OUTPUT_DIR]

Options:
    --pem       Export in PEM format (default)
    --der       Export in DER format
    --p12       Export in PKCS#12 format (requires password)
    --all       Export in all formats
    -h, --help  Show this help message

Environment Variables:
    STEP_CA_HOST    Step-ca hostname (default: pki.home.arpa)
    STEP_CA_PORT    Step-ca port (default: 8443)

Examples:
    $(basename "$0") --pem ./certs
    $(basename "$0") --all /tmp/ca-export
    STEP_CA_HOST=192.168.1.60 $(basename "$0") --der
EOF
}

check_dependencies() {
    local deps=("curl" "openssl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' not found"
            exit 1
        fi
    done
}

fetch_root_cert() {
    log_info "Fetching root CA certificate from ${STEP_CA_HOST}:${STEP_CA_PORT}..."

    local url="https://${STEP_CA_HOST}:${STEP_CA_PORT}/roots.pem"

    if ! curl -sS --insecure "$url" -o "${OUTPUT_DIR}/${CA_NAME}.pem" 2>/dev/null; then
        log_error "Failed to fetch certificate from $url"
        log_warn "Trying alternative method with step CLI..."

        if command -v step &> /dev/null; then
            step ca root "${OUTPUT_DIR}/${CA_NAME}.pem" \
                --ca-url "https://${STEP_CA_HOST}:${STEP_CA_PORT}" \
                --insecure
        else
            log_error "Neither curl nor step CLI could fetch the certificate"
            exit 1
        fi
    fi

    log_info "Root CA certificate saved to ${OUTPUT_DIR}/${CA_NAME}.pem"
}

export_pem() {
    if [[ ! -f "${OUTPUT_DIR}/${CA_NAME}.pem" ]]; then
        fetch_root_cert
    fi
    log_info "PEM format ready: ${OUTPUT_DIR}/${CA_NAME}.pem"
}

export_der() {
    if [[ ! -f "${OUTPUT_DIR}/${CA_NAME}.pem" ]]; then
        fetch_root_cert
    fi

    log_info "Converting to DER format..."
    openssl x509 -in "${OUTPUT_DIR}/${CA_NAME}.pem" \
        -outform DER \
        -out "${OUTPUT_DIR}/${CA_NAME}.der"
    log_info "DER format saved: ${OUTPUT_DIR}/${CA_NAME}.der"
}

export_p12() {
    if [[ ! -f "${OUTPUT_DIR}/${CA_NAME}.pem" ]]; then
        fetch_root_cert
    fi

    log_info "Converting to PKCS#12 format..."

    read -rsp "Enter password for PKCS#12 file: " p12_password
    echo

    openssl pkcs12 -export \
        -nokeys \
        -in "${OUTPUT_DIR}/${CA_NAME}.pem" \
        -out "${OUTPUT_DIR}/${CA_NAME}.p12" \
        -password "pass:${p12_password}"

    log_info "PKCS#12 format saved: ${OUTPUT_DIR}/${CA_NAME}.p12"
}

show_fingerprint() {
    if [[ -f "${OUTPUT_DIR}/${CA_NAME}.pem" ]]; then
        log_info "CA Certificate fingerprint (SHA256):"
        openssl x509 -in "${OUTPUT_DIR}/${CA_NAME}.pem" -noout -fingerprint -sha256
    fi
}

show_install_instructions() {
    cat << EOF

${GREEN}=== Installation Instructions ===${NC}

${YELLOW}Linux (Debian/Ubuntu):${NC}
  sudo cp ${OUTPUT_DIR}/${CA_NAME}.pem /usr/local/share/ca-certificates/${CA_NAME}.crt
  sudo update-ca-certificates

${YELLOW}Linux (RHEL/CentOS/Fedora):${NC}
  sudo cp ${OUTPUT_DIR}/${CA_NAME}.pem /etc/pki/ca-trust/source/anchors/${CA_NAME}.pem
  sudo update-ca-trust

${YELLOW}macOS:${NC}
  sudo security add-trusted-cert -d -r trustRoot \\
    -k /Library/Keychains/System.keychain ${OUTPUT_DIR}/${CA_NAME}.pem

${YELLOW}Windows (PowerShell as Admin):${NC}
  Import-Certificate -FilePath ${OUTPUT_DIR}/${CA_NAME}.der \\
    -CertStoreLocation Cert:\\LocalMachine\\Root

${YELLOW}Docker daemon:${NC}
  # Copy to /etc/docker/certs.d/registry.home.arpa/ca.crt
  # Or add to daemon.json

${YELLOW}Firefox (manual):${NC}
  Settings > Privacy & Security > Certificates > View Certificates
  Import ${OUTPUT_DIR}/${CA_NAME}.pem

${YELLOW}Chrome/Edge (uses system store):${NC}
  Install to system as shown above

EOF
}

main() {
    local format="pem"
    local all_formats=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --pem)
                format="pem"
                shift
                ;;
            --der)
                format="der"
                shift
                ;;
            --p12)
                format="p12"
                shift
                ;;
            --all)
                all_formats=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "${2:-}" ]]; then
                    OUTPUT_DIR="$1"
                fi
                shift
                ;;
        esac
    done

    check_dependencies

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    if $all_formats; then
        export_pem
        export_der
        export_p12
    else
        case $format in
            pem) export_pem ;;
            der) export_der ;;
            p12) export_p12 ;;
        esac
    fi

    show_fingerprint
    show_install_instructions

    log_info "Export complete!"
}

main "$@"
