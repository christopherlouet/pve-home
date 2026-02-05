# =============================================================================
# Variables communes aux environnements Prod et Lab
# =============================================================================
# Ce fichier est symlinke dans les environnements prod et lab.
# Ne PAS modifier les copies - modifier uniquement ce fichier source.
# Les valeurs par defaut sont generiques - chaque environnement
# DOIT specifier ses valeurs dans terraform.tfvars.
# =============================================================================

# -----------------------------------------------------------------------------
# Templates
# -----------------------------------------------------------------------------

variable "lxc_template" {
  description = "Template LXC (ex: local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst)"
  type        = string
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
