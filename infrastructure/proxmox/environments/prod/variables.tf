# =============================================================================
# Variables pour l'environnement Prod
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
  description = "Nom de l'environnement"
  type        = string
  default     = "prod"
}

# -----------------------------------------------------------------------------
# Configuration des VMs et Conteneurs
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Backup
# -----------------------------------------------------------------------------

variable "backup" {
  description = "Configuration des sauvegardes vzdump"
  type = object({
    enabled  = optional(bool, true)
    schedule = optional(string, "01:00")
    storage  = optional(string, "local")
    mode     = optional(string, "snapshot")
    compress = optional(string, "zstd")
    retention = optional(object({
      keep_daily   = optional(number, 7)
      keep_weekly  = optional(number, 4)
      keep_monthly = optional(number, 0)
    }), {})
  })
  default = {}
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
