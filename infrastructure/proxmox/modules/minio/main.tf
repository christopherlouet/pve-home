# =============================================================================
# Module Minio S3 - Homelab
# =============================================================================
# Deploie un conteneur LXC avec Minio S3 pour le stockage de l'etat Terraform.
# Minio est installe via cloud-init et configure comme service systemd.
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  minio_ip = split("/", var.ip_address)[0]

  # Script d'installation Minio
  install_script = <<-SCRIPT
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
    MINIO_ROOT_USER=${var.minio_root_user}
    MINIO_ROOT_PASSWORD=${var.minio_root_password}
    MINIO_VOLUMES="/data/minio"
    MINIO_OPTS="--address :${var.minio_port} --console-address :${var.minio_console_port}"
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
    ExecStart=/usr/local/bin/minio server \$MINIO_VOLUMES \$MINIO_OPTS
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

    # Configurer l'alias
    mc alias set local http://127.0.0.1:${var.minio_port} ${var.minio_root_user} ${var.minio_root_password}

    # Creer les buckets avec versioning
    %{for bucket in var.buckets~}
    mc mb --ignore-existing local/${bucket}
    mc version enable local/${bucket}
    %{endfor~}
  SCRIPT
}

# -----------------------------------------------------------------------------
# Conteneur LXC Minio
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_container" "minio" {
  description   = var.description
  node_name     = var.target_node
  vm_id         = var.container_id
  tags          = var.tags
  unprivileged  = true
  start_on_boot = var.start_on_boot
  started       = true

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = 256
  }

  # Disque systeme
  disk {
    datastore_id = var.datastore
    size         = var.disk_size_gb
  }

  # Disque donnees Minio
  mount_point {
    volume = "${var.datastore}:${var.data_disk_size_gb}"
    path   = "/data"
    size   = var.data_disk_size_gb
  }

  network_interface {
    name    = "eth0"
    bridge  = var.network_bridge
    vlan_id = var.vlan_id
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = var.ssh_keys
    }
  }

  lifecycle {
    ignore_changes = [
      initialization,
      disk[0].size,
    ]
  }
}

# -----------------------------------------------------------------------------
# Provisioning Minio
# -----------------------------------------------------------------------------

resource "terraform_data" "minio_install" {
  depends_on = [proxmox_virtual_environment_container.minio]

  triggers_replace = [
    var.minio_root_user,
    join(",", var.buckets),
  ]

  provisioner "remote-exec" {
    inline = [local.install_script]

    connection {
      type    = "ssh"
      host    = local.minio_ip
      user    = "root"
      timeout = "5m"
      agent   = true
    }
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "endpoint_url" {
  description = "URL de l'API S3 Minio"
  value       = "http://${local.minio_ip}:${var.minio_port}"
}

output "console_url" {
  description = "URL de la console Minio"
  value       = "http://${local.minio_ip}:${var.minio_console_port}"
}

output "container_id" {
  description = "ID du conteneur LXC"
  value       = proxmox_virtual_environment_container.minio.vm_id
}

output "ip_address" {
  description = "Adresse IP du conteneur"
  value       = var.ip_address
}
