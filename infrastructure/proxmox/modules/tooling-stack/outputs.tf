# =============================================================================
# Module Tooling Stack - Outputs
# =============================================================================
# Expose les informations necessaires pour l'integration avec d'autres modules.
# =============================================================================

# -----------------------------------------------------------------------------
# VM Information
# -----------------------------------------------------------------------------

output "vm_id" {
  description = "ID de la VM tooling dans Proxmox"
  value       = proxmox_virtual_environment_vm.tooling.vm_id
}

output "vm_name" {
  description = "Nom de la VM tooling"
  value       = proxmox_virtual_environment_vm.tooling.name
}

output "node_name" {
  description = "Nom du node Proxmox"
  value       = proxmox_virtual_environment_vm.tooling.node_name
}

output "ip_address" {
  description = "Adresse IP de la VM tooling"
  value       = var.ip_address
}

output "domain_suffix" {
  description = "Suffixe de domaine utilise"
  value       = var.domain_suffix
}

output "ssh_command" {
  description = "Commande SSH pour se connecter a la VM"
  value       = "ssh ${var.username}@${var.ip_address}"
}

# -----------------------------------------------------------------------------
# Service URLs
# -----------------------------------------------------------------------------

output "urls" {
  description = "URLs des services deployes"
  value = {
    step_ca = var.step_ca_enabled ? (
      var.traefik_enabled ? "https://pki.${var.domain_suffix}" : "https://${var.ip_address}:8443"
    ) : ""
    harbor = var.harbor_enabled ? (
      var.traefik_enabled ? "https://registry.${var.domain_suffix}" : "https://${var.ip_address}:443"
    ) : ""
    authentik = var.authentik_enabled ? (
      var.traefik_enabled ? "https://auth.${var.domain_suffix}" : "http://${var.ip_address}:9000"
    ) : ""
    traefik = var.traefik_enabled ? "https://traefik.${var.domain_suffix}" : ""
  }
}

# -----------------------------------------------------------------------------
# Service Status
# -----------------------------------------------------------------------------

output "step_ca_enabled" {
  description = "Indique si Step-ca est active"
  value       = var.step_ca_enabled
}

output "harbor_enabled" {
  description = "Indique si Harbor est active"
  value       = var.harbor_enabled
}

output "authentik_enabled" {
  description = "Indique si Authentik est active"
  value       = var.authentik_enabled
}

output "traefik_enabled" {
  description = "Indique si Traefik est active"
  value       = var.traefik_enabled
}

# -----------------------------------------------------------------------------
# Step-ca PKI Outputs
# -----------------------------------------------------------------------------

output "step_ca_fingerprint" {
  description = "Fingerprint du certificat racine CA (pour step ca bootstrap)"
  value       = var.step_ca_enabled ? tls_self_signed_cert.root_ca[0].cert_pem : null
  sensitive   = false
}

output "step_ca_root_cert" {
  description = "Certificat racine CA au format PEM"
  value       = var.step_ca_enabled ? tls_self_signed_cert.root_ca[0].cert_pem : null
  sensitive   = false
}

output "ca_install_instructions" {
  description = "Instructions pour installer le certificat racine CA"
  value = var.step_ca_enabled ? join("\n", [
    "# Telecharger et installer le certificat racine CA:",
    "",
    "# Linux (Debian/Ubuntu):",
    "sudo curl -o /usr/local/share/ca-certificates/homelab-ca.crt https://pki.${var.domain_suffix}/roots.pem",
    "sudo update-ca-certificates",
    "",
    "# macOS:",
    "curl -o ~/homelab-ca.crt https://pki.${var.domain_suffix}/roots.pem",
    "sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/homelab-ca.crt",
    "",
    "# Windows (PowerShell):",
    "Invoke-WebRequest -Uri https://pki.${var.domain_suffix}/roots.pem -OutFile homelab-ca.crt",
    "Import-Certificate -FilePath homelab-ca.crt -CertStoreLocation Cert:\\LocalMachine\\Root",
    "",
    "# Docker (dans daemon.json):",
    "# Ajouter: insecure-registries et copier le CA",
  ]) : ""
}

# -----------------------------------------------------------------------------
# Harbor Registry Outputs
# -----------------------------------------------------------------------------

output "harbor_registry_url" {
  description = "URL du registre Harbor pour docker login"
  value       = var.harbor_enabled ? "registry.${var.domain_suffix}" : ""
}

output "harbor_admin_username" {
  description = "Nom d'utilisateur admin Harbor"
  value       = var.harbor_enabled ? "admin" : ""
}

# -----------------------------------------------------------------------------
# Authentik SSO Outputs
# -----------------------------------------------------------------------------

output "authentik_admin_url" {
  description = "URL de l'interface admin Authentik"
  value = var.authentik_enabled ? (
    var.traefik_enabled ? "https://auth.${var.domain_suffix}/if/admin/" : "http://${var.ip_address}:9000/if/admin/"
  ) : ""
}

output "authentik_admin_username" {
  description = "Nom d'utilisateur admin Authentik"
  value       = var.authentik_enabled ? "akadmin" : ""
}

# -----------------------------------------------------------------------------
# Integration Outputs (pour autres modules)
# -----------------------------------------------------------------------------

output "dns_records" {
  description = "Enregistrements DNS a creer pour les services"
  value = {
    pki      = var.step_ca_enabled && var.traefik_enabled ? { name = "pki", ip = var.ip_address } : null
    registry = var.harbor_enabled && var.traefik_enabled ? { name = "registry", ip = var.ip_address } : null
    auth     = var.authentik_enabled && var.traefik_enabled ? { name = "auth", ip = var.ip_address } : null
    traefik  = var.traefik_enabled ? { name = "traefik", ip = var.ip_address } : null
  }
}

output "monitoring_targets" {
  description = "Cibles de monitoring pour Prometheus"
  value = {
    step_ca = var.step_ca_enabled ? {
      job_name = "step-ca"
      targets  = ["${var.ip_address}:9290"]
    } : null
    harbor = var.harbor_enabled ? {
      job_name = "harbor"
      targets  = ["${var.ip_address}:9090"]
    } : null
    traefik = var.traefik_enabled ? {
      job_name = "traefik"
      targets  = ["${var.ip_address}:8082"]
    } : null
  }
}
