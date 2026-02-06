# =============================================================================
# Module Tooling Stack - Harbor Registry
# =============================================================================
# Registre d'images Docker prive avec Harbor.
# =============================================================================

# -----------------------------------------------------------------------------
# Random Resources
# -----------------------------------------------------------------------------

resource "random_password" "harbor_db" {
  count   = var.harbor_enabled ? 1 : 0
  length  = 32
  special = false
}

# -----------------------------------------------------------------------------
# Harbor Configuration
# -----------------------------------------------------------------------------

locals {
  harbor_config = var.harbor_enabled ? {
    hostname          = "registry.${var.domain_suffix}"
    external_url      = var.traefik_enabled ? "https://registry.${var.domain_suffix}" : "http://${var.ip_address}:8080"
    internal_tls      = var.traefik_enabled ? false : true
    data_volume       = var.harbor_data_volume
    storage_type      = "filesystem"
    storage_path      = "${var.harbor_data_volume}/registry"
    database_type     = "postgresql"
    db_host           = "harbor-db"
    db_port           = 5432
    db_name           = "registry"
    db_username       = "postgres"
    trivy_enabled     = var.harbor_trivy_enabled
    csrf_key          = var.harbor_enabled ? random_password.harbor_db[0].result : ""
    core_secret       = var.harbor_enabled ? random_password.harbor_db[0].result : ""
    jobservice_secret = var.harbor_enabled ? random_password.harbor_db[0].result : ""
  } : null
}
