# =============================================================================
# Module Monitoring Stack - Tests Uptime Kuma
# =============================================================================
# Verifie la configuration Uptime Kuma
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
# Uptime Kuma enabled by default
# -----------------------------------------------------------------------------

run "uptime_kuma_enabled_by_default" {
  command = plan

  assert {
    condition     = output.uptime_kuma_enabled == true
    error_message = "uptime_kuma_enabled should be true by default"
  }

  assert {
    condition     = output.uptime_kuma_url == "http://192.168.1.50:3001"
    error_message = "uptime_kuma_url should return IP:3001"
  }
}

# -----------------------------------------------------------------------------
# Uptime Kuma URL in urls output (with Traefik)
# -----------------------------------------------------------------------------

run "uptime_kuma_url_with_traefik" {
  command = plan

  variables {
    traefik_enabled     = true
    uptime_kuma_enabled = true
    domain_suffix       = "home.lan"
  }

  assert {
    condition     = output.urls.uptime == "http://uptime.home.lan"
    error_message = "Uptime Kuma URL should use domain with Traefik"
  }
}

# -----------------------------------------------------------------------------
# Uptime Kuma URL in urls output (without Traefik)
# -----------------------------------------------------------------------------

run "uptime_kuma_url_without_traefik" {
  command = plan

  variables {
    traefik_enabled     = false
    uptime_kuma_enabled = true
  }

  assert {
    condition     = output.urls.uptime == "http://192.168.1.50:3001"
    error_message = "Uptime Kuma URL should use IP:port without Traefik"
  }
}

# -----------------------------------------------------------------------------
# Uptime Kuma disabled
# -----------------------------------------------------------------------------

run "uptime_kuma_disabled" {
  command = plan

  variables {
    uptime_kuma_enabled = false
  }

  assert {
    condition     = output.uptime_kuma_enabled == false
    error_message = "uptime_kuma_enabled should be false when disabled"
  }

  assert {
    condition     = output.uptime_kuma_url == ""
    error_message = "uptime_kuma_url should be empty when disabled"
  }

  # urls should not contain uptime key when disabled
  assert {
    condition     = !can(output.urls.uptime)
    error_message = "urls should not contain uptime when disabled"
  }
}
