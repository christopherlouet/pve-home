# =============================================================================
# Environnement Prod - Tests d'integration multi-module
# =============================================================================
# Verifie le fonctionnement avec plusieurs VMs et conteneurs deployes
# simultanement, incluant des combinaisons de features.
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
# Multi-VM deployment (3 VMs avec configurations variees)
# -----------------------------------------------------------------------------

run "plan_with_multiple_vms" {
  command = plan

  variables {
    vms = {
      web = {
        ip     = "192.168.1.10"
        cores  = 2
        memory = 2048
        disk   = 20
        docker = true
        tags   = ["web", "frontend"]
      }
      api = {
        ip     = "192.168.1.11"
        cores  = 4
        memory = 4096
        disk   = 30
        docker = true
        tags   = ["api", "backend"]
      }
      db = {
        ip     = "192.168.1.12"
        cores  = 2
        memory = 4096
        disk   = 50
        tags   = ["database"]
      }
    }
    containers = {}
  }
}

# -----------------------------------------------------------------------------
# Multi-LXC deployment (2 conteneurs)
# -----------------------------------------------------------------------------

run "plan_with_multiple_containers" {
  command = plan

  variables {
    vms = {}
    containers = {
      dns = {
        ip     = "192.168.1.20"
        cores  = 1
        memory = 256
        disk   = 4
        tags   = ["dns", "infra"]
      }
      proxy = {
        ip      = "192.168.1.21"
        cores   = 1
        memory  = 512
        disk    = 8
        nesting = true
        tags    = ["proxy"]
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Mixed deployment: VMs + LXC + backup active
# -----------------------------------------------------------------------------

run "plan_with_mixed_workloads" {
  command = plan

  variables {
    vms = {
      app = {
        ip     = "192.168.1.10"
        cores  = 2
        memory = 2048
        disk   = 20
        docker = true
        tags   = ["app"]
      }
    }
    containers = {
      cache = {
        ip     = "192.168.1.20"
        cores  = 1
        memory = 512
        disk   = 8
        tags   = ["cache"]
      }
    }
    backup = {
      enabled  = true
      schedule = "02:00"
      compress = "zstd"
      retention = {
        keep_daily   = 7
        keep_weekly  = 4
        keep_monthly = 0
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Verify outputs are populated with multiple resources
# -----------------------------------------------------------------------------

run "outputs_with_multiple_resources" {
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
      api = {
        ip     = "192.168.1.11"
        cores  = 2
        memory = 2048
        disk   = 20
        tags   = ["api"]
      }
    }
    containers = {
      dns = {
        ip     = "192.168.1.20"
        cores  = 1
        memory = 256
        disk   = 4
        tags   = ["dns"]
      }
    }
  }

  assert {
    condition     = length(output.vms) == 2
    error_message = "Should have 2 VMs in outputs"
  }

  assert {
    condition     = length(output.containers) == 1
    error_message = "Should have 1 container in outputs"
  }

  assert {
    condition     = length(output.ssh_commands) == 3
    error_message = "Should have 3 SSH commands (2 VMs + 1 LXC)"
  }
}

# -----------------------------------------------------------------------------
# Backup disabled should still allow VM/LXC deployment
# -----------------------------------------------------------------------------

run "plan_with_backup_disabled" {
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
    backup = {
      enabled = false
    }
  }
}
