# =============================================================================
# Variables partagees - Expiration (lifecycle management)
# =============================================================================
# Ce fichier est symlinke dans les modules vm et lxc.
# Ne PAS modifier les copies - modifier uniquement ce fichier source.
# La logique expiration_tag est dans chaque module (main.tf locals).
# =============================================================================

variable "expiration_days" {
  description = "Nombre de jours avant expiration (null = pas d'expiration)"
  type        = number
  default     = null

  validation {
    condition     = var.expiration_days == null ? true : var.expiration_days > 0
    error_message = "expiration_days doit etre > 0 ou null."
  }
}
