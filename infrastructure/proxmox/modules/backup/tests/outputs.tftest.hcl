# =============================================================================
# Module Backup - Tests des outputs
# =============================================================================
# Verifie que tous les outputs sont correctement generes avec les valeurs
# attendues selon la configuration fournie.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  target_node      = "pve-test"
  proxmox_endpoint = "https://192.168.1.100:8006"
}

# -----------------------------------------------------------------------------
# Outputs avec configuration par defaut
# -----------------------------------------------------------------------------

run "output_storage_id_default" {
  command = plan

  assert {
    condition     = output.storage_id == "local"
    error_message = "Default storage_id should be 'local'"
  }
}

run "output_schedule_default" {
  command = plan

  assert {
    condition     = output.schedule == "01:00"
    error_message = "Default schedule should be '01:00'"
  }
}

run "output_target_node" {
  command = plan

  assert {
    condition     = output.target_node == "pve-test"
    error_message = "target_node output should match input"
  }
}

run "output_enabled_default" {
  command = plan

  assert {
    condition     = output.enabled == true
    error_message = "Default enabled should be true"
  }
}

run "output_retention_defaults" {
  command = plan

  assert {
    condition     = output.retention.keep_daily == 7
    error_message = "Default keep_daily should be 7"
  }

  assert {
    condition     = output.retention.keep_weekly == 0
    error_message = "Default keep_weekly should be 0"
  }

  assert {
    condition     = output.retention.keep_monthly == 0
    error_message = "Default keep_monthly should be 0"
  }
}

# -----------------------------------------------------------------------------
# Outputs avec configuration custom
# -----------------------------------------------------------------------------

run "output_custom_storage" {
  command = plan

  variables {
    storage_id = "nfs-backup"
  }

  assert {
    condition     = output.storage_id == "nfs-backup"
    error_message = "Custom storage_id should be reflected in output"
  }
}

run "output_custom_schedule" {
  command = plan

  variables {
    schedule = "sun 02:00"
  }

  assert {
    condition     = output.schedule == "sun 02:00"
    error_message = "Custom schedule should be reflected in output"
  }
}

run "output_disabled" {
  command = plan

  variables {
    enabled = false
  }

  assert {
    condition     = output.enabled == false
    error_message = "Disabled state should be reflected in output"
  }
}

run "output_custom_retention" {
  command = plan

  variables {
    retention = {
      keep_daily   = 14
      keep_weekly  = 8
      keep_monthly = 12
    }
  }

  assert {
    condition     = output.retention.keep_daily == 14
    error_message = "Custom keep_daily should be 14"
  }

  assert {
    condition     = output.retention.keep_weekly == 8
    error_message = "Custom keep_weekly should be 8"
  }
}
