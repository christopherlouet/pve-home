# =============================================================================
# Traefik Configuration
# =============================================================================
# Reverse proxy static and dynamic configuration
# =============================================================================

locals {
  # Configuration Traefik (static)
  traefik_static_config = var.traefik_enabled ? templatefile("${path.module}/files/traefik/traefik.yml.tpl", {
    tls_enabled = var.tls_enabled
  }) : ""

  # Configuration Traefik (dynamic routes)
  traefik_dynamic_config = var.traefik_enabled ? templatefile("${path.module}/files/traefik/dynamic.yml.tpl", {
    domain_suffix        = var.domain_suffix
    tls_enabled          = var.tls_enabled
    alertmanager_enabled = var.telegram_enabled
    loki_enabled         = var.loki_enabled
    uptime_kuma_enabled  = var.uptime_kuma_enabled
  }) : ""
}
