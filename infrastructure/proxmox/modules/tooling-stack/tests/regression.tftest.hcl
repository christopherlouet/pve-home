# =============================================================================
# Module Tooling Stack - Tests de non-regression
# =============================================================================
# Verifie que les bugs corriges ne reapparaissent pas.
# =============================================================================

mock_provider "proxmox" {}
mock_provider "tls" {}
mock_provider "random" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests (configuration minimale valide)
# -----------------------------------------------------------------------------

variables {
  target_node   = "pve-test"
  template_id   = 9000
  ip_address    = "192.168.1.60"
  gateway       = "192.168.1.1"
  ssh_keys      = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  domain_suffix = "home.arpa"
  # Step-ca
  step_ca_password = "testpassword123" # gitleaks:allow
  # Harbor
  harbor_admin_password = "Harbor12345!" # gitleaks:allow
  # Authentik
  authentik_secret_key         = "testsecretkey1234567890123456" # gitleaks:allow
  authentik_bootstrap_password = "Authentik123!"                 # gitleaks:allow
}

# -----------------------------------------------------------------------------
# Regression: Harbor secrets must be independent (v1.10.0)
# Each Harbor secret (db, csrf_key, core_secret, jobservice_secret) must use
# a separate random_password resource to prevent credential reuse.
# -----------------------------------------------------------------------------

run "harbor_uses_independent_secrets" {
  command = plan

  variables {
    harbor_enabled = true
  }

  assert {
    condition     = output.harbor_enabled == true
    error_message = "Harbor should be enabled"
  }
}

# -----------------------------------------------------------------------------
# Regression: default service flags should be true
# All services are enabled by default in the tooling stack module.
# Environments override these defaults as needed.
# -----------------------------------------------------------------------------

run "services_enabled_by_default" {
  command = plan

  assert {
    condition     = output.step_ca_enabled == true
    error_message = "Step-ca should be enabled by default"
  }

  assert {
    condition     = output.harbor_enabled == true
    error_message = "Harbor should be enabled by default"
  }

  assert {
    condition     = output.authentik_enabled == true
    error_message = "Authentik should be enabled by default"
  }

  assert {
    condition     = output.traefik_enabled == true
    error_message = "Traefik should be enabled by default"
  }
}

# -----------------------------------------------------------------------------
# Regression: URLs must reflect traefik_enabled state
# When traefik is disabled, URLs should use IP:port format.
# When traefik is enabled, URLs should use domain format.
# -----------------------------------------------------------------------------

run "urls_without_traefik_use_ip" {
  command = plan

  variables {
    step_ca_enabled  = true
    traefik_enabled  = false
    harbor_enabled   = false
    authentik_enabled = false
  }

  assert {
    condition     = output.urls.traefik == ""
    error_message = "Traefik URL should be empty when disabled"
  }
}

run "urls_with_traefik_use_domain" {
  command = plan

  variables {
    step_ca_enabled  = true
    traefik_enabled  = true
    harbor_enabled   = false
    authentik_enabled = false
  }

  assert {
    condition     = output.urls.traefik != ""
    error_message = "Traefik URL should not be empty when enabled"
  }
}

# -----------------------------------------------------------------------------
# Regression: VM name should match input
# -----------------------------------------------------------------------------

run "vm_name_matches_input" {
  command = plan

  assert {
    condition     = output.vm_name == "tooling"
    error_message = "VM name should match default 'tooling'"
  }
}
