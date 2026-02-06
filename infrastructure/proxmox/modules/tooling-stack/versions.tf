# =============================================================================
# Module Tooling Stack - Provider Requirements
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
