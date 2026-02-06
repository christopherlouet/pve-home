# =============================================================================
# Module LXC - Tests de validation des entrees
# =============================================================================
# Verifie que les regles de validation des variables rejettent les valeurs
# invalides et acceptent les valeurs valides.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests (configuration minimale valide)
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
# os_type validation
# -----------------------------------------------------------------------------

run "os_type_valid_ubuntu" {
  command = plan

  variables {
    os_type = "ubuntu"
  }
}

run "os_type_valid_debian" {
  command = plan

  variables {
    os_type = "debian"
  }
}

run "os_type_valid_alpine" {
  command = plan

  variables {
    os_type = "alpine"
  }
}

run "os_type_invalid" {
  command = plan

  variables {
    os_type = "windows"
  }

  expect_failures = [
    var.os_type,
  ]
}

# -----------------------------------------------------------------------------
# cpu_cores validation (1-64)
# -----------------------------------------------------------------------------

run "cpu_cores_valid_minimum" {
  command = plan

  variables {
    cpu_cores = 1
  }
}

run "cpu_cores_valid_maximum" {
  command = plan

  variables {
    cpu_cores = 64
  }
}

run "cpu_cores_invalid_zero" {
  command = plan

  variables {
    cpu_cores = 0
  }

  expect_failures = [
    var.cpu_cores,
  ]
}

run "cpu_cores_invalid_too_high" {
  command = plan

  variables {
    cpu_cores = 65
  }

  expect_failures = [
    var.cpu_cores,
  ]
}

# -----------------------------------------------------------------------------
# memory_mb validation (64-131072)
# -----------------------------------------------------------------------------

run "memory_valid_minimum" {
  command = plan

  variables {
    memory_mb = 64
  }
}

run "memory_valid_maximum" {
  command = plan

  variables {
    memory_mb = 131072
  }
}

run "memory_invalid_too_low" {
  command = plan

  variables {
    memory_mb = 63
  }

  expect_failures = [
    var.memory_mb,
  ]
}

run "memory_invalid_too_high" {
  command = plan

  variables {
    memory_mb = 131073
  }

  expect_failures = [
    var.memory_mb,
  ]
}

# -----------------------------------------------------------------------------
# swap_mb validation (0-131072)
# -----------------------------------------------------------------------------

run "swap_valid_zero" {
  command = plan

  variables {
    swap_mb = 0
  }
}

run "swap_valid_maximum" {
  command = plan

  variables {
    swap_mb = 131072
  }
}

run "swap_invalid_negative" {
  command = plan

  variables {
    swap_mb = -1
  }

  expect_failures = [
    var.swap_mb,
  ]
}

run "swap_invalid_too_high" {
  command = plan

  variables {
    swap_mb = 131073
  }

  expect_failures = [
    var.swap_mb,
  ]
}

# -----------------------------------------------------------------------------
# disk_size_gb validation (1-4096)
# -----------------------------------------------------------------------------

run "disk_valid_minimum" {
  command = plan

  variables {
    disk_size_gb = 1
  }
}

run "disk_valid_maximum" {
  command = plan

  variables {
    disk_size_gb = 4096
  }
}

run "disk_invalid_zero" {
  command = plan

  variables {
    disk_size_gb = 0
  }

  expect_failures = [
    var.disk_size_gb,
  ]
}

run "disk_invalid_too_large" {
  command = plan

  variables {
    disk_size_gb = 4097
  }

  expect_failures = [
    var.disk_size_gb,
  ]
}

# -----------------------------------------------------------------------------
# vlan_id validation (1-4094 or null)
# -----------------------------------------------------------------------------

run "vlan_id_valid_null" {
  command = plan

  variables {
    vlan_id = null
  }
}

run "vlan_id_valid_minimum" {
  command = plan

  variables {
    vlan_id = 1
  }
}

run "vlan_id_valid_maximum" {
  command = plan

  variables {
    vlan_id = 4094
  }
}

run "vlan_id_invalid_zero" {
  command = plan

  variables {
    vlan_id = 0
  }

  expect_failures = [
    var.vlan_id,
  ]
}

run "vlan_id_invalid_too_high" {
  command = plan

  variables {
    vlan_id = 4095
  }

  expect_failures = [
    var.vlan_id,
  ]
}

# -----------------------------------------------------------------------------
# ip_address validation (CIDR format)
# -----------------------------------------------------------------------------

run "ip_address_valid_cidr" {
  command = plan

  variables {
    ip_address = "10.0.0.1/24"
  }
}

run "ip_address_valid_cidr_32" {
  command = plan

  variables {
    ip_address = "172.16.0.1/32"
  }
}

run "ip_address_invalid_no_cidr" {
  command = plan

  variables {
    ip_address = "192.168.1.50"
  }

  expect_failures = [
    var.ip_address,
  ]
}

run "ip_address_invalid_format" {
  command = plan

  variables {
    ip_address = "not-an-ip"
  }

  expect_failures = [
    var.ip_address,
  ]
}

# -----------------------------------------------------------------------------
# Defaults verification
# -----------------------------------------------------------------------------

run "defaults_are_applied" {
  command = plan

  assert {
    condition     = var.os_type == "ubuntu"
    error_message = "Default os_type should be ubuntu"
  }

  assert {
    condition     = var.cpu_cores == 1
    error_message = "Default cpu_cores should be 1"
  }

  assert {
    condition     = var.memory_mb == 512
    error_message = "Default memory_mb should be 512"
  }

  assert {
    condition     = var.swap_mb == 512
    error_message = "Default swap_mb should be 512"
  }

  assert {
    condition     = var.disk_size_gb == 8
    error_message = "Default disk_size_gb should be 8"
  }

  assert {
    condition     = var.datastore == "local-lvm"
    error_message = "Default datastore should be local-lvm"
  }

  assert {
    condition     = var.network_bridge == "vmbr0"
    error_message = "Default network_bridge should be vmbr0"
  }

  assert {
    condition     = var.unprivileged == true
    error_message = "Default unprivileged should be true"
  }

  assert {
    condition     = var.start_on_boot == true
    error_message = "Default start_on_boot should be true"
  }

  assert {
    condition     = var.nesting == false
    error_message = "Default nesting should be false"
  }

  assert {
    condition     = var.backup_enabled == true
    error_message = "Default backup_enabled should be true"
  }
}

# -----------------------------------------------------------------------------
# expiration_days validation (null or > 0)
# -----------------------------------------------------------------------------

run "expiration_days_valid_null" {
  command = plan

  variables {
    expiration_days = null
  }
}

run "expiration_days_valid_one" {
  command = plan

  variables {
    expiration_days = 1
  }
}

run "expiration_days_valid_thirty" {
  command = plan

  variables {
    expiration_days = 30
  }
}

run "expiration_days_invalid_zero" {
  command = plan

  variables {
    expiration_days = 0
  }

  expect_failures = [
    var.expiration_days,
  ]
}

run "expiration_days_invalid_negative" {
  command = plan

  variables {
    expiration_days = -1
  }

  expect_failures = [
    var.expiration_days,
  ]
}
