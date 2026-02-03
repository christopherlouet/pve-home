# =============================================================================
# Proxmox Infrastructure - Versions communes
# =============================================================================
# Ce fichier definit les versions requises pour tous les environnements.
# Chaque environnement copie ou symlinke ce fichier pour garantir
# la coherence des versions du provider et de Terraform.
# =============================================================================

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94"
    }
  }
}
