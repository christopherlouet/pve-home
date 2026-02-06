# Contributing

## Project Structure

```
pve-home/
├── infrastructure/proxmox/
│   ├── modules/              # Reusable Terraform modules
│   │   ├── vm/               # Generic VM with cloud-init
│   │   ├── lxc/              # LXC containers
│   │   ├── backup/           # Backup schedules (vzdump)
│   │   ├── minio/            # S3-compatible storage
│   │   ├── monitoring-stack/ # Prometheus + Grafana + Alertmanager
│   │   └── tooling-stack/    # Step-CA + Harbor + Authentik
│   ├── environments/         # Environment-specific configs
│   │   ├── prod/
│   │   ├── lab/
│   │   └── monitoring/
│   └── shared/               # Shared variables (symlinked)
├── scripts/                  # Operational scripts
│   ├── health/               # Infrastructure health checks
│   ├── restore/              # Backup restore & verification
│   └── lib/                  # Shared shell library (common.sh)
└── tests/                    # BATS test suites
    ├── health/
    ├── lifecycle/
    ├── restore/
    └── scripts/
```

## Running Tests

### Terraform Tests

Run per-module using native `terraform test`:

```bash
cd infrastructure/proxmox/modules/vm
terraform init -backend=false
terraform test
```

Modules with tests: `vm`, `lxc`, `backup`, `minio`, `monitoring-stack`, `tooling-stack`.

### BATS Tests

Run the full suite from the project root:

```bash
bats --recursive tests/
```

Run a specific test directory:

```bash
bats tests/health/
bats tests/restore/
```

### Shellcheck

Check all scripts:

```bash
find scripts -name "*.sh" -type f -print0 | xargs -0 shellcheck -x -S warning
```

For `.sh.tpl` files (Terraform templates), strip directives first:

```bash
sed -e 's/%{[^}]*}//g' -e 's/\${[^}]*}/PLACEHOLDER/g' file.sh.tpl | shellcheck -x -S warning -
```

## Conventions

### Terraform

- Provider: `bpg/proxmox` ~> 0.94
- Use `templatefile()` for shell scripts in `modules/*/files/`
- Shared environment variables via symlinks from `shared/env_variables.tf`
- All modules must have `tests/` directory with `.tftest.hcl` files
- Use `mock_provider` in tests (no real infrastructure required)

### Shell Scripts

- Always start with `set -euo pipefail`
- Source `scripts/lib/common.sh` for logging and utilities
- Support `--dry-run`, `--force`, and `--help` flags
- Use `log_info`, `log_success`, `log_warn`, `log_error` from common.sh

### BATS Tests

- Test file naming: `test_<script_name>.bats`
- Include both static analysis (grep-based) and execution tests
- Execution tests should cover error paths (invalid args, missing deps)
- Use `setup()` / `teardown()` for temp directories

### Commit Messages

Follow Conventional Commits:

```
type(scope): description

feat/fix/refactor/test/docs/chore/perf(module): short description
```

## Workflow

1. Create a feature branch: `feature/description`
2. Write tests first (TDD encouraged)
3. Run `terraform validate` and `terraform test` for TF changes
4. Run `bats --recursive tests/` for shell changes
5. Commit with Conventional Commits format
6. Open a PR against `main`

## Pull Request Process

1. Ensure all CI checks pass (Terraform fmt/validate/test, shellcheck, BATS, tflint)
2. Update documentation if you changed module interfaces (variables, outputs)
3. Add an entry in `CHANGELOG.md` under `[Unreleased]`
4. Fill in the PR template with description, type of change, and checklist
5. Request a review
6. Squash and merge once approved

## Code Review Checklist

Reviewers should verify:

- [ ] Tests cover the change (Terraform tests for modules, BATS for scripts)
- [ ] No hardcoded secrets or IPs in module code
- [ ] Variables have validation blocks and descriptions
- [ ] Shell scripts use `set -euo pipefail`
- [ ] Docker images are pinned with SHA256 digests
- [ ] Commit messages follow Conventional Commits
