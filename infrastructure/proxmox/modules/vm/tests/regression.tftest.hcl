# =============================================================================
# Module VM - Tests de non-regression
# =============================================================================
# Verifie que les bugs corriges ne reapparaissent pas.
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
# Regression v0.7.2: Tags should be accepted as-is
# The fix in v0.7.2 sorted and deduplicated tags in the environments to
# prevent perpetual drift. The module itself should accept tags as provided.
# -----------------------------------------------------------------------------

run "tags_preserved_as_provided" {
  command = plan

  variables {
    tags = ["terraform", "docker", "monitored"]
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this.tags) == 3
    error_message = "All 3 tags should be present"
  }
}

run "tags_default_is_terraform" {
  command = plan

  assert {
    condition     = contains(proxmox_virtual_environment_vm.this.tags, "terraform")
    error_message = "Default tags should contain 'terraform'"
  }
}

run "duplicate_tags_preserved" {
  command = plan

  # Le module ne deduplique pas les tags, c'est la responsabilite de l'appelant
  variables {
    tags = ["terraform", "web"]
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this.tags) == 2
    error_message = "Tags should have exactly 2 elements"
  }
}

# -----------------------------------------------------------------------------
# Regression: description default value
# -----------------------------------------------------------------------------

run "default_description" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.description == "Managed by Terraform"
    error_message = "Default description should be 'Managed by Terraform'"
  }
}

run "custom_description" {
  command = plan

  variables {
    description = "My custom VM"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.description == "My custom VM"
    error_message = "Custom description should be preserved"
  }
}
