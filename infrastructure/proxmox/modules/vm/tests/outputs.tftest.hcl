# =============================================================================
# Module VM - Tests des outputs
# =============================================================================
# Verifie que tous les outputs sont correctement generes.
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
# Outputs verification
# -----------------------------------------------------------------------------

run "output_name" {
  command = plan

  assert {
    condition     = output.name == "test-vm"
    error_message = "name output should match input"
  }
}

run "output_with_custom_name" {
  command = plan

  variables {
    name = "web-prod"
  }

  assert {
    condition     = output.name == "web-prod"
    error_message = "name output should reflect custom value"
  }
}
