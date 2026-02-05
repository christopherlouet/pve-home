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

  # Script d'installation Minio (extrait dans fichier template pour testabilite)
  install_script = templatefile("${path.module}/files/install-minio.sh.tpl", {
    minio_root_user     = var.minio_root_user
    minio_root_password = var.minio_root_password
    minio_port          = var.minio_port
    minio_console_port  = var.minio_console_port
    buckets             = var.buckets
  })
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
    size   = "${var.data_disk_size_gb}G"
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
      mount_point[0].size,
      mount_point[0].volume,
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
