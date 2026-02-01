# =============================================================================
# Module Minio S3 - Outputs
# =============================================================================

output "endpoint_url" {
  description = "URL de l'API S3 Minio"
  value       = "http://${local.minio_ip}:${var.minio_port}"
}

output "console_url" {
  description = "URL de la console Minio"
  value       = "http://${local.minio_ip}:${var.minio_console_port}"
}

output "container_id" {
  description = "ID du conteneur LXC"
  value       = proxmox_virtual_environment_container.minio.vm_id
}

output "ip_address" {
  description = "Adresse IP du conteneur"
  value       = var.ip_address
}
