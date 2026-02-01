# =============================================================================
# Module Backup - Variables
# =============================================================================

variable "target_node" {
  description = "Node Proxmox cible pour les sauvegardes"
  type        = string
}

variable "storage_id" {
  description = "ID du storage pour les sauvegardes (ex: local, backup-store)"
  type        = string
  default     = "local"
}

variable "schedule" {
  description = "Horaire de sauvegarde au format Proxmox (ex: '01:00' pour 1h du matin quotidien, 'sun 03:00' pour dimanche 3h)"
  type        = string
  default     = "01:00"
}

variable "mode" {
  description = "Mode de sauvegarde : snapshot (pas d'interruption), suspend (pause breve), stop (arret complet)"
  type        = string
  default     = "snapshot"

  validation {
    condition     = contains(["snapshot", "suspend", "stop"], var.mode)
    error_message = "Le mode doit etre 'snapshot', 'suspend' ou 'stop'."
  }
}

variable "compress" {
  description = "Algorithme de compression : zstd (recommande), lzo, gzip, none"
  type        = string
  default     = "zstd"

  validation {
    condition     = contains(["zstd", "lzo", "gzip", "none"], var.compress)
    error_message = "L'algorithme doit etre 'zstd', 'lzo', 'gzip' ou 'none'."
  }
}

variable "vmids" {
  description = "Liste des VM/LXC IDs a sauvegarder (vide = toutes les VMs du node)"
  type        = list(number)
  default     = []
}

variable "enabled" {
  description = "Activer le job de sauvegarde"
  type        = bool
  default     = true
}

variable "retention" {
  description = "Politique de retention des sauvegardes"
  type = object({
    keep_daily   = optional(number, 7)
    keep_weekly  = optional(number, 0)
    keep_monthly = optional(number, 0)
  })
  default = {
    keep_daily   = 7
    keep_weekly  = 0
    keep_monthly = 0
  }
}

variable "notification_mode" {
  description = "Mode de notification : always, failure, never"
  type        = string
  default     = "failure"

  validation {
    condition     = contains(["always", "failure", "never"], var.notification_mode)
    error_message = "Le mode de notification doit etre 'always', 'failure' ou 'never'."
  }
}

variable "mail_to" {
  description = "Adresse email pour les notifications (vide = pas de mail)"
  type        = string
  default     = ""
}

variable "notes_template" {
  description = "Template pour les notes de sauvegarde"
  type        = string
  default     = "{{guestname}} - Backup automatique"
}

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
  description = "Ignorer la verification SSL"
  type        = bool
  default     = true
}
