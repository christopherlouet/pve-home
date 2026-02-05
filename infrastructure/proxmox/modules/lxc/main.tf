# =============================================================================
# Module LXC Proxmox - Homelab
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# -----------------------------------------------------------------------------
# Resource LXC
# -----------------------------------------------------------------------------

locals {
  # NOTE: Same expiration_tag pattern used in vm/main.tf
  expiration_tag = var.expiration_days != null ? ["expires:${formatdate("YYYY-MM-DD", timeadd(timestamp(), "${var.expiration_days * 24}h"))}"] : []
  container_ip   = split("/", var.ip_address)[0]
}

resource "proxmox_virtual_environment_container" "this" {
  description   = var.description
  node_name     = var.target_node
  tags          = concat(var.tags, local.expiration_tag)
  unprivileged  = var.unprivileged
  start_on_boot = var.start_on_boot
  started       = true

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.datastore
    size         = var.disk_size_gb
  }

  dynamic "mount_point" {
    for_each = var.mountpoints
    content {
      volume    = mount_point.value.volume
      path      = mount_point.value.path
      size      = mount_point.value.size
      read_only = mount_point.value.read_only
    }
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
      keys     = var.ssh_keys
      password = var.root_password
    }
  }

  features {
    nesting = var.nesting
    fuse    = var.fuse
    keyctl  = var.keyctl
    mount   = var.mount_types
  }

  lifecycle {
    ignore_changes = [
      initialization,
      disk[0].size,
    ]
  }
}

# -----------------------------------------------------------------------------
# Automatic Security Updates (Ubuntu/Debian only)
# -----------------------------------------------------------------------------

resource "terraform_data" "security_updates" {
  count      = var.auto_security_updates && contains(["ubuntu", "debian"], var.os_type) ? 1 : 0
  depends_on = [proxmox_virtual_environment_container.this]

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y unattended-upgrades apt-listchanges",
      "echo 'Unattended-Upgrade::Allowed-Origins { \"$${distro_id}:$${distro_codename}-security\"; };' > /etc/apt/apt.conf.d/50unattended-upgrades-local",
      "echo 'Unattended-Upgrade::Automatic-Reboot \"false\";' >> /etc/apt/apt.conf.d/50unattended-upgrades-local",
      "systemctl enable --now unattended-upgrades",
    ]

    connection {
      type    = "ssh"
      host    = local.container_ip
      user    = "root"
      timeout = "2m"
      agent   = true
    }
  }
}
