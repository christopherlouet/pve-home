# =============================================================================
# Variables pour l'environnement Home
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
}

variable "lxc_template" {
  description = "Template LXC (ex: local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst)"
  type        = string
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
  description = "Nom de l'environnement (home, dev, prod)"
  type        = string
  default     = "home"
}

# -----------------------------------------------------------------------------
# Configuration des VMs et Conteneurs
# -----------------------------------------------------------------------------

variable "vms" {
  description = "Configuration des VMs a creer"
  type = map(object({
    ip            = string
    cores         = number
    memory        = number
    disk          = number
    docker        = optional(bool, false)
    node_exporter = optional(bool, false)
    tags          = list(string)
  }))
  default = {}
}

variable "containers" {
  description = "Configuration des conteneurs LXC a creer"
  type = map(object({
    ip      = string
    cores   = number
    memory  = number
    disk    = number
    nesting = optional(bool, false)
    tags    = list(string)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Stack Monitoring (Prometheus + Grafana + Alertmanager)
# -----------------------------------------------------------------------------

variable "monitoring" {
  description = "Configuration de la stack monitoring"
  type = object({
    enabled = optional(bool, false)
    node    = optional(string, null)
    vm = optional(object({
      ip        = string
      cores     = optional(number, 2)
      memory    = optional(number, 4096)
      disk      = optional(number, 30)
      data_disk = optional(number, 50)
    }), null)
    proxmox_nodes = optional(list(object({
      name = string
      ip   = string
    })), [])
    pve_exporter = optional(object({
      user        = optional(string, "prometheus@pve")
      token_name  = optional(string, "prometheus")
      token_value = string
    }), null)
    retention_days         = optional(number, 30)
    grafana_admin_password = optional(string, "admin")
    telegram = optional(object({
      enabled   = optional(bool, false)
      bot_token = optional(string, "")
      chat_id   = optional(string, "")
    }), { enabled = false })
  })
  default = {
    enabled = false
  }
}
