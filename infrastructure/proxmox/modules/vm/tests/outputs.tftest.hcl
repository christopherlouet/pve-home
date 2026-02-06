# =============================================================================
# Module VM - Tests des outputs
# =============================================================================
# Verifie que tous les outputs sont correctement generes.
# Note: vm_id, ipv4_address et mac_address dependent du provider et ne sont
# pas testables en plan avec mock_provider.
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
# Output: name
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

# -----------------------------------------------------------------------------
# Output: node_name
# -----------------------------------------------------------------------------

run "output_node_name_default" {
  command = plan

  assert {
    condition     = output.node_name == "pve-test"
    error_message = "node_name output should match target_node input"
  }
}

run "output_node_name_custom" {
  command = plan

  variables {
    target_node = "pve-prod"
  }

  assert {
    condition     = output.node_name == "pve-prod"
    error_message = "node_name output should reflect custom target_node"
  }
}

# -----------------------------------------------------------------------------
# Output: verification avec differents inputs
# -----------------------------------------------------------------------------

run "output_name_with_hyphen" {
  command = plan

  variables {
    name = "my-web-server"
  }

  assert {
    condition     = output.name == "my-web-server"
    error_message = "name output should handle hyphens correctly"
  }
}

run "output_name_with_numbers" {
  command = plan

  variables {
    name = "vm01"
  }

  assert {
    condition     = output.name == "vm01"
    error_message = "name output should handle numbers correctly"
  }
}

run "output_node_name_with_different_nodes" {
  command = plan

  variables {
    target_node = "pve-lab"
  }

  assert {
    condition     = output.node_name == "pve-lab"
    error_message = "node_name should reflect the target node for lab environment"
  }
}

run "output_name_preserves_case" {
  command = plan

  variables {
    name = "MyVM"
  }

  assert {
    condition     = output.name == "MyVM"
    error_message = "name output should preserve case"
  }
}

# -----------------------------------------------------------------------------
# Output: ssh_command
# -----------------------------------------------------------------------------

run "output_ssh_command" {
  command = plan

  assert {
    condition     = output.ssh_command == "ssh ubuntu@192.168.1.100"
    error_message = "ssh_command should use default username and strip CIDR from ip_address"
  }
}

run "output_ssh_command_custom_user" {
  command = plan

  variables {
    username = "admin"
  }

  assert {
    condition     = output.ssh_command == "ssh admin@192.168.1.100"
    error_message = "ssh_command should use custom username"
  }
}
