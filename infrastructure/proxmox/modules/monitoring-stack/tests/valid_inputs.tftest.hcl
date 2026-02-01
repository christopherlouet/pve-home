# =============================================================================
# Module Monitoring Stack - Tests de validation des entrees
# =============================================================================
# Verifie que les regles de validation des variables rejettent les valeurs
# invalides et acceptent les valeurs valides.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests (configuration minimale valide)
# -----------------------------------------------------------------------------

variables {
  target_node            = "pve-test"
  template_id            = 9000
  ip_address             = "192.168.1.50"
  gateway                = "192.168.1.1"
  ssh_keys               = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  grafana_admin_password = "testpassword123"
  proxmox_nodes = [
    {
      name        = "pve-test"
      ip          = "192.168.1.100"
      token_value = "test-token-value"
    }
  ]
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

# -----------------------------------------------------------------------------
# vm_config.cores validation (1-64)
# -----------------------------------------------------------------------------

run "vm_config_cores_valid_minimum" {
  command = plan

  variables {
    vm_config = {
      cores = 1
    }
  }
}

run "vm_config_cores_valid_maximum" {
  command = plan

  variables {
    vm_config = {
      cores = 64
    }
  }
}

run "vm_config_cores_invalid_zero" {
  command = plan

  variables {
    vm_config = {
      cores = 0
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

run "vm_config_cores_invalid_too_high" {
  command = plan

  variables {
    vm_config = {
      cores = 65
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

# -----------------------------------------------------------------------------
# vm_config.memory validation (512-131072)
# -----------------------------------------------------------------------------

run "vm_config_memory_valid_minimum" {
  command = plan

  variables {
    vm_config = {
      memory = 512
    }
  }
}

run "vm_config_memory_invalid_too_low" {
  command = plan

  variables {
    vm_config = {
      memory = 511
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

# -----------------------------------------------------------------------------
# vm_config.disk validation (4-4096)
# -----------------------------------------------------------------------------

run "vm_config_disk_valid_minimum" {
  command = plan

  variables {
    vm_config = {
      disk = 4
    }
  }
}

run "vm_config_disk_invalid_too_small" {
  command = plan

  variables {
    vm_config = {
      disk = 3
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

# -----------------------------------------------------------------------------
# vm_config.data_disk validation (4-4096)
# -----------------------------------------------------------------------------

run "vm_config_data_disk_valid_minimum" {
  command = plan

  variables {
    vm_config = {
      data_disk = 4
    }
  }
}

run "vm_config_data_disk_invalid_too_small" {
  command = plan

  variables {
    vm_config = {
      data_disk = 3
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

# -----------------------------------------------------------------------------
# ip_address validation (IPv4 without CIDR)
# -----------------------------------------------------------------------------

run "ip_address_valid" {
  command = plan

  variables {
    ip_address = "10.0.0.50"
  }
}

run "ip_address_valid_another" {
  command = plan

  variables {
    ip_address = "172.16.0.1"
  }
}

run "ip_address_invalid_with_cidr" {
  command = plan

  variables {
    ip_address = "192.168.1.50/24"
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
# network_cidr validation (8-32)
# -----------------------------------------------------------------------------

run "network_cidr_valid_minimum" {
  command = plan

  variables {
    network_cidr = 8
  }
}

run "network_cidr_valid_maximum" {
  command = plan

  variables {
    network_cidr = 32
  }
}

run "network_cidr_invalid_too_low" {
  command = plan

  variables {
    network_cidr = 7
  }

  expect_failures = [
    var.network_cidr,
  ]
}

run "network_cidr_invalid_too_high" {
  command = plan

  variables {
    network_cidr = 33
  }

  expect_failures = [
    var.network_cidr,
  ]
}

# -----------------------------------------------------------------------------
# prometheus_retention_days validation (1-365)
# -----------------------------------------------------------------------------

run "retention_days_valid_minimum" {
  command = plan

  variables {
    prometheus_retention_days = 1
  }
}

run "retention_days_valid_maximum" {
  command = plan

  variables {
    prometheus_retention_days = 365
  }
}

run "retention_days_invalid_zero" {
  command = plan

  variables {
    prometheus_retention_days = 0
  }

  expect_failures = [
    var.prometheus_retention_days,
  ]
}

run "retention_days_invalid_too_high" {
  command = plan

  variables {
    prometheus_retention_days = 366
  }

  expect_failures = [
    var.prometheus_retention_days,
  ]
}

# -----------------------------------------------------------------------------
# prometheus_retention_size validation (format NGB)
# -----------------------------------------------------------------------------

run "retention_size_valid_gb" {
  command = plan

  variables {
    prometheus_retention_size = "40GB"
  }
}

run "retention_size_valid_tb" {
  command = plan

  variables {
    prometheus_retention_size = "1TB"
  }
}

run "retention_size_valid_mb" {
  command = plan

  variables {
    prometheus_retention_size = "500MB"
  }
}

run "retention_size_invalid_format" {
  command = plan

  variables {
    prometheus_retention_size = "40gb"
  }

  expect_failures = [
    var.prometheus_retention_size,
  ]
}

run "retention_size_invalid_no_unit" {
  command = plan

  variables {
    prometheus_retention_size = "40"
  }

  expect_failures = [
    var.prometheus_retention_size,
  ]
}

# -----------------------------------------------------------------------------
# Defaults verification
# -----------------------------------------------------------------------------

run "defaults_are_applied" {
  command = plan

  assert {
    condition     = var.name == "monitoring"
    error_message = "Default name should be monitoring"
  }

  assert {
    condition     = var.vm_config.cores == 2
    error_message = "Default vm_config.cores should be 2"
  }

  assert {
    condition     = var.vm_config.memory == 4096
    error_message = "Default vm_config.memory should be 4096"
  }

  assert {
    condition     = var.vm_config.disk == 30
    error_message = "Default vm_config.disk should be 30"
  }

  assert {
    condition     = var.vm_config.data_disk == 50
    error_message = "Default vm_config.data_disk should be 50"
  }

  assert {
    condition     = var.network_cidr == 24
    error_message = "Default network_cidr should be 24"
  }

  assert {
    condition     = var.prometheus_retention_days == 30
    error_message = "Default prometheus_retention_days should be 30"
  }

  assert {
    condition     = var.prometheus_retention_size == "40GB"
    error_message = "Default prometheus_retention_size should be 40GB"
  }

  assert {
    condition     = var.telegram_enabled == true
    error_message = "Default telegram_enabled should be true"
  }

  assert {
    condition     = var.backup_alerting_enabled == true
    error_message = "Default backup_alerting_enabled should be true"
  }

  assert {
    condition     = var.username == "ubuntu"
    error_message = "Default username should be ubuntu"
  }
}
