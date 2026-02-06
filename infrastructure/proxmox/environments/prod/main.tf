# =============================================================================
# Production Infrastructure - Environnement Prod
# =============================================================================
# Exemple d'infrastructure pour l'environnement de production
# Adaptez les IPs, ressources et services selon vos besoins
# =============================================================================

# -----------------------------------------------------------------------------
# Variables locales
# -----------------------------------------------------------------------------

locals {
  environment  = var.environment
  common_tags  = [local.environment, "terraform"]
  all_ssh_keys = var.monitoring_ssh_public_key != "" ? concat(var.ssh_public_keys, [var.monitoring_ssh_public_key]) : var.ssh_public_keys
}

# -----------------------------------------------------------------------------
# VMs
# -----------------------------------------------------------------------------

module "vms" {
  source   = "../../modules/vm"
  for_each = var.vms

  name        = "${local.environment}-${each.key}"
  description = "${each.key} - Production"
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

  ssh_keys = local.all_ssh_keys
  tags     = sort(distinct(concat(local.common_tags, each.value.tags)))

  # Cloud-init options
  install_docker = try(each.value.docker, false)
}

# -----------------------------------------------------------------------------
# Firewall VMs
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_firewall_options" "vms" {
  for_each = var.vms

  node_name = var.default_node
  vm_id     = module.vms[each.key].vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

# Regles firewall: presets partages (shared/firewall_locals.tf) + exporters prod
resource "proxmox_virtual_environment_firewall_rules" "vms" {
  for_each = var.vms

  node_name = var.default_node
  vm_id     = module.vms[each.key].vm_id

  dynamic "rule" {
    for_each = concat(local.firewall_rules_base, local.firewall_rules_prod_exporters)
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = rule.value.proto
      dport   = rule.value.dport
      comment = rule.value.comment
    }
  }

  depends_on = [proxmox_virtual_environment_firewall_options.vms]
}

# -----------------------------------------------------------------------------
# Conteneurs LXC
# -----------------------------------------------------------------------------

module "containers" {
  source   = "../../modules/lxc"
  for_each = var.containers

  hostname         = "${local.environment}-${each.key}"
  description      = "${each.key} - Production"
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

  tags = sort(distinct(concat(local.common_tags, each.value.tags)))
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
