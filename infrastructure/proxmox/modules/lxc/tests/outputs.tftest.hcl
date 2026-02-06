# =============================================================================
# Module LXC - Tests des outputs
# =============================================================================
# Verifie que tous les outputs sont correctement generes.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  hostname         = "test-lxc"
  target_node      = "pve-test"
  template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  ip_address       = "192.168.1.50/24"
  gateway          = "192.168.1.1"
  ssh_keys         = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
}

# -----------------------------------------------------------------------------
# Outputs verification
# -----------------------------------------------------------------------------

run "output_hostname" {
  command = plan

  assert {
    condition     = output.hostname == "test-lxc"
    error_message = "hostname output should match input"
  }
}

run "output_ipv4_address" {
  command = plan

  assert {
    condition     = output.ipv4_address == "192.168.1.50/24"
    error_message = "ipv4_address output should match input"
  }
}

run "output_different_ip" {
  command = plan

  variables {
    ip_address = "10.0.0.1/16"
  }

  assert {
    condition     = output.ipv4_address == "10.0.0.1/16"
    error_message = "ipv4_address output should reflect custom IP"
  }
}

run "output_different_hostname" {
  command = plan

  variables {
    hostname = "dns01"
  }

  assert {
    condition     = output.hostname == "dns01"
    error_message = "hostname output should reflect custom value"
  }
}
