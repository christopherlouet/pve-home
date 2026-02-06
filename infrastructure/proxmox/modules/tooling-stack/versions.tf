# =============================================================================
# Module Tooling Stack - Provider Requirements
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    tls = {
      source = "hashicorp/tls"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}
