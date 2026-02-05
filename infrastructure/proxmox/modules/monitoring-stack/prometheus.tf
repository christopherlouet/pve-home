# =============================================================================
# Prometheus Configuration
# =============================================================================
# Scrape targets, PVE Exporter, and Prometheus config
# =============================================================================

locals {
  # Node exporter targets: tous les nodes Proxmox
  node_exporter_targets = [
    for node in var.proxmox_nodes : {
      name = node.name
      ip   = node.ip
      port = 9100
    }
  ]

  # Combiner avec les targets additionnels (locaux + distants)
  all_scrape_targets = concat(local.node_exporter_targets, var.additional_scrape_targets, var.remote_scrape_targets)

  # Configuration PVE Exporter (un module par node)
  pve_exporter_config = yamlencode({
    for node in var.proxmox_nodes : node.name => {
      user        = var.pve_exporter_user
      token_name  = var.pve_exporter_token_name
      token_value = node.token_value
      verify_ssl  = false
    }
  })

  # Configuration Prometheus
  prometheus_config = templatefile("${path.module}/files/prometheus.yml.tpl", {
    proxmox_nodes         = var.proxmox_nodes
    scrape_targets        = local.all_scrape_targets
    monitoring_ip         = var.ip_address
    alertmanager_enabled  = var.telegram_enabled
    custom_scrape_configs = var.custom_scrape_configs != "" ? indent(2, var.custom_scrape_configs) : ""
  })

  # Tooling Scrape Config
  tooling_scrape_config = var.tooling_enabled && var.tooling_ip != "" ? templatefile("${path.module}/files/prometheus/scrape/tooling.yml.tpl", {
    tooling_ip        = var.tooling_ip
    step_ca_enabled   = var.tooling_step_ca_enabled
    harbor_enabled    = var.tooling_harbor_enabled
    authentik_enabled = var.tooling_authentik_enabled
    traefik_enabled   = var.tooling_traefik_enabled
  }) : ""
}
