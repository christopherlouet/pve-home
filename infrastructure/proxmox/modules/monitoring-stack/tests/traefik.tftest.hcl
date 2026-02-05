# =============================================================================
# Module Monitoring Stack - Tests Traefik
# =============================================================================
# Verifie la configuration Traefik (reverse proxy)
# =============================================================================

mock_provider "proxmox" {}
mock_provider "tls" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  name        = "test-monitoring"
  target_node = "pve-test"
  template_id = 9000
  ip_address  = "192.168.1.50"
  gateway     = "192.168.1.1"
  ssh_keys    = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]

  grafana_admin_password = "test-password" # gitleaks:allow

  proxmox_nodes = [
    {
      name        = "pve-prod"
      ip          = "192.168.1.100"
      token_value = "test-token-value"
    }
  ]
}

# -----------------------------------------------------------------------------
# Traefik enabled (default)
# -----------------------------------------------------------------------------

run "traefik_enabled_by_default" {
  command = plan

  assert {
    condition     = output.traefik_enabled == true
    error_message = "traefik_enabled should be true by default"
  }

  assert {
    condition     = local.traefik_static_config != ""
    error_message = "Traefik static config should be generated when enabled"
  }

  assert {
    condition     = local.traefik_dynamic_config != ""
    error_message = "Traefik dynamic config should be generated when enabled"
  }
}

# -----------------------------------------------------------------------------
# Traefik disabled
# -----------------------------------------------------------------------------

run "traefik_disabled_no_config" {
  command = plan

  variables {
    traefik_enabled = false
  }

  assert {
    condition     = output.traefik_enabled == false
    error_message = "traefik_enabled should be false when disabled"
  }

  assert {
    condition     = local.traefik_static_config == ""
    error_message = "Traefik static config should be empty when disabled"
  }

  assert {
    condition     = local.traefik_dynamic_config == ""
    error_message = "Traefik dynamic config should be empty when disabled"
  }
}

# -----------------------------------------------------------------------------
# Traefik URLs with domain suffix
# -----------------------------------------------------------------------------

run "traefik_urls_with_domain" {
  command = plan

  variables {
    traefik_enabled = true
    domain_suffix   = "mylab.local"
  }

  assert {
    condition     = output.urls.traefik == "http://traefik.mylab.local"
    error_message = "Traefik URL should use custom domain suffix"
  }

  assert {
    condition     = output.urls.grafana == "http://grafana.mylab.local"
    error_message = "Grafana URL should use custom domain suffix with Traefik"
  }

  assert {
    condition     = output.urls.prometheus == "http://prometheus.mylab.local"
    error_message = "Prometheus URL should use custom domain suffix with Traefik"
  }

  assert {
    condition     = output.domain_suffix == "mylab.local"
    error_message = "domain_suffix output should match input"
  }
}

# -----------------------------------------------------------------------------
# Traefik with TLS
# -----------------------------------------------------------------------------

run "traefik_with_tls" {
  command = plan

  variables {
    traefik_enabled = true
    tls_enabled     = true
    domain_suffix   = "home.lan"
  }

  assert {
    condition     = local.traefik_static_config != ""
    error_message = "Traefik static config should be generated with TLS"
  }

  assert {
    condition     = local.traefik_dynamic_config != ""
    error_message = "Traefik dynamic config should be generated with TLS"
  }
}

# -----------------------------------------------------------------------------
# URLs fallback to IP:port without Traefik
# -----------------------------------------------------------------------------

run "urls_fallback_without_traefik" {
  command = plan

  variables {
    traefik_enabled = false
  }

  assert {
    condition     = output.urls.prometheus == "http://192.168.1.50:9090"
    error_message = "Prometheus URL should use IP:port without Traefik"
  }

  assert {
    condition     = output.urls.grafana == "http://192.168.1.50:3000"
    error_message = "Grafana URL should use IP:port without Traefik"
  }

  assert {
    condition     = output.urls.alertmanager == "http://192.168.1.50:9093"
    error_message = "Alertmanager URL should use IP:port without Traefik"
  }
}
