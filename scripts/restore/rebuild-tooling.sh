#!/usr/bin/env bash
# =============================================================================
# Rebuild Tooling Stack
# =============================================================================
# Script de reconstruction de la stack tooling apres sinistre.
# Prerequis: Terraform, acces Proxmox, terraform.tfvars configure
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${PROJECT_ROOT}/infrastructure/proxmox/environments/monitoring"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Fonctions
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Verification des prerequis..."

    # Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform n'est pas installe"
        exit 1
    fi
    log_success "Terraform: $(terraform version -json | jq -r '.terraform_version')"

    # Fichier tfvars
    if [[ ! -f "${TF_DIR}/terraform.tfvars" ]]; then
        log_error "Fichier terraform.tfvars manquant"
        log_info "Copier terraform.tfvars.example et configurer les valeurs"
        exit 1
    fi
    log_success "terraform.tfvars present"

    # Verifier que tooling.enabled = true
    if ! grep -q 'enabled\s*=\s*true' "${TF_DIR}/terraform.tfvars" 2>/dev/null; then
        log_warning "tooling.enabled n'est pas defini a true dans terraform.tfvars"
    fi
}

init_terraform() {
    log_info "Initialisation Terraform..."
    cd "${TF_DIR}"
    terraform init -upgrade
    log_success "Terraform initialise"
}

plan_tooling() {
    log_info "Generation du plan Terraform..."
    cd "${TF_DIR}"
    terraform plan -target=module.tooling -out=tfplan-tooling
    log_success "Plan genere: tfplan-tooling"
}

apply_tooling() {
    log_info "Application du plan Terraform..."
    cd "${TF_DIR}"
    terraform apply tfplan-tooling
    log_success "Stack tooling deployee"
}

show_status() {
    log_info "Status de la stack tooling..."
    cd "${TF_DIR}"

    # Afficher les outputs
    echo ""
    echo "=== Informations de connexion ==="
    terraform output -json tooling 2>/dev/null | jq -r '
        if . != null then
            "VM ID: \(.vm_id)",
            "VM Name: \(.vm_name)",
            "IP: \(.ip)",
            "",
            "URLs:",
            "  Step-ca: \(.urls.step_ca // "disabled")",
            "  Harbor: \(.urls.harbor // "disabled")",
            "  Authentik: \(.urls.authentik // "disabled")",
            "  Traefik: \(.urls.traefik // "disabled")",
            "",
            "SSH: \(.ssh)"
        else
            "Stack tooling non deployee"
        end
    '

    # Instructions CA
    echo ""
    echo "=== Installation du certificat CA ==="
    terraform output -raw tooling_ca_instructions 2>/dev/null || echo "Step-ca non active"
}

wait_for_services() {
    log_info "Attente du demarrage des services..."

    local tooling_ip
    tooling_ip=$(cd "${TF_DIR}" && terraform output -json tooling 2>/dev/null | jq -r '.ip // empty')

    if [[ -z "${tooling_ip}" ]]; then
        log_warning "Impossible de recuperer l'IP de la VM tooling"
        return
    fi

    local max_attempts=30
    local attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "Tentative ${attempt}/${max_attempts}..."

        if curl -s -o /dev/null -w "%{http_code}" "http://${tooling_ip}:8082/ping" 2>/dev/null | grep -q "200"; then
            log_success "Traefik repond"
            break
        fi

        sleep 10
        ((attempt++))
    done

    if [[ ${attempt} -gt ${max_attempts} ]]; then
        log_warning "Timeout - verifier manuellement les services"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    echo "============================================="
    echo "  Reconstruction Stack Tooling"
    echo "============================================="
    echo ""

    case "${1:-all}" in
        check)
            check_prerequisites
            ;;
        init)
            check_prerequisites
            init_terraform
            ;;
        plan)
            check_prerequisites
            init_terraform
            plan_tooling
            ;;
        apply)
            check_prerequisites
            init_terraform
            plan_tooling
            apply_tooling
            wait_for_services
            show_status
            ;;
        status)
            show_status
            ;;
        all)
            check_prerequisites
            init_terraform
            plan_tooling

            echo ""
            read -p "Appliquer le plan? [y/N] " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                apply_tooling
                wait_for_services
                show_status
            else
                log_info "Application annulee"
            fi
            ;;
        *)
            echo "Usage: $0 [check|init|plan|apply|status|all]"
            echo ""
            echo "Commands:"
            echo "  check   - Verifier les prerequis"
            echo "  init    - Initialiser Terraform"
            echo "  plan    - Generer le plan de deploiement"
            echo "  apply   - Appliquer le plan (deployer)"
            echo "  status  - Afficher le status actuel"
            echo "  all     - Executer tout (defaut)"
            exit 1
            ;;
    esac
}

main "$@"
