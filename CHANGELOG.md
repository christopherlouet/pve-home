# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-01

### Added
- 5 Prometheus alert rules: `SystemdServiceFailed`, `HighLoadAverage`, `HighNetworkErrors`, `PrometheusRuleEvaluationFailures`, `NodeFilesystemAlmostOutOfInodes` (28 total alerts)
- Regression test files (`regression.tftest.hcl`) for 4 modules: LXC (5 tests), Backup (4 tests), Minio (5 tests), Monitoring-stack (4 tests) — all 5 modules now covered
- `retry_with_backoff()` function in `scripts/lib/common.sh` with exponential backoff (1s, 2s, 4s)
- `ssh_exec_retry()` function wrapping SSH execution with 3 automatic retries
- 7 BATS tests covering retry/backoff functions

### Changed
- `check_ssh_access()` now retries 3 times with backoff before declaring SSH failure

## [1.0.0] - 2026-02-01

### Security
- Replace `eval "$command"` with direct execution `"$@"` in `dry_run()` to prevent shell injection
- SSH hardening: `StrictHostKeyChecking=accept-new` replaces `StrictHostKeyChecking=no` across all scripts (6 files)
- SSH hardening: remove `UserKnownHostsFile=/dev/null` to persist known hosts
- Minio credentials passed via `MC_HOST_local` env var instead of CLI arguments (avoids process list exposure)
- Added SECURITY NOTE documentation on accepted homelab risks (NOPASSWD, firewall, SSH key in state)

### Added
- `shared/common_variables.tf` with 11 variables symlinked into all 3 environments (DRY)
- `vlan_id` validation (1-4094 or null) on vm, lxc, and minio modules
- `grafana_admin_password` minimum length validation (8 chars) on monitoring-stack module
- `minio_root_password` minimum length validation (8 chars) on minio module
- Backup module plan tests (`plan_resources.tftest.hcl`): 15 tests covering triggers, retention, VMIDs, custom config
- Monitoring-stack module plan tests (`plan_resources.tftest.hcl`): 15 tests covering VM, disks, network, outputs, scrape targets
- `tests/test_deploy.bats`: 19 tests for deploy.sh (existence, shellcheck, options, SSH config, structure)
- `.terraform.lock.hcl` committed for all 5 modules (reproducible provider installs)

### Changed
- Environment `variables.tf` files reduced to environment-specific variables only (common variables via symlink)
- Minio module outputs extracted from `main.tf` to dedicated `outputs.tf` for consistency
- Module READMEs regenerated with terraform-docs to reflect new validations
- Infrastructure README updated with `shared/` directory and symlink documentation

## [0.9.1] - 2026-02-01

### Changed
- Updated documentation for v0.9.0 features: SSH keypair automation, LXC security updates, deploy.sh, health check improvements
  - README.md, HEALTH-CHECKS.md, VM-LIFECYCLE.md, DISASTER-RECOVERY.md, infrastructure/proxmox/README.md, scripts/README.md

## [0.9.0] - 2026-02-01

### Added
- SSH keypair generation for monitoring VM health checks (`tls_private_key` in monitoring-stack module)
  - Private key provisioned to `/root/.ssh/id_ed25519` via cloud-init
  - Public key exposed as `health_check_ssh_public_key` output for cross-environment injection
- `monitoring_ssh_public_key` variable in prod environment for monitoring VM SSH access
- Automatic security updates (`unattended-upgrades`) for LXC containers via `remote-exec` provisioner
  - Conditional on `auto_security_updates` and Ubuntu/Debian OS type
- `deploy.sh` script for monitoring VM provisioning (rsync scripts, tfvars, systemd timers)

### Changed
- Health check `--ssh-user` option defaults to `ubuntu` (matches cloud-init VMs)
- Health check extracts VM IPs only from `vms = {}` block in tfvars (avoids DNS/gateway false positives)
- Skip Alertmanager health check when Telegram notifications are disabled

### Dependencies
- Bumped `bpg/proxmox` from 0.93.0 to 0.93.1 (prod, lab, monitoring)
- Bumped `actions/checkout` from 4 to 6
- Bumped `github/codeql-action` from 3 to 4
- Bumped `DavidAnson/markdownlint-cli2-action` from 19 to 22
- Added `hashicorp/tls ~> 4.0` provider (monitoring environment)

## [0.8.0] - 2026-02-01

### Added
- Native Terraform test framework (`terraform test`) for all 5 modules with `mock_provider`
  - VM module: 20 validation tests + 13 plan tests + 1 regression test
  - LXC module: 27 validation tests + 13 plan tests
  - Backup module: 20 validation tests
  - Minio module: 23 validation tests + 12 plan tests
  - Monitoring-stack module: 30 validation tests
- Terraform drift detection script (`scripts/drift/check-drift.sh`) with Prometheus metrics and systemd timer
- Infrastructure health checks (`scripts/health/check-health.sh`) for VMs, monitoring endpoints, and Minio
- VM/LXC lifecycle management: snapshots, automatic expiration, security updates, SSH key rotation
  - `scripts/lifecycle/snapshot-vm.sh` - create/list/rollback/delete snapshots
  - `scripts/lifecycle/cleanup-snapshots.sh` - auto-cleanup expired snapshots
  - `scripts/lifecycle/expire-lab-vms.sh` - stop expired lab VMs
  - `scripts/lifecycle/rotate-ssh-keys.sh` - add/revoke SSH keys with anti-lockout
- `auto_security_updates` variable for VM and LXC modules (unattended-upgrades via cloud-init)
- `expiration_days` variable for VM and LXC modules (automatic `expires:YYYY-MM-DD` tag)
- 8 Prometheus alert rules: DriftDetected, DriftCheckFailed, DriftCheckStale, InfraHealthCheckFailed, HealthCheckStale, LabVMExpired, SnapshotOlderThanWeek, VMRebootRequired
- 4 systemd timers: drift check (06:00), health check (4h), snapshot cleanup (05:00), lab expiration (07:00)
- BATS tests for all new scripts (59 tests across drift, health, lifecycle)
- `terraform-test` CI job running all module tests in parallel matrix
- Documentation: DRIFT-DETECTION.md, HEALTH-CHECKS.md, VM-LIFECYCLE.md
- `scripts/README.md` master index for all script directories

### Changed
- Bumped Terraform version from 1.5.7 to 1.9.8 in CI workflows
- Added backup and minio modules to CI validate and docs matrices
- Updated root README with new features, expanded alerts table, testing section
- Updated infrastructure README with operations commands and documentation references

## [0.7.2] - 2026-02-01

### Fixed
- Minio container recreation on plan due to `mount_point.size` expecting string with unit suffix ("50G") not bare number
- Perpetual `terraform plan` drift on tags by sorting and deduplicating all tag concatenations to match Proxmox server-side behavior

## [0.7.1] - 2026-02-01

### Changed
- Tighten Proxmox provider constraint from `~> 0.50` to `~> 0.93` across all environments
- Remove version-pinned `required_providers` from child modules (source-only, version delegated to root)
- Extract VM and LXC module variables/outputs into dedicated files for consistent structure
- Switch Checkov CI scanner to hard fail mode
- Remove weak `"admin"` default for `grafana_admin_password` (now required)

### Added
- Input validations for VM module: template_id, cpu_cores, memory_mb, disk_size_gb, ip_address CIDR format
- Input validations for LXC module: os_type enum, cpu_cores, memory_mb, swap_mb, disk_size_gb, ip_address CIDR
- Input validations for Minio module: container_id, cpu_cores, memory_mb, disk sizes, ip_address CIDR, port ranges
- Input validations for monitoring-stack module: template_id, vm_config ranges, ip_address, network_cidr, retention
- Input validations for backup module: storage_id non-empty, schedule format, retention non-negative
- Validation `vm_template_id >= 100` to all environment variables
- Missing lock file for lab environment

### Removed
- Unused `proxmox_api_token` and `proxmox_insecure` variables from backup module
- Empty placeholder `outputs.tf` from Minio module
- Orphaned lock file from monitoring-stack child module

### Fixed
- Lock file provider constraints synced from `~> 0.50` to `~> 0.93`
- Minio `container_id` validation handles nullable values correctly

## [0.7.0] - 2026-02-01

### Added
- Minio S3 module for Terraform state backend with versioning and bucket management
- Backup module for automated vzdump scheduling with configurable retention per environment
- Backup alerting rules for Prometheus (BackupJobFailed, BackupJobMissing, BackupStorageAlmostFull)
- Backup Overview Grafana dashboard with vzdump supervision metrics
- Restore scripts: `restore-vm.sh`, `restore-tfstate.sh`, `rebuild-minio.sh`, `rebuild-monitoring.sh`, `verify-backups.sh`
- Shared shell library (`scripts/lib/common.sh`) with logging, SSH helpers, input validation, and dry-run support
- Disaster Recovery runbook (`docs/DISASTER-RECOVERY.md`) with 5-step rebuild procedure
- Comprehensive test suite (162 bats tests) covering all restore scripts and common library
- Backup & Restore documentation (`docs/BACKUP-RESTORE.md`) with automated script references
- README sections for backup architecture, monitoring stack, Grafana dashboards, Terraform modules, and restore scripts

### Changed
- Monitoring-stack module: added `backup_alerting_enabled` variable and backup alert rules
- Monitoring-stack module: Grafana provisioning includes Backup Overview dashboard
- Test fixture for Minio module uses sensitive variable instead of hardcoded password

### Fixed
- Backup module retention format using `--prune-backups` with proper keep-daily/keep-weekly syntax
- Backup module notification mode validation (auto, legacy-sendmail, notification-system)
- Minio module provisioner script execution (single inline script instead of split lines)
- Nodes Overview and Backup Overview Grafana dashboard template variables

## [0.6.0] - 2026-01-31

### Added
- Checkov policy-as-code scanning with SARIF upload to GitHub Security tab
- Trivy IaC misconfiguration scanning with SARIF upload to GitHub Security tab
- SARIF upload for tfsec results to GitHub Security tab
- CODEOWNERS file for automated PR review assignments
- terraform-docs validation job in CI pipeline (matrix over all modules)
- Auto-generated README.md with terraform-docs for vm, lxc, and monitoring-stack modules
- Grafana dashboards documentation section in project README

### Changed
- Hardened tfsec to hard-fail on findings (previously soft-fail)
- Hardened Gitleaks to hard-fail on detected secrets
- Pinned Trivy action to @0.33.1 and Terraform to 1.5.7 for reproducibility
- Added `permissions`, `concurrency` control, and `timeout-minutes` to all CI/CD jobs
- Updated project README security section to reflect all 4 CI scan tools

### Fixed
- Node Exporter dashboard template variables (`job` query using correct metric)
- Monitoring job name in Prometheus scrape config
- Nodes overview dashboard default job variable set to All

## [0.5.0] - 2026-01-31

### Added
- Node Exporter container in monitoring VM Docker Compose for host-level metrics (CPU, RAM, disk, network)
- Auto-provisioned Grafana dashboards: Node Exporter, PVE Exporter, Prometheus self-monitoring
- Per-node PVE exporter credentials (`token_value` per `proxmox_nodes` entry) for multi-PVE isolation
- Firewall rule for port 9100 (Node Exporter) on monitoring VM
- `install-node-exporter.sh` documentation in infrastructure README
- Terraform provider lock file (`.terraform.lock.hcl`)

### Changed
- PVE exporter configuration generates one module per Proxmox node instead of a single `default` module
- `pve_exporter_token_value` removed as standalone variable, now embedded in `proxmox_nodes`
- Prometheus scrape config uses `node.name` as pve-exporter module parameter

### Fixed
- PVE exporter crash-loop: mount `pve.yml` config with API credentials, use Docker service name for scrape target
- Alert rules never loaded when Telegram notifications disabled (`rule_files` was inside conditional block)
- PVE dashboard PromQL queries rewritten to match actual pve-exporter metric labels
- Proxmox templates (cloud-init images) excluded from VM counts in dashboards

## [0.4.0] - 2026-01-31

### Added
- Per-VM firewall rules via Terraform for monitoring and prod environments
- Firewall enabled on VM network devices (`firewall = true`) in vm and monitoring-stack modules
- Monitoring VM: allow SSH, Grafana (3000), Prometheus (9090), Alertmanager (9093), PVE Exporter (9221), ICMP
- Prod VMs: allow SSH, HTTP (80), HTTPS (443), Node Exporter (9100), ICMP
- Input policy set to DROP on all VMs for defense-in-depth

### Fixed
- Use `virtio-scsi-single` SCSI controller to enable iothread on disks

## [0.3.0] - 2026-01-31

### Added
- Multi-environment architecture: prod, lab, and dedicated monitoring environments
- Lab environment for test/development workloads
- Dedicated monitoring environment (no workloads, monitoring stack only)
- `remote_scrape_targets` variable in monitoring-stack module for cross-PVE scraping
- Shared templates (`_shared/backend.tf.example`, `_shared/provider.tf.example`)
- Reference `versions.tf` at infrastructure root level
- CI matrix strategy validating all modules and environments

### Changed
- Renamed environment `home` to `prod`
- Renamed Proxmox node hostnames: `pve` to `pve-prod`, `pve-lab`, `pve-mon`
- Consolidated all PVE instances to `192.168.1.0/24` network
- Extracted `provider.tf` and `versions.tf` per environment
- Monitoring stack moved from per-environment to dedicated monitoring environment
- Updated all documentation with 3-environment architecture

### Removed
- Root-level `main.tf` and `variables.tf` (replaced by per-environment configs)
- Monitoring configuration from prod/lab environments
- `home` and `office` environment directories (replaced by `prod` and `lab`)

## [0.2.0] - 2026-01-31

### Added
- Monitoring stack module (Prometheus, Grafana, Alertmanager, PVE Exporter)
- Post-installation script for Proxmox VE with automated setup
- fail2ban configuration for SSH and Proxmox web UI protection
- `--reset-tokens` option to recreate lost API tokens
- Firewall configuration documentation (datacenter + node levels)

### Changed
- Monitoring network IP addressing: dedicated PVE node at .50, VMs from .51+

### Fixed
- Reboot moved to end of post-install script to avoid interrupting setup
- Token capture improved in post-install script

## [0.1.0] - 2025-01-01

### Added
- Initial Terraform infrastructure with bpg/proxmox provider
- VM module with cloud-init and Docker support
- LXC container module with nesting support
- Environment-based configuration (home)
- Installation guide for Proxmox VE on Intel NUC
