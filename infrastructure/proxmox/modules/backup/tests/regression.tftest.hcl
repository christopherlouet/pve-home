# =============================================================================
# Module Backup - Tests de non-regression
# =============================================================================
# Verifie que les bugs corriges ne reapparaissent pas.
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
# Regression v0.7.0: Retention triggers must use correct format
# The backup job triggers include retention values. keep_daily defaults to 7.
# -----------------------------------------------------------------------------

run "retention_default_keep_daily" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[7] == 7
    error_message = "Default keep_daily should be 7 (position [7] in triggers)"
  }
}

# -----------------------------------------------------------------------------
# Regression v0.7.0: Empty VMIDs should produce empty string, not null
# When no specific VMIDs are provided, the module backs up all VMs.
# -----------------------------------------------------------------------------

run "empty_vmids_produces_empty_string" {
  command = plan

  variables {
    vmids = []
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[6] == ""
    error_message = "Empty VMIDs should produce empty string in triggers, not null"
  }
}

# -----------------------------------------------------------------------------
# Regression v0.7.0: Disabled job should not change retention triggers
# When enabled=false, retention values should still be present in triggers.
# -----------------------------------------------------------------------------

run "disabled_job_preserves_retention" {
  command = plan

  variables {
    enabled = false
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[5] == false
    error_message = "Enabled trigger should be false when disabled"
  }

  assert {
    condition     = terraform_data.backup_job.triggers_replace[7] == 7
    error_message = "Retention keep_daily should still be 7 even when disabled"
  }
}

# -----------------------------------------------------------------------------
# Regression v0.7.0: Default schedule should be "01:00"
# -----------------------------------------------------------------------------

run "default_schedule" {
  command = plan

  assert {
    condition     = terraform_data.backup_job.triggers_replace[0] == "01:00"
    error_message = "Default schedule should be '01:00' (position [0] in triggers)"
  }
}
