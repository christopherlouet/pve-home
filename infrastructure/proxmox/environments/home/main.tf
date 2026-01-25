# =============================================================================
# Homelab Infrastructure - Environnement Home
# =============================================================================
# Exemple d'infrastructure pour un homelab sur Intel NUC
# Adaptez les IPs, ressources et services selon vos besoins
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider Proxmox
# -----------------------------------------------------------------------------

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  ssh {
    agent    = true
    username = var.ssh_username
  }
}

# -----------------------------------------------------------------------------
# Variables locales
# -----------------------------------------------------------------------------

locals {
  environment = var.environment
  common_tags = [local.environment, "terraform"]
}

# -----------------------------------------------------------------------------
# VMs
# -----------------------------------------------------------------------------

module "vms" {
  source   = "../../modules/vm"
  for_each = var.vms

  name        = "${local.environment}-${each.key}"
  description = "${each.key} - Homelab"
  target_node = var.default_node
  template_id = var.vm_template_id

  cpu_cores    = each.value.cores
  memory_mb    = each.value.memory
  disk_size_gb = each.value.disk
  datastore    = var.default_datastore

  network_bridge = var.network_bridge
  ip_address     = "${each.value.ip}/24"
  gateway        = var.network_gateway
  dns_servers    = var.network_dns

  ssh_keys = var.ssh_public_keys
  tags     = concat(local.common_tags, each.value.tags)

  # Cloud-init options
  install_docker = try(each.value.docker, false)
}

# -----------------------------------------------------------------------------
# Conteneurs LXC
# -----------------------------------------------------------------------------

module "containers" {
  source   = "../../modules/lxc"
  for_each = var.containers

  hostname         = "${local.environment}-${each.key}"
  description      = "${each.key} - Homelab"
  target_node      = var.default_node
  template_file_id = var.lxc_template
  os_type          = "ubuntu"

  cpu_cores    = each.value.cores
  memory_mb    = each.value.memory
  disk_size_gb = each.value.disk
  datastore    = var.default_datastore

  network_bridge = var.network_bridge
  ip_address     = "${each.value.ip}/24"
  gateway        = var.network_gateway
  dns_servers    = var.network_dns

  ssh_keys     = var.ssh_public_keys
  unprivileged = true
  nesting      = each.value.nesting

  tags = concat(local.common_tags, each.value.tags)
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "vms" {
  description = "VMs créées"
  value = {
    for k, v in module.vms : k => {
      id   = v.vm_id
      name = v.name
      ip   = v.ipv4_address
    }
  }
}

output "containers" {
  description = "Conteneurs LXC créés"
  value = {
    for k, v in module.containers : k => {
      id       = v.container_id
      hostname = v.hostname
      ip       = v.ipv4_address
    }
  }
}

output "ssh_commands" {
  description = "Commandes SSH pour se connecter"
  value = merge(
    { for k, v in module.vms : k => "ssh ubuntu@${split("/", v.ipv4_address)[0]}" },
    { for k, v in module.containers : k => "ssh root@${split("/", v.ipv4_address)[0]}" }
  )
}
