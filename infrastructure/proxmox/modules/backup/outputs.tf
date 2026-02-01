# =============================================================================
# Module Backup - Outputs
# =============================================================================

output "job_id" {
  description = "ID du resource terraform_data pour le job de backup"
  value       = terraform_data.backup_job.id
}

output "storage_id" {
  description = "Storage utilise pour les sauvegardes"
  value       = var.storage_id
}

output "schedule" {
  description = "Horaire de sauvegarde configure"
  value       = var.schedule
}

output "target_node" {
  description = "Node Proxmox cible"
  value       = var.target_node
}

output "enabled" {
  description = "Etat du job de backup"
  value       = var.enabled
}

output "retention" {
  description = "Politique de retention configuree"
  value       = var.retention
}
