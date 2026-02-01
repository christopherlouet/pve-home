# =============================================================================
# Module Minio - Tests du plan genere
# =============================================================================
# Verifie que le plan Terraform genere les bonnes ressources avec les bons
# attributs selon la configuration fournie.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  hostname             = "minio-test"
  target_node          = "pve-test"
  ip_address           = "192.168.1.200/24"
  gateway              = "192.168.1.1"
  ssh_keys             = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  minio_root_password  = "testpassword123"
}

# -----------------------------------------------------------------------------
# Conteneur LXC de base
# -----------------------------------------------------------------------------

run "minio_creates_container" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.minio.node_name == "pve-test"
    error_message = "Container should be deployed on pve-test"
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.unprivileged == true
    error_message = "Container should be unprivileged"
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.start_on_boot == true
    error_message = "Container should start on boot"
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.started == true
    error_message = "Container should be started"
  }
}

run "minio_os_is_debian" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.minio.operating_system[0].type == "debian"
    error_message = "OS type should be debian"
  }
}

run "minio_cpu_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.minio.cpu[0].cores == 1
    error_message = "Default CPU cores should be 1"
  }
}

run "minio_memory_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.minio.memory[0].dedicated == 512
    error_message = "Default memory should be 512 MB"
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.memory[0].swap == 256
    error_message = "Swap should be 256 MB"
  }
}

run "minio_disk_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.minio.disk[0].datastore_id == "local-lvm"
    error_message = "Default datastore should be local-lvm"
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.disk[0].size == 8
    error_message = "Default disk size should be 8 GB"
  }
}

run "minio_data_mount_point" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.minio.mount_point[0].path == "/data"
    error_message = "Data mount point path should be /data"
  }
}

run "minio_network_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.minio.network_interface[0].name == "eth0"
    error_message = "Network interface should be eth0"
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.network_interface[0].bridge == "vmbr0"
    error_message = "Network bridge should be vmbr0"
  }
}

run "minio_default_tags" {
  command = plan

  assert {
    condition     = length(proxmox_virtual_environment_container.minio.tags) == 3
    error_message = "Should have 3 default tags (terraform, minio, s3)"
  }

  assert {
    condition     = contains(proxmox_virtual_environment_container.minio.tags, "minio")
    error_message = "Tags should contain 'minio'"
  }
}

run "minio_default_description" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.minio.description == "Minio S3 - Managed by Terraform"
    error_message = "Default description should be 'Minio S3 - Managed by Terraform'"
  }
}

# -----------------------------------------------------------------------------
# Custom configuration
# -----------------------------------------------------------------------------

run "minio_custom_configuration" {
  command = plan

  variables {
    cpu_cores         = 2
    memory_mb         = 2048
    disk_size_gb      = 16
    data_disk_size_gb = 200
    container_id      = 500
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.cpu[0].cores == 2
    error_message = "CPU cores should be 2"
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.memory[0].dedicated == 2048
    error_message = "Memory should be 2048 MB"
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.disk[0].size == 16
    error_message = "Disk size should be 16 GB"
  }

  assert {
    condition     = proxmox_virtual_environment_container.minio.vm_id == 500
    error_message = "Container ID should be 500"
  }
}
