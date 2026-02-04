# =============================================================================
# Module VM - Tests Promtail
# =============================================================================
# Verifie la configuration Promtail sur les VMs
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  name        = "test-vm"
  target_node = "pve-test"
  template_id = 9000
  ip_address  = "192.168.1.100/24"
  gateway     = "192.168.1.1"
  ssh_keys    = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
}

# -----------------------------------------------------------------------------
# Promtail disabled by default
# -----------------------------------------------------------------------------

run "promtail_disabled_by_default" {
  command = plan

  assert {
    condition     = var.install_promtail == false
    error_message = "install_promtail should be false by default"
  }
}

# -----------------------------------------------------------------------------
# Promtail enabled creates cloud_config
# -----------------------------------------------------------------------------

run "promtail_enabled_creates_cloud_config" {
  command = plan

  variables {
    install_promtail = true
    loki_url         = "http://192.168.1.51:3100"
  }

  assert {
    condition     = length(proxmox_virtual_environment_file.cloud_config) == 1
    error_message = "Cloud config should be created when Promtail is enabled"
  }
}

# -----------------------------------------------------------------------------
# Promtail requires loki_url (with all defaults disabled)
# -----------------------------------------------------------------------------

run "promtail_without_loki_url_no_extra_cloud_config" {
  command = plan

  variables {
    install_promtail      = true
    loki_url              = ""
    install_qemu_agent    = false
    install_docker        = false
    auto_security_updates = false
  }

  # Without other features enabled and no valid loki_url, no cloud_config should be created
  assert {
    condition     = length(proxmox_virtual_environment_file.cloud_config) == 0
    error_message = "Cloud config should not be created when Promtail is enabled but loki_url is empty (and no other features)"
  }
}

# -----------------------------------------------------------------------------
# Promtail with all options
# -----------------------------------------------------------------------------

run "promtail_with_docker_and_agent" {
  command = plan

  variables {
    install_promtail   = true
    loki_url           = "http://192.168.1.51:3100"
    install_docker     = true
    install_qemu_agent = true
  }

  assert {
    condition     = length(proxmox_virtual_environment_file.cloud_config) == 1
    error_message = "Cloud config should be created"
  }
}
