# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.10.0] - 2026-02-05

### Added
- **Firewall rules for monitoring exporters** on prod VMs
  - cAdvisor (9080), Nginx Exporter (9113), Blackbox Exporter (9115)
  - PostgreSQL Exporter (9187), Process Exporter (9256)

### Fixed
- **Memory ballooning** disabled (`floating = 0`) in vm and monitoring-stack modules to prevent Proxmox reporting inflated memory usage (100% instead of actual ~22%)
- **Node Exporter dashboard** uses `MemAvailable` instead of `MemFree` for accurate memory usage (was counting cache as used)

### Changed
- **README** updated with accurate test counts (422 Terraform, 867 BATS), 14 Grafana dashboards (added tooling folder), 53 Prometheus alerts (added 25 tooling alerts), missing documentation links, tooling scripts section, and updated project structure

## [1.9.0] - 2026-02-05

### Added
- **ARCHITECTURE.md** documentation with 3 Mermaid diagrams (high-level, module flow, CI pipeline)
- **CONTRIBUTING.md** guide with project structure, testing, conventions, and contribution workflow
- **19 BATS error-path tests** for check-health, restore-vm, and verify-backups scripts
- **11 Terraform tests** for monitoring-stack (traefik and alertmanager configurations)
- **tooling-stack module** added to all 3 CI matrices (validate, test, docs)

### Changed
- **Cross-reference comments** added between vm/monitoring-stack (Docker install) and vm/lxc (expiration tag) modules

## [1.8.0] - 2026-02-05

### Changed
- **Monitoring-stack module** split `main.tf` (411 lines) into 6 focused files
  - `prometheus.tf`: Scrape targets, PVE exporter, Prometheus config
  - `grafana.tf`: Dashboard locals, datasource configurations
  - `alertmanager.tf`: Alertmanager config, tooling alerts
  - `traefik.tf`: Reverse proxy static and dynamic config
  - `loki.tf`: Log aggregation and Promtail config
  - `main.tf`: VM resource, cloud-init, Docker setup (316 lines)
- **Shared variables** centralized via symlinks (`shared/env_variables.tf`)
- **Inline scripts** extracted to `.sh.tpl` template files for testability
- **CI BATS tests** expanded from 37 to 395 tests (explicit directory listing)

### Fixed
- **test_common.bats** hardcoded absolute path replaced with relative path
- **CI** BATS step now runs all CI-compatible test directories (excludes TUI/drift requiring external deps)

### Added
- **Mermaid architecture diagram** in README for project visualization
- **55 BATS tests** converted from skipped to passing static analysis tests (0 skips remaining)

## [1.7.3] - 2026-02-05

### Fixed
- **verify-backups.sh** node detection now uses correct tfvars key (`default_node`)
- **verify-backups.sh** gracefully skips vzdump/full verifications when node is not available
- **get_pve_node()** in common.sh now tries both `default_node` and `pve_node` for compatibility

## [1.7.2] - 2026-02-05

### Fixed
- **verify-backups.sh** now gracefully skips Minio verification when `mc` is not installed (instead of failing)

## [1.7.1] - 2026-02-05

### Fixed
- **README** corrected TUI usage examples (removed non-existent CLI subcommands)

## [1.7.0] - 2026-02-05

### Added
- **TUI Homelab Manager** complete implementation (11 modules, 439 tests)
  - `scripts/homelab` as new entry point
  - Status & Health monitoring with drill-down
  - Terraform Plan/Apply/Output integration
  - Snapshots management (create/list/restore/delete)
  - Drift detection with colored status
  - Disaster Recovery (VM restore, tfstate restore)
  - Services management (Harbor, Monitoring stack)
  - Configuration preferences (SSH, display, logging)
- **Health check enhancements**
  - Display VM names instead of IPs using tfvars parsing
  - Add monitoring VM to health checks
  - Dynamic environment listing from tfvars files
- **Documentation reference** for Claude Code integration
  - `docs/reference/` with commands, agents, skills catalogs

### Changed
- **Scripts reorganization** for cleaner structure
  - `scripts/tui/` → `scripts/lib/tui/` (library files)
  - `scripts/tui/menus/` → `scripts/menus/` (menu modules)
  - `scripts/tui/tui.sh` → `scripts/homelab` (entry point)
  - Renamed `tui-*.sh` to simpler names (e.g., `tui-colors.sh` → `colors.sh`)
- **TUI display improvements**
  - Added `clear` between menu transitions
  - Changed muted text (gray) to white for better visibility
  - Removed excessive blank lines in menus
  - Reduced `tui_banner` margins for compact display

### Fixed
- **Drift detection** no longer hangs on environments without tfvars
- **Drift summary** now correctly shows drift status (was always showing "Conforme")
- **Health check parsing** handles VM names with dots and numbers
- **Keyboard navigation** arrays initialized for `nounset` compatibility
- **Path resolution** issues in TUI library loading

## [1.6.1] - 2026-02-05

### Added
- **Security functions** in `scripts/lib/common.sh`
  - `log_secret()` : Masks secrets (tokens, UUIDs, passwords, base64) in log output
  - `log_info_secure()` : Alias for secure logging operations
- **HCL parsing functions** to reduce code duplication
  - `parse_hcl_block()` : Generic HCL block parser
  - `parse_hcl_block_first()` : Returns first match only
  - `parse_hcl_block_unique()` : Returns unique sorted values
  - `validate_choice()` : Validates value against allowed options
- **Traefik security headers** in monitoring-stack and tooling-stack
  - Content-Security-Policy (CSP)
  - HSTS with preload
  - X-Frame-Options, X-Content-Type-Options

### Changed
- Proxmox provider version constraint synchronized to `~> 0.94` across all environments
- Step-ca Docker image pinned to version `0.27.5` (was `latest`)
- `terraform.tfvars.example` uses placeholder `${GRAFANA_ADMIN_PASSWORD:?required}` instead of weak example password

### Security
- Fixed weak example password in monitoring terraform.tfvars.example
- Added CSP headers to prevent XSS attacks
- Pinned Docker images to avoid supply chain attacks

## [1.6.0] - 2026-02-05

### Added
- **Tooling Stack module** (`modules/tooling-stack/`) for internal homelab services
  - **Step-ca PKI** : Internal Certificate Authority with ACME support
    - Root CA generation via Terraform TLS provider
    - Traefik ACME integration for automatic certificates
    - Configurable cert duration and provisioner name
  - **Harbor Registry** : Private Docker registry with Trivy vulnerability scanning
    - GC garbage collection script (`scripts/tooling/harbor-gc.sh`)
    - Configurable admin password and Trivy toggle
  - **Authentik SSO** : Centralized authentication (SSO)
    - Bootstrap password and secret key configuration
    - Prepared for Grafana/Harbor OIDC integration
  - **Traefik** : Reverse proxy with automatic TLS via Step-ca ACME
    - Dynamic routing for pki/registry/auth.home.arpa
- **Conditional service enablement** with master switch and individual toggles
  - `tooling.enabled` : Master switch for entire stack
  - `tooling.step_ca.enabled`, `tooling.harbor.enabled`, `tooling.authentik.enabled` : Per-service toggles
- **Monitoring integration** for tooling stack
  - 3 Grafana dashboards (Step-ca, Harbor, Authentik) in "Tooling" folder
  - 10 Prometheus alerts for tooling services (`tooling.yml`)
  - Scrape configuration template (`scrape/tooling.yml.tpl`)
  - Variables `tooling_*` in monitoring-stack module
- **Dynamic firewall rules** based on enabled services (SSH, HTTP/S, per-service ports)
- **Rebuild script** `scripts/restore/rebuild-tooling.sh` with check/init/plan/apply/status commands
- **138 Terraform tests** for tooling-stack module (validation, plan, regression)
- **14 Terraform tests** for tooling integration in monitoring-stack module
- **Documentation** `docs/TOOLING-STACK.md` (~380 lines) covering deployment, services, monitoring, backup

### Changed
- README.md updated with tooling stack section, module reference, and features
- Project structure updated to include tooling-stack module
- Test count updated from ~270 to ~495 Terraform tests (6 modules)
- terraform.tfvars.example includes complete tooling configuration

## [1.5.0] - 2026-02-04

### Changed
- **Docker Containers dashboard** enhanced with new features
  - Added **Top Consumers** section with horizontal bar gauges for CPU and Memory
  - Added **Avg Memory % of Limit** stat in Overview section
  - Enhanced **All Containers** table:
    - New Memory % column with color thresholds (green/orange/red)
    - New Uptime column showing container uptime
    - Conditional coloring for CPU % and Mem % columns
  - Changed CPU rate window from 1m to 5m for more reliable metrics
  - Cleaned up table to show only essential columns (removed redundant labels)

## [1.4.0] - 2026-02-04

### Added
- **Observability tools** for monitoring-stack module
  - **Traefik** reverse proxy with optional TLS support
  - **Loki** log aggregation with Promtail
  - **Uptime Kuma** availability monitoring
- **Custom Prometheus scrape configs** (`custom_scrape_configs` variable)
  - Support for relabel_configs, metric_relabel_configs
  - Blackbox exporter HTTP probes configuration
  - Advanced scrape parameters (metrics_path, params)
- **Application monitoring dashboards**
  - `application-overview`: Main dashboard with health summary and drill-down links
  - `http-probes`: Blackbox exporter metrics (latency, SSL, success rate)
  - `postgresql`: Database metrics (connections, transactions, cache hit ratio)
  - `docker-containers`: cAdvisor metrics (CPU, memory, network, disk I/O)
- **Grafana folder organization** for better dashboard navigation
  - Infrastructure: nodes-overview, node-exporter, pve-exporter, prometheus
  - Observability: alerting-overview, backup-overview, logs-overview
  - Applications: application-overview, http-probes, postgresql, docker-containers

### Changed
- Dashboard provisioning now uses multiple providers for folder organization

## [1.3.0] - 2026-02-03

### Added
- **SSH security hardening** with dedicated known_hosts file
  - New `HOMELAB_KNOWN_HOSTS` file at `~/.ssh/homelab_known_hosts`
  - `init_known_hosts()` function for first-time setup with `ssh-keyscan`
  - `is_host_known()` validation before SSH connections
  - `get_ssh_opts()` centralized SSH options with `StrictHostKeyChecking=yes`
  - All scripts updated to use secure SSH pattern (deploy, health-check, rebuild-monitoring, rotate-ssh-keys)
- **Prometheus recording rules** (`prometheus/recording/aggregations.yml`)
  - CPU, RAM, disk, network aggregations for improved query performance
  - Proxmox-specific aggregations (VM count, storage usage, uptime)
- **Test suite for lifecycle scripts** (59 new tests)
  - `test_cleanup_snapshots.bats`: 27 tests covering date parsing, JSON handling, dry-run mode
  - `test_expire_lab.bats`: 32 tests covering tag parsing, expiration logic, security
- **Test suite for post-install-proxmox.sh** (55 new tests)
  - Coverage for CLI options, PVE version detection, token security
  - Validation of fail2ban config, Terraform roles, VM template creation
- **14 new tests for SSH security** in `test_common.bats`

### Changed
- **Token security**: tokens saved to secure files (`/root/.pve-tokens/`) instead of logging in plaintext
  - Terraform token: `~/.pve-tokens/terraform.token` (chmod 600)
  - Prometheus token: `~/.pve-tokens/prometheus.token` (chmod 600)
  - Token directory created with chmod 700

### Security
- SSH connections now use `StrictHostKeyChecking=yes` (was `accept-new`)
- Dedicated known_hosts file prevents host key pollution
- API tokens no longer exposed in logs

### Dependencies
- Bumped `bpg/proxmox` from 0.93 to **0.94**
- Bumped `prom/prometheus` from v2.50.1 to **v3.5.1**
- Bumped `grafana/grafana` from 11.0.0 to **12.1.1**
- Bumped `prom/alertmanager` from v0.27.0 to **v0.30.1**
- Bumped `prom/node-exporter` from v1.8.2 to **v1.10.2**

## [1.2.0] - 2026-02-03

### Added
- **Alerting Overview Grafana dashboard** (`alerting-overview.json`)
  - Real-time alert counters by severity (Critical, Warning, Info)
  - Active alerts table with links to Prometheus
  - Collapsible sections: Distribution, Timeline, Alerts by Category, Meta-Monitoring
  - Top 10 most frequent alerts visualization
  - Alert duration tracking (longest, average)
  - Prometheus/Alertmanager health monitoring panels
  - Quick links to Prometheus, Alertmanager, and Silences
- Dashboard provisioning in monitoring-stack module (`main.tf`)

### Fixed
- ProxmoxNodeDown alert false positives on template VMs (`qemu/9000`)
  - Changed expression from `pve_up == 0` to `pve_up{id=~"node/.*"} == 0`

## [1.1.3] - 2026-02-03

### Added
- Telegram alerting configuration guide (`docs/ALERTING.md`)
  - Step-by-step bot creation with @BotFather
  - Chat ID retrieval for private chats and groups
  - Terraform configuration examples
  - Manual testing procedures (curl, Alertmanager API)
  - Troubleshooting section for common issues
  - Security best practices for bot tokens

### Changed
- README: add ALERTING.md to documentation table and project structure
- README: reference alerting guide in Monitoring & Alertes section

## [1.1.2] - 2026-02-03

### Added
- Troubleshooting documentation for Intel e1000e "Hardware Unit Hang" issue (`docs/troubleshooting/e1000e-hardware-hang.md`)
  - Diagnostic commands and symptom identification
  - 4 solutions ranked by priority (SmartPowerDownEnable, ring buffers, TSO/GSO, speed limit)
  - Recommended configuration for Intel I219-V/LM NICs

## [1.1.1] - 2026-02-02

### Changed
- README: complete Prometheus alerts table (11 → 28 alerts, organized by 7 groups)
- README: add resilience SSH feature (retry/backoff) to features list
- README: detail test coverage (3 test types per module, BATS breakdown by domain with counts)
- README: document SSH hardening and Minio credential security in security section

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

[1.10.0]: https://github.com/christopherlouet/pve-home/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/christopherlouet/pve-home/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/christopherlouet/pve-home/compare/v1.7.3...v1.8.0
[1.7.3]: https://github.com/christopherlouet/pve-home/compare/v1.7.2...v1.7.3
[1.7.2]: https://github.com/christopherlouet/pve-home/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/christopherlouet/pve-home/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/christopherlouet/pve-home/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/christopherlouet/pve-home/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/christopherlouet/pve-home/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/christopherlouet/pve-home/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/christopherlouet/pve-home/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/christopherlouet/pve-home/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/christopherlouet/pve-home/compare/v1.1.3...v1.2.0
[1.1.3]: https://github.com/christopherlouet/pve-home/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/christopherlouet/pve-home/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/christopherlouet/pve-home/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/christopherlouet/pve-home/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/christopherlouet/pve-home/compare/v0.9.1...v1.0.0
[0.9.1]: https://github.com/christopherlouet/pve-home/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/christopherlouet/pve-home/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/christopherlouet/pve-home/compare/v0.7.2...v0.8.0
[0.7.2]: https://github.com/christopherlouet/pve-home/compare/v0.7.1...v0.7.2
[0.7.1]: https://github.com/christopherlouet/pve-home/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/christopherlouet/pve-home/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/christopherlouet/pve-home/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/christopherlouet/pve-home/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/christopherlouet/pve-home/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/christopherlouet/pve-home/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/christopherlouet/pve-home/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/christopherlouet/pve-home/releases/tag/v0.1.0
