# =============================================================================
# Environnement Prod - Tests d'integration
# =============================================================================
# Verifie la coherence de la configuration : variables, modules, outputs.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables minimales valides
# -----------------------------------------------------------------------------

variables {
  proxmox_endpoint  = "https://192.168.1.100:8006"
  proxmox_api_token = "test@pam!test=00000000-0000-0000-0000-000000000000" # gitleaks:allow
  network_gateway   = "192.168.1.1"
  ssh_public_keys   = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  lxc_template      = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  default_node      = "pve-test"
}

# -----------------------------------------------------------------------------
# Plan reussit sans VMs ni conteneurs (configuration vide)
# -----------------------------------------------------------------------------

run "plan_with_empty_config" {
  command = plan

  variables {
    vms        = {}
    containers = {}
  }

  assert {
    condition     = var.environment == "prod"
    error_message = "Environment should default to prod"
  }
}

# -----------------------------------------------------------------------------
# Plan reussit avec une VM
# -----------------------------------------------------------------------------

run "plan_with_one_vm" {
  command = plan

  variables {
    vms = {
      web = {
        ip     = "192.168.1.10"
        cores  = 2
        memory = 2048
        disk   = 20
        tags   = ["web"]
      }
    }
    containers = {}
  }
}

# -----------------------------------------------------------------------------
# Plan reussit avec un conteneur LXC
# -----------------------------------------------------------------------------

run "plan_with_one_container" {
  command = plan

  variables {
    vms = {}
    containers = {
      dns = {
        ip     = "192.168.1.20"
        cores  = 1
        memory = 512
        disk   = 8
        tags   = ["dns"]
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Defaults verification
# -----------------------------------------------------------------------------

run "defaults_are_correct" {
  command = plan

  variables {
    vms        = {}
    containers = {}
  }

  assert {
    condition     = var.network_bridge == "vmbr0"
    error_message = "Default network_bridge should be vmbr0"
  }

  assert {
    condition     = var.default_datastore == "local-lvm"
    error_message = "Default datastore should be local-lvm"
  }

  assert {
    condition     = var.vm_template_id == 9000
    error_message = "Default vm_template_id should be 9000"
  }

  assert {
    condition     = var.proxmox_insecure == true
    error_message = "Default proxmox_insecure should be true"
  }
}

# -----------------------------------------------------------------------------
# Output structure - VMs
# -----------------------------------------------------------------------------

run "outputs_with_vms" {
  command = plan

  variables {
    vms = {
      web = {
        ip     = "192.168.1.10"
        cores  = 2
        memory = 2048
        disk   = 20
        tags   = ["web"]
      }
    }
    containers = {}
  }

  assert {
    condition     = length(output.vms) == 1
    error_message = "vms output should contain 1 VM"
  }

  assert {
    condition     = length(output.ssh_commands) == 1
    error_message = "ssh_commands should contain 1 entry"
  }
}

# -----------------------------------------------------------------------------
# Output structure - Empty
# -----------------------------------------------------------------------------

run "outputs_empty_when_no_resources" {
  command = plan

  variables {
    vms        = {}
    containers = {}
  }

  assert {
    condition     = length(output.vms) == 0
    error_message = "vms output should be empty map"
  }

  assert {
    condition     = length(output.containers) == 0
    error_message = "containers output should be empty map"
  }

  assert {
    condition     = length(output.ssh_commands) == 0
    error_message = "ssh_commands output should be empty map"
  }
}
