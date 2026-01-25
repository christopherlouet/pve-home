# =============================================================================
# Proxmox Home Lab - Configuration principale
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }

  # Backend local pour un homelab (suffisant pour un seul utilisateur)
  # Pour un usage plus avancé, envisager un backend S3/Minio
}

# -----------------------------------------------------------------------------
# Variables du provider
# -----------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox (ex: https://192.168.1.100:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "Token API Proxmox (format: user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Ignorer la vérification SSL (true si certificat auto-signé)"
  type        = bool
  default     = true
}

variable "ssh_username" {
  description = "Username SSH pour les nodes Proxmox"
  type        = string
  default     = "root"
}

# -----------------------------------------------------------------------------
# Provider Proxmox
# -----------------------------------------------------------------------------

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  ssh {
    agent    = true
    username = var.ssh_username
  }
}

# -----------------------------------------------------------------------------
# Data sources
# -----------------------------------------------------------------------------

data "proxmox_virtual_environment_nodes" "available" {}

data "proxmox_virtual_environment_datastores" "available" {
  node_name = data.proxmox_virtual_environment_nodes.available.names[0]
}

# -----------------------------------------------------------------------------
# Outputs informatifs
# -----------------------------------------------------------------------------

output "proxmox_nodes" {
  description = "Nodes Proxmox disponibles"
  value       = data.proxmox_virtual_environment_nodes.available.names
}

output "proxmox_datastores" {
  description = "Datastores disponibles"
  value       = [for ds in data.proxmox_virtual_environment_datastores.available.datastore_ids : ds]
}
