# =============================================================================
# Module Tooling Stack - Authentik SSO
# =============================================================================
# Fournisseur SSO avec Authentik (OAuth2/OIDC).
# =============================================================================

# -----------------------------------------------------------------------------
# Random Resources
# -----------------------------------------------------------------------------

resource "random_password" "authentik_pg" {
  count   = var.authentik_enabled ? 1 : 0
  length  = 32
  special = false
}

# -----------------------------------------------------------------------------
# Authentik Configuration
# -----------------------------------------------------------------------------

locals {
  authentik_config = var.authentik_enabled ? {
    hostname         = "auth.${var.domain_suffix}"
    external_url     = var.traefik_enabled ? "https://auth.${var.domain_suffix}" : "http://${var.ip_address}:9000"
    db_type          = "postgresql"
    db_host          = "authentik-db"
    db_port          = 5432
    db_name          = "authentik"
    db_username      = "authentik"
    redis_host       = "authentik-redis"
    redis_port       = 6379
    bootstrap_email  = var.authentik_bootstrap_email
    email_enabled    = false
    error_reporting  = false
    avatars          = "none"
    outpost_traefik  = var.traefik_enabled
    forward_auth_url = "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
    server_port      = 9000
    metrics_port     = 9300
  } : null

  # Authentik OAuth/OIDC provider configurations for integrated services
  authentik_oauth_providers = var.authentik_enabled ? merge(
    # Grafana OAuth2 provider
    {
      grafana = {
        name         = "Grafana"
        client_id    = "grafana"
        redirect_uri = var.traefik_enabled ? "https://grafana.${var.domain_suffix}/login/generic_oauth" : "http://${var.ip_address}:3000/login/generic_oauth"
        scopes       = ["openid", "profile", "email"]
        protocol     = "oauth2"
      }
    },
    # Harbor OIDC provider (if Harbor is enabled)
    var.harbor_enabled ? {
      harbor = {
        name         = "Harbor"
        client_id    = "harbor"
        redirect_uri = var.traefik_enabled ? "https://registry.${var.domain_suffix}/c/oidc/callback" : "http://${var.ip_address}:8080/c/oidc/callback"
        scopes       = ["openid", "profile", "email", "groups"]
        protocol     = "oidc"
      }
    } : {},
    # Proxmox OIDC provider (for future Phase 2 SSO)
    {
      proxmox = {
        name         = "Proxmox VE"
        client_id    = "proxmox"
        redirect_uri = "https://pve.${var.domain_suffix}:8006"
        scopes       = ["openid", "profile", "email"]
        protocol     = "oidc"
      }
    },
    # Traefik Dashboard (for future Phase 2 SSO with ForwardAuth)
    var.traefik_enabled ? {
      traefik = {
        name         = "Traefik Dashboard"
        client_id    = "traefik"
        redirect_uri = "https://traefik.${var.domain_suffix}"
        scopes       = ["openid", "profile", "email"]
        protocol     = "forward_auth"
      }
    } : {}
  ) : {}
}
