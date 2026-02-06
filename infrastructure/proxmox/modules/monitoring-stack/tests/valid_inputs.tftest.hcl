# =============================================================================
# Module Monitoring Stack - Tests de validation des entrees
# =============================================================================
# Verifie que les regles de validation des variables rejettent les valeurs
# invalides et acceptent les valeurs valides.
# =============================================================================

mock_provider "proxmox" {}

# -----------------------------------------------------------------------------
# Variables par defaut pour les tests (configuration minimale valide)
# -----------------------------------------------------------------------------

variables {
  target_node            = "pve-test"
  template_id            = 9000
  ip_address             = "192.168.1.50"
  gateway                = "192.168.1.1"
  ssh_keys               = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITEST test@test"]
  grafana_admin_password = "testpassword123" # gitleaks:allow
  proxmox_nodes = [
    {
      name        = "pve-test"
      ip          = "192.168.1.100"
      token_value = "test-token-value"
    }
  ]
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
# vm_config.data_disk validation (4-4096)
# -----------------------------------------------------------------------------

run "vm_config_data_disk_valid_minimum" {
  command = plan

  variables {
    loki_enabled = false
    vm_config = {
      data_disk = 4
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

run "vm_config_data_disk_too_small_for_loki" {
  command = plan

  variables {
    loki_enabled = true
    vm_config = {
      data_disk = 8
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
    ip_address = "10.0.0.50"
  }
}

run "ip_address_valid_another" {
  command = plan

  variables {
    ip_address = "172.16.0.1"
  }
}

run "ip_address_invalid_with_cidr" {
  command = plan

  variables {
    ip_address = "192.168.1.50/24"
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
# prometheus_retention_days validation (1-365)
# -----------------------------------------------------------------------------

run "retention_days_valid_minimum" {
  command = plan

  variables {
    prometheus_retention_days = 1
  }
}

run "retention_days_valid_maximum" {
  command = plan

  variables {
    prometheus_retention_days = 365
  }
}

run "retention_days_invalid_zero" {
  command = plan

  variables {
    prometheus_retention_days = 0
  }

  expect_failures = [
    var.prometheus_retention_days,
  ]
}

run "retention_days_invalid_too_high" {
  command = plan

  variables {
    prometheus_retention_days = 366
  }

  expect_failures = [
    var.prometheus_retention_days,
  ]
}

# -----------------------------------------------------------------------------
# prometheus_retention_size validation (format NGB)
# -----------------------------------------------------------------------------

run "retention_size_valid_gb" {
  command = plan

  variables {
    prometheus_retention_size = "40GB"
  }
}

run "retention_size_valid_tb" {
  command = plan

  variables {
    prometheus_retention_size = "1TB"
  }
}

run "retention_size_valid_mb" {
  command = plan

  variables {
    prometheus_retention_size = "500MB"
  }
}

run "retention_size_invalid_format" {
  command = plan

  variables {
    prometheus_retention_size = "40gb"
  }

  expect_failures = [
    var.prometheus_retention_size,
  ]
}

run "retention_size_invalid_no_unit" {
  command = plan

  variables {
    prometheus_retention_size = "40"
  }

  expect_failures = [
    var.prometheus_retention_size,
  ]
}

# -----------------------------------------------------------------------------
# grafana_admin_password validation (>= 8 chars)
# -----------------------------------------------------------------------------

run "grafana_password_valid" {
  command = plan

  variables {
    grafana_admin_password = "12345678" # gitleaks:allow
  }
}

run "grafana_password_invalid_too_short" {
  command = plan

  variables {
    grafana_admin_password = "1234567" # gitleaks:allow
  }

  expect_failures = [
    var.grafana_admin_password,
  ]
}

# -----------------------------------------------------------------------------
# Defaults verification
# -----------------------------------------------------------------------------

run "defaults_are_applied" {
  command = plan

  assert {
    condition     = var.name == "monitoring"
    error_message = "Default name should be monitoring"
  }

  assert {
    condition     = var.vm_config.cores == 2
    error_message = "Default vm_config.cores should be 2"
  }

  assert {
    condition     = var.vm_config.memory == 4096
    error_message = "Default vm_config.memory should be 4096"
  }

  assert {
    condition     = var.vm_config.disk == 30
    error_message = "Default vm_config.disk should be 30"
  }

  assert {
    condition     = var.vm_config.data_disk == 50
    error_message = "Default vm_config.data_disk should be 50"
  }

  assert {
    condition     = var.network_cidr == 24
    error_message = "Default network_cidr should be 24"
  }

  assert {
    condition     = var.prometheus_retention_days == 30
    error_message = "Default prometheus_retention_days should be 30"
  }

  assert {
    condition     = var.prometheus_retention_size == "40GB"
    error_message = "Default prometheus_retention_size should be 40GB"
  }

  assert {
    condition     = var.telegram_enabled == true
    error_message = "Default telegram_enabled should be true"
  }

  assert {
    condition     = var.backup_alerting_enabled == true
    error_message = "Default backup_alerting_enabled should be true"
  }

  assert {
    condition     = var.username == "ubuntu"
    error_message = "Default username should be ubuntu"
  }

  # New observability tools defaults
  assert {
    condition     = var.traefik_enabled == true
    error_message = "Default traefik_enabled should be true"
  }

  assert {
    condition     = var.loki_enabled == true
    error_message = "Default loki_enabled should be true"
  }

  assert {
    condition     = var.uptime_kuma_enabled == true
    error_message = "Default uptime_kuma_enabled should be true"
  }

  assert {
    condition     = var.domain_suffix == "home.lan"
    error_message = "Default domain_suffix should be home.lan"
  }

  assert {
    condition     = var.loki_retention_days == 7
    error_message = "Default loki_retention_days should be 7"
  }

  assert {
    condition     = var.tls_enabled == false
    error_message = "Default tls_enabled should be false"
  }
}

# -----------------------------------------------------------------------------
# domain_suffix validation (valid domain name)
# -----------------------------------------------------------------------------

run "domain_suffix_valid_simple" {
  command = plan

  variables {
    domain_suffix = "home.lan"
  }
}

run "domain_suffix_valid_subdomain" {
  command = plan

  variables {
    domain_suffix = "homelab.local"
  }
}

run "domain_suffix_valid_longer" {
  command = plan

  variables {
    domain_suffix = "my.home.network"
  }
}

run "domain_suffix_invalid_starts_with_dot" {
  command = plan

  variables {
    domain_suffix = ".home.lan"
  }

  expect_failures = [
    var.domain_suffix,
  ]
}

run "domain_suffix_invalid_ends_with_dot" {
  command = plan

  variables {
    domain_suffix = "home.lan."
  }

  expect_failures = [
    var.domain_suffix,
  ]
}

run "domain_suffix_invalid_uppercase" {
  command = plan

  variables {
    domain_suffix = "HOME.LAN"
  }

  expect_failures = [
    var.domain_suffix,
  ]
}

# -----------------------------------------------------------------------------
# loki_retention_days validation (1-90)
# -----------------------------------------------------------------------------

run "loki_retention_days_valid_minimum" {
  command = plan

  variables {
    loki_retention_days = 1
  }
}

run "loki_retention_days_valid_maximum" {
  command = plan

  variables {
    loki_retention_days = 90
  }
}

run "loki_retention_days_invalid_zero" {
  command = plan

  variables {
    loki_retention_days = 0
  }

  expect_failures = [
    var.loki_retention_days,
  ]
}

run "loki_retention_days_invalid_too_high" {
  command = plan

  variables {
    loki_retention_days = 91
  }

  expect_failures = [
    var.loki_retention_days,
  ]
}

# -----------------------------------------------------------------------------
# custom_scrape_configs validation
# -----------------------------------------------------------------------------

run "custom_scrape_configs_empty_default" {
  command = plan

  assert {
    condition     = var.custom_scrape_configs == ""
    error_message = "Default custom_scrape_configs should be empty"
  }
}

run "custom_scrape_configs_with_content" {
  command = plan

  variables {
    custom_scrape_configs = <<-YAML
  - job_name: 'custom-app'
    static_configs:
      - targets: ['192.168.1.101:9100']
        labels:
          app: 'test'
YAML
  }
}
