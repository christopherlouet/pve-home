# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
