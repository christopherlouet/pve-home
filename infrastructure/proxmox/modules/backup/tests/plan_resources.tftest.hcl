# =============================================================================
# Module Backup - Tests du plan genere
# =============================================================================
# Verifie que le plan Terraform genere les bonnes ressources avec les bons
# attributs selon la configuration fournie.
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
# Resource terraform_data.backup_job
# -----------------------------------------------------------------------------

run "backup_creates_data_resource" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace != null
    error_message = "Backup job should have triggers_replace defined"
  }
}

run "backup_triggers_include_schedule" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[0] == "01:00"
    error_message = "First trigger should be schedule (default: 01:00)"
  }
}

run "backup_triggers_include_storage" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[1] == "local"
    error_message = "Second trigger should be storage_id (default: local)"
  }
}

run "backup_triggers_include_mode" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[2] == "snapshot"
    error_message = "Third trigger should be mode (default: snapshot)"
  }
}

run "backup_triggers_include_compress" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[3] == "zstd"
    error_message = "Fourth trigger should be compress (default: zstd)"
  }
}

run "backup_triggers_include_node" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[4] == "pve-test"
    error_message = "Fifth trigger should be target_node"
  }
}

run "backup_triggers_include_enabled" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[5] == true
    error_message = "Sixth trigger should be enabled (default: true)"
  }
}

# -----------------------------------------------------------------------------
# Custom configuration
# -----------------------------------------------------------------------------

run "backup_custom_schedule" {
  command = plan

  variables {
    schedule = "sun 03:00"
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[0] == "sun 03:00"
    error_message = "Schedule trigger should be updated to sun 03:00"
  }
}

run "backup_custom_storage" {
  command = plan

  variables {
    storage_id = "backup-nfs"
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[1] == "backup-nfs"
    error_message = "Storage trigger should be updated to backup-nfs"
  }
}

run "backup_custom_mode_stop" {
  command = plan

  variables {
    mode = "stop"
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[2] == "stop"
    error_message = "Mode trigger should be updated to stop"
  }
}

run "backup_disabled" {
  command = plan

  variables {
    enabled = false
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[5] == false
    error_message = "Enabled trigger should be false when disabled"
  }
}

# -----------------------------------------------------------------------------
# Retention triggers
# -----------------------------------------------------------------------------

run "backup_default_retention_triggers" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[7] == 7
    error_message = "Keep daily trigger should default to 7"
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[8] == 0
    error_message = "Keep weekly trigger should default to 0"
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[9] == 0
    error_message = "Keep monthly trigger should default to 0"
  }
}

run "backup_custom_retention" {
  command = plan

  variables {
    retention = {
      keep_daily   = 14
      keep_weekly  = 4
      keep_monthly = 6
    }
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[7] == 14
    error_message = "Keep daily trigger should be 14"
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[8] == 4
    error_message = "Keep weekly trigger should be 4"
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[9] == 6
    error_message = "Keep monthly trigger should be 6"
  }
}

# -----------------------------------------------------------------------------
# VMIDs trigger
# -----------------------------------------------------------------------------

run "backup_no_vmids_trigger_empty" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[6] == ""
    error_message = "VMIDs trigger should be empty string when no VMIDs specified"
  }
}

run "backup_with_vmids" {
  command = plan

  variables {
    vmids = [100, 101, 102]
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[6] == "100,101,102"
    error_message = "VMIDs trigger should contain comma-separated IDs"
  }
}
