# =============================================================================
# Module Monitoring Stack - Tests du plan genere
# =============================================================================
# Verifie que le plan Terraform genere les bonnes ressources avec les bons
# attributs selon la configuration fournie.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables de base (configuration minimale valide)
# -----------------------------------------------------------------------------

variables {
  name        = "test-monitoring"
  target_node = "pve-test"
  template_id = 9000
  ip_address  = "192.168.1.50"
  gateway     = "192.168.1.1"
  ssh_keys    = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]

  grafana_admin_password = "test-password" # gitleaks:allow

  proxmox_nodes = [
    {
      name        = "pve-prod"
      ip          = "192.168.1.100"
      token_value = "test-token-value"
    }
  ]
}

# -----------------------------------------------------------------------------
# VM de base (configuration minimale)
# -----------------------------------------------------------------------------

run "monitoring_creates_vm" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.name == "test-monitoring"
    error_message = "VM name should be test-monitoring"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.node_name == "pve-test"
    error_message = "VM should be deployed on pve-test"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.on_boot == true
    error_message = "VM should start on boot"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.started == true
    error_message = "VM should be started"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.scsi_hardware == "virtio-scsi-single"
    error_message = "SCSI hardware should be virtio-scsi-single"
  }
}

# -----------------------------------------------------------------------------
# Clone configuration
# -----------------------------------------------------------------------------

run "monitoring_clone_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.clone[0].vm_id == 9000
    error_message = "Clone should use template_id 9000"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.clone[0].full == true
    error_message = "Clone should be full (not linked)"
  }
}

# -----------------------------------------------------------------------------
# CPU configuration
# -----------------------------------------------------------------------------

run "monitoring_default_cpu" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.cpu[0].cores == 2
    error_message = "Default CPU cores should be 2"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.cpu[0].type == "host"
    error_message = "CPU type should be host"
  }
}

run "monitoring_custom_cpu" {
  command = plan

  variables {
    vm_config = {
      cores     = 4
      memory    = 4096
      disk      = 30
      data_disk = 50
    }
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.cpu[0].cores == 4
    error_message = "CPU cores should be 4"
  }
}

# -----------------------------------------------------------------------------
# Memory configuration
# -----------------------------------------------------------------------------

run "monitoring_default_memory" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.memory[0].dedicated == 4096
    error_message = "Default memory should be 4096 MB"
  }
}

# -----------------------------------------------------------------------------
# Disk configuration (system + data)
# -----------------------------------------------------------------------------

run "monitoring_system_disk" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.disk[0].size == 30
    error_message = "Default system disk should be 30 GB"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.disk[0].interface == "scsi0"
    error_message = "System disk interface should be scsi0"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.disk[0].iothread == true
    error_message = "IO thread should be enabled"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.disk[0].ssd == true
    error_message = "SSD should be enabled"
  }
}

run "monitoring_data_disk" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.disk[1].size == 50
    error_message = "Default data disk should be 50 GB"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.disk[1].interface == "scsi1"
    error_message = "Data disk interface should be scsi1"
  }
}

# -----------------------------------------------------------------------------
# Network configuration
# -----------------------------------------------------------------------------

run "monitoring_network" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.network_device[0].bridge == "vmbr0"
    error_message = "Network bridge should be vmbr0"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.network_device[0].model == "virtio"
    error_message = "Network model should be virtio"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.network_device[0].firewall == true
    error_message = "Firewall should be enabled"
  }
}

# -----------------------------------------------------------------------------
# Agent configuration
# -----------------------------------------------------------------------------

run "monitoring_agent" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.agent[0].enabled == true
    error_message = "QEMU agent should be enabled"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.agent[0].timeout == "2m"
    error_message = "Agent timeout should be 2m"
  }
}

# -----------------------------------------------------------------------------
# Cloud-init snippet
# -----------------------------------------------------------------------------

run "monitoring_creates_cloud_config" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_file.cloud_config.content_type == "snippets"
    error_message = "Cloud config should be a snippet"
  }

  assert {
    condition     = proxmox_virtual_environment_file.cloud_config.datastore_id == "local"
    error_message = "Cloud config should be stored on local datastore"
  }
}

# -----------------------------------------------------------------------------
# SSH keypair for health checks
# -----------------------------------------------------------------------------

run "monitoring_creates_ssh_keypair" {
  command = plan

  assert {
    condition     = tls_private_key.health_check.algorithm == "ED25519"
    error_message = "SSH key algorithm should be ED25519"
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

run "monitoring_outputs" {
  command = plan

  assert {
    condition     = output.ip_address == "192.168.1.50"
    error_message = "Output ip_address should be 192.168.1.50"
  }

  assert {
    condition     = output.ssh_command == "ssh ubuntu@192.168.1.50"
    error_message = "Output ssh_command should use default username"
  }

  assert {
    condition     = output.urls.prometheus == "http://192.168.1.50:9090"
    error_message = "Prometheus URL should be correct"
  }

  assert {
    condition     = output.urls.grafana == "http://192.168.1.50:3000"
    error_message = "Grafana URL should be correct"
  }

  assert {
    condition     = output.urls.alertmanager == "http://192.168.1.50:9093"
    error_message = "Alertmanager URL should be correct"
  }
}

# -----------------------------------------------------------------------------
# Custom datastore
# -----------------------------------------------------------------------------

run "monitoring_custom_datastore" {
  command = plan

  variables {
    datastore = "ceph-pool"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.monitoring.disk[0].datastore_id == "ceph-pool"
    error_message = "Datastore should be ceph-pool"
  }
}

# -----------------------------------------------------------------------------
# Scrape targets (nodes + additional)
# -----------------------------------------------------------------------------

run "monitoring_scrape_targets_from_nodes" {
  command = plan

  assert {
    condition     = length(output.scrape_targets) == 1
    error_message = "Should have 1 scrape target from proxmox_nodes"
  }

  assert {
    condition     = output.scrape_targets[0] == "192.168.1.100:9100"
    error_message = "Scrape target should be node IP with port 9100"
  }
}

run "monitoring_scrape_targets_with_additional" {
  command = plan

  variables {
    additional_scrape_targets = [
      {
        name = "app-server"
        ip   = "192.168.1.200"
        port = 9100
      }
    ]
  }

  assert {
    condition     = length(output.scrape_targets) == 2
    error_message = "Should have 2 scrape targets (1 node + 1 additional)"
  }
}
