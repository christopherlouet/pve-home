# =============================================================================
# Module Tooling Stack - Tests de validation des entrees
# =============================================================================
# Verifie que les regles de validation des variables rejettent les valeurs
# invalides et acceptent les valeurs valides.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests (configuration minimale valide)
# -----------------------------------------------------------------------------

variables {
  target_node         = "pve-test"
  template_id         = 9000
  ip_address          = "192.168.1.60"
  gateway             = "192.168.1.1"
  ssh_keys            = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  domain_suffix       = "home.arpa"
  # Step-ca
  step_ca_password    = "testpassword123" # gitleaks:allow
  # Harbor
  harbor_admin_password = "Harbor12345!" # gitleaks:allow
  # Authentik
  authentik_secret_key  = "testsecretkey1234567890123456" # gitleaks:allow
  authentik_bootstrap_password = "Authentik123!" # gitleaks:allow
}

# -----------------------------------------------------------------------------
# template_id validation (>= 100)
# -----------------------------------------------------------------------------

run "template_id_valid_minimum" {
  command = plan

  variables {
    template_id = 100
  }
}

run "template_id_invalid_too_low" {
  command = plan

  variables {
    template_id = 99
  }

  expect_failures = [
    var.template_id,
  ]
}

# -----------------------------------------------------------------------------
# vm_config.cores validation (1-64)
# -----------------------------------------------------------------------------

run "vm_config_cores_valid_minimum" {
  command = plan

  variables {
    vm_config = {
      cores = 1
    }
  }
}

run "vm_config_cores_valid_maximum" {
  command = plan

  variables {
    vm_config = {
      cores = 64
    }
  }
}

run "vm_config_cores_invalid_zero" {
  command = plan

  variables {
    vm_config = {
      cores = 0
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

run "vm_config_cores_invalid_too_high" {
  command = plan

  variables {
    vm_config = {
      cores = 65
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

# -----------------------------------------------------------------------------
# vm_config.memory validation (512-131072)
# -----------------------------------------------------------------------------

run "vm_config_memory_valid_minimum" {
  command = plan

  variables {
    vm_config = {
      memory = 512
    }
  }
}

run "vm_config_memory_valid_for_tooling" {
  command = plan

  variables {
    vm_config = {
      memory = 6144
    }
  }
}

run "vm_config_memory_invalid_too_low" {
  command = plan

  variables {
    vm_config = {
      memory = 511
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

# -----------------------------------------------------------------------------
# vm_config.disk validation (4-4096)
# -----------------------------------------------------------------------------

run "vm_config_disk_valid_minimum" {
  command = plan

  variables {
    vm_config = {
      disk = 4
    }
  }
}

run "vm_config_disk_invalid_too_small" {
  command = plan

  variables {
    vm_config = {
      disk = 3
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

# -----------------------------------------------------------------------------
# vm_config.data_disk validation (4-4096) - Harbor storage
# -----------------------------------------------------------------------------

run "vm_config_data_disk_valid_for_harbor" {
  command = plan

  variables {
    vm_config = {
      data_disk = 100
    }
  }
}

run "vm_config_data_disk_invalid_too_small" {
  command = plan

  variables {
    vm_config = {
      data_disk = 3
    }
  }

  expect_failures = [
    var.vm_config,
  ]
}

# -----------------------------------------------------------------------------
# ip_address validation (IPv4 without CIDR)
# -----------------------------------------------------------------------------

run "ip_address_valid" {
  command = plan

  variables {
    ip_address = "10.0.0.60"
  }
}

run "ip_address_valid_another" {
  command = plan

  variables {
    ip_address = "172.16.0.60"
  }
}

run "ip_address_invalid_with_cidr" {
  command = plan

  variables {
    ip_address = "192.168.1.60/24"
  }

  expect_failures = [
    var.ip_address,
  ]
}

run "ip_address_invalid_format" {
  command = plan

  variables {
    ip_address = "not-an-ip"
  }

  expect_failures = [
    var.ip_address,
  ]
}

# -----------------------------------------------------------------------------
# network_cidr validation (8-32)
# -----------------------------------------------------------------------------

run "network_cidr_valid_minimum" {
  command = plan

  variables {
    network_cidr = 8
  }
}

run "network_cidr_valid_maximum" {
  command = plan

  variables {
    network_cidr = 32
  }
}

run "network_cidr_invalid_too_low" {
  command = plan

  variables {
    network_cidr = 7
  }

  expect_failures = [
    var.network_cidr,
  ]
}

run "network_cidr_invalid_too_high" {
  command = plan

  variables {
    network_cidr = 33
  }

  expect_failures = [
    var.network_cidr,
  ]
}

# -----------------------------------------------------------------------------
# domain_suffix validation (valid domain name) - home.arpa recommended
# -----------------------------------------------------------------------------

run "domain_suffix_valid_home_arpa" {
  command = plan

  variables {
    domain_suffix = "home.arpa"
  }
}

run "domain_suffix_valid_subdomain" {
  command = plan

  variables {
    domain_suffix = "lab.home.arpa"
  }
}

run "domain_suffix_valid_homelab_local" {
  command = plan

  variables {
    domain_suffix = "homelab.local"
  }
}

run "domain_suffix_invalid_starts_with_dot" {
  command = plan

  variables {
    domain_suffix = ".home.arpa"
  }

  expect_failures = [
    var.domain_suffix,
  ]
}

run "domain_suffix_invalid_ends_with_dot" {
  command = plan

  variables {
    domain_suffix = "home.arpa."
  }

  expect_failures = [
    var.domain_suffix,
  ]
}

run "domain_suffix_invalid_uppercase" {
  command = plan

  variables {
    domain_suffix = "HOME.ARPA"
  }

  expect_failures = [
    var.domain_suffix,
  ]
}

# -----------------------------------------------------------------------------
# Step-ca password validation (>= 8 chars)
# -----------------------------------------------------------------------------

run "step_ca_password_valid" {
  command = plan

  variables {
    step_ca_password = "mysecurepassword" # gitleaks:allow
  }
}

run "step_ca_password_invalid_too_short" {
  command = plan

  variables {
    step_ca_password = "1234567" # gitleaks:allow
  }

  expect_failures = [
    var.step_ca_password,
  ]
}

# -----------------------------------------------------------------------------
# Harbor admin password validation (>= 8 chars)
# -----------------------------------------------------------------------------

run "harbor_admin_password_valid" {
  command = plan

  variables {
    harbor_admin_password = "Harbor12345!" # gitleaks:allow
  }
}

run "harbor_admin_password_invalid_too_short" {
  command = plan

  variables {
    harbor_admin_password = "short" # gitleaks:allow
  }

  expect_failures = [
    var.harbor_admin_password,
  ]
}

# -----------------------------------------------------------------------------
# Authentik secret key validation (>= 24 chars)
# -----------------------------------------------------------------------------

run "authentik_secret_key_valid" {
  command = plan

  variables {
    authentik_secret_key = "thisisaverylongsecretkey123456" # gitleaks:allow
  }
}

run "authentik_secret_key_invalid_too_short" {
  command = plan

  variables {
    authentik_secret_key = "tooshort" # gitleaks:allow
  }

  expect_failures = [
    var.authentik_secret_key,
  ]
}

# -----------------------------------------------------------------------------
# Authentik bootstrap password validation (>= 8 chars)
# -----------------------------------------------------------------------------

run "authentik_bootstrap_password_valid" {
  command = plan

  variables {
    authentik_bootstrap_password = "Authentik123!" # gitleaks:allow
  }
}

run "authentik_bootstrap_password_invalid_too_short" {
  command = plan

  variables {
    authentik_bootstrap_password = "short" # gitleaks:allow
  }

  expect_failures = [
    var.authentik_bootstrap_password,
  ]
}

# -----------------------------------------------------------------------------
# Defaults verification
# -----------------------------------------------------------------------------

run "defaults_are_applied" {
  command = plan

  assert {
    condition     = var.name == "tooling"
    error_message = "Default name should be tooling"
  }

  assert {
    condition     = var.vm_config.cores == 4
    error_message = "Default vm_config.cores should be 4"
  }

  assert {
    condition     = var.vm_config.memory == 6144
    error_message = "Default vm_config.memory should be 6144 (6GB)"
  }

  assert {
    condition     = var.vm_config.disk == 30
    error_message = "Default vm_config.disk should be 30"
  }

  assert {
    condition     = var.vm_config.data_disk == 100
    error_message = "Default vm_config.data_disk should be 100 (for Harbor images)"
  }

  assert {
    condition     = var.network_cidr == 24
    error_message = "Default network_cidr should be 24"
  }

  assert {
    condition     = var.username == "ubuntu"
    error_message = "Default username should be ubuntu"
  }

  assert {
    condition     = var.step_ca_enabled == true
    error_message = "Default step_ca_enabled should be true"
  }

  assert {
    condition     = var.harbor_enabled == true
    error_message = "Default harbor_enabled should be true"
  }

  assert {
    condition     = var.authentik_enabled == true
    error_message = "Default authentik_enabled should be true"
  }

  assert {
    condition     = var.traefik_enabled == true
    error_message = "Default traefik_enabled should be true"
  }

  assert {
    condition     = var.step_ca_provisioner_name == "acme"
    error_message = "Default step_ca_provisioner_name should be acme"
  }

  assert {
    condition     = var.harbor_db_password != ""
    error_message = "harbor_db_password should have a default value"
  }
}

# -----------------------------------------------------------------------------
# Service enable/disable flags
# -----------------------------------------------------------------------------

run "step_ca_can_be_disabled" {
  command = plan

  variables {
    step_ca_enabled = false
  }
}

run "harbor_can_be_disabled" {
  command = plan

  variables {
    harbor_enabled = false
  }
}

run "authentik_can_be_disabled" {
  command = plan

  variables {
    authentik_enabled = false
  }
}

run "traefik_can_be_disabled" {
  command = plan

  variables {
    traefik_enabled = false
  }
}

# -----------------------------------------------------------------------------
# Step-ca certificate duration validation
# -----------------------------------------------------------------------------

run "step_ca_cert_duration_valid" {
  command = plan

  variables {
    step_ca_cert_duration = "8760h"
  }
}

run "step_ca_cert_duration_valid_days" {
  command = plan

  variables {
    step_ca_cert_duration = "720h"
  }
}
