# =============================================================================
# Module Tooling Stack - Main
# =============================================================================
# Stack d'outillage: Step-ca (PKI) + Harbor (Registry) + Authentik (SSO)
# Deploye sur une VM dediee avec Docker Compose
#
# Configuration des services repartie dans:
#   stepca.tf    - Certificat racine CA et configuration Step-ca
#   harbor.tf    - Configuration Harbor et secrets DB
#   authentik.tf - Configuration Authentik et providers OAuth/OIDC
#   traefik.tf   - Configuration reverse proxy et routes
#   docker.tf    - Listes services et volumes Docker Compose
# =============================================================================

# -----------------------------------------------------------------------------
# Cloud-init Configuration
# -----------------------------------------------------------------------------

locals {
  # Services configuration for cloud-init
  services_config = {
    step_ca = {
      enabled          = var.step_ca_enabled
      password         = var.step_ca_password
      provisioner_name = var.step_ca_provisioner_name
      cert_duration    = var.step_ca_cert_duration
      root_cn          = var.step_ca_root_cn
    }
    harbor = {
      enabled        = var.harbor_enabled
      admin_password = var.harbor_admin_password
      db_password    = var.harbor_enabled ? random_password.harbor_db[0].result : ""
      trivy_enabled  = var.harbor_trivy_enabled
      data_volume    = var.harbor_data_volume
    }
    authentik = {
      enabled            = var.authentik_enabled
      secret_key         = var.authentik_secret_key
      bootstrap_password = var.authentik_bootstrap_password
      bootstrap_email    = var.authentik_bootstrap_email
      pg_password        = var.authentik_enabled ? random_password.authentik_pg[0].result : ""
    }
    traefik = {
      enabled = var.traefik_enabled
    }
  }

  # Cloud-init user-data
  cloud_init_user_data = <<-EOT
    #cloud-config
    hostname: ${var.name}
    fqdn: ${var.name}.${var.domain_suffix}
    manage_etc_hosts: true

    users:
      - name: ${var.username}
        groups: [adm, cdrom, dip, plugdev, lxd, sudo, docker]
        lock_passwd: true
        shell: /bin/bash
        ssh_authorized_keys:
          ${indent(6, join("\n", [for key in var.ssh_keys : "- ${key}"]))}

    package_update: true
    package_upgrade: true

    packages:
      - docker.io
      - docker-compose
      - curl
      - jq
      - htop
      - vim

    runcmd:
      - systemctl enable docker
      - systemctl start docker
      - usermod -aG docker ${var.username}
      # Mount data disk
      - |
        if [ -b /dev/sdb ]; then
          mkfs.ext4 -F /dev/sdb
          mkdir -p /data
          echo '/dev/sdb /data ext4 defaults 0 2' >> /etc/fstab
          mount /data
          chown ${var.username}:${var.username} /data
        fi
      # Create service directories
      - mkdir -p /data/step-ca /data/harbor /data/authentik /data/traefik
      - chown -R ${var.username}:${var.username} /data

    write_files:
      - path: /etc/docker/daemon.json
        content: |
          {
            "log-driver": "json-file",
            "log-opts": {
              "max-size": "10m",
              "max-file": "3"
            }
          }

    final_message: "Tooling VM ready after $UPTIME seconds"
  EOT
}

# -----------------------------------------------------------------------------
# Cloud-init Snippet
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.target_node

  source_raw {
    data      = local.cloud_init_user_data
    file_name = "${var.name}-cloud-init.yaml"
  }
}

# -----------------------------------------------------------------------------
# Virtual Machine
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "tooling" {
  name        = var.name
  description = "Tooling Stack: Step-ca PKI, Harbor Registry, Authentik SSO"
  tags        = var.tags
  node_name   = var.target_node

  on_boot = true
  started = true

  clone {
    vm_id = var.template_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.vm_config.cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_config.memory
  }

  # System disk (cloned from template)
  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.vm_config.disk
    file_format  = "raw"
  }

  # Data disk for Harbor images and service data
  disk {
    datastore_id = var.datastore
    interface    = "scsi1"
    size         = var.vm_config.data_disk
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address}/${var.network_cidr}"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  lifecycle {
    ignore_changes = [
      clone,
      initialization,
    ]
  }
}
