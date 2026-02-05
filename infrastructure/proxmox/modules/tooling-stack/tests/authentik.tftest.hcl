# =============================================================================
# Module Tooling Stack - Tests Authentik SSO
# =============================================================================
# Verifie que Authentik est correctement configure.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests
# -----------------------------------------------------------------------------

variables {
  target_node                  = "pve-test"
  template_id                  = 9000
  ip_address                   = "192.168.1.60"
  gateway                      = "192.168.1.1"
  ssh_keys                     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  domain_suffix                = "home.arpa"
  step_ca_password             = "testpassword123"               # gitleaks:allow
  harbor_admin_password        = "Harbor12345!"                  # gitleaks:allow
  authentik_secret_key         = "testsecretkey1234567890123456" # gitleaks:allow
  authentik_bootstrap_password = "Authentik123!"                 # gitleaks:allow
}

# -----------------------------------------------------------------------------
# Authentik Configuration Tests
# -----------------------------------------------------------------------------

run "authentik_config_generated" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = local.authentik_config != null
    error_message = "Authentik config should be generated when enabled"
  }

  assert {
    condition     = local.authentik_config.hostname == "auth.home.arpa"
    error_message = "Authentik hostname should be auth.home.arpa"
  }
}

run "authentik_config_with_custom_domain" {
  command = plan

  variables {
    authentik_enabled = true
    domain_suffix     = "lab.local"
  }

  assert {
    condition     = local.authentik_config.hostname == "auth.lab.local"
    error_message = "Authentik hostname should use custom domain suffix"
  }
}

run "authentik_config_disabled" {
  command = plan

  variables {
    authentik_enabled = false
  }

  assert {
    condition     = local.authentik_config == null
    error_message = "Authentik config should be null when disabled"
  }
}

run "authentik_external_url_with_traefik" {
  command = plan

  variables {
    authentik_enabled = true
    traefik_enabled   = true
  }

  assert {
    condition     = local.authentik_config.external_url == "https://auth.home.arpa"
    error_message = "Authentik external URL should use HTTPS with Traefik"
  }
}

run "authentik_external_url_without_traefik" {
  command = plan

  variables {
    authentik_enabled = true
    traefik_enabled   = false
  }

  assert {
    condition     = local.authentik_config.external_url == "http://192.168.1.60:9000"
    error_message = "Authentik external URL should use HTTP without Traefik"
  }
}

# -----------------------------------------------------------------------------
# Authentik Database Tests
# -----------------------------------------------------------------------------

run "authentik_db_host" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = local.authentik_config.db_host == "authentik-db"
    error_message = "Authentik DB host should be authentik-db"
  }
}

run "authentik_uses_postgresql" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = local.authentik_config.db_type == "postgresql"
    error_message = "Authentik should use PostgreSQL database"
  }
}

run "authentik_redis_host" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = local.authentik_config.redis_host == "authentik-redis"
    error_message = "Authentik Redis host should be authentik-redis"
  }
}

# -----------------------------------------------------------------------------
# Authentik Bootstrap Tests
# -----------------------------------------------------------------------------

run "authentik_bootstrap_email_configurable" {
  command = plan

  variables {
    authentik_enabled         = true
    authentik_bootstrap_email = "admin@mylab.local"
  }

  assert {
    condition     = local.authentik_config.bootstrap_email == "admin@mylab.local"
    error_message = "Authentik bootstrap email should be configurable"
  }
}

run "authentik_bootstrap_email_default" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = local.authentik_config.bootstrap_email == "admin@home.arpa"
    error_message = "Authentik bootstrap email should default to admin@domain"
  }
}

# -----------------------------------------------------------------------------
# Authentik Components Tests
# -----------------------------------------------------------------------------

run "authentik_server_in_services" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "authentik-server")
    error_message = "Authentik server should be in Docker Compose services"
  }
}

run "authentik_worker_in_services" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "authentik-worker")
    error_message = "Authentik worker should be in Docker Compose services"
  }
}

run "authentik_db_in_services" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "authentik-db")
    error_message = "Authentik DB should be in Docker Compose services"
  }
}

run "authentik_redis_in_services" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "authentik-redis")
    error_message = "Authentik Redis should be in Docker Compose services"
  }
}

# -----------------------------------------------------------------------------
# Authentik Integration Tests
# -----------------------------------------------------------------------------

run "authentik_traefik_route_exists" {
  command = plan

  variables {
    authentik_enabled = true
    traefik_enabled   = true
  }

  assert {
    condition     = contains(keys(local.traefik_routes), "auth")
    error_message = "Traefik should have a route for Authentik"
  }
}

run "authentik_traefik_route_correct_port" {
  command = plan

  variables {
    authentik_enabled = true
    traefik_enabled   = true
  }

  assert {
    condition     = local.traefik_routes.auth.port == 9000
    error_message = "Authentik Traefik route should point to port 9000"
  }
}

run "authentik_volumes_configured" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_volumes, "authentik-db-data")
    error_message = "Authentik DB data volume should be configured"
  }

  assert {
    condition     = contains(local.docker_compose_volumes, "authentik-redis-data")
    error_message = "Authentik Redis data volume should be configured"
  }
}

# -----------------------------------------------------------------------------
# OAuth2/OIDC Provider Configuration Tests
# -----------------------------------------------------------------------------

run "authentik_oauth_providers_generated" {
  command = plan

  variables {
    authentik_enabled = true
    harbor_enabled    = true
  }

  assert {
    condition     = contains(keys(local.authentik_oauth_providers), "harbor")
    error_message = "Authentik should have OAuth provider config for Harbor"
  }
}

run "authentik_oauth_provider_grafana" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = contains(keys(local.authentik_oauth_providers), "grafana")
    error_message = "Authentik should have OAuth provider config for Grafana"
  }
}

run "authentik_oauth_grafana_redirect_uri" {
  command = plan

  variables {
    authentik_enabled = true
    traefik_enabled   = true
  }

  assert {
    condition     = local.authentik_oauth_providers.grafana.redirect_uri == "https://grafana.home.arpa/login/generic_oauth"
    error_message = "Grafana OAuth redirect URI should be correct"
  }
}

run "authentik_oauth_harbor_redirect_uri" {
  command = plan

  variables {
    authentik_enabled = true
    harbor_enabled    = true
    traefik_enabled   = true
  }

  assert {
    condition     = local.authentik_oauth_providers.harbor.redirect_uri == "https://registry.home.arpa/c/oidc/callback"
    error_message = "Harbor OIDC redirect URI should be correct"
  }
}

# -----------------------------------------------------------------------------
# Authentik Outposts Tests (Forward Auth)
# -----------------------------------------------------------------------------

run "authentik_outpost_traefik_configured" {
  command = plan

  variables {
    authentik_enabled = true
    traefik_enabled   = true
  }

  assert {
    condition     = local.authentik_config.outpost_traefik == true
    error_message = "Authentik should have Traefik outpost configured"
  }
}

run "authentik_forward_auth_middleware" {
  command = plan

  variables {
    authentik_enabled = true
    traefik_enabled   = true
  }

  assert {
    condition     = local.authentik_config.forward_auth_url == "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
    error_message = "Authentik forward auth URL should be correct"
  }
}

# -----------------------------------------------------------------------------
# Authentik Email Tests
# -----------------------------------------------------------------------------

run "authentik_email_disabled_by_default" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = local.authentik_config.email_enabled == false
    error_message = "Authentik email should be disabled by default"
  }
}

# -----------------------------------------------------------------------------
# Authentik Security Tests
# -----------------------------------------------------------------------------

run "authentik_error_reporting_disabled" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = local.authentik_config.error_reporting == false
    error_message = "Authentik error reporting should be disabled (privacy)"
  }
}

run "authentik_avatars_disabled" {
  command = plan

  variables {
    authentik_enabled = true
  }

  # Disable Gravatar for privacy
  assert {
    condition     = local.authentik_config.avatars == "none"
    error_message = "Authentik avatars should be disabled for privacy"
  }
}
