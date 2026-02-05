# =============================================================================
# Module Monitoring Stack - Tests Alertmanager
# =============================================================================
# Verifie la configuration Alertmanager et les alertes Telegram
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
# Telegram enabled by default
# -----------------------------------------------------------------------------

run "telegram_enabled_by_default" {
  command = plan

  assert {
    condition     = var.telegram_enabled == true
    error_message = "telegram_enabled should be true by default"
  }

  assert {
    condition     = local.alertmanager_config != ""
    error_message = "Alertmanager config should always be generated"
  }
}

# -----------------------------------------------------------------------------
# Telegram disabled - alertmanager config still generated
# -----------------------------------------------------------------------------

run "alertmanager_config_with_telegram_disabled" {
  command = plan

  variables {
    telegram_enabled = false
  }

  assert {
    condition     = local.alertmanager_config != ""
    error_message = "Alertmanager config should be generated even with Telegram disabled"
  }
}

# -----------------------------------------------------------------------------
# Alertmanager URL with Traefik
# -----------------------------------------------------------------------------

run "alertmanager_url_with_traefik" {
  command = plan

  variables {
    traefik_enabled = true
    domain_suffix   = "home.lan"
  }

  assert {
    condition     = output.urls.alertmanager == "http://alertmanager.home.lan"
    error_message = "Alertmanager URL should use domain with Traefik"
  }
}

# -----------------------------------------------------------------------------
# Alertmanager URL without Traefik
# -----------------------------------------------------------------------------

run "alertmanager_url_without_traefik" {
  command = plan

  variables {
    traefik_enabled = false
  }

  assert {
    condition     = output.urls.alertmanager == "http://192.168.1.50:9093"
    error_message = "Alertmanager URL should use IP:port without Traefik"
  }
}

# -----------------------------------------------------------------------------
# Tooling alerts integration
# -----------------------------------------------------------------------------

run "tooling_alerts_with_tooling_enabled" {
  command = plan

  variables {
    tooling_enabled = true
    tooling_ip      = "192.168.1.100"
  }

  assert {
    condition     = local.tooling_alerts != ""
    error_message = "Tooling alerts should be loaded when tooling enabled"
  }
}

run "tooling_alerts_with_tooling_disabled" {
  command = plan

  variables {
    tooling_enabled = false
  }

  assert {
    condition     = local.tooling_alerts == ""
    error_message = "Tooling alerts should be empty when tooling disabled"
  }
}
