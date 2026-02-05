#!/bin/bash
set -euo pipefail

# Installer Minio
apt-get update && apt-get install -y curl ca-certificates

# Telecharger le binaire Minio
curl -fsSL https://dl.min.io/server/minio/release/linux-amd64/minio -o /usr/local/bin/minio
chmod +x /usr/local/bin/minio

# Creer utilisateur minio
useradd -r -s /sbin/nologin minio-user || true

# Creer les repertoires
mkdir -p /data/minio
chown -R minio-user:minio-user /data/minio

# Configurer les variables d'environnement
cat > /etc/default/minio <<EOF
MINIO_ROOT_USER=${minio_root_user}
MINIO_ROOT_PASSWORD=${minio_root_password}
MINIO_VOLUMES="/data/minio"
MINIO_OPTS="--address :${minio_port} --console-address :${minio_console_port}"
EOF

# Creer le service systemd
cat > /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO Object Storage
After=network-online.target
Wants=network-online.target

[Service]
User=minio-user
Group=minio-user
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server $${MINIO_VOLUMES} $${MINIO_OPTS}
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now minio

# Attendre que Minio demarre
sleep 5

# Installer mc (Minio Client) pour creer les buckets
curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc
chmod +x /usr/local/bin/mc

# Configurer l'alias via variable d'environnement (evite les credentials en arguments CLI)
export MC_HOST_local="http://${minio_root_user}:${minio_root_password}@127.0.0.1:${minio_port}"

# Creer les buckets avec versioning
%{for bucket in buckets~}
mc mb --ignore-existing local/${bucket}
mc version enable local/${bucket}
%{endfor~}
