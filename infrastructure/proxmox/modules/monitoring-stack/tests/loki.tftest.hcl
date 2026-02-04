# =============================================================================
# Module Monitoring Stack - Tests Loki
# =============================================================================
# Verifie la configuration Loki et Promtail
# =============================================================================

mock_provider "proxmox" {}

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
# Loki outputs (enabled by default)
# -----------------------------------------------------------------------------

run "loki_enabled_by_default" {
  command = plan

  assert {
    condition     = output.loki_enabled == true
    error_message = "loki_enabled should be true by default"
  }

  assert {
    condition     = output.loki_url == "http://192.168.1.50:3100"
    error_message = "loki_url should return IP:3100"
  }
}

# -----------------------------------------------------------------------------
# Loki URL in urls output (with Traefik)
# -----------------------------------------------------------------------------

run "loki_url_with_traefik" {
  command = plan

  variables {
    traefik_enabled = true
    loki_enabled    = true
    domain_suffix   = "home.lan"
  }

  assert {
    condition     = output.urls.loki == "http://loki.home.lan"
    error_message = "Loki URL should use domain with Traefik"
  }
}

# -----------------------------------------------------------------------------
# Loki URL in urls output (without Traefik)
# -----------------------------------------------------------------------------

run "loki_url_without_traefik" {
  command = plan

  variables {
    traefik_enabled = false
    loki_enabled    = true
  }

  assert {
    condition     = output.urls.loki == "http://192.168.1.50:3100"
    error_message = "Loki URL should use IP:port without Traefik"
  }
}

# -----------------------------------------------------------------------------
# Loki disabled
# -----------------------------------------------------------------------------

run "loki_disabled" {
  command = plan

  variables {
    loki_enabled = false
  }

  assert {
    condition     = output.loki_enabled == false
    error_message = "loki_enabled should be false when disabled"
  }

  assert {
    condition     = output.loki_url == ""
    error_message = "loki_url should be empty when disabled"
  }

  # urls should not contain loki key when disabled
  assert {
    condition     = !can(output.urls.loki)
    error_message = "urls should not contain loki when disabled"
  }
}

# -----------------------------------------------------------------------------
# Loki retention configuration
# -----------------------------------------------------------------------------

run "loki_custom_retention" {
  command = plan

  variables {
    loki_enabled        = true
    loki_retention_days = 14
  }

  assert {
    condition     = output.loki_enabled == true
    error_message = "loki_enabled should be true"
  }
}
