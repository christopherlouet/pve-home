# =============================================================================
# Module Monitoring Stack - Variables
# =============================================================================
# Stack de monitoring: Prometheus + Grafana + Alertmanager
# Deploye sur une VM dediee avec Docker Compose
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

# -----------------------------------------------------------------------------
# VM Configuration
# -----------------------------------------------------------------------------

variable "name" {
  description = "Nom de base pour les ressources monitoring"
  type        = string
  default     = "monitoring"
}

variable "target_node" {
  description = "Node Proxmox pour deployer la VM monitoring"
  type        = string
}

variable "template_id" {
  description = "ID du template VM cloud-init"
  type        = number
}

variable "vm_config" {
  description = "Configuration des ressources VM"
  type = object({
    cores     = optional(number, 2)
    memory    = optional(number, 4096)
    disk      = optional(number, 30)
    data_disk = optional(number, 50)
  })
  default = {}
}

variable "datastore" {
  description = "Datastore pour les disques"
  type        = string
  default     = "local-lvm"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "ip_address" {
  description = "Adresse IP de la VM monitoring (sans CIDR)"
  type        = string
}

variable "network_cidr" {
  description = "CIDR du reseau (ex: 24)"
  type        = number
  default     = 24
}

variable "gateway" {
  description = "Passerelle reseau"
  type        = string
}

variable "dns_servers" {
  description = "Serveurs DNS"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "network_bridge" {
  description = "Bridge reseau Proxmox"
  type        = string
  default     = "vmbr0"
}

# -----------------------------------------------------------------------------
# SSH Configuration
# -----------------------------------------------------------------------------

variable "ssh_keys" {
  description = "Cles SSH publiques"
  type        = list(string)
}

variable "username" {
  description = "Utilisateur cloud-init"
  type        = string
  default     = "ubuntu"
}

# -----------------------------------------------------------------------------
# Proxmox Nodes to Monitor
# -----------------------------------------------------------------------------

variable "proxmox_nodes" {
  description = "Liste des nodes Proxmox a monitorer avec credentials par node"
  type = list(object({
    name        = string
    ip          = string
    token_value = string
  }))
}

variable "pve_exporter_user" {
  description = "Utilisateur API pour pve-exporter (format: user@realm)"
  type        = string
  default     = "prometheus@pve"
}

variable "pve_exporter_token_name" {
  description = "Nom du token API pour pve-exporter"
  type        = string
  default     = "prometheus"
}


# -----------------------------------------------------------------------------
# Additional Scrape Targets
# -----------------------------------------------------------------------------

variable "additional_scrape_targets" {
  description = "Cibles additionnelles a scraper (VMs avec node_exporter sur le meme reseau)"
  type = list(object({
    name   = string
    ip     = string
    port   = optional(number, 9100)
    labels = optional(map(string), {})
  }))
  default = []
}

variable "remote_scrape_targets" {
  description = "Cibles distantes a scraper (VMs sur d'autres PVE/reseaux)"
  type = list(object({
    name   = string
    ip     = string
    port   = optional(number, 9100)
    labels = optional(map(string), {})
  }))
  default = []
}

# -----------------------------------------------------------------------------
# Prometheus Configuration
# -----------------------------------------------------------------------------

variable "prometheus_retention_days" {
  description = "Duree de retention des metriques en jours"
  type        = number
  default     = 30
}

variable "prometheus_retention_size" {
  description = "Taille max de retention (ex: 40GB)"
  type        = string
  default     = "40GB"
}

# -----------------------------------------------------------------------------
# Grafana Configuration
# -----------------------------------------------------------------------------

variable "grafana_admin_password" {
  description = "Mot de passe admin Grafana"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Alertmanager Configuration - Telegram
# -----------------------------------------------------------------------------

variable "telegram_enabled" {
  description = "Activer les notifications Telegram"
  type        = bool
  default     = true
}

variable "telegram_bot_token" {
  description = "Token du bot Telegram"
  type        = string
  sensitive   = true
  default     = ""
}

variable "telegram_chat_id" {
  description = "Chat ID Telegram pour les notifications"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Backup Alerting
# -----------------------------------------------------------------------------

variable "backup_alerting_enabled" {
  description = "Activer les alertes de supervision des sauvegardes vzdump"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags pour la VM"
  type        = list(string)
  default     = ["terraform", "monitoring"]
}
