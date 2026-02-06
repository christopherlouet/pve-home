# =============================================================================
# Module LXC Proxmox - Variables
# =============================================================================

variable "hostname" {
  description = "Hostname du conteneur"
  type        = string
}

variable "description" {
  description = "Description du conteneur"
  type        = string
  default     = "Managed by Terraform"
}

variable "target_node" {
  description = "Node Proxmox cible"
  type        = string
}

variable "template_file_id" {
  description = "ID du template LXC"
  type        = string
}

variable "os_type" {
  description = "Type d'OS (ubuntu, debian, alpine)"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = contains(["ubuntu", "debian", "alpine", "centos", "fedora", "archlinux", "unmanaged"], var.os_type)
    error_message = "os_type doit etre un type supporte par Proxmox."
  }
}

variable "cpu_cores" {
  description = "Nombre de cores CPU"
  type        = number
  default     = 1

  validation {
    condition     = var.cpu_cores >= 1 && var.cpu_cores <= 64
    error_message = "cpu_cores doit etre entre 1 et 64."
  }
}

variable "memory_mb" {
  description = "RAM en MB"
  type        = number
  default     = 512

  validation {
    condition     = var.memory_mb >= 64 && var.memory_mb <= 131072
    error_message = "memory_mb doit etre entre 64 et 131072 (64 MB - 128 GB)."
  }
}

variable "swap_mb" {
  description = "Swap en MB"
  type        = number
  default     = 512

  validation {
    condition     = var.swap_mb >= 0 && var.swap_mb <= 131072
    error_message = "swap_mb doit etre entre 0 et 131072."
  }
}

variable "disk_size_gb" {
  description = "Taille du rootfs en GB"
  type        = number
  default     = 8

  validation {
    condition     = var.disk_size_gb >= 1 && var.disk_size_gb <= 4096
    error_message = "disk_size_gb doit etre entre 1 et 4096 (1 GB - 4 TB)."
  }
}

variable "datastore" {
  description = "Datastore pour le rootfs"
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
  description = "Adresse IP en notation CIDR"
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

variable "ssh_keys" {
  description = "Clés SSH publiques"
  type        = list(string)
}

variable "root_password" {
  description = "Mot de passe root (optionnel)"
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Tags du conteneur"
  type        = list(string)
  default     = ["terraform"]
}

variable "unprivileged" {
  description = "Conteneur non privilégié (recommandé)"
  type        = bool
  default     = true
}

variable "start_on_boot" {
  description = "Démarrer automatiquement au boot"
  type        = bool
  default     = true
}

variable "nesting" {
  description = "Activer le nesting (Docker dans LXC)"
  type        = bool
  default     = false
}

variable "fuse" {
  description = "Activer FUSE"
  type        = bool
  default     = false
}

variable "keyctl" {
  description = "Activer keyctl"
  type        = bool
  default     = false
}

variable "mount_types" {
  description = "Types de mount autorisés"
  type        = list(string)
  default     = []
}

variable "mountpoints" {
  description = "Mountpoints additionnels"
  type = list(object({
    volume    = string
    path      = string
    size      = optional(number)
    read_only = optional(bool, false)
  }))
  default = []
}

variable "backup_enabled" {
  description = "Inclure ce conteneur dans les sauvegardes vzdump"
  type        = bool
  default     = true
}

variable "auto_security_updates" {
  description = "Configurer unattended-upgrades pour les mises a jour de securite (Ubuntu/Debian)"
  type        = bool
  default     = true
}

# expiration_days: voir expiration_variables.tf (symlink vers shared/)
