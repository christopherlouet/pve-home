# =============================================================================
# Module VM Proxmox - Variables
# =============================================================================

variable "name" {
  description = "Nom de la VM"
  type        = string
}

variable "description" {
  description = "Description de la VM"
  type        = string
  default     = "Managed by Terraform"
}

variable "target_node" {
  description = "Node Proxmox cible"
  type        = string
}

variable "template_id" {
  description = "ID du template à cloner"
  type        = number

  validation {
    condition     = var.template_id >= 100
    error_message = "template_id doit etre >= 100 (Proxmox reserve les IDs 0-99)."
  }
}

variable "cpu_cores" {
  description = "Nombre de cores CPU"
  type        = number
  default     = 2

  validation {
    condition     = var.cpu_cores >= 1 && var.cpu_cores <= 64
    error_message = "cpu_cores doit etre entre 1 et 64."
  }
}

variable "cpu_type" {
  description = "Type de CPU (host, kvm64, etc.)"
  type        = string
  default     = "host"
}

variable "memory_mb" {
  description = "RAM en MB"
  type        = number
  default     = 2048

  validation {
    condition     = var.memory_mb >= 128 && var.memory_mb <= 131072
    error_message = "memory_mb doit etre entre 128 et 131072 (128 MB - 128 GB)."
  }
}

variable "disk_size_gb" {
  description = "Taille du disque système en GB"
  type        = number
  default     = 20

  validation {
    condition     = var.disk_size_gb >= 4 && var.disk_size_gb <= 4096
    error_message = "disk_size_gb doit etre entre 4 et 4096 (4 GB - 4 TB)."
  }
}

variable "datastore" {
  description = "Datastore pour le disque"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Bridge réseau"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN ID (null si pas de VLAN)"
  type        = number
  default     = null

  validation {
    condition     = var.vlan_id == null ? true : var.vlan_id >= 1 && var.vlan_id <= 4094
    error_message = "vlan_id doit etre entre 1 et 4094 ou null."
  }
}

variable "ip_address" {
  description = "Adresse IP en notation CIDR (ex: 192.168.1.10/24)"
  type        = string

  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}$", var.ip_address))
    error_message = "ip_address doit etre au format CIDR (ex: 192.168.1.10/24)."
  }
}

variable "gateway" {
  description = "Passerelle par défaut"
  type        = string
}

variable "dns_servers" {
  description = "Serveurs DNS"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "username" {
  description = "Utilisateur cloud-init"
  type        = string
  default     = "ubuntu"
}

variable "ssh_keys" {
  description = "Clés SSH publiques"
  type        = list(string)
}

variable "tags" {
  description = "Tags de la VM"
  type        = list(string)
  default     = ["terraform"]
}

variable "start_on_boot" {
  description = "Démarrer automatiquement au boot du node"
  type        = bool
  default     = true
}

variable "agent_enabled" {
  description = "Activer QEMU Guest Agent"
  type        = bool
  default     = true
}

variable "additional_disks" {
  description = "Disques additionnels"
  type = list(object({
    size         = number
    datastore_id = optional(string, "local-lvm")
    interface    = optional(string, "scsi")
  }))
  default = []
}

variable "backup_enabled" {
  description = "Inclure les disques de cette VM dans les sauvegardes vzdump"
  type        = bool
  default     = true
}

variable "install_docker" {
  description = "Installer Docker via cloud-init"
  type        = bool
  default     = false
}

variable "install_qemu_agent" {
  description = "Installer QEMU Guest Agent via cloud-init"
  type        = bool
  default     = true
}

variable "additional_packages" {
  description = "Packages supplementaires a installer via cloud-init"
  type        = list(string)
  default     = []
}

variable "auto_security_updates" {
  description = "Installer et configurer unattended-upgrades pour les mises a jour de securite"
  type        = bool
  default     = true
}

variable "expiration_days" {
  description = "Nombre de jours avant expiration de la VM (null = pas d'expiration)"
  type        = number
  default     = null

  validation {
    condition     = var.expiration_days == null ? true : var.expiration_days > 0
    error_message = "expiration_days doit etre > 0 ou null."
  }
}

# -----------------------------------------------------------------------------
# Promtail Configuration (Log Collection Agent)
# -----------------------------------------------------------------------------

variable "install_promtail" {
  description = "Installer Promtail pour envoyer les logs vers Loki"
  type        = bool
  default     = false
}

variable "loki_url" {
  description = "URL du serveur Loki (ex: http://192.168.1.51:3100)"
  type        = string
  default     = ""

  validation {
    condition     = var.loki_url == "" ? true : can(regex("^https?://", var.loki_url))
    error_message = "loki_url doit etre une URL valide commencant par http:// ou https://."
  }
}
