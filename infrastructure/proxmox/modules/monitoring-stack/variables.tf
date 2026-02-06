# =============================================================================
# Module Monitoring Stack - Variables
# =============================================================================
# Stack de monitoring: Prometheus + Grafana + Alertmanager
# Deploye sur une VM dediee avec Docker Compose
# =============================================================================

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
  nullable    = false
}

variable "template_id" {
  description = "ID du template VM cloud-init"
  type        = number
  nullable    = false

  validation {
    condition     = var.template_id >= 100
    error_message = "template_id doit etre >= 100 (Proxmox reserve les IDs 0-99)."
  }
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

  validation {
    condition     = var.vm_config.cores >= 1 && var.vm_config.cores <= 64
    error_message = "vm_config.cores doit etre entre 1 et 64."
  }

  validation {
    condition     = var.vm_config.memory >= 512 && var.vm_config.memory <= 131072
    error_message = "vm_config.memory doit etre entre 512 et 131072 (512 MB - 128 GB)."
  }

  validation {
    condition     = var.vm_config.disk >= 4 && var.vm_config.disk <= 4096
    error_message = "vm_config.disk doit etre entre 4 et 4096 (4 GB - 4 TB)."
  }

  validation {
    condition     = var.vm_config.data_disk >= 4 && var.vm_config.data_disk <= 4096
    error_message = "vm_config.data_disk doit etre entre 4 et 4096 (4 GB - 4 TB)."
  }
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
  nullable    = false

  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.ip_address))
    error_message = "ip_address doit etre une adresse IPv4 valide (ex: 192.168.1.50)."
  }
}

variable "network_cidr" {
  description = "CIDR du reseau (ex: 24)"
  type        = number
  default     = 24

  validation {
    condition     = var.network_cidr >= 8 && var.network_cidr <= 32
    error_message = "network_cidr doit etre entre 8 et 32."
  }
}

variable "gateway" {
  description = "Passerelle reseau"
  type        = string
  nullable    = false
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
  nullable    = false
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

  validation {
    condition     = var.prometheus_retention_days >= 1 && var.prometheus_retention_days <= 365
    error_message = "prometheus_retention_days doit etre entre 1 et 365."
  }
}

variable "prometheus_retention_size" {
  description = "Taille max de retention (ex: 40GB)"
  type        = string
  default     = "40GB"

  validation {
    condition     = can(regex("^\\d+[KMGT]B$", var.prometheus_retention_size))
    error_message = "prometheus_retention_size doit etre au format NGB (ex: 40GB, 1TB)."
  }
}

variable "custom_scrape_configs" {
  description = "Configurations scrape Prometheus personnalisees (YAML brut, sans indentation)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Grafana Configuration
# -----------------------------------------------------------------------------

variable "grafana_admin_password" {
  description = "Mot de passe admin Grafana"
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(var.grafana_admin_password) >= 8
    error_message = "grafana_admin_password doit contenir au moins 8 caracteres."
  }
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
# Traefik Configuration (Reverse Proxy)
# -----------------------------------------------------------------------------

variable "traefik_enabled" {
  description = "Activer Traefik comme reverse proxy pour les services"
  type        = bool
  default     = true
}

variable "domain_suffix" {
  description = "Suffixe de domaine pour les URLs locales (ex: home.lan)"
  type        = string
  default     = "home.lan"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.domain_suffix))
    error_message = "domain_suffix doit etre un nom de domaine valide (ex: home.lan, homelab.local)."
  }
}

variable "tls_enabled" {
  description = "Activer HTTPS avec certificats auto-signes locaux"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Loki Configuration (Log Aggregation)
# -----------------------------------------------------------------------------

variable "loki_enabled" {
  description = "Activer Loki pour la centralisation des logs"
  type        = bool
  default     = true
}

variable "loki_retention_days" {
  description = "Duree de retention des logs en jours"
  type        = number
  default     = 7

  validation {
    condition     = var.loki_retention_days >= 1 && var.loki_retention_days <= 90
    error_message = "loki_retention_days doit etre entre 1 et 90."
  }
}

# -----------------------------------------------------------------------------
# Uptime Kuma Configuration (Status Page)
# -----------------------------------------------------------------------------

variable "uptime_kuma_enabled" {
  description = "Activer Uptime Kuma pour la surveillance de disponibilite"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Tooling Stack Integration (Step-ca, Harbor, Authentik)
# -----------------------------------------------------------------------------

variable "tooling_enabled" {
  description = "Activer l'intégration des dashboards et métriques du tooling stack"
  type        = bool
  default     = false
}

variable "tooling_ip" {
  description = "Adresse IP de la VM tooling (sans CIDR)"
  type        = string
  default     = ""

  validation {
    condition     = var.tooling_ip == "" || can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.tooling_ip))
    error_message = "tooling_ip doit être une adresse IPv4 valide (ex: 192.168.1.100) ou vide si tooling_enabled est false."
  }

  validation {
    condition     = !var.tooling_enabled || var.tooling_ip != ""
    error_message = "tooling_ip est requis quand tooling_enabled est true."
  }
}

variable "tooling_step_ca_enabled" {
  description = "Activer les dashboards et métriques Step-ca (PKI)"
  type        = bool
  default     = false
}

variable "tooling_harbor_enabled" {
  description = "Activer les dashboards et métriques Harbor (Registry)"
  type        = bool
  default     = false
}

variable "tooling_authentik_enabled" {
  description = "Activer les dashboards et métriques Authentik (SSO)"
  type        = bool
  default     = false
}

variable "tooling_traefik_enabled" {
  description = "Activer les dashboards et métriques Traefik sur tooling VM"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags pour la VM"
  type        = list(string)
  default     = ["terraform", "monitoring"]
}
