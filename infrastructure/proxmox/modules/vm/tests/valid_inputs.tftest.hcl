# =============================================================================
# Module VM - Tests de validation des entrees
# =============================================================================
# Verifie que les regles de validation des variables rejettent les valeurs
# invalides et acceptent les valeurs valides.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests (configuration minimale valide)
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
# template_id validation (>= 100)
# -----------------------------------------------------------------------------

run "template_id_valid_minimum" {
  command = plan

  variables {
    template_id = 100
  }
}

run "template_id_invalid_too_low" {
  command = plan

  variables {
    template_id = 99
  }

  expect_failures = [
    var.template_id,
  ]
}

run "template_id_invalid_zero" {
  command = plan

  variables {
    template_id = 0
  }

  expect_failures = [
    var.template_id,
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
# memory_mb validation (128-131072)
# -----------------------------------------------------------------------------

run "memory_valid_minimum" {
  command = plan

  variables {
    memory_mb = 128
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
    memory_mb = 127
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
# disk_size_gb validation (4-4096)
# -----------------------------------------------------------------------------

run "disk_valid_minimum" {
  command = plan

  variables {
    disk_size_gb = 4
  }
}

run "disk_valid_maximum" {
  command = plan

  variables {
    disk_size_gb = 4096
  }
}

run "disk_invalid_too_small" {
  command = plan

  variables {
    disk_size_gb = 3
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
    ip_address = "192.168.1.100"
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
    condition     = var.cpu_cores == 2
    error_message = "Default cpu_cores should be 2"
  }

  assert {
    condition     = var.memory_mb == 2048
    error_message = "Default memory_mb should be 2048"
  }

  assert {
    condition     = var.disk_size_gb == 20
    error_message = "Default disk_size_gb should be 20"
  }

  assert {
    condition     = var.install_docker == false
    error_message = "Default install_docker should be false"
  }

  assert {
    condition     = var.install_qemu_agent == true
    error_message = "Default install_qemu_agent should be true"
  }

  assert {
    condition     = var.backup_enabled == true
    error_message = "Default backup_enabled should be true"
  }

  assert {
    condition     = var.agent_enabled == true
    error_message = "Default agent_enabled should be true"
  }

  assert {
    condition     = var.start_on_boot == true
    error_message = "Default start_on_boot should be true"
  }

  assert {
    condition     = var.cpu_type == "host"
    error_message = "Default cpu_type should be host"
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
    condition     = var.username == "ubuntu"
    error_message = "Default username should be ubuntu"
  }
}
