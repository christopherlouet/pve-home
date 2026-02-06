# =============================================================================
# Monitoring Stack Configuration
# =============================================================================
# Stack de monitoring centralisee: Prometheus + Grafana + Alertmanager
# Deployee sur un PVE dedie, supervise TOUS les environnements (prod, lab, etc.)
# =============================================================================

module "monitoring" {
  source = "../../modules/monitoring-stack"

  name        = "monitoring-stack"
  target_node = var.monitoring.node != null ? var.monitoring.node : var.default_node
  template_id = var.vm_template_id

  vm_config = {
    cores     = var.monitoring.vm.cores
    memory    = var.monitoring.vm.memory
    disk      = var.monitoring.vm.disk
    data_disk = var.monitoring.vm.data_disk
  }

  datastore      = var.default_datastore
  ip_address     = var.monitoring.vm.ip
  network_cidr   = 24
  gateway        = var.network_gateway
  dns_servers    = var.network_dns
  network_bridge = var.network_bridge
  ssh_keys       = var.ssh_public_keys

  # Nodes Proxmox a monitorer (TOUS les PVE: prod, lab, monitoring)
  proxmox_nodes = var.monitoring.proxmox_nodes

  # Credentials pve-exporter
  pve_exporter_user       = var.monitoring.pve_exporter.user
  pve_exporter_token_name = var.monitoring.pve_exporter.token_name

  # Cibles distantes (VMs sur d'autres PVE)
  remote_scrape_targets = var.remote_targets

  # Prometheus
  prometheus_retention_days = var.monitoring.retention_days
  prometheus_retention_size = "${var.monitoring.vm.data_disk - 10}GB"
  custom_scrape_configs     = local.combined_scrape_configs

  # Grafana
  grafana_admin_password = var.monitoring.grafana_admin_password

  # Tooling Stack Integration (dashboards et alertes)
  tooling_enabled           = var.tooling.enabled
  tooling_ip                = var.tooling.enabled ? var.tooling.vm.ip : ""
  tooling_step_ca_enabled   = var.tooling.enabled && var.tooling.step_ca.enabled
  tooling_harbor_enabled    = var.tooling.enabled && var.tooling.harbor.enabled
  tooling_authentik_enabled = var.tooling.enabled && var.tooling.authentik.enabled
  tooling_traefik_enabled   = var.tooling.enabled && var.tooling.traefik_enabled

  # Alertmanager - Telegram
  telegram_enabled   = var.monitoring.telegram.enabled
  telegram_bot_token = var.monitoring.telegram.bot_token
  telegram_chat_id   = var.monitoring.telegram.chat_id

  tags = sort(distinct(concat(local.common_tags, ["monitoring", "prometheus", "grafana"])))
}

# -----------------------------------------------------------------------------
# Firewall Monitoring
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_firewall_options" "monitoring" {
  node_name = module.monitoring.node_name
  vm_id     = module.monitoring.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

# Regles firewall: presets partages (shared/firewall_locals.tf) + services monitoring
resource "proxmox_virtual_environment_firewall_rules" "monitoring" {
  node_name = module.monitoring.node_name
  vm_id     = module.monitoring.vm_id

  # Regles de base partagees (SSH, HTTP, HTTPS, Node Exporter, Ping)
  dynamic "rule" {
    for_each = local.firewall_rules_base
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = rule.value.proto
      dport   = rule.value.dport
      comment = rule.value.comment
    }
  }

  # Services monitoring specifiques
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "8080"
    comment = "Traefik Dashboard"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "3000"
    comment = "Grafana"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "9090"
    comment = "Prometheus"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "9093"
    comment = "Alertmanager"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "9221"
    comment = "PVE Exporter"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "3100"
    comment = "Loki API"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "9080"
    comment = "Promtail"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "3001"
    comment = "Uptime Kuma"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.monitoring]
}

# -----------------------------------------------------------------------------
# Outputs Monitoring
# -----------------------------------------------------------------------------

output "monitoring" {
  description = "Stack monitoring"
  value = {
    vm_id   = module.monitoring.vm_id
    vm_name = module.monitoring.vm_name
    ip      = module.monitoring.ip_address
    urls    = module.monitoring.urls
    ssh     = module.monitoring.ssh_command
  }
}

output "scrape_targets" {
  description = "Toutes les cibles Prometheus configurees"
  value       = module.monitoring.scrape_targets
}

output "health_check_ssh_public_key" {
  description = "Cle SSH publique a ajouter aux ssh_public_keys des autres environnements"
  value       = module.monitoring.health_check_ssh_public_key
}
