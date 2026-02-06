# =============================================================================
# Module Tooling Stack - Variables
# =============================================================================
# Stack d'outillage: Step-ca (PKI) + Harbor (Registry) + Authentik (SSO)
# Deploye sur une VM dediee avec Docker Compose
# =============================================================================

# -----------------------------------------------------------------------------
# VM Configuration
# -----------------------------------------------------------------------------

variable "name" {
  description = "Nom de base pour les ressources tooling"
  type        = string
  default     = "tooling"
}

variable "target_node" {
  description = "Node Proxmox pour deployer la VM tooling"
  type        = string
}

variable "template_id" {
  description = "ID du template VM cloud-init"
  type        = number

  validation {
    condition     = var.template_id >= 100
    error_message = "template_id doit etre >= 100 (Proxmox reserve les IDs 0-99)."
  }
}

variable "vm_config" {
  description = "Configuration des ressources VM"
  type = object({
    cores     = optional(number, 4)
    memory    = optional(number, 6144)
    disk      = optional(number, 30)
    data_disk = optional(number, 100)
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
  description = "Adresse IP de la VM tooling (sans CIDR)"
  type        = string

  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.ip_address))
    error_message = "ip_address doit etre une adresse IPv4 valide (ex: 192.168.1.60)."
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

variable "domain_suffix" {
  description = "Suffixe de domaine pour les URLs locales (ex: home.arpa)"
  type        = string
  default     = "home.arpa"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.domain_suffix))
    error_message = "domain_suffix doit etre un nom de domaine valide en minuscules (ex: home.arpa, homelab.local)."
  }
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
# Step-ca (PKI) Configuration
# -----------------------------------------------------------------------------

variable "step_ca_enabled" {
  description = "Activer Step-ca comme autorite de certification interne"
  type        = bool
  default     = true
}

variable "step_ca_password" {
  description = "Mot de passe pour la CA Step-ca"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.step_ca_password) >= 8
    error_message = "step_ca_password doit contenir au moins 8 caracteres."
  }
}

variable "step_ca_provisioner_name" {
  description = "Nom du provisioner ACME pour Step-ca"
  type        = string
  default     = "acme"
}

variable "step_ca_cert_duration" {
  description = "Duree de validite des certificats (format Go duration, ex: 8760h = 1 an)"
  type        = string
  default     = "8760h"
}

variable "step_ca_root_cn" {
  description = "Common Name pour le certificat racine CA"
  type        = string
  default     = "Homelab Root CA"
}

# -----------------------------------------------------------------------------
# Harbor (Registry) Configuration
# -----------------------------------------------------------------------------

variable "harbor_enabled" {
  description = "Activer Harbor comme registre d'images Docker"
  type        = bool
  default     = true
}

variable "harbor_admin_password" {
  description = "Mot de passe admin Harbor"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.harbor_admin_password) >= 8
    error_message = "harbor_admin_password doit contenir au moins 8 caracteres."
  }
}

variable "harbor_db_password" {
  description = "Mot de passe pour la base PostgreSQL Harbor"
  type        = string
  sensitive   = true
  default     = "harbor_db_password_default_change_me" # gitleaks:allow
}

variable "harbor_trivy_enabled" {
  description = "Activer le scanner de vulnerabilites Trivy dans Harbor"
  type        = bool
  default     = true
}

variable "harbor_data_volume" {
  description = "Chemin du volume de donnees Harbor"
  type        = string
  default     = "/data/harbor"
}

# -----------------------------------------------------------------------------
# Authentik (SSO) Configuration
# -----------------------------------------------------------------------------

variable "authentik_enabled" {
  description = "Activer Authentik comme fournisseur SSO"
  type        = bool
  default     = true
}

variable "authentik_secret_key" {
  description = "Cle secrete pour Authentik (min 24 caracteres)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.authentik_secret_key) >= 24
    error_message = "authentik_secret_key doit contenir au moins 24 caracteres."
  }
}

variable "authentik_bootstrap_password" {
  description = "Mot de passe initial pour l'admin Authentik (akadmin)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.authentik_bootstrap_password) >= 8
    error_message = "authentik_bootstrap_password doit contenir au moins 8 caracteres."
  }
}

variable "authentik_bootstrap_email" {
  description = "Email pour l'admin Authentik"
  type        = string
  default     = "admin@home.arpa"
}

# -----------------------------------------------------------------------------
# Traefik (Reverse Proxy) Configuration
# -----------------------------------------------------------------------------

variable "traefik_enabled" {
  description = "Activer Traefik comme reverse proxy pour les services"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags pour la VM"
  type        = list(string)
  default     = ["terraform", "tooling"]
}
