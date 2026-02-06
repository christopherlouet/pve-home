#!/bin/bash
# =============================================================================
# Installation de Promtail sur une VM cloud-init
# =============================================================================
# Usage: ./install-promtail.sh [version]
# Exemple: ./install-promtail.sh 3.5.0
#
# Ce script installe Promtail pour envoyer les logs systeme vers Loki.
# La configuration est geree separement via cloud-init.
# =============================================================================

set -euo pipefail

# Configuration
PROMTAIL_VERSION="${1:-3.5.0}"
INSTALL_DIR="/usr/local/bin"
DOWNLOAD_URL="https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
CHECKSUM_URL="https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/SHA256SUMS"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verification root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit etre execute en tant que root"
    exit 1
fi

log_info "=== Installation de Promtail v${PROMTAIL_VERSION} ==="

# Verifier si deja installe avec la bonne version
if command -v promtail &>/dev/null && systemctl is-active --quiet promtail 2>/dev/null; then
    CURRENT_VERSION=$(promtail --version 2>&1 | grep -oP 'version \K[0-9.]+' || echo "unknown")
    if [[ "${CURRENT_VERSION}" == "${PROMTAIL_VERSION}" ]]; then
        log_warn "Promtail v${PROMTAIL_VERSION} est deja installe et actif"
        exit 0
    else
        log_info "Mise a jour de v${CURRENT_VERSION} vers v${PROMTAIL_VERSION}"
        systemctl stop promtail
    fi
fi

# Creer les repertoires
log_info "Creation des repertoires"
mkdir -p /var/lib/promtail
mkdir -p /etc/promtail

# Telecharger et installer
log_info "Telechargement de Promtail v${PROMTAIL_VERSION}"
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

if ! curl -fsSL -o promtail.zip "${DOWNLOAD_URL}"; then
    log_error "Echec du telechargement"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# Verification d'integrite SHA256
log_info "Verification du checksum SHA256"
if curl -fsSL -o SHA256SUMS "${CHECKSUM_URL}"; then
    grep "promtail-linux-amd64.zip" SHA256SUMS > expected.sha256
    if sha256sum -c expected.sha256; then
        log_info "Checksum SHA256 valide"
    else
        log_error "Checksum SHA256 invalide - fichier corrompu"
        rm -rf "${TEMP_DIR}"
        exit 1
    fi
else
    log_warn "Checksum non disponible - verification ignoree"
fi

log_info "Extraction et installation"
unzip -o promtail.zip -d .
mv promtail-linux-amd64 "${INSTALL_DIR}/promtail"
chmod +x "${INSTALL_DIR}/promtail"

# Nettoyage
cd /
rm -rf "${TEMP_DIR}"

# Creer le service systemd
log_info "Configuration du service systemd"
cat > /etc/systemd/system/promtail.service << 'SERVICE'
[Unit]
Description=Promtail Log Collector
Documentation=https://grafana.com/docs/loki/latest/clients/promtail/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=always
RestartSec=10

# Securite
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ReadWritePaths=/var/lib/promtail

[Install]
WantedBy=multi-user.target
SERVICE

# Activer et demarrer Promtail
log_info "Activation et demarrage du service"
systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

# Verification
sleep 2
if systemctl is-active --quiet promtail; then
    log_info "Promtail demarre avec succes"
else
    log_error "Echec du demarrage de Promtail"
    journalctl -u promtail --no-pager -n 20
    exit 1
fi

log_info "=== Installation terminee ==="
