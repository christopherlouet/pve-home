# =============================================================================
# Module LXC - Tests du plan genere
# =============================================================================
# Verifie que le plan Terraform genere les bonnes ressources avec les bons
# attributs selon la configuration fournie.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  hostname         = "test-lxc"
  target_node      = "pve-test"
  template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  ip_address       = "192.168.1.50/24"
  gateway          = "192.168.1.1"
  ssh_keys         = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
}

# -----------------------------------------------------------------------------
# LXC de base (configuration minimale)
# -----------------------------------------------------------------------------

run "basic_lxc_creates_container" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.node_name == "pve-test"
    error_message = "Container should be deployed on pve-test"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.unprivileged == true
    error_message = "Container should be unprivileged by default"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.start_on_boot == true
    error_message = "Container should start on boot by default"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.started == true
    error_message = "Container should be started"
  }
}

run "basic_lxc_os_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.operating_system[0].type == "ubuntu"
    error_message = "Default OS type should be ubuntu"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.operating_system[0].template_file_id == "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    error_message = "Template file ID should match"
  }
}

run "basic_lxc_cpu_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.cpu[0].cores == 1
    error_message = "Default CPU cores should be 1"
  }
}

run "basic_lxc_memory_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.memory[0].dedicated == 512
    error_message = "Default memory should be 512 MB"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.memory[0].swap == 512
    error_message = "Default swap should be 512 MB"
  }
}

run "basic_lxc_disk_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.disk[0].size == 8
    error_message = "Default disk size should be 8 GB"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.disk[0].datastore_id == "local-lvm"
    error_message = "Default datastore should be local-lvm"
  }
}

run "basic_lxc_network_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.network_interface[0].name == "eth0"
    error_message = "Network interface should be eth0"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.network_interface[0].bridge == "vmbr0"
    error_message = "Network bridge should be vmbr0"
  }
}

run "basic_lxc_features_configuration" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.features[0].nesting == false
    error_message = "Nesting should be disabled by default"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.features[0].fuse == false
    error_message = "FUSE should be disabled by default"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.features[0].keyctl == false
    error_message = "Keyctl should be disabled by default"
  }
}

# -----------------------------------------------------------------------------
# Custom configuration
# -----------------------------------------------------------------------------

run "custom_lxc_configuration" {
  command = plan

  variables {
    cpu_cores    = 4
    memory_mb    = 4096
    swap_mb      = 1024
    disk_size_gb = 50
    datastore    = "ceph-pool"
    os_type      = "debian"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.cpu[0].cores == 4
    error_message = "CPU cores should be 4"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.memory[0].dedicated == 4096
    error_message = "Memory should be 4096 MB"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.memory[0].swap == 1024
    error_message = "Swap should be 1024 MB"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.disk[0].size == 50
    error_message = "Disk size should be 50 GB"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.disk[0].datastore_id == "ceph-pool"
    error_message = "Datastore should be ceph-pool"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.operating_system[0].type == "debian"
    error_message = "OS type should be debian"
  }
}

# -----------------------------------------------------------------------------
# Nesting (Docker dans LXC)
# -----------------------------------------------------------------------------

run "nesting_enabled" {
  command = plan

  variables {
    nesting = true
    keyctl  = true
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.features[0].nesting == true
    error_message = "Nesting should be enabled"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.features[0].keyctl == true
    error_message = "Keyctl should be enabled"
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
    condition     = proxmox_virtual_environment_container.this.network_interface[0].vlan_id == 100
    error_message = "VLAN ID should be 100"
  }
}

# -----------------------------------------------------------------------------
# Description
# -----------------------------------------------------------------------------

run "default_description" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.description == "Managed by Terraform"
    error_message = "Default description should be 'Managed by Terraform'"
  }
}

run "custom_description" {
  command = plan

  variables {
    description = "My custom container"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.description == "My custom container"
    error_message = "Custom description should be preserved"
  }
}

# -----------------------------------------------------------------------------
# Privileged container
# -----------------------------------------------------------------------------

run "privileged_container" {
  command = plan

  variables {
    unprivileged = false
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.unprivileged == false
    error_message = "Container should be privileged when unprivileged is false"
  }
}

# -----------------------------------------------------------------------------
# Mountpoints (dynamic for_each)
# -----------------------------------------------------------------------------

run "mountpoint_single" {
  command = plan

  variables {
    mountpoints = [
      {
        volume = "local-lvm:50"
        path   = "/data"
        size   = 50
      }
    ]
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.mount_point[0].path == "/data"
    error_message = "Mountpoint path should be /data"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.mount_point[0].volume == "local-lvm:50"
    error_message = "Mountpoint volume should match"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.mount_point[0].read_only == false
    error_message = "Mountpoint should not be read-only by default"
  }
}

run "mountpoint_read_only" {
  command = plan

  variables {
    mountpoints = [
      {
        volume    = "local-lvm:10"
        path      = "/config"
        size      = 10
        read_only = true
      }
    ]
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.mount_point[0].read_only == true
    error_message = "Mountpoint should be read-only when specified"
  }
}

run "no_mountpoints" {
  command = plan

  variables {
    mountpoints = []
  }

  # Container should still be valid without mountpoints
  assert {
    condition     = proxmox_virtual_environment_container.this.node_name == "pve-test"
    error_message = "Container should be created without mountpoints"
  }
}
