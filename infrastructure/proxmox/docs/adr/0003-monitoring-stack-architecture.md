# ADR-0003: Monitoring Stack as Single VM with Docker Compose

## Status: Accepted

## Context

The homelab needs monitoring (metrics, dashboards, alerts, logs). We must decide how to deploy and manage the monitoring services (Prometheus, Grafana, Alertmanager, Loki, Traefik).

## Decision

Deploy all monitoring services on a **single VM** using **Docker Compose**, provisioned via cloud-init. The Terraform module generates all configuration files (prometheus.yml, docker-compose.yml, Grafana dashboards) from variables.

## Rationale

- **Single VM simplicity**: One VM to manage, backup, and restore for all monitoring
- **Docker Compose**: Declarative service management, easy to update, well-understood
- **Terraform-generated configs**: Prometheus scrape targets, Grafana dashboards, and alert rules are generated from Terraform variables, ensuring consistency with the infrastructure being monitored
- **Module split**: Complex configuration is split across `prometheus.tf`, `grafana.tf`, `alertmanager.tf`, `loki.tf`, `traefik.tf` for maintainability

## Alternatives Considered

- **Separate VMs per service**: Rejected as overkill for homelab; adds complexity without proportional benefit
- **LXC containers**: Rejected because Docker Compose simplifies multi-service orchestration
- **Kubernetes**: Rejected; too complex for a homelab monitoring setup

## Consequences

- monitoring-stack module is the most complex module (~310 lines in main.tf)
- All monitoring services share the same VM resources (CPU, memory, disk)
- Traefik provides reverse proxy with domain-based routing for all services
- Conditional features (Loki, Uptime Kuma, tooling integration) increase template complexity
