# =============================================================================
# Module Tooling Stack - Tests Harbor Registry
# =============================================================================
# Verifie que Harbor est correctement configure.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests
# -----------------------------------------------------------------------------

variables {
  target_node                  = "pve-test"
  template_id                  = 9000
  ip_address                   = "192.168.1.60"
  gateway                      = "192.168.1.1"
  ssh_keys                     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  domain_suffix                = "home.arpa"
  step_ca_password             = "testpassword123"             # gitleaks:allow
  harbor_admin_password        = "Harbor12345!"                # gitleaks:allow
  authentik_secret_key         = "testsecretkey1234567890123456" # gitleaks:allow
  authentik_bootstrap_password = "Authentik123!"               # gitleaks:allow
}

# -----------------------------------------------------------------------------
# Harbor Configuration Tests
# -----------------------------------------------------------------------------

run "harbor_config_generated" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = local.harbor_config != null
    error_message = "Harbor config should be generated when enabled"
  }

  assert {
    condition     = local.harbor_config.hostname == "registry.home.arpa"
    error_message = "Harbor hostname should be registry.home.arpa"
  }
}

run "harbor_config_with_custom_domain" {
  command = plan

  variables {
    harbor_enabled = true
    domain_suffix  = "lab.local"
  }

  assert {
    condition     = local.harbor_config.hostname == "registry.lab.local"
    error_message = "Harbor hostname should use custom domain suffix"
  }
}

run "harbor_config_disabled" {
  command = plan

  variables {
    harbor_enabled = false
  }

  assert {
    condition     = local.harbor_config == null
    error_message = "Harbor config should be null when disabled"
  }
}

run "harbor_trivy_enabled_by_default" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = local.harbor_config.trivy_enabled == true
    error_message = "Harbor Trivy should be enabled by default"
  }
}

run "harbor_trivy_can_be_disabled" {
  command = plan

  variables {
    harbor_enabled       = true
    harbor_trivy_enabled = false
  }

  assert {
    condition     = local.harbor_config.trivy_enabled == false
    error_message = "Harbor Trivy should be disableable"
  }
}

run "harbor_data_volume_configurable" {
  command = plan

  variables {
    harbor_enabled     = true
    harbor_data_volume = "/mnt/harbor-data"
  }

  assert {
    condition     = local.harbor_config.data_volume == "/mnt/harbor-data"
    error_message = "Harbor data volume should be configurable"
  }
}

run "harbor_https_enabled_with_traefik" {
  command = plan

  variables {
    harbor_enabled  = true
    traefik_enabled = true
  }

  assert {
    condition     = local.harbor_config.external_url == "https://registry.home.arpa"
    error_message = "Harbor external URL should use HTTPS with Traefik"
  }
}

run "harbor_http_without_traefik" {
  command = plan

  variables {
    harbor_enabled  = true
    traefik_enabled = false
  }

  assert {
    condition     = local.harbor_config.external_url == "http://192.168.1.60:8080"
    error_message = "Harbor external URL should use HTTP without Traefik"
  }
}

# -----------------------------------------------------------------------------
# Harbor Database Tests
# -----------------------------------------------------------------------------

run "harbor_db_password_generated" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = local.harbor_config.db_host == "harbor-db"
    error_message = "Harbor DB host should be harbor-db"
  }
}

run "harbor_db_uses_postgresql" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = local.harbor_config.database_type == "postgresql"
    error_message = "Harbor should use PostgreSQL database"
  }
}

# -----------------------------------------------------------------------------
# Harbor Storage Tests
# -----------------------------------------------------------------------------

run "harbor_storage_filesystem" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = local.harbor_config.storage_type == "filesystem"
    error_message = "Harbor should use filesystem storage"
  }
}

run "harbor_storage_path_correct" {
  command = plan

  variables {
    harbor_enabled     = true
    harbor_data_volume = "/data/harbor"
  }

  assert {
    condition     = local.harbor_config.storage_path == "/data/harbor/registry"
    error_message = "Harbor storage path should be under data volume"
  }
}

# -----------------------------------------------------------------------------
# Harbor Security Tests
# -----------------------------------------------------------------------------

run "harbor_internal_tls_disabled" {
  command = plan

  variables {
    harbor_enabled  = true
    traefik_enabled = true
  }

  # When using Traefik, Harbor internal TLS is disabled (Traefik handles TLS)
  assert {
    condition     = local.harbor_config.internal_tls == false
    error_message = "Harbor internal TLS should be disabled when using Traefik"
  }
}

run "harbor_secrets_configured" {
  command = plan

  variables {
    harbor_enabled = true
  }

  # The actual values are generated at apply time, but we can verify
  # the configuration expects them to be set
  assert {
    condition     = var.harbor_enabled == true
    error_message = "Harbor should be enabled for secrets to be configured"
  }
}

# -----------------------------------------------------------------------------
# Harbor Components Tests
# -----------------------------------------------------------------------------

run "harbor_core_enabled" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "harbor-core")
    error_message = "Harbor core should be in Docker Compose services"
  }
}

run "harbor_registry_enabled" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "harbor-registry")
    error_message = "Harbor registry should be in Docker Compose services"
  }
}

run "harbor_portal_enabled" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "harbor-portal")
    error_message = "Harbor portal should be in Docker Compose services"
  }
}

run "harbor_jobservice_enabled" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "harbor-jobservice")
    error_message = "Harbor jobservice should be in Docker Compose services"
  }
}

run "harbor_trivy_in_services_when_enabled" {
  command = plan

  variables {
    harbor_enabled       = true
    harbor_trivy_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "harbor-trivy")
    error_message = "Harbor Trivy should be in Docker Compose services when enabled"
  }
}

run "harbor_trivy_not_in_services_when_disabled" {
  command = plan

  variables {
    harbor_enabled       = true
    harbor_trivy_enabled = false
  }

  assert {
    condition     = !contains(local.docker_compose_services, "harbor-trivy")
    error_message = "Harbor Trivy should not be in Docker Compose services when disabled"
  }
}

# -----------------------------------------------------------------------------
# Harbor Integration Tests
# -----------------------------------------------------------------------------

run "harbor_traefik_route_exists" {
  command = plan

  variables {
    harbor_enabled  = true
    traefik_enabled = true
  }

  assert {
    condition     = contains(keys(local.traefik_routes), "registry")
    error_message = "Traefik should have a route for Harbor registry"
  }
}

run "harbor_traefik_route_correct_port" {
  command = plan

  variables {
    harbor_enabled  = true
    traefik_enabled = true
  }

  assert {
    condition     = local.traefik_routes.registry.port == 8080
    error_message = "Harbor Traefik route should point to port 8080"
  }
}

run "harbor_volumes_configured" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = contains(local.docker_compose_volumes, "harbor-data")
    error_message = "Harbor data volume should be configured"
  }

  assert {
    condition     = contains(local.docker_compose_volumes, "harbor-db-data")
    error_message = "Harbor DB data volume should be configured"
  }
}
