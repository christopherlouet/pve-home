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
    grafana_admin_password = string
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

# -----------------------------------------------------------------------------
# Minio S3 (Backend Terraform State)
# -----------------------------------------------------------------------------

variable "minio" {
  description = "Configuration du conteneur Minio S3"
  type = object({
    ip                = string
    template_file_id  = optional(string, "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst")
    cpu_cores         = optional(number, 1)
    memory_mb         = optional(number, 512)
    disk_size_gb      = optional(number, 8)
    data_disk_size_gb = optional(number, 50)
    root_user         = optional(string, "minioadmin")
    root_password     = string
    port              = optional(number, 9000)
    console_port      = optional(number, 9001)
    buckets           = optional(list(string), ["tfstate-prod", "tfstate-lab", "tfstate-monitoring"])
  })
}

# -----------------------------------------------------------------------------
# Backup
# -----------------------------------------------------------------------------

variable "backup" {
  description = "Configuration des sauvegardes vzdump"
  type = object({
    enabled  = optional(bool, true)
    schedule = optional(string, "02:00")
    storage  = optional(string, "local")
    mode     = optional(string, "snapshot")
    compress = optional(string, "zstd")
    retention = optional(object({
      keep_daily   = optional(number, 7)
      keep_weekly  = optional(number, 0)
      keep_monthly = optional(number, 0)
    }), {})
  })
  default = {}
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
