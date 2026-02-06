# =============================================================================
# Traefik Configuration
# =============================================================================
# Reverse proxy static and dynamic configuration.
#
# Traefik expose les services monitoring via HTTPS (domain_suffix) :
#   - grafana.<domain>    → Grafana (port 3000)
#   - prometheus.<domain> → Prometheus (port 9090)
#   - alertmanager.<domain> → Alertmanager (conditionnel)
#   - loki.<domain>       → Loki API (conditionnel)
#   - uptime.<domain>     → Uptime Kuma (conditionnel)
#
# Static config : entrypoints, certificat resolver (TLS via Step-ca si active)
# Dynamic config : routers et services pour chaque composant
# =============================================================================

locals {
  # Config statique : ports d'ecoute (80/443), TLS, et API dashboard
  traefik_static_config = var.traefik_enabled ? templatefile("${path.module}/files/traefik/traefik.yml.tpl", {
    tls_enabled = var.tls_enabled
  }) : ""

  # Config dynamique : genere les routes pour chaque service actif.
  # Les services desactives n'ont pas de route (pas de router Traefik).
  traefik_dynamic_config = var.traefik_enabled ? templatefile("${path.module}/files/traefik/dynamic.yml.tpl", {
    domain_suffix        = var.domain_suffix
    tls_enabled          = var.tls_enabled
    alertmanager_enabled = var.telegram_enabled
    loki_enabled         = var.loki_enabled
    uptime_kuma_enabled  = var.uptime_kuma_enabled
  }) : ""
}
