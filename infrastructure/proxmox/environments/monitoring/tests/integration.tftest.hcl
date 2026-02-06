# =============================================================================
# Environnement Monitoring - Tests d'integration
# =============================================================================
# Verifie la coherence de la configuration : variables, modules, outputs.
# =============================================================================

mock_provider "proxmox" {}
mock_provider "tls" {}

# -----------------------------------------------------------------------------
# Variables minimales valides
# -----------------------------------------------------------------------------

variables {
  proxmox_endpoint  = "https://192.168.1.100:8006"
  proxmox_api_token = "test@pam!test=00000000-0000-0000-0000-000000000000" # gitleaks:allow
  network_gateway   = "192.168.1.1"
  ssh_public_keys   = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  default_node      = "pve-test"

  monitoring = {
    vm = {
      ip = "192.168.1.51"
    }
    proxmox_nodes = [{
      name        = "pve-test"
      ip          = "192.168.1.100"
      token_value = "00000000-0000-0000-0000-000000000000" # gitleaks:allow
    }]
    pve_exporter = {
      user       = "prometheus@pve"
      token_name = "prometheus"
    }
    grafana_admin_password = "testpassword123" # gitleaks:allow
  }

  minio = {
    ip            = "192.168.1.52"
    root_password = "testpassword123" # gitleaks:allow
  }
}

# -----------------------------------------------------------------------------
# Plan reussit avec configuration minimale
# -----------------------------------------------------------------------------

run "plan_with_minimal_config" {
  command = plan

  assert {
    condition     = var.environment == "monitoring"
    error_message = "Environment should default to monitoring"
  }
}

# -----------------------------------------------------------------------------
# Defaults verification
# -----------------------------------------------------------------------------

run "defaults_are_correct" {
  command = plan

  assert {
    condition     = var.network_bridge == "vmbr0"
    error_message = "Default network_bridge should be vmbr0"
  }

  assert {
    condition     = var.backup.enabled == true
    error_message = "Default backup should be enabled"
  }

  assert {
    condition     = var.backup.schedule == "02:00"
    error_message = "Default backup schedule should be 02:00"
  }

  assert {
    condition     = var.minio.port == 9000
    error_message = "Default minio port should be 9000"
  }

  assert {
    condition     = var.tooling.enabled == false
    error_message = "Tooling should be disabled by default"
  }
}

# -----------------------------------------------------------------------------
# Plan reussit avec tooling desactive (par defaut)
# -----------------------------------------------------------------------------

run "plan_without_tooling" {
  command = plan

  variables {
    tooling = {
      enabled = false
      vm = {
        ip = ""
      }
    }
  }
}
