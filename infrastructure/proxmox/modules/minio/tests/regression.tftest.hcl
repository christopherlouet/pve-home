# =============================================================================
# Module Minio - Tests de non-regression
# =============================================================================
# Verifie que les bugs corriges ne reapparaissent pas.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  hostname            = "test-minio"
  target_node         = "pve-test"
  ip_address          = "192.168.1.200/24"
  gateway             = "192.168.1.1"
  ssh_keys            = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  minio_root_password = "testpassword123" # gitleaks:allow
}

# -----------------------------------------------------------------------------
# Regression v0.7.2: mount_point size must have "G" suffix
# The data disk mount_point size must include the "G" suffix for Proxmox.
# Without it, Proxmox interprets the value incorrectly.
# -----------------------------------------------------------------------------

run "mount_point_size_has_g_suffix" {
  command = plan

  variables {
    data_disk_size_gb = 50
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.mount_point[0].size == "50G"
    error_message = "Mount point size should have 'G' suffix (got: ${proxmox_virtual_environment_container.minio.mount_point[0].size})"
  }
}

# -----------------------------------------------------------------------------
# Regression v0.7.2: Tags should be preserved as-is
# -----------------------------------------------------------------------------

run "tags_preserved" {
  command = plan

  variables {
    tags = ["terraform", "minio", "s3"]
  }

  assert {
    condition     = length(proxmox_virtual_environment_container.minio.tags) == 3
    error_message = "All 3 tags should be preserved"
  }

  assert {
    condition     = contains(proxmox_virtual_environment_container.minio.tags, "minio")
    error_message = "Tag 'minio' should be present"
  }
}

# -----------------------------------------------------------------------------
# Regression v1.0.0: Outputs must exist
# The module must expose endpoint_url, console_url, and container_id outputs.
# These are used by dependent modules (backup state storage, monitoring).
# -----------------------------------------------------------------------------

run "output_endpoint_url_exists" {
  command = plan

  assert {
    condition     = output.endpoint_url == "http://192.168.1.200:9000"
    error_message = "endpoint_url output should be http://IP:9000"
  }
}

run "output_console_url_exists" {
  command = plan

  assert {
    condition     = output.console_url == "http://192.168.1.200:9001"
    error_message = "console_url output should be http://IP:9001"
  }
}

run "output_ip_address_exists" {
  command = plan

  assert {
    condition     = output.ip_address == "192.168.1.200/24"
    error_message = "ip_address output should match the provided IP"
  }
}
