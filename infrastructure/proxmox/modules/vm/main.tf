# =============================================================================
# Module VM Proxmox - Homelab
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# -----------------------------------------------------------------------------
# Cloud-init configuration
# -----------------------------------------------------------------------------

locals {
  base_packages   = var.install_qemu_agent ? ["qemu-guest-agent"] : []
  docker_packages = var.install_docker ? ["ca-certificates", "curl", "gnupg"] : []
  all_packages    = concat(local.base_packages, local.docker_packages, var.additional_packages)

  docker_runcmd = var.install_docker ? [
    "install -m 0755 -d /etc/apt/keyrings",
    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
    "chmod a+r /etc/apt/keyrings/docker.asc",
    "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable\" > /etc/apt/sources.list.d/docker.list",
    "apt-get update",
    "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
    "systemctl enable --now docker",
    "usermod -aG docker ${var.username}"
  ] : []

  qemu_agent_runcmd = var.install_qemu_agent ? [
    "systemctl enable --now qemu-guest-agent"
  ] : []

  security_updates_packages = var.auto_security_updates ? ["unattended-upgrades", "apt-listchanges"] : []

  security_updates_runcmd = var.auto_security_updates ? [
    "echo 'Unattended-Upgrade::Allowed-Origins { \"$${distro_id}:$${distro_codename}-security\"; };' > /etc/apt/apt.conf.d/50unattended-upgrades-local",
    "echo 'Unattended-Upgrade::Automatic-Reboot \"false\";' >> /etc/apt/apt.conf.d/50unattended-upgrades-local",
    "systemctl enable --now unattended-upgrades"
  ] : []

  # Tag d'expiration pour le lifecycle management
  expiration_tag = var.expiration_days != null ? ["expires:${formatdate("YYYY-MM-DD", timeadd(timestamp(), "${var.expiration_days * 24}h"))}"] : []

  cloud_config = {
    users = [
      {
        name = var.username
        # SECURITY NOTE: NOPASSWD:ALL accepte pour homelab - restreindre en production
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        shell               = "/bin/bash"
        ssh_authorized_keys = var.ssh_keys
      }
    ]
    package_update  = true
    package_upgrade = false
    packages        = concat(local.all_packages, local.security_updates_packages)
    runcmd          = concat(local.docker_runcmd, local.qemu_agent_runcmd, local.security_updates_runcmd)
  }
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  count = var.install_docker || var.install_qemu_agent || var.auto_security_updates || length(var.additional_packages) > 0 ? 1 : 0

  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.target_node

  source_raw {
    data      = "#cloud-config\n${yamlencode(local.cloud_config)}"
    file_name = "${var.name}-cloud-config.yaml"
  }
}

# -----------------------------------------------------------------------------
# Resource VM
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "this" {
  name          = var.name
  description   = var.description
  tags          = concat(var.tags, local.expiration_tag)
  node_name     = var.target_node
  on_boot       = var.start_on_boot
  started       = true
  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore
    size         = var.disk_size_gb
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
    backup       = var.backup_enabled
  }

  dynamic "disk" {
    for_each = var.additional_disks
    content {
      datastore_id = disk.value.datastore_id
      size         = disk.value.size
      interface    = "${disk.value.interface}${disk.key + 1}"
      iothread     = true
      discard      = "on"
      backup       = var.backup_enabled
    }
  }

  network_device {
    bridge   = var.network_bridge
    model    = "virtio"
    vlan_id  = var.vlan_id
    firewall = true
  }

  agent {
    enabled = var.agent_enabled
    timeout = "1m"
  }

  initialization {
    user_data_file_id = length(proxmox_virtual_environment_file.cloud_config) > 0 ? proxmox_virtual_environment_file.cloud_config[0].id : null

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
      username = var.username
      keys     = var.ssh_keys
    }
  }

  lifecycle {
    ignore_changes = [
      initialization,
      disk[0].size,
    ]
  }
}
