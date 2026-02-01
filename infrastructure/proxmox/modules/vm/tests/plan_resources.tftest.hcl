# =============================================================================
# Module VM - Tests du plan genere
# =============================================================================
# Verifie que le plan Terraform genere les bonnes ressources avec les bons
# attributs selon la configuration fournie.
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
# VM de base (configuration minimale)
# -----------------------------------------------------------------------------

run "basic_vm_creates_vm_resource" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.name == "test-vm"
    error_message = "VM name should be test-vm"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.node_name == "pve-test"
    error_message = "VM should be deployed on pve-test"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.on_boot == true
    error_message = "VM should start on boot by default"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.started == true
    error_message = "VM should be started"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.scsi_hardware == "virtio-scsi-single"
    error_message = "SCSI hardware should be virtio-scsi-single"
  }
}

run "basic_vm_clone_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.clone[0].vm_id == 9000
    error_message = "Clone should use template_id 9000"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.clone[0].full == true
    error_message = "Clone should be full (not linked)"
  }
}

run "basic_vm_cpu_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.cpu[0].cores == 2
    error_message = "Default CPU cores should be 2"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.cpu[0].type == "host"
    error_message = "CPU type should be host"
  }
}

run "basic_vm_memory_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.memory[0].dedicated == 2048
    error_message = "Default memory should be 2048 MB"
  }
}

run "basic_vm_disk_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].size == 20
    error_message = "Default disk size should be 20 GB"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].interface == "scsi0"
    error_message = "Disk interface should be scsi0"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].iothread == true
    error_message = "IO thread should be enabled"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].discard == "on"
    error_message = "Discard should be on"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].ssd == true
    error_message = "SSD should be enabled"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].backup == true
    error_message = "Backup should be enabled by default"
  }
}

run "basic_vm_network_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].bridge == "vmbr0"
    error_message = "Network bridge should be vmbr0"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].model == "virtio"
    error_message = "Network model should be virtio"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].firewall == true
    error_message = "Firewall should be enabled"
  }
}

run "basic_vm_agent_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.agent[0].enabled == true
    error_message = "QEMU agent should be enabled by default"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.agent[0].timeout == "1m"
    error_message = "Agent timeout should be 1m"
  }
}

# -----------------------------------------------------------------------------
# Cloud-init : QEMU agent installe par defaut
# -----------------------------------------------------------------------------

run "default_config_creates_cloud_init" {
  command = plan

  # install_qemu_agent=true par defaut, donc cloud_config est cree
  assert {
    condition     = length(proxmox_virtual_environment_file.cloud_config) == 1
    error_message = "Cloud-init config should be created when install_qemu_agent is true"
  }
}

run "no_cloud_init_when_no_packages" {
  command = plan

  variables {
    install_qemu_agent  = false
    install_docker      = false
    additional_packages = []
  }

  assert {
    condition     = length(proxmox_virtual_environment_file.cloud_config) == 0
    error_message = "Cloud-init config should not be created when no packages needed"
  }
}

# -----------------------------------------------------------------------------
# Docker optionnel
# -----------------------------------------------------------------------------

run "docker_enabled_creates_cloud_init" {
  command = plan

  variables {
    install_docker = true
  }

  assert {
    condition     = length(proxmox_virtual_environment_file.cloud_config) == 1
    error_message = "Cloud-init should be created when Docker is enabled"
  }
}

# -----------------------------------------------------------------------------
# Backup desactive
# -----------------------------------------------------------------------------

run "backup_disabled" {
  command = plan

  variables {
    backup_enabled = false
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].backup == false
    error_message = "Backup should be disabled when backup_enabled is false"
  }
}

# -----------------------------------------------------------------------------
# Custom configuration
# -----------------------------------------------------------------------------

run "custom_vm_configuration" {
  command = plan

  variables {
    cpu_cores    = 4
    memory_mb    = 8192
    disk_size_gb = 100
    cpu_type     = "kvm64"
    datastore    = "ceph-pool"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.cpu[0].cores == 4
    error_message = "CPU cores should be 4"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.memory[0].dedicated == 8192
    error_message = "Memory should be 8192 MB"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].size == 100
    error_message = "Disk size should be 100 GB"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].datastore_id == "ceph-pool"
    error_message = "Datastore should be ceph-pool"
  }
}

# -----------------------------------------------------------------------------
# VLAN configuration
# -----------------------------------------------------------------------------

run "vlan_configuration" {
  command = plan

  variables {
    vlan_id = 100
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].vlan_id == 100
    error_message = "VLAN ID should be 100"
  }
}

# -----------------------------------------------------------------------------
# Additional disks
# -----------------------------------------------------------------------------

run "additional_disks" {
  command = plan

  variables {
    additional_disks = [
      {
        size         = 50
        datastore_id = "local-lvm"
        interface    = "scsi"
      }
    ]
  }

  # La VM doit avoir 2 disques : scsi0 (systeme) + scsi1 (additionnel)
  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].interface == "scsi0"
    error_message = "First disk should be scsi0"
  }
}
