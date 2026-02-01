# =============================================================================
# Module LXC Proxmox - Outputs
# =============================================================================

output "container_id" {
  description = "ID du conteneur"
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "hostname" {
  description = "Hostname du conteneur"
  value       = var.hostname
}

output "ipv4_address" {
  description = "Adresse IPv4"
  value       = var.ip_address
}

output "node_name" {
  description = "Node Proxmox"
  value       = proxmox_virtual_environment_container.this.node_name
}
