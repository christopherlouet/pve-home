#!/bin/bash
set -e

echo "=== Installing Promtail ==="

# Create directories
mkdir -p /var/lib/promtail
mkdir -p /etc/promtail

# Download Promtail binary
PROMTAIL_VERSION="3.5.0"
curl -fsSL -o /tmp/promtail.zip "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
unzip -o /tmp/promtail.zip -d /tmp
mv /tmp/promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail
rm /tmp/promtail.zip

# Create systemd service
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

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start Promtail
systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

echo "=== Promtail installed and started ==="
