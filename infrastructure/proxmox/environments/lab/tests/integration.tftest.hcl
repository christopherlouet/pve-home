# =============================================================================
# Environnement Lab - Tests d'integration
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
    condition     = var.environment == "lab"
    error_message = "Environment should default to lab"
  }
}

# -----------------------------------------------------------------------------
# Plan reussit avec une VM
# -----------------------------------------------------------------------------

run "plan_with_one_vm" {
  command = plan

  variables {
    vms = {
      test = {
        ip     = "192.168.1.10"
        cores  = 1
        memory = 1024
        disk   = 10
        tags   = ["test"]
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
      test-lxc = {
        ip      = "192.168.1.20"
        cores   = 1
        memory  = 256
        disk    = 4
        nesting = true
        tags    = ["test"]
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
}

# -----------------------------------------------------------------------------
# Output structure - VMs with expiration
# -----------------------------------------------------------------------------

run "outputs_with_lab_vm" {
  command = plan

  variables {
    vms = {
      dev = {
        ip     = "192.168.1.10"
        cores  = 1
        memory = 1024
        disk   = 10
        tags   = ["dev"]
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
}
