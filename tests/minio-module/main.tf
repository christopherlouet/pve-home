# =============================================================================
# Test : Module Minio
# =============================================================================
# Configuration minimale pour valider le module minio avec terraform validate.
# Usage: cd tests/minio-module && terraform init && terraform validate
# =============================================================================

variable "minio_root_password" {
  description = "Minio root password"
  type        = string
  sensitive   = true
  default     = "test-password-change-me"
}

module "minio" {
  source = "../../infrastructure/proxmox/modules/minio"

  hostname    = "test-minio"
  target_node = "pve-test"

  ip_address = "192.168.1.200/24"
  gateway    = "192.168.1.1"

  ssh_keys = ["ssh-ed25519 AAAA... test@test"]

  minio_root_user     = "minioadmin"
  minio_root_password = var.minio_root_password

  buckets = ["tfstate-prod", "tfstate-lab", "tfstate-monitoring"]
}

# Verify outputs exist
output "test_endpoint_url" {
  value = module.minio.endpoint_url
}

output "test_console_url" {
  value = module.minio.console_url
}

output "test_container_id" {
  value = module.minio.container_id
}

output "test_ip_address" {
  value = module.minio.ip_address
}
