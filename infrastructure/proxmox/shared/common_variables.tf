# =============================================================================
# Variables communes a tous les environnements
# =============================================================================
# Ce fichier est symlinke dans chaque environnement (prod, lab, monitoring).
# Ne PAS modifier les copies - modifier uniquement ce fichier source.
# =============================================================================

# -----------------------------------------------------------------------------
# Provider Proxmox
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
  # SECURITY NOTE: true par defaut pour homelab avec certificats auto-signes.
  # En production, configurer des certificats valides et passer a false.
  description = "Ignorer la verification SSL (true si certificat auto-signe)"
  type        = bool
  default     = true
}

variable "ssh_username" {
  description = "Username SSH pour les nodes Proxmox"
  type        = string
  default     = "root"
}

# -----------------------------------------------------------------------------
# Infrastructure
# -----------------------------------------------------------------------------

variable "default_node" {
  description = "Node Proxmox par defaut"
  type        = string
  default     = "pve"
}

# -----------------------------------------------------------------------------
# Templates
# -----------------------------------------------------------------------------

variable "vm_template_id" {
  description = "ID du template VM cloud-init"
  type        = number
  default     = 9000

  validation {
    condition     = var.vm_template_id >= 100
    error_message = "vm_template_id doit etre >= 100 (Proxmox reserve les IDs 0-99)."
  }
}

# -----------------------------------------------------------------------------
# Reseau
# -----------------------------------------------------------------------------

variable "network_bridge" {
  description = "Bridge reseau Proxmox"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Passerelle reseau"
  type        = string
}

variable "network_dns" {
  description = "Serveurs DNS"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------

variable "ssh_public_keys" {
  description = "Cles SSH publiques autorisees"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# Stockage
# -----------------------------------------------------------------------------

variable "default_datastore" {
  description = "Datastore par defaut pour les disques"
  type        = string
  default     = "local-lvm"
}
