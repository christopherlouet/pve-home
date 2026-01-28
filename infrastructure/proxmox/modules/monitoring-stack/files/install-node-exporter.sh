#!/bin/bash
# =============================================================================
# Installation de Node Exporter sur un host Proxmox
# =============================================================================
# Usage: ./install-node-exporter.sh [version]
# Exemple: ./install-node-exporter.sh 1.8.2
#
# Ce script installe node_exporter directement sur l'host Proxmox
# pour collecter les metriques systeme (CPU, RAM, disque, reseau)
# =============================================================================

set -euo pipefail

# Configuration
NODE_EXPORTER_VERSION="${1:-1.8.2}"
NODE_EXPORTER_PORT="${2:-9100}"
NODE_EXPORTER_USER="node_exporter"
INSTALL_DIR="/opt/node_exporter"
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

log_info "=== Installation de Node Exporter v${NODE_EXPORTER_VERSION} ==="

# Verifier si deja installe
if systemctl is-active --quiet node_exporter 2>/dev/null; then
    CURRENT_VERSION=$("${INSTALL_DIR}/node_exporter" --version 2>&1 | head -1 | awk '{print $3}')
    if [[ "${CURRENT_VERSION}" == "${NODE_EXPORTER_VERSION}" ]]; then
        log_warn "Node Exporter v${NODE_EXPORTER_VERSION} est deja installe et actif"
        exit 0
    else
        log_info "Mise a jour de v${CURRENT_VERSION} vers v${NODE_EXPORTER_VERSION}"
        systemctl stop node_exporter
    fi
fi

# Creer l'utilisateur systeme
if ! id "${NODE_EXPORTER_USER}" &>/dev/null; then
    log_info "Creation de l'utilisateur ${NODE_EXPORTER_USER}"
    useradd --system --no-create-home --shell /bin/false "${NODE_EXPORTER_USER}"
fi

# Telecharger et installer
log_info "Telechargement de Node Exporter v${NODE_EXPORTER_VERSION}"
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

if ! wget -q "${DOWNLOAD_URL}" -O node_exporter.tar.gz; then
    log_error "Echec du telechargement"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

log_info "Extraction et installation"
tar xzf node_exporter.tar.gz
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" "${INSTALL_DIR}/"
chown -R "${NODE_EXPORTER_USER}:${NODE_EXPORTER_USER}" "${INSTALL_DIR}"

# Nettoyage
cd /
rm -rf "${TEMP_DIR}"

# Creer le service systemd
log_info "Configuration du service systemd"
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${NODE_EXPORTER_USER}
Group=${NODE_EXPORTER_USER}
ExecStart=${INSTALL_DIR}/node_exporter \\
    --web.listen-address=:${NODE_EXPORTER_PORT} \\
    --collector.filesystem.mount-points-exclude="^/(sys|proc|dev|run)(\$|/)" \\
    --collector.netclass.ignored-devices="^(veth|docker|br-).*" \\
    --collector.textfile.directory=/var/lib/node_exporter/textfile_collector

Restart=always
RestartSec=5

# Securite
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes

[Install]
WantedBy=multi-user.target
EOF

# Creer le repertoire pour les textfile collectors
mkdir -p /var/lib/node_exporter/textfile_collector
chown -R "${NODE_EXPORTER_USER}:${NODE_EXPORTER_USER}" /var/lib/node_exporter

# Activer et demarrer le service
log_info "Activation et demarrage du service"
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Verification
sleep 2
if systemctl is-active --quiet node_exporter; then
    log_info "Node Exporter demarre avec succes"
    log_info "Metriques disponibles sur: http://$(hostname -I | awk '{print $1}'):${NODE_EXPORTER_PORT}/metrics"
else
    log_error "Echec du demarrage de Node Exporter"
    journalctl -u node_exporter --no-pager -n 20
    exit 1
fi

# Test de connectivite
if curl -s "http://localhost:${NODE_EXPORTER_PORT}/metrics" | head -1 | grep -q "HELP"; then
    log_info "Test de connectivite: OK"
else
    log_warn "Test de connectivite: echec (verifier le firewall)"
fi

log_info "=== Installation terminee ==="
echo ""
echo "Pour verifier: curl http://localhost:${NODE_EXPORTER_PORT}/metrics | head"
echo "Pour les logs: journalctl -u node_exporter -f"
