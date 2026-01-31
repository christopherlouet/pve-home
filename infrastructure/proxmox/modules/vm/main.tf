# =============================================================================
# Module VM Proxmox - Homelab
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

variable "name" {
  description = "Nom de la VM"
  type        = string
}

variable "description" {
  description = "Description de la VM"
  type        = string
  default     = "Managed by Terraform"
}

variable "target_node" {
  description = "Node Proxmox cible"
  type        = string
}

variable "template_id" {
  description = "ID du template à cloner"
  type        = number
}

variable "cpu_cores" {
  description = "Nombre de cores CPU"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "Type de CPU (host, kvm64, etc.)"
  type        = string
  default     = "host"
}

variable "memory_mb" {
  description = "RAM en MB"
  type        = number
  default     = 2048
}

variable "disk_size_gb" {
  description = "Taille du disque système en GB"
  type        = number
  default     = 20
}

variable "datastore" {
  description = "Datastore pour le disque"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Bridge réseau"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN ID (null si pas de VLAN)"
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Adresse IP en notation CIDR (ex: 192.168.1.10/24)"
  type        = string
}

variable "gateway" {
  description = "Passerelle par défaut"
  type        = string
}

variable "dns_servers" {
  description = "Serveurs DNS"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "username" {
  description = "Utilisateur cloud-init"
  type        = string
  default     = "ubuntu"
}

variable "ssh_keys" {
  description = "Clés SSH publiques"
  type        = list(string)
}

variable "tags" {
  description = "Tags de la VM"
  type        = list(string)
  default     = ["terraform"]
}

variable "start_on_boot" {
  description = "Démarrer automatiquement au boot du node"
  type        = bool
  default     = true
}

variable "agent_enabled" {
  description = "Activer QEMU Guest Agent"
  type        = bool
  default     = true
}

variable "additional_disks" {
  description = "Disques additionnels"
  type = list(object({
    size         = number
    datastore_id = optional(string, "local-lvm")
    interface    = optional(string, "scsi")
  }))
  default = []
}

variable "install_docker" {
  description = "Installer Docker via cloud-init"
  type        = bool
  default     = false
}

variable "install_qemu_agent" {
  description = "Installer QEMU Guest Agent via cloud-init"
  type        = bool
  default     = true
}

variable "additional_packages" {
  description = "Packages supplementaires a installer via cloud-init"
  type        = list(string)
  default     = []
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

  cloud_config = {
    users = [
      {
        name                = var.username
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        shell               = "/bin/bash"
        ssh_authorized_keys = var.ssh_keys
      }
    ]
    package_update  = true
    package_upgrade = false
    packages        = local.all_packages
    runcmd          = concat(local.docker_runcmd, local.qemu_agent_runcmd)
  }
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  count = var.install_docker || var.install_qemu_agent || length(var.additional_packages) > 0 ? 1 : 0

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
  tags          = var.tags
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
  }

  dynamic "disk" {
    for_each = var.additional_disks
    content {
      datastore_id = disk.value.datastore_id
      size         = disk.value.size
      interface    = "${disk.value.interface}${disk.key + 1}"
      iothread     = true
      discard      = "on"
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

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "vm_id" {
  description = "ID de la VM"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "Nom de la VM"
  value       = proxmox_virtual_environment_vm.this.name
}

output "ipv4_address" {
  description = "Adresse IPv4"
  value       = try(proxmox_virtual_environment_vm.this.ipv4_addresses[1][0], var.ip_address)
}

output "mac_address" {
  description = "Adresse MAC"
  value       = try(proxmox_virtual_environment_vm.this.mac_addresses[0], null)
}

output "node_name" {
  description = "Node Proxmox"
  value       = proxmox_virtual_environment_vm.this.node_name
}
