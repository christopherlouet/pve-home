# ADR-0001: Multi-Environment Strategy

## Status: Accepted

## Context

The homelab runs multiple Proxmox VE hosts with different purposes (production workloads, lab/testing, monitoring infrastructure). We need isolated Terraform configurations for each while avoiding code duplication.

## Decision

Use **separate environment directories** (`environments/prod`, `environments/lab`, `environments/monitoring`) with independent Terraform state, rather than Terraform workspaces.

Shared variables are centralized in `shared/` and symlinked into each environment to avoid duplication.

## Rationale

- **State isolation**: Each environment has its own state file, preventing accidental cross-environment changes
- **Independent lifecycles**: Lab can be destroyed/recreated without affecting prod
- **Different providers**: Each environment targets a different Proxmox host with separate credentials
- **Symlink DRY**: `shared/common_variables.tf` and `shared/env_variables.tf` are symlinked into environments, maintaining a single source of truth

## Alternatives Considered

- **Terraform workspaces**: Rejected because environments target different Proxmox hosts (not just different variable sets)
- **Terragrunt**: Rejected as overkill for 3 environments; symlinks achieve similar DRY benefits with less tooling

## Consequences

- New shared variables must be added to `shared/` and symlinked
- Each environment can evolve independently (monitoring has different modules than prod)
- CI matrix tests all environments in parallel
