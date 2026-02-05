# =============================================================================
# Loki Configuration
# =============================================================================
# Loki log aggregation and Promtail agent config
# =============================================================================

locals {
  # Configuration Loki
  loki_config = var.loki_enabled ? file("${path.module}/files/loki/loki-config.yml") : ""

  # Configuration Promtail (local)
  promtail_config = var.loki_enabled ? templatefile("${path.module}/files/promtail/promtail-config.yml.tpl", {
    hostname = local.vm_name
  }) : ""
}
