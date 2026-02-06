# =============================================================================
# Module Monitoring Stack - Main
# =============================================================================
# Deploie une VM avec la stack de monitoring complete:
# - Prometheus (collecte metriques)       → prometheus.tf
# - Grafana (visualisation)               → grafana.tf
# - Alertmanager (alertes Telegram)       → alertmanager.tf
# - PVE Exporter (metriques Proxmox)      → prometheus.tf
# - Traefik (reverse proxy) - optionnel   → traefik.tf
# - Loki (centralisation logs) - optionnel → loki.tf
# - Uptime Kuma (surveillance disponibilite) - optionnel
# =============================================================================

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  vm_name = var.name

  # Configuration Docker Compose
  docker_compose_content = templatefile("${path.module}/files/docker-compose.yml.tpl", {
    grafana_admin_password = var.grafana_admin_password
    monitoring_ip          = var.ip_address
    telegram_enabled       = var.telegram_enabled
    retention_days         = var.prometheus_retention_days
    retention_size         = var.prometheus_retention_size
    # Traefik
    traefik_enabled = var.traefik_enabled
    domain_suffix   = var.domain_suffix
    tls_enabled     = var.tls_enabled
    # Loki
    loki_enabled = var.loki_enabled
    # Uptime Kuma
    uptime_kuma_enabled = var.uptime_kuma_enabled
  })

  # Script de setup monitoring (extrait dans fichier template pour testabilite)
  monitoring_setup_script = templatefile("${path.module}/files/setup-monitoring.sh.tpl", {
    tooling_enabled         = var.tooling_enabled
    traefik_enabled         = var.traefik_enabled
    tls_enabled             = var.tls_enabled
    loki_enabled            = var.loki_enabled
    ip_address              = var.ip_address
    domain_suffix           = var.domain_suffix
    docker_compose_content  = local.docker_compose_content
    prometheus_config       = local.prometheus_config
    alertmanager_config     = local.alertmanager_config
    traefik_static_config   = local.traefik_static_config
    traefik_dynamic_config  = local.traefik_dynamic_config
    loki_config             = local.loki_config
    promtail_config         = local.promtail_config
    grafana_datasource_loki = local.grafana_datasource_loki
    dashboard_logs_overview = local.dashboard_logs_overview
  })

  # Packages necessaires
  packages = ["qemu-guest-agent", "ca-certificates", "curl", "gnupg"]

  # Docker install commands shared with vm module (see shared/docker-install-runcmd.json.tpl)
  docker_install_runcmd = jsondecode(templatefile("${path.module}/../../shared/docker-install-runcmd.json.tpl", {
    username = var.username
  }))

  cloud_config = {
    users = [
      {
        name = var.username
        # SECURITY NOTE: NOPASSWD:ALL accepte pour homelab - restreindre en production
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        shell               = "/bin/bash"
        ssh_authorized_keys = var.ssh_keys
      }
    ]
    package_update  = true
    package_upgrade = false
    packages        = local.packages
    write_files = concat(
      [
        {
          path        = "/opt/setup-monitoring.sh"
          permissions = "0755"
          content     = local.monitoring_setup_script
        },
        # Infrastructure dashboards
        {
          path        = "/opt/monitoring/grafana/dashboards/infrastructure/node-exporter.json"
          permissions = "0644"
          content     = local.dashboard_node_exporter
        },
        {
          path        = "/opt/monitoring/grafana/dashboards/infrastructure/pve-exporter.json"
          permissions = "0644"
          content     = local.dashboard_pve_exporter
        },
        {
          path        = "/opt/monitoring/grafana/dashboards/infrastructure/prometheus.json"
          permissions = "0644"
          content     = local.dashboard_prometheus
        },
        {
          path        = "/opt/monitoring/grafana/dashboards/infrastructure/nodes-overview.json"
          permissions = "0644"
          content     = local.dashboard_nodes_overview
        },
        # Observability dashboards
        {
          path        = "/opt/monitoring/grafana/dashboards/observability/backup-overview.json"
          permissions = "0644"
          content     = local.dashboard_backup_overview
        },
        {
          path        = "/opt/monitoring/grafana/dashboards/observability/alerting-overview.json"
          permissions = "0644"
          content     = local.dashboard_alerting_overview
        },
        # Applications dashboards
        {
          path        = "/opt/monitoring/grafana/dashboards/applications/application-overview.json"
          permissions = "0644"
          content     = local.dashboard_application_overview
        },
        {
          path        = "/opt/monitoring/grafana/dashboards/applications/http-probes.json"
          permissions = "0644"
          content     = local.dashboard_http_probes
        },
        {
          path        = "/opt/monitoring/grafana/dashboards/applications/postgresql.json"
          permissions = "0644"
          content     = local.dashboard_postgresql
        },
        {
          path        = "/opt/monitoring/grafana/dashboards/applications/docker-containers.json"
          permissions = "0644"
          content     = local.dashboard_docker_containers
        },
        {
          path        = "/opt/monitoring/prometheus/alerts/default.yml"
          permissions = "0644"
          content     = file("${path.module}/files/prometheus/alerts/default.yml")
        },
        {
          path        = "/opt/monitoring/prometheus/recording/aggregations.yml"
          permissions = "0644"
          content     = file("${path.module}/files/prometheus/recording/aggregations.yml")
        },
        {
          path        = "/opt/monitoring/pve-exporter/pve.yml"
          permissions = "0644"
          content     = local.pve_exporter_config
        },
        # SECURITY NOTE: Cle privee deployee via cloud-init et stockee dans le Terraform state.
        # Acceptable pour homelab - en production, generer les cles en dehors de Terraform.
        {
          path        = "/root/.ssh/id_ed25519"
          permissions = "0600"
          owner       = "root:root"
          content     = tls_private_key.health_check.private_key_openssh
        }
      ],
      # Tooling dashboards (conditionally included)
      var.tooling_enabled && var.tooling_step_ca_enabled ? [
        {
          path        = "/opt/monitoring/grafana/dashboards/tooling/step-ca.json"
          permissions = "0644"
          content     = local.dashboard_step_ca
        }
      ] : [],
      var.tooling_enabled && var.tooling_harbor_enabled ? [
        {
          path        = "/opt/monitoring/grafana/dashboards/tooling/harbor.json"
          permissions = "0644"
          content     = local.dashboard_harbor
        }
      ] : [],
      var.tooling_enabled && var.tooling_authentik_enabled ? [
        {
          path        = "/opt/monitoring/grafana/dashboards/tooling/authentik.json"
          permissions = "0644"
          content     = local.dashboard_authentik
        }
      ] : [],
      # Tooling alerts
      var.tooling_enabled ? [
        {
          path        = "/opt/monitoring/prometheus/alerts/tooling.yml"
          permissions = "0644"
          content     = local.tooling_alerts
        }
      ] : []
    )
    runcmd = concat(
      local.docker_install_runcmd,
      ["systemctl enable --now qemu-guest-agent"],
      ["/opt/setup-monitoring.sh"]
    )
  }
}

# -----------------------------------------------------------------------------
# SSH keypair for health checks (monitoring -> other VMs)
# -----------------------------------------------------------------------------

resource "tls_private_key" "health_check" {
  algorithm = "ED25519"
}

# -----------------------------------------------------------------------------
# Cloud-init file
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.target_node

  source_raw {
    data      = "#cloud-config\n${yamlencode(local.cloud_config)}"
    file_name = "${local.vm_name}-cloud-config.yaml"
  }
}

# -----------------------------------------------------------------------------
# VM Monitoring
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "monitoring" {
  name          = local.vm_name
  description   = "Stack Monitoring - Prometheus/Grafana/Alertmanager"
  tags          = var.tags
  node_name     = var.target_node
  on_boot       = true
  started       = true
  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = var.vm_config.cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_config.memory
    floating  = 0
  }

  # Disque systeme
  disk {
    datastore_id = var.datastore
    size         = var.vm_config.disk
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  # Disque donnees (metrics Prometheus)
  disk {
    datastore_id = var.datastore
    size         = var.vm_config.data_disk
    interface    = "scsi1"
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = true
  }

  agent {
    enabled = true
    timeout = "2m"
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id

    ip_config {
      ipv4 {
        address = "${var.ip_address}/${var.network_cidr}"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.username
      keys     = var.ssh_keys
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      initialization,
      disk[0].size,
      disk[1].size,
    ]
  }
}
