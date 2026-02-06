# =============================================================================
# Grafana Configuration
# =============================================================================
# Dashboards, datasources, and Grafana-related locals.
#
# Les dashboards JSON sont auto-provisionnes via cloud-init : chaque fichier
# est ecrit dans /opt/monitoring/grafana/dashboards/<categorie>/ sur la VM.
# Grafana les decouvre au demarrage via le provisioning (dashboard provider).
#
# Categories :
#   - infrastructure/ : metriques systeme (node-exporter, pve-exporter, prometheus)
#   - observability/  : backup, alerting overview
#   - applications/   : app overview, http probes, postgresql, docker, logs
#   - tooling/        : Step-ca, Harbor, Authentik (conditionnel)
# =============================================================================

locals {
  # Datasource Loki : active uniquement si loki_enabled, permet les requetes LogQL dans Grafana
  grafana_datasource_loki = var.loki_enabled ? file("${path.module}/files/grafana/provisioning/datasources/loki.yml") : ""

  # Infrastructure dashboards (toujours inclus)
  dashboard_node_exporter  = file("${path.module}/files/grafana/dashboards/node-exporter.json")
  dashboard_pve_exporter   = file("${path.module}/files/grafana/dashboards/pve-exporter.json")
  dashboard_prometheus     = file("${path.module}/files/grafana/dashboards/prometheus.json")
  dashboard_nodes_overview = file("${path.module}/files/grafana/dashboards/nodes-overview.json")

  # Observability dashboards (toujours inclus)
  dashboard_backup_overview   = file("${path.module}/files/grafana/dashboards/backup-overview.json")
  dashboard_alerting_overview = file("${path.module}/files/grafana/dashboards/alerting-overview.json")

  # Applications dashboards (toujours inclus)
  dashboard_application_overview = file("${path.module}/files/grafana/dashboards/application-overview.json")
  dashboard_http_probes          = file("${path.module}/files/grafana/dashboards/http-probes.json")
  dashboard_postgresql           = file("${path.module}/files/grafana/dashboards/postgresql.json")
  dashboard_docker_containers    = file("${path.module}/files/grafana/dashboards/docker-containers.json")

  # Logs dashboard : conditionnel, requiert Loki pour les requetes LogQL
  dashboard_logs_overview = var.loki_enabled ? file("${path.module}/files/grafana/dashboards/logs-overview.json") : ""

  # Tooling Dashboards : inclus uniquement si le service correspondant est active.
  # Chaque dashboard est couple a un scrape target dans prometheus.tf (tooling_scrape_config).
  dashboard_step_ca   = var.tooling_enabled && var.tooling_step_ca_enabled ? file("${path.module}/files/grafana/dashboards/tooling/step-ca.json") : ""
  dashboard_harbor    = var.tooling_enabled && var.tooling_harbor_enabled ? file("${path.module}/files/grafana/dashboards/tooling/harbor.json") : ""
  dashboard_authentik = var.tooling_enabled && var.tooling_authentik_enabled ? file("${path.module}/files/grafana/dashboards/tooling/authentik.json") : ""
}
