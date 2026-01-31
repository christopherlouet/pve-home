# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
