# =============================================================================
# Tests - Tooling Stack Integration
# =============================================================================
# Tests for tooling dashboards (Step-ca, Harbor, Authentik) integration
# Phase 5: Monitoring Integration (T032)
# =============================================================================

mock_provider "proxmox" {}
mock_provider "tls" {}

# -----------------------------------------------------------------------------
# Variables communes
# -----------------------------------------------------------------------------

variables {
  name                   = "monitoring-test"
  target_node            = "pve1"
  template_id            = 9000
  ip_address             = "192.168.1.50"
  gateway                = "192.168.1.1"
  ssh_keys               = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample test@test"]
  grafana_admin_password = "test-password-123" # gitleaks:allow
  proxmox_nodes = [
    {
      name        = "pve1"
      ip          = "192.168.1.10"
      token_value = "test-token-123"
    }
  ]
}

# -----------------------------------------------------------------------------
# Test: Tooling variables defaults
# -----------------------------------------------------------------------------

run "tooling_disabled_by_default" {
  command = plan

  assert {
    condition     = var.tooling_enabled == false
    error_message = "tooling_enabled should default to false"
  }

  assert {
    condition     = var.tooling_step_ca_enabled == false
    error_message = "tooling_step_ca_enabled should default to false"
  }

  assert {
    condition     = var.tooling_harbor_enabled == false
    error_message = "tooling_harbor_enabled should default to false"
  }

  assert {
    condition     = var.tooling_authentik_enabled == false
    error_message = "tooling_authentik_enabled should default to false"
  }

  assert {
    condition     = var.tooling_traefik_enabled == false
    error_message = "tooling_traefik_enabled should default to false"
  }
}

# -----------------------------------------------------------------------------
# Test: Tooling IP validation
# -----------------------------------------------------------------------------

run "tooling_ip_valid" {
  command = plan

  variables {
    tooling_enabled = true
    tooling_ip      = "192.168.1.100"
  }

  assert {
    condition     = var.tooling_ip == "192.168.1.100"
    error_message = "tooling_ip should accept valid IPv4 address"
  }
}

run "tooling_ip_invalid" {
  command = plan

  variables {
    tooling_enabled = true
    tooling_ip      = "not-an-ip"
  }

  expect_failures = [var.tooling_ip]
}

# Note: tooling_ip validation is conditional - empty string is allowed
# The scrape config simply won't be generated if tooling_ip is empty
run "tooling_ip_empty_generates_no_scrape_config" {
  command = plan

  variables {
    tooling_enabled = true
    tooling_ip      = ""
  }

  assert {
    condition     = local.tooling_scrape_config == ""
    error_message = "Tooling scrape config should be empty when tooling_ip is empty"
  }
}

# -----------------------------------------------------------------------------
# Test: Dashboard locals when tooling enabled
# -----------------------------------------------------------------------------

run "tooling_dashboards_loaded_when_enabled" {
  command = plan

  variables {
    tooling_enabled           = true
    tooling_ip                = "192.168.1.100"
    tooling_step_ca_enabled   = true
    tooling_harbor_enabled    = true
    tooling_authentik_enabled = true
  }

  assert {
    condition     = local.dashboard_step_ca != ""
    error_message = "Step-ca dashboard should be loaded when step_ca enabled"
  }

  assert {
    condition     = local.dashboard_harbor != ""
    error_message = "Harbor dashboard should be loaded when harbor enabled"
  }

  assert {
    condition     = local.dashboard_authentik != ""
    error_message = "Authentik dashboard should be loaded when authentik enabled"
  }
}

run "tooling_dashboards_empty_when_disabled" {
  command = plan

  variables {
    tooling_enabled = false
  }

  assert {
    condition     = local.dashboard_step_ca == ""
    error_message = "Step-ca dashboard should be empty when tooling disabled"
  }

  assert {
    condition     = local.dashboard_harbor == ""
    error_message = "Harbor dashboard should be empty when tooling disabled"
  }

  assert {
    condition     = local.dashboard_authentik == ""
    error_message = "Authentik dashboard should be empty when tooling disabled"
  }
}

# -----------------------------------------------------------------------------
# Test: Tooling alerts loaded when enabled
# -----------------------------------------------------------------------------

run "tooling_alerts_loaded_when_enabled" {
  command = plan

  variables {
    tooling_enabled           = true
    tooling_ip                = "192.168.1.100"
    tooling_step_ca_enabled   = true
    tooling_harbor_enabled    = true
    tooling_authentik_enabled = true
    tooling_traefik_enabled   = true
  }

  assert {
    condition     = local.tooling_alerts != ""
    error_message = "Tooling alerts should be loaded when tooling enabled"
  }
}

run "tooling_alerts_empty_when_disabled" {
  command = plan

  variables {
    tooling_enabled = false
  }

  assert {
    condition     = local.tooling_alerts == ""
    error_message = "Tooling alerts should be empty when tooling disabled"
  }
}

# -----------------------------------------------------------------------------
# Test: Tooling scrape config generated when enabled
# -----------------------------------------------------------------------------

run "tooling_scrape_config_generated_when_enabled" {
  command = plan

  variables {
    tooling_enabled           = true
    tooling_ip                = "192.168.1.100"
    tooling_step_ca_enabled   = true
    tooling_harbor_enabled    = true
    tooling_authentik_enabled = true
    tooling_traefik_enabled   = true
  }

  assert {
    condition     = local.tooling_scrape_config != ""
    error_message = "Tooling scrape config should be generated when tooling enabled"
  }

  assert {
    condition     = can(regex("step-ca", local.tooling_scrape_config))
    error_message = "Tooling scrape config should include step-ca job when enabled"
  }

  assert {
    condition     = can(regex("harbor", local.tooling_scrape_config))
    error_message = "Tooling scrape config should include harbor job when enabled"
  }

  assert {
    condition     = can(regex("authentik", local.tooling_scrape_config))
    error_message = "Tooling scrape config should include authentik job when enabled"
  }

  assert {
    condition     = can(regex("traefik-tooling", local.tooling_scrape_config))
    error_message = "Tooling scrape config should include traefik-tooling job when enabled"
  }
}

run "tooling_scrape_config_empty_when_disabled" {
  command = plan

  variables {
    tooling_enabled = false
  }

  assert {
    condition     = local.tooling_scrape_config == ""
    error_message = "Tooling scrape config should be empty when tooling disabled"
  }
}

# -----------------------------------------------------------------------------
# Test: Individual service scrape config
# -----------------------------------------------------------------------------

run "only_step_ca_scrape_when_only_step_ca_enabled" {
  command = plan

  variables {
    tooling_enabled           = true
    tooling_ip                = "192.168.1.100"
    tooling_step_ca_enabled   = true
    tooling_harbor_enabled    = false
    tooling_authentik_enabled = false
    tooling_traefik_enabled   = false
  }

  assert {
    condition     = can(regex("step-ca", local.tooling_scrape_config))
    error_message = "Scrape config should include step-ca when enabled"
  }

  assert {
    condition     = !can(regex("job_name: 'harbor'", local.tooling_scrape_config))
    error_message = "Scrape config should not include harbor when disabled"
  }

  assert {
    condition     = !can(regex("job_name: 'authentik'", local.tooling_scrape_config))
    error_message = "Scrape config should not include authentik when disabled"
  }
}

# -----------------------------------------------------------------------------
# Test: Cloud-init includes tooling folder creation
# -----------------------------------------------------------------------------

run "cloud_init_creates_tooling_folder_when_enabled" {
  command = plan

  variables {
    tooling_enabled = true
    tooling_ip      = "192.168.1.100"
  }

  assert {
    condition     = can(regex("grafana/dashboards/\\{.*tooling", local.monitoring_setup_script)) || can(regex("mkdir.*tooling", local.monitoring_setup_script))
    error_message = "Setup script should create tooling dashboards folder when enabled"
  }
}

# -----------------------------------------------------------------------------
# Test: Provisioning config includes Tooling folder when enabled
# -----------------------------------------------------------------------------

run "provisioning_includes_tooling_folder_when_enabled" {
  command = plan

  variables {
    tooling_enabled = true
    tooling_ip      = "192.168.1.100"
  }

  assert {
    condition     = can(regex("name: 'Tooling'", local.monitoring_setup_script)) || can(regex("folder: 'Tooling'", local.monitoring_setup_script))
    error_message = "Provisioning config should include Tooling folder when enabled"
  }
}

# -----------------------------------------------------------------------------
# Test: Conditional tooling services
# -----------------------------------------------------------------------------

run "tooling_master_switch_disables_all" {
  command = plan

  variables {
    tooling_enabled           = false
    tooling_step_ca_enabled   = true
    tooling_harbor_enabled    = true
    tooling_authentik_enabled = true
    tooling_traefik_enabled   = true
  }

  assert {
    condition     = local.dashboard_step_ca == ""
    error_message = "Step-ca dashboard should be empty when tooling master switch is off"
  }

  assert {
    condition     = local.tooling_scrape_config == ""
    error_message = "Scrape config should be empty when tooling master switch is off"
  }
}
