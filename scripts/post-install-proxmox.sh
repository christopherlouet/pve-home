#!/bin/bash
# =============================================================================
# Post-installation de Proxmox VE
# =============================================================================
# Usage: ./post-install-proxmox.sh [options]
#
# Ce script automatise la configuration post-installation de Proxmox VE :
# - Suppression du popup de souscription
# - Configuration des depots APT (no-subscription)
# - Mise a jour systeme
# - Configuration du fuseau horaire
# - Installation des outils utiles
# - Creation de l'utilisateur Terraform avec token API
# - Creation de l'utilisateur Prometheus (optionnel)
# - Activation des snippets cloud-init
# - Telechargement des templates (LXC + VM cloud-init)
# - Verification de l'installation
#
# Supporte PVE 9.x (DEB822 .sources) et PVE 8.x (ancien .list)
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration par defaut
# =============================================================================

TIMEZONE="Europe/Paris"
VM_TEMPLATE_ID="9000"
SKIP_REBOOT=false
AUTO_YES=false
NO_PROMETHEUS=false
NO_TEMPLATE_VM=false

# URLs et noms de templates
UBUNTU_CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
UBUNTU_CLOUD_IMAGE_NAME="noble-server-cloudimg-amd64.img"
LXC_TEMPLATES=(
    "ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    "debian-12-standard_12.12-1_amd64.tar.zst"
)

# Variables pour le resume final
TERRAFORM_TOKEN=""
PROMETHEUS_TOKEN=""
NEEDS_REBOOT=false

# =============================================================================
# Couleurs et fonctions de log
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Fonctions utilitaires
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: post-install-proxmox.sh [options]

Script de post-installation pour Proxmox VE (8.x et 9.x).
Automatise la configuration des depots, utilisateurs, templates et outils.

Options:
  -y, --yes              Mode non-interactif (accepter toutes les confirmations)
  --skip-reboot          Ne pas redemarrer apres la mise a jour systeme
  --timezone ZONE        Fuseau horaire (defaut: Europe/Paris)
  --vm-template-id ID    ID du template VM cloud-init (defaut: 9000)
  --no-prometheus        Ne pas creer l'utilisateur Prometheus
  --no-template-vm       Ne pas creer le template VM cloud-init
  -h, --help             Afficher cette aide

Exemples:
  ./post-install-proxmox.sh                    # Mode interactif
  ./post-install-proxmox.sh --yes              # Tout accepter automatiquement
  ./post-install-proxmox.sh --timezone UTC     # Fuseau horaire UTC
  ./post-install-proxmox.sh --no-prometheus    # Sans utilisateur Prometheus
HELPEOF
}

confirm() {
    local message="$1"
    if [[ "$AUTO_YES" == true ]]; then
        log_info "$message"
        return 0
    fi
    echo -en "${BLUE}[?]${NC} $message [O/n] "
    read -r response
    case "$response" in
        [nN]|[nN][oO]) return 1 ;;
        *) return 0 ;;
    esac
}

detect_pve_version() {
    if ! command -v pveversion &>/dev/null; then
        log_error "Ce script doit etre execute sur un node Proxmox VE"
        log_error "La commande 'pveversion' est introuvable"
        exit 1
    fi

    local pve_full
    pve_full=$(pveversion | sed 's/.*pve-manager\/\([0-9]*\.[0-9]*\).*/\1/')
    PVE_MAJOR="${pve_full%%.*}"

    if [[ "$PVE_MAJOR" -ge 9 ]]; then
        PVE_CODENAME="trixie"
        PVE_REPO_FORMAT="deb822"
    elif [[ "$PVE_MAJOR" -ge 8 ]]; then
        PVE_CODENAME="bookworm"
        PVE_REPO_FORMAT="list"
    else
        log_error "Version Proxmox VE ${pve_full} non supportee (minimum 8.x)"
        exit 1
    fi

    log_info "Proxmox VE ${pve_full} detecte (${PVE_CODENAME}, format ${PVE_REPO_FORMAT})"
}

# =============================================================================
# Parsing des options
# =============================================================================

parse_options() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            --skip-reboot)
                SKIP_REBOOT=true
                shift
                ;;
            --timezone)
                TIMEZONE="${2:?--timezone necessite une valeur}"
                shift 2
                ;;
            --vm-template-id)
                VM_TEMPLATE_ID="${2:?--vm-template-id necessite une valeur}"
                shift 2
                ;;
            --no-prometheus)
                NO_PROMETHEUS=true
                shift
                ;;
            --no-template-vm)
                NO_TEMPLATE_VM=true
                shift
                ;;
            *)
                log_error "Option inconnue : $1"
                echo "Utilisez --help pour voir les options disponibles"
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Fonctions metier
# =============================================================================

remove_subscription_popup() {
    log_info "=== Suppression du popup de souscription ==="

    local target="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

    if [[ ! -f "$target" ]]; then
        log_warn "Fichier proxmoxlib.js introuvable, etape ignoree"
        return 0
    fi

    if grep -q 'void({' "$target" 2>/dev/null; then
        log_success "Popup deja desactive"
        return 0
    fi

    if ! confirm "Supprimer le popup de souscription ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    cp "$target" "${target}.bak"
    sed -Ezi "s/(Ext\.Msg\.show\(\{.+?title: 'No valid subscription)/void({ \/\/ \1/g" "$target"
    systemctl restart pveproxy.service
    log_success "Popup de souscription desactive"
}

configure_repositories() {
    log_info "=== Configuration des depots APT ==="

    if ! confirm "Configurer les depots no-subscription ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    if [[ "$PVE_REPO_FORMAT" == "deb822" ]]; then
        _configure_repos_deb822
    else
        _configure_repos_list
    fi

    log_success "Depots APT configures"
}

_configure_repos_deb822() {
    # Desactiver le depot enterprise PVE
    local pve_enterprise="/etc/apt/sources.list.d/pve-enterprise.sources"
    if [[ -f "$pve_enterprise" ]]; then
        mv "$pve_enterprise" "${pve_enterprise}.disabled"
        log_info "Depot enterprise PVE desactive"
    fi

    # Desactiver le depot enterprise Ceph
    local ceph_enterprise="/etc/apt/sources.list.d/ceph.sources"
    if [[ -f "$ceph_enterprise" ]]; then
        mv "$ceph_enterprise" "${ceph_enterprise}.disabled"
        log_info "Depot enterprise Ceph desactive"
    fi

    # Ajouter le depot no-subscription PVE
    local pve_nosub="/etc/apt/sources.list.d/pve-no-subscription.sources"
    if [[ -f "$pve_nosub" ]]; then
        log_success "Depot no-subscription PVE deja present"
    else
        cat > "$pve_nosub" << EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: ${PVE_CODENAME}
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
        log_info "Depot no-subscription PVE ajoute"
    fi
}

_configure_repos_list() {
    # Desactiver le depot enterprise PVE (ancien format)
    local pve_enterprise="/etc/apt/sources.list.d/pve-enterprise.list"
    if [[ -f "$pve_enterprise" ]] && grep -q '^deb' "$pve_enterprise"; then
        cp "$pve_enterprise" "${pve_enterprise}.bak"
        sed -i 's/^deb/#deb/' "$pve_enterprise"
        log_info "Depot enterprise PVE desactive"
    fi

    # Ajouter le depot no-subscription PVE
    local pve_nosub="/etc/apt/sources.list.d/pve-no-subscription.list"
    if [[ -f "$pve_nosub" ]]; then
        log_success "Depot no-subscription PVE deja present"
    else
        echo "deb http://download.proxmox.com/debian/pve ${PVE_CODENAME} pve-no-subscription" > "$pve_nosub"
        log_info "Depot no-subscription PVE ajoute"
    fi
}

update_system() {
    log_info "=== Mise a jour du systeme ==="

    if ! confirm "Mettre a jour le systeme (apt update && apt full-upgrade) ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    apt update
    apt full-upgrade -y
    log_success "Systeme mis a jour"
    NEEDS_REBOOT=true
}

configure_timezone() {
    log_info "=== Configuration du fuseau horaire ==="

    local current_tz
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")

    if [[ "$current_tz" == "$TIMEZONE" ]]; then
        log_success "Fuseau horaire deja configure sur $TIMEZONE"
        return 0
    fi

    if ! confirm "Configurer le fuseau horaire sur $TIMEZONE ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    timedatectl set-timezone "$TIMEZONE"
    log_success "Fuseau horaire configure sur $TIMEZONE"
}

install_tools() {
    log_info "=== Installation des outils utiles ==="

    local tools=(vim htop iotop curl wget net-tools sudo fail2ban)
    local missing=()

    for tool in "${tools[@]}"; do
        if ! dpkg -l "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_success "Tous les outils sont deja installes"
        return 0
    fi

    if ! confirm "Installer les outils manquants : ${missing[*]} ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    apt install -y "${missing[@]}"
    log_success "Outils installes : ${missing[*]}"
}

create_terraform_user() {
    log_info "=== Creation de l'utilisateur Terraform ==="

    if pveum user list 2>/dev/null | grep -q 'terraform@pve'; then
        log_success "Utilisateur terraform@pve existe deja"
        log_warn "Token existant non affichable. Si vous l'avez perdu, supprimez et recreez l'utilisateur."
        return 0
    fi

    if ! confirm "Creer l'utilisateur Terraform avec token API ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    # Creer l'utilisateur
    pveum user add terraform@pve --comment "Terraform automation"

    # Creer le role avec les permissions necessaires
    if ! pveum role list 2>/dev/null | grep -q 'TerraformRole'; then
        pveum role add TerraformRole -privs \
            "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.GuestAgent.Audit VM.Migrate VM.PowerMgmt User.Modify"
    fi

    # Assigner le role
    pveum aclmod / -user terraform@pve -role TerraformRole

    # Creer le token API et capturer la sortie complete
    local token_output
    token_output=$(pveum user token add terraform@pve terraform-token --privsep=0 2>&1)

    # Extraire le token (format: "│ value        │ xxxxxxxx-xxxx-... │")
    # On cherche la ligne contenant une valeur UUID apres "value"
    TERRAFORM_TOKEN=$(echo "$token_output" | grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')

    log_success "Utilisateur terraform@pve cree"
    echo ""
    echo "$token_output"
    echo ""
    if [[ -n "$TERRAFORM_TOKEN" ]]; then
        log_info "Token complet : terraform@pve!terraform-token=${TERRAFORM_TOKEN}"
    else
        log_warn "Impossible d'extraire le token automatiquement. Copiez-le depuis la sortie ci-dessus."
    fi
    echo ""
    log_warn "IMPORTANT : Notez ce token, il ne sera plus affichable ensuite !"
    echo ""
}

create_prometheus_user() {
    if [[ "$NO_PROMETHEUS" == true ]]; then
        log_info "=== Utilisateur Prometheus : ignore (--no-prometheus) ==="
        return 0
    fi

    log_info "=== Creation de l'utilisateur Prometheus ==="

    if pveum user list 2>/dev/null | grep -q 'prometheus@pve'; then
        log_success "Utilisateur prometheus@pve existe deja"
        return 0
    fi

    if ! confirm "Creer l'utilisateur Prometheus (monitoring, lecture seule) ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    pveum user add prometheus@pve --comment "Prometheus monitoring"
    pveum aclmod / -user prometheus@pve -role PVEAuditor

    local token_output
    token_output=$(pveum user token add prometheus@pve prometheus --privsep=0 2>&1)

    PROMETHEUS_TOKEN=$(echo "$token_output" | grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')

    log_success "Utilisateur prometheus@pve cree"
    echo ""
    echo "$token_output"
    echo ""
    if [[ -n "$PROMETHEUS_TOKEN" ]]; then
        log_info "Token complet : prometheus@pve!prometheus=${PROMETHEUS_TOKEN}"
    else
        log_warn "Impossible d'extraire le token automatiquement. Copiez-le depuis la sortie ci-dessus."
    fi
    echo ""
    log_warn "IMPORTANT : Notez ce token, il ne sera plus affichable ensuite !"
    echo ""
}

enable_snippets() {
    log_info "=== Activation des snippets cloud-init ==="

    local content
    content=$(pvesm status 2>/dev/null || echo "")

    if echo "$content" | grep -q 'snippets'; then
        log_success "Snippets deja actives"
        return 0
    fi

    if ! confirm "Activer les snippets cloud-init sur le storage local ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    mkdir -p /var/lib/vz/snippets
    pvesm set local --content backup,iso,vztmpl,snippets
    log_success "Snippets cloud-init actives sur le storage local"
}

download_templates() {
    log_info "=== Telechargement des templates ==="

    _download_lxc_templates
    _create_vm_template
}

_download_lxc_templates() {
    log_info "--- Templates LXC ---"

    if ! confirm "Telecharger les templates LXC ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    pveam update

    for template in "${LXC_TEMPLATES[@]}"; do
        if pveam list local 2>/dev/null | grep -q "$template"; then
            log_success "Template LXC deja present : $template"
        else
            log_info "Telechargement de $template..."
            if pveam download local "$template"; then
                log_success "Template LXC telecharge : $template"
            else
                log_warn "Echec du telechargement de $template (disponibilite peut varier selon la version PVE)"
            fi
        fi
    done
}

_create_vm_template() {
    if [[ "$NO_TEMPLATE_VM" == true ]]; then
        log_info "--- Template VM cloud-init : ignore (--no-template-vm) ---"
        return 0
    fi

    log_info "--- Template VM cloud-init (ID ${VM_TEMPLATE_ID}) ---"

    # Verifier si le template existe deja
    if qm status "$VM_TEMPLATE_ID" &>/dev/null; then
        log_success "Template VM ID ${VM_TEMPLATE_ID} existe deja"
        return 0
    fi

    if ! confirm "Creer le template VM cloud-init (ID ${VM_TEMPLATE_ID}) ?"; then
        log_warn "Etape ignoree"
        return 0
    fi

    # Verifier que local-lvm existe
    if ! pvesm status 2>/dev/null | grep -q 'local-lvm'; then
        log_error "Storage local-lvm introuvable. Verifiez votre configuration de stockage."
        return 1
    fi

    # Verifier l'espace disque (~700 MB necessaires)
    local available_mb
    available_mb=$(df -BM /var/lib/vz/template/iso 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'M')
    if [[ -n "$available_mb" ]] && [[ "$available_mb" -lt 1000 ]]; then
        log_error "Espace disque insuffisant (${available_mb}M disponible, 1000M recommande)"
        return 1
    fi

    # Telecharger l'image cloud Ubuntu
    local iso_dir="/var/lib/vz/template/iso"
    mkdir -p "$iso_dir"

    if [[ -f "${iso_dir}/${UBUNTU_CLOUD_IMAGE_NAME}" ]]; then
        log_success "Image cloud deja telechargee"
    else
        log_info "Telechargement de l'image cloud Ubuntu (~700 MB)..."
        if ! wget -q --show-progress -O "${iso_dir}/${UBUNTU_CLOUD_IMAGE_NAME}" "$UBUNTU_CLOUD_IMAGE_URL"; then
            log_error "Echec du telechargement de l'image cloud"
            log_error "URL : $UBUNTU_CLOUD_IMAGE_URL"
            return 1
        fi
        log_success "Image cloud telechargee"
    fi

    # Creer la VM template
    log_info "Creation de la VM template..."
    qm create "$VM_TEMPLATE_ID" \
        --name "ubuntu-cloud-template" \
        --memory 2048 \
        --cores 2 \
        --net0 virtio,bridge=vmbr0

    qm importdisk "$VM_TEMPLATE_ID" "${iso_dir}/${UBUNTU_CLOUD_IMAGE_NAME}" local-lvm
    qm set "$VM_TEMPLATE_ID" --scsihw virtio-scsi-pci --scsi0 "local-lvm:vm-${VM_TEMPLATE_ID}-disk-0"
    qm set "$VM_TEMPLATE_ID" --ide2 local-lvm:cloudinit
    qm set "$VM_TEMPLATE_ID" --boot c --bootdisk scsi0
    qm set "$VM_TEMPLATE_ID" --serial0 socket --vga serial0
    qm set "$VM_TEMPLATE_ID" --agent enabled=1
    qm template "$VM_TEMPLATE_ID"

    log_success "Template VM cloud-init cree (ID ${VM_TEMPLATE_ID})"
}

verify_installation() {
    log_info "=== Verification de l'installation ==="

    local errors=0

    # Services Proxmox
    if systemctl is-active --quiet pvedaemon && systemctl is-active --quiet pveproxy; then
        log_success "Services Proxmox actifs (pvedaemon, pveproxy)"
    else
        log_error "Services Proxmox inactifs"
        errors=$((errors + 1))
    fi

    # Stockage
    if pvesm status &>/dev/null; then
        log_success "Stockage accessible"
    else
        log_error "Probleme d'acces au stockage"
        errors=$((errors + 1))
    fi

    # Templates
    local template_count
    template_count=$(pveam list local 2>/dev/null | wc -l)
    if [[ "$template_count" -gt 1 ]]; then
        log_success "Templates disponibles : $((template_count - 1))"
    else
        log_warn "Aucun template trouve"
    fi

    # API
    if curl -sk "https://127.0.0.1:8006/api2/json/" &>/dev/null; then
        log_success "API Proxmox accessible"
    else
        log_error "API Proxmox inaccessible"
        errors=$((errors + 1))
    fi

    if [[ "$errors" -gt 0 ]]; then
        log_error "${errors} verification(s) en echec"
        return 1
    fi

    log_success "Toutes les verifications sont passees"
}

# =============================================================================
# Resume final
# =============================================================================

show_summary() {
    echo ""
    echo "============================================================================="
    echo " RESUME FINAL - Informations a noter"
    echo "============================================================================="
    echo ""

    local hostname_ip
    hostname_ip=$(hostname -I 2>/dev/null | awk '{print $1}')

    echo "  URL Proxmox :          https://${hostname_ip:-<IP>}:8006"
    echo "  Node name :            $(hostname)"
    echo "  Fuseau horaire :       $TIMEZONE"
    echo ""

    if [[ -n "$TERRAFORM_TOKEN" ]]; then
        echo "  Token Terraform :      terraform@pve!terraform-token=${TERRAFORM_TOKEN}"
    else
        echo "  Token Terraform :      (deja existant ou etape ignoree)"
    fi

    if [[ -n "$PROMETHEUS_TOKEN" ]]; then
        echo "  Token Prometheus :     prometheus@pve!prometheus=${PROMETHEUS_TOKEN}"
    elif [[ "$NO_PROMETHEUS" == true ]]; then
        echo "  Token Prometheus :     (non configure, --no-prometheus)"
    else
        echo "  Token Prometheus :     (deja existant ou etape ignoree)"
    fi

    echo ""
    echo "  Template VM ID :       ${VM_TEMPLATE_ID}"
    echo "  Bridge reseau :        vmbr0"
    echo "  Datastore :            local-lvm"
    echo ""
    echo "============================================================================="
    echo " Prochaine etape : configurez Terraform dans infrastructure/proxmox/"
    echo "============================================================================="
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_options "$@"

    echo ""
    log_info "============================================="
    log_info " Post-installation Proxmox VE"
    log_info "============================================="
    echo ""

    # Verification environnement
    detect_pve_version

    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit etre execute en tant que root"
        exit 1
    fi

    # Execution des etapes
    remove_subscription_popup
    configure_repositories
    update_system
    configure_timezone
    install_tools
    create_terraform_user
    create_prometheus_user
    enable_snippets
    download_templates
    verify_installation

    # Resume
    show_summary

    log_success "Post-installation terminee !"

    # Reboot en dernier, apres le resume
    if [[ "$NEEDS_REBOOT" == true ]]; then
        if [[ "$SKIP_REBOOT" == true ]]; then
            log_warn "Un redemarrage est recommande (--skip-reboot actif). Pensez a redemarrer manuellement."
        else
            echo ""
            if confirm "Redemarrer maintenant ? (recommande apres une mise a jour du noyau)"; then
                log_info "Redemarrage dans 5 secondes... (Ctrl+C pour annuler)"
                sleep 5
                reboot
            else
                log_warn "Pensez a redemarrer manuellement."
            fi
        fi
    fi
}

main "$@"
