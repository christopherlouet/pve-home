# =============================================================================
# Module Backup - Tests de validation des entrees
# =============================================================================
# Verifie que les regles de validation des variables rejettent les valeurs
# invalides et acceptent les valeurs valides.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests (configuration minimale valide)
# -----------------------------------------------------------------------------

variables {
  target_node      = "pve-test"
  proxmox_endpoint = "https://192.168.1.100:8006"
}

# -----------------------------------------------------------------------------
# storage_id validation (non-empty)
# -----------------------------------------------------------------------------

run "storage_id_valid" {
  command = plan

  variables {
    storage_id = "backup-store"
  }
}

run "storage_id_invalid_empty" {
  command = plan

  variables {
    storage_id = ""
  }

  expect_failures = [
    var.storage_id,
  ]
}

# -----------------------------------------------------------------------------
# schedule validation (HH:MM or dow HH:MM)
# -----------------------------------------------------------------------------

run "schedule_valid_time_only" {
  command = plan

  variables {
    schedule = "01:00"
  }
}

run "schedule_valid_with_day" {
  command = plan

  variables {
    schedule = "sun 03:00"
  }
}

run "schedule_valid_weekday" {
  command = plan

  variables {
    schedule = "mon 22:30"
  }
}

run "schedule_invalid_format" {
  command = plan

  variables {
    schedule = "every day at noon"
  }

  expect_failures = [
    var.schedule,
  ]
}

run "schedule_invalid_day" {
  command = plan

  variables {
    schedule = "sunday 03:00"
  }

  expect_failures = [
    var.schedule,
  ]
}

# -----------------------------------------------------------------------------
# mode validation (snapshot, suspend, stop)
# -----------------------------------------------------------------------------

run "mode_valid_snapshot" {
  command = plan

  variables {
    mode = "snapshot"
  }
}

run "mode_valid_suspend" {
  command = plan

  variables {
    mode = "suspend"
  }
}

run "mode_valid_stop" {
  command = plan

  variables {
    mode = "stop"
  }
}

run "mode_invalid" {
  command = plan

  variables {
    mode = "live"
  }

  expect_failures = [
    var.mode,
  ]
}

# -----------------------------------------------------------------------------
# compress validation (zstd, lzo, gzip, none)
# -----------------------------------------------------------------------------

run "compress_valid_zstd" {
  command = plan

  variables {
    compress = "zstd"
  }
}

run "compress_valid_none" {
  command = plan

  variables {
    compress = "none"
  }
}

run "compress_invalid" {
  command = plan

  variables {
    compress = "bzip2"
  }

  expect_failures = [
    var.compress,
  ]
}

# -----------------------------------------------------------------------------
# notification_mode validation
# -----------------------------------------------------------------------------

run "notification_mode_valid_auto" {
  command = plan

  variables {
    notification_mode = "auto"
  }
}

run "notification_mode_valid_notification_system" {
  command = plan

  variables {
    notification_mode = "notification-system"
  }
}

run "notification_mode_invalid" {
  command = plan

  variables {
    notification_mode = "email"
  }

  expect_failures = [
    var.notification_mode,
  ]
}

# -----------------------------------------------------------------------------
# retention validation (>= 0)
# -----------------------------------------------------------------------------

run "retention_valid_defaults" {
  command = plan
}

run "retention_valid_custom" {
  command = plan

  variables {
    retention = {
      keep_daily   = 14
      keep_weekly  = 4
      keep_monthly = 6
    }
  }
}

run "retention_invalid_negative_daily" {
  command = plan

  variables {
    retention = {
      keep_daily   = -1
      keep_weekly  = 0
      keep_monthly = 0
    }
  }

  expect_failures = [
    var.retention,
  ]
}

# -----------------------------------------------------------------------------
# Defaults verification
# -----------------------------------------------------------------------------

run "defaults_are_applied" {
  command = plan

  assert {
    condition     = var.storage_id == "local"
    error_message = "Default storage_id should be local"
  }

  assert {
    condition     = var.schedule == "01:00"
    error_message = "Default schedule should be 01:00"
  }

  assert {
    condition     = var.mode == "snapshot"
    error_message = "Default mode should be snapshot"
  }

  assert {
    condition     = var.compress == "zstd"
    error_message = "Default compress should be zstd"
  }

  assert {
    condition     = var.enabled == true
    error_message = "Default enabled should be true"
  }

  assert {
    condition     = var.notification_mode == "auto"
    error_message = "Default notification_mode should be auto"
  }

  assert {
    condition     = var.retention.keep_daily == 7
    error_message = "Default keep_daily should be 7"
  }
}
