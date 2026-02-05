# =============================================================================
# Variables pour l'environnement Monitoring
# =============================================================================
# Variables communes: voir common_variables.tf (symlink vers shared/)
# =============================================================================

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

# -----------------------------------------------------------------------------
# Custom Prometheus Scrape Configs
# -----------------------------------------------------------------------------

variable "custom_scrape_configs" {
  description = "Configurations scrape Prometheus personnalisees (YAML brut pour configs avancees)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Stack Tooling (Step-ca PKI + Harbor Registry + Authentik SSO)
# -----------------------------------------------------------------------------

variable "tooling" {
  description = "Configuration de la stack tooling (PKI, Registry, SSO)"
  type = object({
    enabled = optional(bool, false)
    node    = optional(string, null)
    vm = object({
      ip        = string
      cores     = optional(number, 4)
      memory    = optional(number, 8192)
      disk      = optional(number, 50)
      data_disk = optional(number, 200)
    })
    domain_suffix   = optional(string, "home.arpa")
    traefik_enabled = optional(bool, true)
    step_ca = optional(object({
      enabled          = optional(bool, true)
      password         = string
      provisioner_name = optional(string, "acme")
      cert_duration    = optional(string, "720h")
    }), { enabled = false, password = "" })
    harbor = optional(object({
      enabled        = optional(bool, true)
      admin_password = string
      trivy_enabled  = optional(bool, true)
    }), { enabled = false, admin_password = "" })
    authentik = optional(object({
      enabled            = optional(bool, true)
      secret_key         = string
      bootstrap_password = string
      bootstrap_email    = optional(string, "admin@home.arpa")
    }), { enabled = false, secret_key = "", bootstrap_password = "" })
  })
  default = {
    enabled = false
    vm = {
      ip = ""
    }
  }
}
