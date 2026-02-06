# ADR-0004: Shared Variables via Symlinks

## Status: Accepted

## Context

Multiple modules and environments need the same variable definitions (e.g., `expiration_days`, common VM/LXC map types). Duplicating variable definitions leads to inconsistencies and maintenance burden.

## Decision

Use **filesystem symlinks** to share variable and locals files from `shared/` into modules and environments.

```
shared/
  common_variables.tf    -> symlinked into environments
  env_variables.tf       -> symlinked into environments
  expiration_variables.tf -> symlinked into vm/ and lxc/
  expiration_locals.tf   -> symlinked into vm/ and lxc/
```

## Rationale

- **Single source of truth**: One file to modify, changes propagate everywhere
- **No extra tooling**: Symlinks work natively with Terraform, Git, and CI
- **Terraform-compatible**: Terraform reads `.tf` files from the module directory; symlinks are transparent
- **Testable**: Tests in each module validate the shared variables work correctly

## Alternatives Considered

- **Copy-paste**: Rejected; leads to drift between modules
- **Terragrunt inputs**: Rejected; adds tooling dependency
- **Terraform module for variables**: Not possible; Terraform modules can't export variable definitions

## Consequences

- Symlinks must be preserved in Git (`.gitattributes` or careful handling)
- New shared variables require creating symlinks in target directories
- CI must handle symlinks correctly (GitHub Actions does by default)
