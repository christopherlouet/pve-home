# =============================================================================
# Locals partagees - Expiration tag (lifecycle management)
# =============================================================================
# Ce fichier est symlinke dans les modules vm et lxc.
# Ne PAS modifier les copies - modifier uniquement ce fichier source.
# Genere un tag "expires:YYYY-MM-DD" pour le lifecycle management.
# =============================================================================

locals {
  expiration_tag = var.expiration_days != null ? ["expires:${formatdate("YYYY-MM-DD", timeadd(timestamp(), "${var.expiration_days * 24}h"))}"] : []
}
