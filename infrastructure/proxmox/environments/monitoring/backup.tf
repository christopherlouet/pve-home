# =============================================================================
# Backup Configuration - Monitoring
# =============================================================================
# Sauvegardes vzdump quotidiennes a 02:00 pour la stack monitoring.
# =============================================================================

module "backup" {
  source = "../../modules/backup"

  target_node = var.default_node
  storage_id  = var.backup.storage
  schedule    = var.backup.schedule
  mode        = var.backup.mode
  compress    = var.backup.compress
  enabled     = var.backup.enabled

  retention = var.backup.retention

  proxmox_endpoint  = var.proxmox_endpoint
  proxmox_api_token = var.proxmox_api_token
  proxmox_insecure  = var.proxmox_insecure
}

# -----------------------------------------------------------------------------
# Outputs Backup
# -----------------------------------------------------------------------------

output "backup" {
  description = "Configuration backup"
  value = {
    enabled  = module.backup.enabled
    schedule = module.backup.schedule
    storage  = module.backup.storage_id
  }
}
