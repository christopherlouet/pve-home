# =============================================================================
# Variables pour l'environnement Lab
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
  default     = "lab"
}
