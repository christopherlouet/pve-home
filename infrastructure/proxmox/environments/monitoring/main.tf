# =============================================================================
# Infrastructure - Environnement Monitoring
# =============================================================================
# PVE dedie au monitoring centralise de tous les environnements.
# Pas de VMs workload, uniquement la stack monitoring.
# =============================================================================

# -----------------------------------------------------------------------------
# Variables locales
# -----------------------------------------------------------------------------

locals {
  environment = var.environment
  common_tags = [local.environment, "terraform"]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "environment" {
  description = "Nom de l'environnement"
  value       = local.environment
}
