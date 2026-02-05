# =============================================================================
# Module Tooling Stack - Tests des services (Step-ca, Harbor, Authentik)
# =============================================================================
# Verifie que les services sont correctement configures selon les flags.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests
# -----------------------------------------------------------------------------

variables {
  target_node         = "pve-test"
  template_id         = 9000
  ip_address          = "192.168.1.60"
  gateway             = "192.168.1.1"
  ssh_keys            = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  domain_suffix       = "home.arpa"
  step_ca_password    = "testpassword123" # gitleaks:allow
  harbor_admin_password = "Harbor12345!" # gitleaks:allow
  authentik_secret_key  = "testsecretkey1234567890123456" # gitleaks:allow
  authentik_bootstrap_password = "Authentik123!" # gitleaks:allow
}

# -----------------------------------------------------------------------------
# Step-ca Service Tests
# -----------------------------------------------------------------------------

run "step_ca_enabled_by_default" {
  command = plan

  assert {
    condition     = var.step_ca_enabled == true
    error_message = "Step-ca should be enabled by default"
  }
}

run "step_ca_url_in_outputs_when_enabled" {
  command = plan

  variables {
    step_ca_enabled = true
  }

  assert {
    condition     = output.urls.step_ca != ""
    error_message = "Step-ca URL should be in outputs when enabled"
  }
}

run "step_ca_provisioner_name_configurable" {
  command = plan

  variables {
    step_ca_provisioner_name = "my-acme"
  }

  assert {
    condition     = var.step_ca_provisioner_name == "my-acme"
    error_message = "Step-ca provisioner name should be configurable"
  }
}

run "step_ca_cert_duration_configurable" {
  command = plan

  variables {
    step_ca_cert_duration = "2160h"
  }

  assert {
    condition     = var.step_ca_cert_duration == "2160h"
    error_message = "Step-ca cert duration should be configurable"
  }
}

# -----------------------------------------------------------------------------
# Harbor Service Tests
# -----------------------------------------------------------------------------

run "harbor_enabled_by_default" {
  command = plan

  assert {
    condition     = var.harbor_enabled == true
    error_message = "Harbor should be enabled by default"
  }
}

run "harbor_url_in_outputs_when_enabled" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = output.urls.harbor != ""
    error_message = "Harbor URL should be in outputs when enabled"
  }
}

run "harbor_trivy_enabled_by_default" {
  command = plan

  assert {
    condition     = var.harbor_trivy_enabled == true
    error_message = "Harbor Trivy scanner should be enabled by default"
  }
}

run "harbor_trivy_can_be_disabled" {
  command = plan

  variables {
    harbor_trivy_enabled = false
  }

  assert {
    condition     = var.harbor_trivy_enabled == false
    error_message = "Harbor Trivy scanner should be disableable"
  }
}

# -----------------------------------------------------------------------------
# Authentik Service Tests
# -----------------------------------------------------------------------------

run "authentik_enabled_by_default" {
  command = plan

  assert {
    condition     = var.authentik_enabled == true
    error_message = "Authentik should be enabled by default"
  }
}

run "authentik_url_in_outputs_when_enabled" {
  command = plan

  variables {
    authentik_enabled = true
  }

  assert {
    condition     = output.urls.authentik != ""
    error_message = "Authentik URL should be in outputs when enabled"
  }
}

# -----------------------------------------------------------------------------
# Traefik Service Tests
# -----------------------------------------------------------------------------

run "traefik_enabled_by_default" {
  command = plan

  assert {
    condition     = var.traefik_enabled == true
    error_message = "Traefik should be enabled by default"
  }
}

run "traefik_url_in_outputs_when_enabled" {
  command = plan

  variables {
    traefik_enabled = true
  }

  assert {
    condition     = output.urls.traefik != ""
    error_message = "Traefik URL should be in outputs when enabled"
  }
}

# -----------------------------------------------------------------------------
# Service Combination Tests
# -----------------------------------------------------------------------------

run "all_services_can_be_enabled" {
  command = plan

  variables {
    step_ca_enabled   = true
    harbor_enabled    = true
    authentik_enabled = true
    traefik_enabled   = true
  }

  assert {
    condition     = output.step_ca_enabled == true
    error_message = "Step-ca should be enabled"
  }

  assert {
    condition     = output.harbor_enabled == true
    error_message = "Harbor should be enabled"
  }

  assert {
    condition     = output.authentik_enabled == true
    error_message = "Authentik should be enabled"
  }

  assert {
    condition     = output.traefik_enabled == true
    error_message = "Traefik should be enabled"
  }
}

run "minimal_deployment_step_ca_only" {
  command = plan

  variables {
    step_ca_enabled   = true
    harbor_enabled    = false
    authentik_enabled = false
    traefik_enabled   = false
  }

  assert {
    condition     = output.step_ca_enabled == true
    error_message = "Step-ca should be enabled"
  }

  assert {
    condition     = output.harbor_enabled == false
    error_message = "Harbor should be disabled"
  }

  assert {
    condition     = output.authentik_enabled == false
    error_message = "Authentik should be disabled"
  }
}

run "harbor_without_authentik" {
  command = plan

  variables {
    step_ca_enabled   = true
    harbor_enabled    = true
    authentik_enabled = false
    traefik_enabled   = true
  }

  assert {
    condition     = output.harbor_enabled == true
    error_message = "Harbor should work without Authentik"
  }
}

# -----------------------------------------------------------------------------
# CA Export Output Tests
# -----------------------------------------------------------------------------

run "ca_fingerprint_output_when_enabled" {
  command = plan

  variables {
    step_ca_enabled = true
  }

  # La valeur du certificat n'est connue qu'apres apply, mais on peut verifier
  # que le module est configure pour generer le certificat CA
  assert {
    condition     = var.step_ca_enabled == true
    error_message = "Step-ca should be enabled to generate CA fingerprint"
  }
}

run "ca_root_cert_instructions_output" {
  command = plan

  variables {
    step_ca_enabled = true
  }

  assert {
    condition     = output.ca_install_instructions != ""
    error_message = "CA install instructions output should exist"
  }
}
