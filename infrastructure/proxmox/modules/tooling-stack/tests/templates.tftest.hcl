# =============================================================================
# Module Tooling Stack - Tests des templates
# =============================================================================
# Verifie que les templates sont correctement configures.
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
  step_ca_password             = "testpassword123"               # gitleaks:allow
  harbor_admin_password        = "Harbor12345!"                  # gitleaks:allow
  authentik_secret_key         = "testsecretkey1234567890123456" # gitleaks:allow
  authentik_bootstrap_password = "Authentik123!"                 # gitleaks:allow
}

# -----------------------------------------------------------------------------
# Step-ca Template Tests
# -----------------------------------------------------------------------------

run "step_ca_config_generated" {
  command = plan

  variables {
    step_ca_enabled = true
  }

  assert {
    condition     = local.step_ca_config.ca_name == "Homelab CA"
    error_message = "Step-ca CA name should be 'Homelab CA'"
  }

  assert {
    condition     = local.step_ca_config.dns_names[0] == "pki.home.arpa"
    error_message = "Step-ca DNS should include pki.home.arpa"
  }
}

run "step_ca_provisioner_configured" {
  command = plan

  variables {
    step_ca_enabled          = true
    step_ca_provisioner_name = "acme"
  }

  assert {
    condition     = local.step_ca_config.provisioner_name == "acme"
    error_message = "Step-ca provisioner should be 'acme'"
  }
}

run "step_ca_cert_duration_configured" {
  command = plan

  variables {
    step_ca_enabled       = true
    step_ca_cert_duration = "2160h"
  }

  assert {
    condition     = local.step_ca_config.cert_duration == "2160h"
    error_message = "Step-ca cert duration should be configurable"
  }
}

run "step_ca_disabled_no_config" {
  command = plan

  variables {
    step_ca_enabled = false
  }

  assert {
    condition     = local.step_ca_config == null
    error_message = "Step-ca config should be null when disabled"
  }
}

# -----------------------------------------------------------------------------
# Traefik Template Tests
# -----------------------------------------------------------------------------

run "traefik_config_generated" {
  command = plan

  variables {
    traefik_enabled = true
    step_ca_enabled = true
  }

  assert {
    condition     = local.traefik_config.acme_enabled == true
    error_message = "Traefik ACME should be enabled with Step-ca"
  }

  assert {
    condition     = local.traefik_config.acme_server == "https://127.0.0.1:8443/acme/acme/directory"
    error_message = "Traefik ACME server should point to local Step-ca"
  }
}

run "traefik_routes_generated" {
  command = plan

  variables {
    traefik_enabled   = true
    step_ca_enabled   = true
    harbor_enabled    = true
    authentik_enabled = true
  }

  assert {
    condition     = contains(keys(local.traefik_routes), "pki")
    error_message = "Traefik routes should include pki"
  }

  assert {
    condition     = contains(keys(local.traefik_routes), "registry")
    error_message = "Traefik routes should include registry"
  }

  assert {
    condition     = contains(keys(local.traefik_routes), "auth")
    error_message = "Traefik routes should include auth"
  }
}

run "traefik_pki_route_correct" {
  command = plan

  variables {
    traefik_enabled = true
    step_ca_enabled = true
    domain_suffix   = "home.arpa"
  }

  assert {
    condition     = local.traefik_routes.pki.host == "pki.home.arpa"
    error_message = "PKI route host should be pki.home.arpa"
  }

  assert {
    condition     = local.traefik_routes.pki.port == 8443
    error_message = "PKI route should point to port 8443"
  }
}

run "traefik_disabled_no_config" {
  command = plan

  variables {
    traefik_enabled = false
  }

  assert {
    condition     = local.traefik_config == null
    error_message = "Traefik config should be null when disabled"
  }
}

# -----------------------------------------------------------------------------
# Docker Compose Template Tests
# -----------------------------------------------------------------------------

run "docker_compose_services_enabled" {
  command = plan

  variables {
    step_ca_enabled   = true
    harbor_enabled    = true
    authentik_enabled = true
    traefik_enabled   = true
  }

  assert {
    condition     = contains(local.docker_compose_services, "step-ca")
    error_message = "Docker Compose should include step-ca service"
  }

  assert {
    condition     = contains(local.docker_compose_services, "traefik")
    error_message = "Docker Compose should include traefik service"
  }
}

run "docker_compose_step_ca_only" {
  command = plan

  variables {
    step_ca_enabled   = true
    harbor_enabled    = false
    authentik_enabled = false
    traefik_enabled   = false
  }

  assert {
    condition     = contains(local.docker_compose_services, "step-ca")
    error_message = "Docker Compose should include step-ca when enabled"
  }

  assert {
    condition     = !contains(local.docker_compose_services, "harbor-core")
    error_message = "Docker Compose should not include harbor when disabled"
  }
}

run "docker_compose_volumes_configured" {
  command = plan

  variables {
    step_ca_enabled = true
    harbor_enabled  = true
  }

  assert {
    condition     = contains(local.docker_compose_volumes, "step-ca-data")
    error_message = "Docker Compose should include step-ca-data volume"
  }
}

# -----------------------------------------------------------------------------
# Cloud-init Integration Tests
# -----------------------------------------------------------------------------

run "cloud_init_includes_docker_compose" {
  command = plan

  variables {
    step_ca_enabled   = true
    harbor_enabled    = true
    authentik_enabled = true
    traefik_enabled   = true
  }

  assert {
    condition     = proxmox_virtual_environment_file.cloud_config != null
    error_message = "Cloud-init config should exist"
  }
}
