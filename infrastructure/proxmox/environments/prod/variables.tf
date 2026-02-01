# =============================================================================
# Variables pour l'environnement Prod
# =============================================================================
# Variables communes: voir common_variables.tf (symlink vers shared/)
# =============================================================================

# -----------------------------------------------------------------------------
# Environnement
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "prod"
}

# -----------------------------------------------------------------------------
# Templates
# -----------------------------------------------------------------------------

variable "lxc_template" {
  description = "Template LXC (ex: local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst)"
  type        = string
}

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------

variable "monitoring_ssh_public_key" {
  description = "Cle SSH publique de la VM monitoring pour les health checks (output de l'env monitoring)"
  type        = string
  default     = ""
}

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
