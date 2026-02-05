# =============================================================================
# Grafana Configuration
# =============================================================================
# Dashboards, datasources, and Grafana-related locals
# =============================================================================

locals {
  # Datasource Loki pour Grafana
  grafana_datasource_loki = var.loki_enabled ? file("${path.module}/files/grafana/provisioning/datasources/loki.yml") : ""

  # Infrastructure dashboards
  dashboard_node_exporter  = file("${path.module}/files/grafana/dashboards/node-exporter.json")
  dashboard_pve_exporter   = file("${path.module}/files/grafana/dashboards/pve-exporter.json")
  dashboard_prometheus     = file("${path.module}/files/grafana/dashboards/prometheus.json")
  dashboard_nodes_overview = file("${path.module}/files/grafana/dashboards/nodes-overview.json")

  # Observability dashboards
  dashboard_backup_overview   = file("${path.module}/files/grafana/dashboards/backup-overview.json")
  dashboard_alerting_overview = file("${path.module}/files/grafana/dashboards/alerting-overview.json")

  # Applications dashboards
  dashboard_application_overview = file("${path.module}/files/grafana/dashboards/application-overview.json")
  dashboard_http_probes          = file("${path.module}/files/grafana/dashboards/http-probes.json")
  dashboard_postgresql           = file("${path.module}/files/grafana/dashboards/postgresql.json")
  dashboard_docker_containers    = file("${path.module}/files/grafana/dashboards/docker-containers.json")

  # Logs dashboard
  dashboard_logs_overview = var.loki_enabled ? file("${path.module}/files/grafana/dashboards/logs-overview.json") : ""

  # Tooling Dashboards (Step-ca, Harbor, Authentik)
  dashboard_step_ca   = var.tooling_enabled && var.tooling_step_ca_enabled ? file("${path.module}/files/grafana/dashboards/tooling/step-ca.json") : ""
  dashboard_harbor    = var.tooling_enabled && var.tooling_harbor_enabled ? file("${path.module}/files/grafana/dashboards/tooling/harbor.json") : ""
  dashboard_authentik = var.tooling_enabled && var.tooling_authentik_enabled ? file("${path.module}/files/grafana/dashboards/tooling/authentik.json") : ""
}
