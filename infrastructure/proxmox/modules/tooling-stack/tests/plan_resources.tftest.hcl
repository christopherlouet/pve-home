# =============================================================================
# Module Tooling Stack - Tests de planification des ressources
# =============================================================================
# Verifie que le plan Terraform cree les ressources attendues.
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
# VM Resource Tests
# -----------------------------------------------------------------------------

run "vm_is_created" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.tooling != null
    error_message = "VM tooling should be created"
  }
}

run "vm_has_correct_name" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.tooling.name == "tooling"
    error_message = "VM should be named 'tooling'"
  }
}

run "vm_has_custom_name" {
  command = plan

  variables {
    name = "my-tooling"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.tooling.name == "my-tooling"
    error_message = "VM should use custom name"
  }
}

run "vm_has_correct_node" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.tooling.node_name == "pve-test"
    error_message = "VM should be on correct node"
  }
}

run "vm_has_correct_cpu" {
  command = plan

  variables {
    vm_config = {
      cores = 4
    }
  }

  assert {
    condition     = proxmox_virtual_environment_vm.tooling.cpu[0].cores == 4
    error_message = "VM should have 4 cores"
  }
}

run "vm_has_correct_memory" {
  command = plan

  variables {
    vm_config = {
      memory = 6144
    }
  }

  assert {
    condition     = proxmox_virtual_environment_vm.tooling.memory[0].dedicated == 6144
    error_message = "VM should have 6144 MB memory"
  }
}

run "vm_has_two_disks" {
  command = plan

  assert {
    condition     = length(proxmox_virtual_environment_vm.tooling.disk) == 2
    error_message = "VM should have 2 disks (system + data)"
  }
}

run "vm_has_network" {
  command = plan

  assert {
    condition     = length(proxmox_virtual_environment_vm.tooling.network_device) == 1
    error_message = "VM should have 1 network device"
  }
}

run "vm_has_qemu_agent" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.tooling.agent[0].enabled == true
    error_message = "VM should have QEMU agent enabled"
  }
}

run "vm_starts_on_boot" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.tooling.on_boot == true
    error_message = "VM should start on boot"
  }
}

# -----------------------------------------------------------------------------
# Cloud-init Resource Tests
# -----------------------------------------------------------------------------

run "cloud_init_file_is_created" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_file.cloud_config != null
    error_message = "Cloud-init config file should be created"
  }
}

run "cloud_init_is_snippet" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_file.cloud_config.content_type == "snippets"
    error_message = "Cloud-init should be a snippet"
  }
}

# -----------------------------------------------------------------------------
# Tags Tests
# -----------------------------------------------------------------------------

run "vm_has_default_tags" {
  command = plan

  assert {
    condition     = contains(proxmox_virtual_environment_vm.tooling.tags, "terraform")
    error_message = "VM should have 'terraform' tag"
  }

  assert {
    condition     = contains(proxmox_virtual_environment_vm.tooling.tags, "tooling")
    error_message = "VM should have 'tooling' tag"
  }
}

run "vm_has_custom_tags" {
  command = plan

  variables {
    tags = ["terraform", "tooling", "pki", "registry"]
  }

  assert {
    condition     = contains(proxmox_virtual_environment_vm.tooling.tags, "pki")
    error_message = "VM should have custom 'pki' tag"
  }

  assert {
    condition     = contains(proxmox_virtual_environment_vm.tooling.tags, "registry")
    error_message = "VM should have custom 'registry' tag"
  }
}

# -----------------------------------------------------------------------------
# Output Tests
# -----------------------------------------------------------------------------

run "outputs_are_correct" {
  command = plan

  assert {
    condition     = output.ip_address == "192.168.1.60"
    error_message = "Output ip_address should be correct"
  }

  assert {
    condition     = output.domain_suffix == "home.arpa"
    error_message = "Output domain_suffix should be correct"
  }

  assert {
    condition     = output.ssh_command == "ssh ubuntu@192.168.1.60"
    error_message = "Output ssh_command should be correct"
  }
}

run "urls_output_with_traefik" {
  command = plan

  variables {
    traefik_enabled = true
  }

  assert {
    condition     = output.urls.step_ca == "https://pki.home.arpa"
    error_message = "Step-ca URL should use domain suffix"
  }

  assert {
    condition     = output.urls.harbor == "https://registry.home.arpa"
    error_message = "Harbor URL should use domain suffix"
  }

  assert {
    condition     = output.urls.authentik == "https://auth.home.arpa"
    error_message = "Authentik URL should use domain suffix"
  }
}

run "urls_output_without_traefik" {
  command = plan

  variables {
    traefik_enabled = false
  }

  assert {
    condition     = output.urls.step_ca == "https://192.168.1.60:8443"
    error_message = "Step-ca URL should use IP when Traefik disabled"
  }

  assert {
    condition     = output.urls.harbor == "https://192.168.1.60:443"
    error_message = "Harbor URL should use IP when Traefik disabled"
  }

  assert {
    condition     = output.urls.authentik == "http://192.168.1.60:9000"
    error_message = "Authentik URL should use IP when Traefik disabled"
  }
}

run "service_enabled_outputs" {
  command = plan

  assert {
    condition     = output.step_ca_enabled == true
    error_message = "step_ca_enabled output should be true by default"
  }

  assert {
    condition     = output.harbor_enabled == true
    error_message = "harbor_enabled output should be true by default"
  }

  assert {
    condition     = output.authentik_enabled == true
    error_message = "authentik_enabled output should be true by default"
  }
}
