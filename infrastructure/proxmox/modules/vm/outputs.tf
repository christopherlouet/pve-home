# =============================================================================
# Module VM Proxmox - Outputs
# =============================================================================

output "vm_id" {
  description = "ID de la VM"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "Nom de la VM"
  value       = proxmox_virtual_environment_vm.this.name
}

output "ipv4_address" {
  description = "Adresse IPv4"
  value       = try(proxmox_virtual_environment_vm.this.ipv4_addresses[1][0], var.ip_address)
}

output "mac_address" {
  description = "Adresse MAC"
  value       = try(proxmox_virtual_environment_vm.this.mac_addresses[0], null)
}

output "node_name" {
  description = "Node Proxmox"
  value       = proxmox_virtual_environment_vm.this.node_name
}
