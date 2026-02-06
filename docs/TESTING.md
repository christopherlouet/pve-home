# Testing

## Overview

The project uses two testing frameworks:

- **Terraform native tests** (`terraform test`): 512 tests across 34 test files
- **BATS** (Bash Automated Testing System): 1048 tests across 31 test files

Total: **1560 tests**

## Terraform Tests

### Running Tests

```bash
# All tests for a module
cd infrastructure/proxmox/modules/<module>
terraform test

# Single test file
terraform test -filter=tests/<file>.tftest.hcl

# All modules
for dir in infrastructure/proxmox/modules/*/; do
  echo "=== $(basename "$dir") ==="
  (cd "$dir" && terraform test)
done
```

### Test Structure

Each module has a `tests/` directory with the following files:

| File | Purpose |
|------|---------|
| `valid_inputs.tftest.hcl` | Variable validation (types, ranges, formats) |
| `plan_resources.tftest.hcl` | Resource configuration assertions |
| `outputs.tftest.hcl` | Output value verification |
| `regression.tftest.hcl` | Non-regression tests for fixed bugs |

Some modules have additional domain-specific test files (e.g., `traefik.tftest.hcl`, `harbor.tftest.hcl`).

### Test Counts by Module

| Module | Tests | Files |
|--------|-------|-------|
| vm | 73 | 5 |
| lxc | 65 | 4 |
| backup | 49 | 4 |
| minio | 54 | 4 |
| monitoring-stack | 112 | 9 |
| tooling-stack | 159 | 8 |
| **Total** | **512** | **34** |

### Mock Providers

All Terraform tests use `mock_provider` to run without a real Proxmox connection:

```hcl
mock_provider "proxmox" {}
mock_provider "tls" {}
mock_provider "random" {}
```

Tests use `command = plan` for assertions on known values. Provider-dependent outputs (e.g., `vm_id`, `mac_address`) are not testable with mock providers during plan.

## BATS Tests

### Running Tests

```bash
# All BATS tests
bats --recursive tests/

# Single test file
bats tests/scripts/test_docker_compose_monitoring.bats

# Specific directory
bats --recursive tests/scripts/
```

### Test Categories

| Directory | Purpose | Tests |
|-----------|---------|-------|
| `tests/scripts/` | Script template validation (docker-compose, install scripts) | Static analysis |
| `tests/lifecycle/` | VM lifecycle operations (snapshots, expiration, SSH rotation) | Static analysis |
| `tests/drift/` | Configuration drift detection | Static analysis |
| `tests/health/` | Health check scripts | Static analysis |
| `tests/restore/` | Backup restore procedures | Static analysis |
| `tests/tui/` | TUI menu scripts (requires `gum`) | Static analysis |

### Testing Approach

BATS tests use **static analysis** (grep-based) rather than execution, because the scripts require infrastructure dependencies (Proxmox API, SSH, MinIO client). Tests verify:

- Required variables and functions exist
- Error handling (`set -euo pipefail`)
- Security patterns (no hardcoded credentials, input validation)
- Docker Compose template structure (valid YAML, required services, security options)
- Script structure (proper logging, exit codes)

## CI Integration

Tests run automatically in GitHub Actions CI:

```yaml
# Terraform tests
- terraform init && terraform test  # Per module

# BATS tests
- bats --recursive tests/

# Additional checks
- shellcheck on .sh and .sh.tpl files
- terraform validate per environment
- gitleaks for secret detection
- markdownlint for documentation
```

## Adding Tests

### New Terraform Test

1. Create or edit `tests/<category>.tftest.hcl` in the module
2. Use `mock_provider` for all providers
3. Use `command = plan` for assertions on configuration values
4. Add `variables {}` block with required inputs

### New BATS Test

1. Create `tests/<category>/test_<name>.bats`
2. Use `@test` annotations for each test case
3. Use grep-based assertions for static analysis
4. Add `setup()` to define the file path being tested
