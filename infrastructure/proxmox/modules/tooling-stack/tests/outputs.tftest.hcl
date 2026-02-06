# =============================================================================
# Module Tooling Stack - Tests des outputs
# =============================================================================
# Verifie que tous les outputs sont correctement generes, en particulier
# les outputs conditionnels (step_ca, harbor, authentik, traefik).
# Note: vm_id, vm_name, node_name sont provider-computed (mock_provider).
# =============================================================================

mock_provider "proxmox" {}
mock_provider "tls" {}
mock_provider "random" {}

# -----------------------------------------------------------------------------
# Variables de base
# -----------------------------------------------------------------------------

variables {
  name        = "test-tooling"
  target_node = "pve-test"
  template_id = 9000
  ip_address  = "192.168.1.60"
  gateway     = "192.168.1.1"
  ssh_keys    = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]

  step_ca_password             = "test-ca-password123"                  # gitleaks:allow
  harbor_admin_password        = "test-harbor-password"                 # gitleaks:allow
  authentik_secret_key         = "test-authentik-secret-key-min24chars" # gitleaks:allow
  authentik_bootstrap_password = "test-authentik-pass"                  # gitleaks:allow
}

# -----------------------------------------------------------------------------
# Outputs de base (variable pass-through)
# -----------------------------------------------------------------------------

run "output_ip_address" {
  command = plan

  assert {
    condition     = output.ip_address == "192.168.1.60"
    error_message = "ip_address should match input"
  }
}

run "output_domain_suffix_default" {
  command = plan

  assert {
    condition     = output.domain_suffix == "home.arpa"
    error_message = "Default domain_suffix should be home.arpa"
  }
}

run "output_ssh_command" {
  command = plan

  assert {
    condition     = output.ssh_command == "ssh ubuntu@192.168.1.60"
    error_message = "ssh_command should use default username and ip_address"
  }
}

# -----------------------------------------------------------------------------
# Service status outputs (defaults: all enabled)
# -----------------------------------------------------------------------------

run "output_services_enabled_defaults" {
  command = plan

  assert {
    condition     = output.step_ca_enabled == true
    error_message = "step_ca_enabled should be true by default"
  }

  assert {
    condition     = output.harbor_enabled == true
    error_message = "harbor_enabled should be true by default"
  }

  assert {
    condition     = output.authentik_enabled == true
    error_message = "authentik_enabled should be true by default"
  }

  assert {
    condition     = output.traefik_enabled == true
    error_message = "traefik_enabled should be true by default"
  }
}

# -----------------------------------------------------------------------------
# URLs with traefik enabled (default)
# -----------------------------------------------------------------------------

run "output_urls_with_traefik" {
  command = plan

  assert {
    condition     = output.urls.step_ca == "https://pki.home.arpa"
    error_message = "step_ca URL should use traefik domain"
  }

  assert {
    condition     = output.urls.harbor == "https://registry.home.arpa"
    error_message = "harbor URL should use traefik domain"
  }

  assert {
    condition     = output.urls.authentik == "https://auth.home.arpa"
    error_message = "authentik URL should use traefik domain"
  }

  assert {
    condition     = output.urls.traefik == "https://traefik.home.arpa"
    error_message = "traefik URL should use domain"
  }
}

# -----------------------------------------------------------------------------
# URLs without traefik
# -----------------------------------------------------------------------------

run "output_urls_without_traefik" {
  command = plan

  variables {
    traefik_enabled = false
  }

  assert {
    condition     = output.urls.step_ca == "https://192.168.1.60:8443"
    error_message = "step_ca URL should use direct IP without traefik"
  }

  assert {
    condition     = output.urls.harbor == "https://192.168.1.60:443"
    error_message = "harbor URL should use direct IP without traefik"
  }

  assert {
    condition     = output.urls.authentik == "http://192.168.1.60:9000"
    error_message = "authentik URL should use direct IP without traefik"
  }

  assert {
    condition     = output.urls.traefik == ""
    error_message = "traefik URL should be empty when disabled"
  }
}

# -----------------------------------------------------------------------------
# Services disabled
# -----------------------------------------------------------------------------

run "output_urls_services_disabled" {
  command = plan

  variables {
    step_ca_enabled   = false
    harbor_enabled    = false
    authentik_enabled = false
  }

  assert {
    condition     = output.urls.step_ca == ""
    error_message = "step_ca URL should be empty when disabled"
  }

  assert {
    condition     = output.urls.harbor == ""
    error_message = "harbor URL should be empty when disabled"
  }

  assert {
    condition     = output.urls.authentik == ""
    error_message = "authentik URL should be empty when disabled"
  }

  assert {
    condition     = output.step_ca_enabled == false
    error_message = "step_ca_enabled should reflect disabled state"
  }
}

# -----------------------------------------------------------------------------
# Harbor outputs
# -----------------------------------------------------------------------------

run "output_harbor_registry_url" {
  command = plan

  assert {
    condition     = output.harbor_registry_url == "registry.home.arpa"
    error_message = "harbor_registry_url should use domain_suffix"
  }

  assert {
    condition     = output.harbor_admin_username == "admin"
    error_message = "harbor_admin_username should be admin"
  }
}

run "output_harbor_disabled" {
  command = plan

  variables {
    harbor_enabled = false
  }

  assert {
    condition     = output.harbor_registry_url == ""
    error_message = "harbor_registry_url should be empty when disabled"
  }

  assert {
    condition     = output.harbor_admin_username == ""
    error_message = "harbor_admin_username should be empty when disabled"
  }
}

# -----------------------------------------------------------------------------
# Authentik outputs
# -----------------------------------------------------------------------------

run "output_authentik_admin_url" {
  command = plan

  assert {
    condition     = output.authentik_admin_url == "https://auth.home.arpa/if/admin/"
    error_message = "authentik_admin_url should use traefik domain with /if/admin/"
  }

  assert {
    condition     = output.authentik_admin_username == "akadmin"
    error_message = "authentik_admin_username should be akadmin"
  }
}

run "output_authentik_disabled" {
  command = plan

  variables {
    authentik_enabled = false
  }

  assert {
    condition     = output.authentik_admin_url == ""
    error_message = "authentik_admin_url should be empty when disabled"
  }

  assert {
    condition     = output.authentik_admin_username == ""
    error_message = "authentik_admin_username should be empty when disabled"
  }
}

# -----------------------------------------------------------------------------
# DNS records
# -----------------------------------------------------------------------------

run "output_dns_records_all_enabled" {
  command = plan

  assert {
    condition     = output.dns_records.pki.name == "pki"
    error_message = "dns_records.pki should have name pki"
  }

  assert {
    condition     = output.dns_records.registry.name == "registry"
    error_message = "dns_records.registry should have name registry"
  }

  assert {
    condition     = output.dns_records.auth.name == "auth"
    error_message = "dns_records.auth should have name auth"
  }

  assert {
    condition     = output.dns_records.traefik.ip == "192.168.1.60"
    error_message = "dns_records.traefik should point to VM IP"
  }
}

run "output_dns_records_services_disabled" {
  command = plan

  variables {
    step_ca_enabled   = false
    harbor_enabled    = false
    authentik_enabled = false
  }

  assert {
    condition     = output.dns_records.pki == null
    error_message = "dns_records.pki should be null when step_ca disabled"
  }

  assert {
    condition     = output.dns_records.registry == null
    error_message = "dns_records.registry should be null when harbor disabled"
  }

  assert {
    condition     = output.dns_records.auth == null
    error_message = "dns_records.auth should be null when authentik disabled"
  }
}

# -----------------------------------------------------------------------------
# Monitoring targets
# -----------------------------------------------------------------------------

run "output_monitoring_targets_all_enabled" {
  command = plan

  assert {
    condition     = output.monitoring_targets.step_ca.job_name == "step-ca"
    error_message = "monitoring_targets should include step-ca"
  }

  assert {
    condition     = output.monitoring_targets.harbor.job_name == "harbor"
    error_message = "monitoring_targets should include harbor"
  }

  assert {
    condition     = output.monitoring_targets.traefik.job_name == "traefik"
    error_message = "monitoring_targets should include traefik"
  }
}

run "output_monitoring_targets_disabled" {
  command = plan

  variables {
    step_ca_enabled = false
    harbor_enabled  = false
    traefik_enabled = false
  }

  assert {
    condition     = output.monitoring_targets.step_ca == null
    error_message = "monitoring_targets.step_ca should be null when disabled"
  }

  assert {
    condition     = output.monitoring_targets.harbor == null
    error_message = "monitoring_targets.harbor should be null when disabled"
  }

  assert {
    condition     = output.monitoring_targets.traefik == null
    error_message = "monitoring_targets.traefik should be null when disabled"
  }
}

# -----------------------------------------------------------------------------
# Custom domain suffix
# -----------------------------------------------------------------------------

run "output_custom_domain" {
  command = plan

  variables {
    domain_suffix = "lab.local"
  }

  assert {
    condition     = output.domain_suffix == "lab.local"
    error_message = "domain_suffix should reflect custom value"
  }

  assert {
    condition     = output.urls.step_ca == "https://pki.lab.local"
    error_message = "step_ca URL should use custom domain"
  }

  assert {
    condition     = output.harbor_registry_url == "registry.lab.local"
    error_message = "harbor_registry_url should use custom domain"
  }
}
