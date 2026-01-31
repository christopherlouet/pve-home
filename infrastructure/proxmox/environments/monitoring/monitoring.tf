# =============================================================================
# Monitoring Stack Configuration
# =============================================================================
# Stack de monitoring centralisee: Prometheus + Grafana + Alertmanager
# Deployee sur un PVE dedie, supervise TOUS les environnements (prod, lab, etc.)
# =============================================================================

module "monitoring" {
  source = "../../modules/monitoring-stack"

  name        = "${local.environment}-monitoring"
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
  pve_exporter_user        = var.monitoring.pve_exporter.user
  pve_exporter_token_name  = var.monitoring.pve_exporter.token_name
  pve_exporter_token_value = var.monitoring.pve_exporter.token_value

  # Cibles distantes (VMs sur d'autres PVE)
  remote_scrape_targets = var.remote_targets

  # Prometheus
  prometheus_retention_days = var.monitoring.retention_days
  prometheus_retention_size = "${var.monitoring.vm.data_disk - 10}GB"

  # Grafana
  grafana_admin_password = var.monitoring.grafana_admin_password

  # Alertmanager - Telegram
  telegram_enabled   = var.monitoring.telegram.enabled
  telegram_bot_token = var.monitoring.telegram.bot_token
  telegram_chat_id   = var.monitoring.telegram.chat_id

  tags = concat(local.common_tags, ["monitoring", "prometheus", "grafana"])
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
