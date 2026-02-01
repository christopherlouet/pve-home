# =============================================================================
# Module LXC - Tests de non-regression
# =============================================================================
# Verifie que les bugs corriges ne reapparaissent pas.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  hostname         = "test-lxc"
  target_node      = "pve-test"
  template_file_id = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  ip_address       = "192.168.1.100/24"
  gateway          = "192.168.1.1"
  ssh_keys         = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
}

# -----------------------------------------------------------------------------
# Regression v0.7.2: Tags should be preserved via concat
# The module uses concat(var.tags, local.expiration_tag) to merge tags.
# Tags provided by the caller must be preserved as-is.
# -----------------------------------------------------------------------------

run "tags_preserved_as_provided" {
  command = plan

  variables {
    tags = ["terraform", "web", "production"]
  }

  assert {
    condition     = length(proxmox_virtual_environment_container.this.tags) == 3
    error_message = "All 3 provided tags should be present"
  }

  assert {
    condition     = contains(proxmox_virtual_environment_container.this.tags, "terraform")
    error_message = "Tag 'terraform' should be preserved"
  }

  assert {
    condition     = contains(proxmox_virtual_environment_container.this.tags, "web")
    error_message = "Tag 'web' should be preserved"
  }
}

# -----------------------------------------------------------------------------
# Regression v0.7.2: Default description = "Managed by Terraform"
# -----------------------------------------------------------------------------

run "default_description" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.description == "Managed by Terraform"
    error_message = "Default description should be 'Managed by Terraform'"
  }
}

run "custom_description_preserved" {
  command = plan

  variables {
    description = "My custom LXC container"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.description == "My custom LXC container"
    error_message = "Custom description should be preserved"
  }
}

# -----------------------------------------------------------------------------
# Regression v0.9.0: auto_security_updates conditional on os_type
# Security updates should only be enabled for ubuntu/debian, not other OS types.
# -----------------------------------------------------------------------------

run "security_updates_disabled_for_alpine" {
  command = plan

  variables {
    os_type               = "alpine"
    auto_security_updates = true
  }

  assert {
    condition     = length(terraform_data.security_updates) == 0
    error_message = "Security updates should not be provisioned for alpine"
  }
}

run "security_updates_enabled_for_ubuntu" {
  command = plan

  variables {
    os_type               = "ubuntu"
    auto_security_updates = true
  }

  assert {
    condition     = length(terraform_data.security_updates) == 1
    error_message = "Security updates should be provisioned for ubuntu with flag enabled"
  }
}
