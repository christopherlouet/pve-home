# =============================================================================
# Variables pour l'environnement Monitoring
# =============================================================================

# -----------------------------------------------------------------------------
# Provider Proxmox
# -----------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox du PVE monitoring (ex: https://192.168.1.50:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "Token API Proxmox (format: user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
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
  description = "Node Proxmox par defaut (PVE dedie monitoring)"
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

# -----------------------------------------------------------------------------
# Environnement
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "monitoring"
}

# -----------------------------------------------------------------------------
# Stack Monitoring (Prometheus + Grafana + Alertmanager)
# -----------------------------------------------------------------------------

variable "monitoring" {
  description = "Configuration de la stack monitoring"
  type = object({
    node = optional(string, null)
    vm = object({
      ip        = string
      cores     = optional(number, 2)
      memory    = optional(number, 4096)
      disk      = optional(number, 30)
      data_disk = optional(number, 50)
    })
    proxmox_nodes = list(object({
      name        = string
      ip          = string
      token_value = string
    }))
    pve_exporter = object({
      user       = optional(string, "prometheus@pve")
      token_name = optional(string, "prometheus")
    })
    retention_days         = optional(number, 30)
    grafana_admin_password = optional(string, "admin")
    telegram = optional(object({
      enabled   = optional(bool, false)
      bot_token = optional(string, "")
      chat_id   = optional(string, "")
    }), { enabled = false })
  })
}

# -----------------------------------------------------------------------------
# Cibles distantes (VMs sur d'autres PVE)
# -----------------------------------------------------------------------------

variable "remote_targets" {
  description = "VMs hebergees sur d'autres PVE a monitorer via node_exporter"
  type = list(object({
    name   = string
    ip     = string
    port   = optional(number, 9100)
    labels = optional(map(string), {})
  }))
  default = []
}
