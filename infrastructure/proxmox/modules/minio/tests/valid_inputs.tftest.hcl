# =============================================================================
# Module Minio - Tests de validation des entrees
# =============================================================================
# Verifie que les regles de validation des variables rejettent les valeurs
# invalides et acceptent les valeurs valides.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests (configuration minimale valide)
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
# container_id validation (null or >= 100)
# -----------------------------------------------------------------------------

run "container_id_valid_null" {
  command = plan

  variables {
    container_id = null
  }
}

run "container_id_valid_minimum" {
  command = plan

  variables {
    container_id = 100
  }
}

run "container_id_valid_high" {
  command = plan

  variables {
    container_id = 999
  }
}

run "container_id_invalid_too_low" {
  command = plan

  variables {
    container_id = 99
  }

  expect_failures = [
    var.container_id,
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

# -----------------------------------------------------------------------------
# disk_size_gb validation (1-4096)
# -----------------------------------------------------------------------------

run "disk_valid_minimum" {
  command = plan

  variables {
    disk_size_gb = 1
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

# -----------------------------------------------------------------------------
# data_disk_size_gb validation (1-4096)
# -----------------------------------------------------------------------------

run "data_disk_valid_minimum" {
  command = plan

  variables {
    data_disk_size_gb = 1
  }
}

run "data_disk_valid_maximum" {
  command = plan

  variables {
    data_disk_size_gb = 4096
  }
}

run "data_disk_invalid_zero" {
  command = plan

  variables {
    data_disk_size_gb = 0
  }

  expect_failures = [
    var.data_disk_size_gb,
  ]
}

# -----------------------------------------------------------------------------
# ip_address validation (CIDR format)
# -----------------------------------------------------------------------------

run "ip_address_valid_cidr" {
  command = plan

  variables {
    ip_address = "10.0.0.200/24"
  }
}

run "ip_address_invalid_no_cidr" {
  command = plan

  variables {
    ip_address = "192.168.1.200"
  }

  expect_failures = [
    var.ip_address,
  ]
}

# -----------------------------------------------------------------------------
# minio_port validation (1024-65535)
# -----------------------------------------------------------------------------

run "minio_port_valid_minimum" {
  command = plan

  variables {
    minio_port = 1024
  }
}

run "minio_port_valid_maximum" {
  command = plan

  variables {
    minio_port = 65535
  }
}

run "minio_port_invalid_too_low" {
  command = plan

  variables {
    minio_port = 1023
  }

  expect_failures = [
    var.minio_port,
  ]
}

# -----------------------------------------------------------------------------
# minio_console_port validation (1024-65535)
# -----------------------------------------------------------------------------

run "minio_console_port_valid" {
  command = plan

  variables {
    minio_console_port = 9001
  }
}

run "minio_console_port_invalid_too_low" {
  command = plan

  variables {
    minio_console_port = 80
  }

  expect_failures = [
    var.minio_console_port,
  ]
}

# -----------------------------------------------------------------------------
# Defaults verification
# -----------------------------------------------------------------------------

run "defaults_are_applied" {
  command = plan

  assert {
    condition     = var.cpu_cores == 1
    error_message = "Default cpu_cores should be 1"
  }

  assert {
    condition     = var.memory_mb == 512
    error_message = "Default memory_mb should be 512"
  }

  assert {
    condition     = var.disk_size_gb == 8
    error_message = "Default disk_size_gb should be 8"
  }

  assert {
    condition     = var.data_disk_size_gb == 50
    error_message = "Default data_disk_size_gb should be 50"
  }

  assert {
    condition     = var.minio_port == 9000
    error_message = "Default minio_port should be 9000"
  }

  assert {
    condition     = var.minio_console_port == 9001
    error_message = "Default minio_console_port should be 9001"
  }

  assert {
    condition     = var.datastore == "local-lvm"
    error_message = "Default datastore should be local-lvm"
  }

  assert {
    condition     = var.start_on_boot == true
    error_message = "Default start_on_boot should be true"
  }

  assert {
    condition     = var.minio_root_user == "minioadmin"
    error_message = "Default minio_root_user should be minioadmin"
  }
}
