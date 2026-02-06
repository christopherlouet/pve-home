# =============================================================================
# Module Minio - Tests des outputs
# =============================================================================
# Verifie que tous les outputs sont correctement generes.
# Note: container_id est provider-computed et inconnu au plan avec mock_provider.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  hostname            = "minio-test"
  target_node         = "pve-test"
  ip_address          = "192.168.1.200/24"
  gateway             = "192.168.1.1"
  ssh_keys            = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  minio_root_password = "testpassword123" # gitleaks:allow
}

# -----------------------------------------------------------------------------
# Outputs avec configuration par defaut
# -----------------------------------------------------------------------------

run "output_endpoint_url_default" {
  command = plan

  assert {
    condition     = output.endpoint_url == "http://192.168.1.200:9000"
    error_message = "Default endpoint_url should use port 9000"
  }
}

run "output_console_url_default" {
  command = plan

  assert {
    condition     = output.console_url == "http://192.168.1.200:9001"
    error_message = "Default console_url should use port 9001"
  }
}

run "output_ip_address" {
  command = plan

  assert {
    condition     = output.ip_address == "192.168.1.200/24"
    error_message = "ip_address output should match input"
  }
}

# -----------------------------------------------------------------------------
# Outputs avec configuration custom
# -----------------------------------------------------------------------------

run "output_custom_ports" {
  command = plan

  variables {
    minio_port         = 9002
    minio_console_port = 9003
  }

  assert {
    condition     = output.endpoint_url == "http://192.168.1.200:9002"
    error_message = "Custom endpoint_url should reflect custom port"
  }

  assert {
    condition     = output.console_url == "http://192.168.1.200:9003"
    error_message = "Custom console_url should reflect custom console port"
  }
}

run "output_custom_ip" {
  command = plan

  variables {
    ip_address = "10.0.0.50/16"
  }

  assert {
    condition     = output.endpoint_url == "http://10.0.0.50:9000"
    error_message = "endpoint_url should use IP from custom ip_address"
  }

  assert {
    condition     = output.console_url == "http://10.0.0.50:9001"
    error_message = "console_url should use IP from custom ip_address"
  }

  assert {
    condition     = output.ip_address == "10.0.0.50/16"
    error_message = "ip_address output should match custom input"
  }
}
