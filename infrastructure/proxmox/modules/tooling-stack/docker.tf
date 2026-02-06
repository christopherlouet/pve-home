# =============================================================================
# Module Tooling Stack - Docker Compose
# =============================================================================
# Listes de services et volumes Docker Compose.
# =============================================================================

locals {
  # tflint-ignore: terraform_unused_declarations
  docker_compose_services = compact([
    var.step_ca_enabled ? "step-ca" : "",
    var.traefik_enabled ? "traefik" : "",
    var.harbor_enabled ? "harbor-core" : "",
    var.harbor_enabled ? "harbor-db" : "",
    var.harbor_enabled ? "harbor-registry" : "",
    var.harbor_enabled ? "harbor-portal" : "",
    var.harbor_enabled ? "harbor-jobservice" : "",
    var.harbor_enabled && var.harbor_trivy_enabled ? "harbor-trivy" : "",
    var.authentik_enabled ? "authentik-server" : "",
    var.authentik_enabled ? "authentik-worker" : "",
    var.authentik_enabled ? "authentik-db" : "",
    var.authentik_enabled ? "authentik-redis" : "",
  ])

  # tflint-ignore: terraform_unused_declarations
  docker_compose_volumes = compact([
    var.step_ca_enabled ? "step-ca-data" : "",
    var.traefik_enabled ? "traefik-certs" : "",
    var.harbor_enabled ? "harbor-data" : "",
    var.harbor_enabled ? "harbor-db-data" : "",
    var.authentik_enabled ? "authentik-db-data" : "",
    var.authentik_enabled ? "authentik-redis-data" : "",
  ])
}
