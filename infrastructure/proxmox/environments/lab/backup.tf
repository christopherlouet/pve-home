# =============================================================================
# Backup Configuration - Lab
# =============================================================================
# Sauvegardes vzdump hebdomadaires (dimanche 03:00) pour les VMs/LXC lab.
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
