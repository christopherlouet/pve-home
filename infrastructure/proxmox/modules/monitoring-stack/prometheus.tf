# =============================================================================
# Prometheus Configuration
# =============================================================================
# Scrape targets, PVE Exporter, and Prometheus config.
#
# Architecture des metriques :
#   1. node_exporter (port 9100) : metriques systeme des hosts PVE
#   2. pve-exporter (port 9221) : metriques API Proxmox (VMs, LXC, storage)
#   3. additional_scrape_targets : exporters locaux (cAdvisor, blackbox, etc.)
#   4. remote_scrape_targets : exporters des VMs d'autres environnements
#   5. tooling scrape : metriques Step-ca, Harbor, Authentik, Traefik
#
# Le fichier prometheus.yml.tpl genere la config finale avec tous les targets.
# =============================================================================

locals {
  # Genere un target node_exporter par host PVE declare dans var.proxmox_nodes.
  # Chaque host PVE doit avoir node_exporter installe (voir install-node-exporter.sh).
  node_exporter_targets = [
    for node in var.proxmox_nodes : {
      name = node.name
      ip   = node.ip
      port = 9100
    }
  ]

  # Fusion de toutes les sources de scrape en une seule liste :
  # - Hosts PVE (node_exporter) + targets locaux + targets distants (cross-env)
  all_scrape_targets = concat(local.node_exporter_targets, var.additional_scrape_targets, var.remote_scrape_targets)

  # Config PVE Exporter : mappe chaque node Proxmox a ses credentials API.
  # Utilise comme fichier /opt/monitoring/pve-exporter/pve.yml sur la VM.
  # verify_ssl=false car les hosts PVE utilisent des certificats auto-signes.
  pve_exporter_config = yamlencode({
    for node in var.proxmox_nodes : node.name => {
      user        = var.pve_exporter_user
      token_name  = var.pve_exporter_token_name
      token_value = node.token_value
      verify_ssl  = false
    }
  })

  # Genere prometheus.yml a partir du template avec tous les scrape targets.
  # Le template gere les sections scrape_configs, alerting, et rules.
  prometheus_config = templatefile("${path.module}/files/prometheus.yml.tpl", {
    proxmox_nodes         = var.proxmox_nodes
    scrape_targets        = local.all_scrape_targets
    monitoring_ip         = var.ip_address
    alertmanager_enabled  = var.telegram_enabled
    custom_scrape_configs = var.custom_scrape_configs != "" ? indent(2, var.custom_scrape_configs) : ""
  })

  # Config scrape conditionnelle pour la tooling-stack (Step-ca, Harbor, etc.).
  # Active uniquement si tooling_enabled=true et tooling_ip est renseigne.
  tooling_scrape_config = var.tooling_enabled && var.tooling_ip != "" ? templatefile("${path.module}/files/prometheus/scrape/tooling.yml.tpl", {
    tooling_ip        = var.tooling_ip
    step_ca_enabled   = var.tooling_step_ca_enabled
    harbor_enabled    = var.tooling_harbor_enabled
    authentik_enabled = var.tooling_authentik_enabled
    traefik_enabled   = var.tooling_traefik_enabled
  }) : ""
}
