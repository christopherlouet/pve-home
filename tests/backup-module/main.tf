# =============================================================================
# Test : Module Backup
# =============================================================================
# Configuration minimale pour valider le module backup avec terraform validate.
# Usage: cd tests/backup-module && terraform init && terraform validate
# =============================================================================

module "backup" {
  source = "../../infrastructure/proxmox/modules/backup"

  target_node = "pve-test"
  storage_id  = "local"

  schedule = "01:00"
  mode     = "snapshot"
  compress = "zstd"
  enabled  = true

  vmids = [100, 101, 102]

  retention = {
    keep_daily   = 7
    keep_weekly  = 4
    keep_monthly = 0
  }

  proxmox_endpoint  = "https://192.168.1.100:8006"
  proxmox_api_token = "test@pve!test=00000000-0000-0000-0000-000000000000"
}

# Verify outputs exist
output "test_job_id" {
  value = module.backup.job_id
}

output "test_storage_id" {
  value = module.backup.storage_id
}

output "test_schedule" {
  value = module.backup.schedule
}
