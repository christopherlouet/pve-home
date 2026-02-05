# =============================================================================
# Variables pour l'environnement Prod
# =============================================================================
# Variables communes: voir common_variables.tf (symlink vers shared/)
# Variables partagees prod/lab: voir env_variables.tf (symlink vers shared/)
# =============================================================================

# -----------------------------------------------------------------------------
# Environnement
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "prod"
}

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------

variable "monitoring_ssh_public_key" {
  description = "Cle SSH publique de la VM monitoring pour les health checks (output de l'env monitoring)"
  type        = string
  default     = ""
}
