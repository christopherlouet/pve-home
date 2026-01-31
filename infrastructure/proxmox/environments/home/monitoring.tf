# =============================================================================
# Monitoring Stack Configuration
# =============================================================================
# Stack de monitoring optionnelle: Prometheus + Grafana + Alertmanager
# Deployee sur une VM dediee avec Docker Compose
# =============================================================================

module "monitoring" {
  source = "../../modules/monitoring-stack"
  count  = var.monitoring.enabled ? 1 : 0

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

  # Nodes Proxmox a monitorer
  proxmox_nodes = var.monitoring.proxmox_nodes

  # Credentials pve-exporter
  pve_exporter_user        = var.monitoring.pve_exporter.user
  pve_exporter_token_name  = var.monitoring.pve_exporter.token_name
  pve_exporter_token_value = var.monitoring.pve_exporter.token_value

  # Cibles additionnelles (VMs avec node_exporter)
  additional_scrape_targets = [
    for k, v in var.vms : {
      name = k
      ip   = v.ip
      port = 9100
      labels = {
        app  = k
        type = "vm"
      }
    }
    if try(v.node_exporter, false)
  ]

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
  value = var.monitoring.enabled ? {
    vm_id   = module.monitoring[0].vm_id
    vm_name = module.monitoring[0].vm_name
    ip      = module.monitoring[0].ip_address
    urls    = module.monitoring[0].urls
    ssh     = module.monitoring[0].ssh_command
  } : null
}
