# ADR-0005: Terraform Native Tests over Terratest

## Status: Accepted

## Context

Infrastructure code needs automated testing to prevent regressions and validate variable constraints. We need to choose between Terraform native tests (terraform test, HCL-based) and Go-based frameworks (Terratest, kitchen-terraform).

## Decision

Use **Terraform native tests** (`*.tftest.hcl` files with `mock_provider`) as the primary testing strategy, complemented by **BATS tests** for shell script validation.

## Rationale

- **No Go dependency**: Tests are written in HCL, the same language as the infrastructure code
- **Mock providers**: `mock_provider "proxmox" {}` allows plan-level testing without real infrastructure
- **Fast execution**: Plan-only tests run in seconds, enabling comprehensive CI coverage
- **Test patterns**: Supports validation testing (`expect_failures`), plan assertions, and output verification
- **BATS complement**: Shell templates (`.sh.tpl`) are tested via BATS for static analysis (grep-based) since they require infrastructure to execute

## Test Structure

```
modules/*/tests/
  valid_inputs.tftest.hcl    # Variable validation boundaries
  plan_resources.tftest.hcl  # Resource attribute verification
  regression.tftest.hcl      # Bug fix non-regression
  outputs.tftest.hcl         # Output correctness
environments/*/tests/
  integration.tftest.hcl     # Cross-module integration
  multi-module.tftest.hcl    # Complex deployment scenarios
```

## Alternatives Considered

- **Terratest (Go)**: Rejected; requires Go toolchain, more complex for HCL-centric team
- **No tests**: Rejected; too risky for infrastructure code managing production VMs
- **Apply-level tests**: Deferred; plan-level tests catch most issues without requiring real infrastructure

## Consequences

- 467+ test runs across 31 test files
- CI matrix tests 6 modules + 3 environments in parallel
- Tests validate all variable constraints at boundaries (min, max, null, invalid)
- Cannot test actual apply behavior (provider responses, API errors)
