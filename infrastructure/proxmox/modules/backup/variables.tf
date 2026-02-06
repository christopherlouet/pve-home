# =============================================================================
# Module Backup - Variables
# =============================================================================

variable "target_node" {
  description = "Node Proxmox cible pour les sauvegardes"
  type        = string
  nullable    = false
}

variable "storage_id" {
  description = "ID du storage pour les sauvegardes (ex: local, backup-store)"
  type        = string
  default     = "local"

  validation {
    condition     = length(var.storage_id) > 0
    error_message = "storage_id ne peut pas etre vide."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.storage_id))
    error_message = "storage_id doit contenir uniquement des caracteres alphanumeriques, tirets et underscores."
  }
}

variable "schedule" {
  description = "Horaire de sauvegarde au format Proxmox (ex: '01:00' pour 1h du matin quotidien, 'sun 03:00' pour dimanche 3h)"
  type        = string
  default     = "01:00"

  validation {
    condition     = can(regex("^(mon|tue|wed|thu|fri|sat|sun)?\\s?\\d{2}:\\d{2}$", var.schedule))
    error_message = "Le format doit etre 'HH:MM' ou 'dow HH:MM' (ex: '01:00', 'sun 03:00')."
  }
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

  validation {
    condition     = var.retention.keep_daily >= 0 && var.retention.keep_weekly >= 0 && var.retention.keep_monthly >= 0
    error_message = "Les valeurs de retention (keep_daily, keep_weekly, keep_monthly) doivent etre >= 0."
  }
}

variable "notification_mode" {
  description = "Mode de notification Proxmox : auto, legacy-sendmail, notification-system"
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "legacy-sendmail", "notification-system"], var.notification_mode)
    error_message = "Le mode de notification doit etre 'auto', 'legacy-sendmail' ou 'notification-system'."
  }
}

variable "mail_to" {
  description = "Adresse email pour les notifications (vide = pas de mail)"
  type        = string
  default     = ""

  validation {
    condition     = var.mail_to == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.mail_to))
    error_message = "mail_to doit etre une adresse email valide ou vide."
  }
}

variable "notes_template" {
  description = "Template pour les notes de sauvegarde"
  type        = string
  default     = "{{guestname}} - Backup automatique"

  validation {
    condition     = !can(regex("[;`$\\\\|><&]", var.notes_template))
    error_message = "notes_template ne doit pas contenir de metacaracteres shell (;`$\\|><&)."
  }
}

variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox (ex: https://192.168.1.100:8006)"
  type        = string
  nullable    = false
}

