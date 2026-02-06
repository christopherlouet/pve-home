# =============================================================================
# Module Monitoring Stack - Tests des outputs
# =============================================================================
# Verifie que tous les outputs sont correctement generes, en particulier
# les outputs conditionnels (loki, uptime_kuma, tooling).
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
# Base outputs
# -----------------------------------------------------------------------------

run "output_ip_address" {
  command = plan

  assert {
    condition     = output.ip_address == "192.168.1.50"
    error_message = "ip_address output should match input"
  }
}

run "output_ssh_command" {
  command = plan

  assert {
    condition     = output.ssh_command == "ssh ubuntu@192.168.1.50"
    error_message = "ssh_command should use default username and ip"
  }
}

run "output_ssh_command_custom_user" {
  command = plan

  variables {
    username = "admin"
  }

  assert {
    condition     = output.ssh_command == "ssh admin@192.168.1.50"
    error_message = "ssh_command should use custom username"
  }
}

run "output_domain_suffix" {
  command = plan

  variables {
    domain_suffix = "home.lab"
  }

  assert {
    condition     = output.domain_suffix == "home.lab"
    error_message = "domain_suffix output should match input"
  }
}

# -----------------------------------------------------------------------------
# Conditional outputs - loki
# -----------------------------------------------------------------------------

run "output_loki_enabled_default" {
  command = plan

  assert {
    condition     = output.loki_enabled == true
    error_message = "loki_enabled should be true by default"
  }
}

run "output_loki_url_when_enabled" {
  command = plan

  assert {
    condition     = output.loki_url == "http://192.168.1.50:3100"
    error_message = "loki_url should be set when enabled"
  }
}

run "output_loki_url_when_disabled" {
  command = plan

  variables {
    loki_enabled = false
  }

  assert {
    condition     = output.loki_url == ""
    error_message = "loki_url should be empty when disabled"
  }

  assert {
    condition     = output.loki_enabled == false
    error_message = "loki_enabled should be false"
  }
}

# -----------------------------------------------------------------------------
# Conditional outputs - uptime_kuma
# -----------------------------------------------------------------------------

run "output_uptime_kuma_url_when_enabled" {
  command = plan

  assert {
    condition     = output.uptime_kuma_url == "http://192.168.1.50:3001"
    error_message = "uptime_kuma_url should be set when enabled"
  }
}

run "output_uptime_kuma_url_when_disabled" {
  command = plan

  variables {
    uptime_kuma_enabled = false
  }

  assert {
    condition     = output.uptime_kuma_url == ""
    error_message = "uptime_kuma_url should be empty when disabled"
  }

  assert {
    condition     = output.uptime_kuma_enabled == false
    error_message = "uptime_kuma_enabled should be false"
  }
}

# -----------------------------------------------------------------------------
# Conditional outputs - tooling
# -----------------------------------------------------------------------------

run "output_tooling_disabled_by_default" {
  command = plan

  assert {
    condition     = output.tooling_enabled == false
    error_message = "tooling_enabled should be false by default"
  }

  assert {
    condition     = length(output.tooling_dashboards) == 0
    error_message = "tooling_dashboards should be empty when disabled"
  }
}

run "output_tooling_enabled" {
  command = plan

  variables {
    tooling_enabled = true
  }

  assert {
    condition     = output.tooling_enabled == true
    error_message = "tooling_enabled should be true"
  }

  assert {
    condition     = length(output.tooling_dashboards) > 0
    error_message = "tooling_dashboards should be populated when enabled"
  }
}

# -----------------------------------------------------------------------------
# URLs output structure (traefik enabled vs disabled)
# -----------------------------------------------------------------------------

run "output_urls_without_traefik" {
  command = plan

  variables {
    traefik_enabled = false
  }

  assert {
    condition     = output.urls.prometheus == "http://192.168.1.50:9090"
    error_message = "Prometheus URL should use IP:port without traefik"
  }

  assert {
    condition     = output.urls.grafana == "http://192.168.1.50:3000"
    error_message = "Grafana URL should use IP:port without traefik"
  }

  assert {
    condition     = output.traefik_enabled == false
    error_message = "traefik_enabled should be false"
  }
}

run "output_urls_with_traefik" {
  command = plan

  variables {
    traefik_enabled = true
    domain_suffix   = "home.lab"
  }

  assert {
    condition     = output.urls.grafana == "http://grafana.home.lab"
    error_message = "Grafana URL should use domain with traefik"
  }

  assert {
    condition     = output.urls.prometheus == "http://prometheus.home.lab"
    error_message = "Prometheus URL should use domain with traefik"
  }
}

# -----------------------------------------------------------------------------
# Scrape targets output
# -----------------------------------------------------------------------------

run "output_scrape_targets_populated" {
  command = plan

  assert {
    condition     = length(output.scrape_targets) > 0
    error_message = "scrape_targets should contain at least one target"
  }
}
