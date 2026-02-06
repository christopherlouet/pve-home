# =============================================================================
# Loki Configuration
# =============================================================================
# Loki log aggregation and Promtail agent config.
#
# Loki centralise les logs de la stack monitoring (Promtail local) et des VMs
# distantes (Promtail agent installe via le module vm avec install_promtail=true).
# Les logs sont interrogeables dans Grafana via LogQL (datasource loki.yml).
# =============================================================================

locals {
  # Config Loki server : retention, stockage, limites d'ingestion
  loki_config = var.loki_enabled ? file("${path.module}/files/loki/loki-config.yml") : ""

  # Promtail local : collecte les logs des conteneurs Docker de la stack monitoring.
  # Les VMs distantes utilisent leur propre Promtail (voir vm/files/install-promtail.sh).
  promtail_config = var.loki_enabled ? templatefile("${path.module}/files/promtail/promtail-config.yml.tpl", {
    hostname = local.vm_name
  }) : ""
}
