# =============================================================================
# Module Tooling Stack - Traefik Reverse Proxy
# =============================================================================
# Configuration du reverse proxy Traefik avec routage par domaine.
# =============================================================================

locals {
  # Traefik configuration object
  traefik_config = var.traefik_enabled ? {
    acme_enabled  = var.step_ca_enabled
    acme_server   = "https://127.0.0.1:8443/acme/acme/directory"
    acme_email    = "admin@${var.domain_suffix}"
    dashboard     = true
    entrypoints   = ["web", "websecure"]
    providers     = ["docker", "file"]
    log_level     = "INFO"
    metrics_port  = 8082
    insecure_skip = true # Skip TLS verification for internal Step-ca
  } : null

  # Traefik routes for each service
  traefik_routes = var.traefik_enabled ? merge(
    var.step_ca_enabled ? {
      pki = {
        host    = "pki.${var.domain_suffix}"
        port    = 8443
        service = "step-ca"
        tls     = true
      }
    } : {},
    var.harbor_enabled ? {
      registry = {
        host    = "registry.${var.domain_suffix}"
        port    = 8080
        service = "harbor-core"
        tls     = true
      }
    } : {},
    var.authentik_enabled ? {
      auth = {
        host    = "auth.${var.domain_suffix}"
        port    = 9000
        service = "authentik-server"
        tls     = true
      }
    } : {},
    {
      traefik = {
        host    = "traefik.${var.domain_suffix}"
        port    = 8080
        service = "api@internal"
        tls     = true
      }
    }
  ) : {}
}
