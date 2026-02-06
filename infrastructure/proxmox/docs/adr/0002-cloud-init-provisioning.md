# ADR-0002: Cloud-Init Provisioning via Terraform

## Status: Accepted

## Context

VMs need to be provisioned with users, SSH keys, packages, Docker, and service configurations. We need a reliable, idempotent provisioning method that works without network access to Ansible or other external tools.

## Decision

Use **cloud-init** via Terraform's `proxmox_virtual_environment_file` resource to provision VMs. Configuration is generated as YAML using `templatefile()` and injected as a cloud-config snippet.

## Rationale

- **No external dependencies**: Cloud-init runs at first boot without needing Ansible, SSH connectivity, or network access to a config server
- **Idempotent**: Cloud-init runs once at VM creation, preventing configuration drift from re-runs
- **Terraform-native**: The cloud-config is generated directly from Terraform variables, ensuring consistency between infrastructure and configuration
- **Testable**: Template rendering can be validated in `terraform plan` without actual infrastructure

## Alternatives Considered

- **Ansible**: Rejected because it requires SSH access and introduces an additional tool dependency
- **Packer images**: Rejected for homelab context; cloud-init is more flexible for per-VM customization
- **Terraform provisioners**: Rejected as they are considered a last resort by HashiCorp and require SSH connectivity

## Consequences

- Complex configurations (monitoring-stack) result in large cloud-init files
- Shell scripts are externalized to `.sh.tpl` files for testability with shellcheck and BATS
- Changes to provisioning require VM recreation (cloud-init is immutable)
