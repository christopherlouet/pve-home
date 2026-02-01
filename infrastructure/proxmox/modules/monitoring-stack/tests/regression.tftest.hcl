# =============================================================================
# Module Monitoring Stack - Tests de non-regression
# =============================================================================
# Verifie que les bugs corriges ne reapparaissent pas.
# =============================================================================

mock_provider "proxmox" {}
mock_provider "tls" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  target_node            = "pve-test"
  template_id            = 9000
  ip_address             = "192.168.1.50"
  gateway                = "192.168.1.1"
  ssh_keys               = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  grafana_admin_password = "testpassword123" # gitleaks:allow
  proxmox_nodes = [{
    name        = "pve-test"
    ip          = "192.168.1.100"
    token_value = "test-token-value"
  }]
}

# -----------------------------------------------------------------------------
# Regression v0.4.0: SCSI hardware must be virtio-scsi-single
# Without this setting, disk I/O performance is degraded.
# -----------------------------------------------------------------------------

run "scsi_hardware_virtio" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.scsi_hardware == "virtio-scsi-single"
    error_message = "SCSI hardware should be 'virtio-scsi-single'"
  }
}

# -----------------------------------------------------------------------------
# Regression v0.5.0: Cloud-init snippet datastore must be "local"
# Snippets can only be stored on the "local" datastore in Proxmox.
# -----------------------------------------------------------------------------

run "cloud_config_datastore_local" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_file.cloud_config.datastore_id == "local"
    error_message = "Cloud-init snippet datastore should be 'local'"
  }
}

# -----------------------------------------------------------------------------
# Regression v0.9.0: SSH keypair must use ED25519 algorithm
# RSA keys were replaced with ED25519 for better security and smaller size.
# -----------------------------------------------------------------------------

run "ssh_keypair_ed25519" {
  command = plan

  assert {
    condition     = tls_private_key.health_check.algorithm == "ED25519"
    error_message = "SSH keypair should use ED25519 algorithm"
  }
}

# -----------------------------------------------------------------------------
# Regression v0.7.2: VM description must be set
# The monitoring VM should have a descriptive name for identification.
# -----------------------------------------------------------------------------

run "vm_description_set" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.description == "Stack Monitoring - Prometheus/Grafana/Alertmanager"
    error_message = "VM description should be set to the monitoring stack description"
  }
}
