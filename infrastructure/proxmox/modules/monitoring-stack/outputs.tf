# =============================================================================
# Module Monitoring Stack - Outputs
# =============================================================================

output "vm_id" {
  description = "ID de la VM monitoring"
  value       = proxmox_virtual_environment_vm.monitoring.vm_id
}

output "vm_name" {
  description = "Nom de la VM monitoring"
  value       = proxmox_virtual_environment_vm.monitoring.name
}

output "ip_address" {
  description = "Adresse IP de la VM monitoring"
  value       = var.ip_address
}

output "node_name" {
  description = "Node Proxmox"
  value       = proxmox_virtual_environment_vm.monitoring.node_name
}

output "urls" {
  description = "URLs des services monitoring"
  value = {
    prometheus   = "http://${var.ip_address}:9090"
    grafana      = "http://${var.ip_address}:3000"
    alertmanager = "http://${var.ip_address}:9093"
  }
}

output "ssh_command" {
  description = "Commande SSH pour se connecter"
  value       = "ssh ${var.username}@${var.ip_address}"
}

output "scrape_targets" {
  description = "Liste des cibles Prometheus configurees"
  value = [
    for target in local.all_scrape_targets : "${target.ip}:${target.port}"
  ]
}

output "health_check_ssh_public_key" {
  description = "Cle SSH publique de la VM monitoring pour les health checks"
  value       = trimspace(tls_private_key.health_check.public_key_openssh)
}
