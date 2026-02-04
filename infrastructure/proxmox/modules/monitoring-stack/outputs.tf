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
  value = var.traefik_enabled ? merge(
    {
      grafana      = "http://grafana.${var.domain_suffix}"
      prometheus   = "http://prometheus.${var.domain_suffix}"
      alertmanager = "http://alertmanager.${var.domain_suffix}"
      traefik      = "http://traefik.${var.domain_suffix}"
    },
    var.loki_enabled ? { loki = "http://loki.${var.domain_suffix}" } : {},
    var.uptime_kuma_enabled ? { uptime = "http://uptime.${var.domain_suffix}" } : {}
    ) : merge(
    {
      prometheus   = "http://${var.ip_address}:9090"
      grafana      = "http://${var.ip_address}:3000"
      alertmanager = "http://${var.ip_address}:9093"
    },
    var.loki_enabled ? { loki = "http://${var.ip_address}:3100" } : {},
    var.uptime_kuma_enabled ? { uptime = "http://${var.ip_address}:3001" } : {}
  )
}

output "traefik_enabled" {
  description = "Indique si Traefik est active"
  value       = var.traefik_enabled
}

output "loki_enabled" {
  description = "Indique si Loki est active"
  value       = var.loki_enabled
}

output "loki_url" {
  description = "URL du serveur Loki pour les agents Promtail distants"
  value       = var.loki_enabled ? "http://${var.ip_address}:3100" : ""
}

output "uptime_kuma_enabled" {
  description = "Indique si Uptime Kuma est active"
  value       = var.uptime_kuma_enabled
}

output "uptime_kuma_url" {
  description = "URL du serveur Uptime Kuma"
  value       = var.uptime_kuma_enabled ? "http://${var.ip_address}:3001" : ""
}

output "domain_suffix" {
  description = "Suffixe de domaine utilise pour les URLs"
  value       = var.domain_suffix
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
