# =============================================================================
# Module LXC - Provider Requirements
# =============================================================================

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94.0"
    }
  }
}
