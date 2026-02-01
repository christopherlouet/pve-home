# =============================================================================
# Versions Terraform et providers
# =============================================================================
# Maintenir en coherence avec infrastructure/proxmox/versions.tf
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.93"
    }
  }
}
