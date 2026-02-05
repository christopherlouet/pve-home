# =============================================================================
# Module Monitoring Stack - Main
# =============================================================================
# Deploie une VM avec la stack de monitoring complete:
# - Prometheus (collecte metriques)
# - Grafana (visualisation)
# - Alertmanager (alertes Telegram)
# - PVE Exporter (metriques Proxmox)
# - Traefik (reverse proxy) - optionnel
# - Loki (centralisation logs) - optionnel
# - Uptime Kuma (surveillance disponibilite) - optionnel
# =============================================================================

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  vm_name = var.name

  # Node exporter targets: tous les nodes Proxmox
  node_exporter_targets = [
    for node in var.proxmox_nodes : {
      name = node.name
      ip   = node.ip
      port = 9100
    }
  ]

  # Combiner avec les targets additionnels (locaux + distants)
  all_scrape_targets = concat(local.node_exporter_targets, var.additional_scrape_targets, var.remote_scrape_targets)

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

  # Configuration Traefik (static)
  traefik_static_config = var.traefik_enabled ? templatefile("${path.module}/files/traefik/traefik.yml.tpl", {
    tls_enabled = var.tls_enabled
  }) : ""

  # Configuration Traefik (dynamic routes)
  traefik_dynamic_config = var.traefik_enabled ? templatefile("${path.module}/files/traefik/dynamic.yml.tpl", {
    domain_suffix        = var.domain_suffix
    tls_enabled          = var.tls_enabled
    alertmanager_enabled = var.telegram_enabled
    loki_enabled         = var.loki_enabled
    uptime_kuma_enabled  = var.uptime_kuma_enabled
  }) : ""

  # Configuration Loki
  loki_config = var.loki_enabled ? file("${path.module}/files/loki/loki-config.yml") : ""

  # Configuration Promtail (local)
  promtail_config = var.loki_enabled ? templatefile("${path.module}/files/promtail/promtail-config.yml.tpl", {
    hostname = local.vm_name
  }) : ""

  # Datasource Loki pour Grafana
  grafana_datasource_loki = var.loki_enabled ? file("${path.module}/files/grafana/provisioning/datasources/loki.yml") : ""

  # Dashboard Logs Overview
  dashboard_logs_overview = var.loki_enabled ? file("${path.module}/files/grafana/dashboards/logs-overview.json") : ""

  # Configuration PVE Exporter (un module par node)
  pve_exporter_config = yamlencode({
    for node in var.proxmox_nodes : node.name => {
      user        = var.pve_exporter_user
      token_name  = var.pve_exporter_token_name
      token_value = node.token_value
      verify_ssl  = false
    }
  })

  # Configuration Prometheus
  prometheus_config = templatefile("${path.module}/files/prometheus.yml.tpl", {
    proxmox_nodes         = var.proxmox_nodes
    scrape_targets        = local.all_scrape_targets
    monitoring_ip         = var.ip_address
    alertmanager_enabled  = var.telegram_enabled
    custom_scrape_configs = var.custom_scrape_configs != "" ? indent(2, var.custom_scrape_configs) : ""
  })

  # Dashboards Grafana
  dashboard_node_exporter        = file("${path.module}/files/grafana/dashboards/node-exporter.json")
  dashboard_pve_exporter         = file("${path.module}/files/grafana/dashboards/pve-exporter.json")
  dashboard_prometheus           = file("${path.module}/files/grafana/dashboards/prometheus.json")
  dashboard_nodes_overview       = file("${path.module}/files/grafana/dashboards/nodes-overview.json")
  dashboard_backup_overview      = file("${path.module}/files/grafana/dashboards/backup-overview.json")
  dashboard_alerting_overview    = file("${path.module}/files/grafana/dashboards/alerting-overview.json")
  dashboard_application_overview = file("${path.module}/files/grafana/dashboards/application-overview.json")
  dashboard_http_probes          = file("${path.module}/files/grafana/dashboards/http-probes.json")
  dashboard_postgresql           = file("${path.module}/files/grafana/dashboards/postgresql.json")
  dashboard_docker_containers    = file("${path.module}/files/grafana/dashboards/docker-containers.json")

  # Tooling Dashboards (Step-ca, Harbor, Authentik)
  dashboard_step_ca   = var.tooling_enabled && var.tooling_step_ca_enabled ? file("${path.module}/files/grafana/dashboards/tooling/step-ca.json") : ""
  dashboard_harbor    = var.tooling_enabled && var.tooling_harbor_enabled ? file("${path.module}/files/grafana/dashboards/tooling/harbor.json") : ""
  dashboard_authentik = var.tooling_enabled && var.tooling_authentik_enabled ? file("${path.module}/files/grafana/dashboards/tooling/authentik.json") : ""

  # Tooling Alerts
  tooling_alerts = var.tooling_enabled ? file("${path.module}/files/prometheus/alerts/tooling.yml") : ""

  # Tooling Scrape Config
  tooling_scrape_config = var.tooling_enabled && var.tooling_ip != "" ? templatefile("${path.module}/files/prometheus/scrape/tooling.yml.tpl", {
    tooling_ip         = var.tooling_ip
    step_ca_enabled    = var.tooling_step_ca_enabled
    harbor_enabled     = var.tooling_harbor_enabled
    authentik_enabled  = var.tooling_authentik_enabled
    traefik_enabled    = var.tooling_traefik_enabled
  }) : ""

  # Configuration Alertmanager
  alertmanager_config = templatefile("${path.module}/files/alertmanager.yml.tpl", {
    telegram_enabled   = var.telegram_enabled
    telegram_bot_token = var.telegram_bot_token
    telegram_chat_id   = var.telegram_chat_id
  })

  # Script de setup monitoring
  monitoring_setup_script = <<-EOT
#!/bin/bash
set -e

echo "=== Configuration Stack Monitoring ==="

# Creer les repertoires
mkdir -p /opt/monitoring/{prometheus,alertmanager,grafana/provisioning/{datasources,dashboards},grafana/dashboards/{infrastructure,observability,applications},pve-exporter}
mkdir -p /opt/monitoring/prometheus/data
mkdir -p /opt/monitoring/grafana/data
%{if var.tooling_enabled}
mkdir -p /opt/monitoring/grafana/dashboards/tooling
%{endif}
%{if var.traefik_enabled}
mkdir -p /opt/monitoring/traefik
%{if var.tls_enabled}
mkdir -p /opt/monitoring/traefik/certs
%{endif}
%{endif}
%{if var.loki_enabled}
mkdir -p /opt/monitoring/loki/{chunks,rules,wal,compactor}
mkdir -p /opt/monitoring/promtail
%{endif}

# Permissions pour Prometheus (user 65534 = nobody)
chown -R 65534:65534 /opt/monitoring/prometheus/data

# Permissions pour Grafana (user 472)
chown -R 472:472 /opt/monitoring/grafana/data
chown -R 472:472 /opt/monitoring/grafana/dashboards

%{if var.loki_enabled}
# Permissions pour Loki (user 10001)
chown -R 10001:10001 /opt/monitoring/loki
%{endif}

# Docker Compose
cat > /opt/monitoring/docker-compose.yml << 'COMPOSE'
${local.docker_compose_content}
COMPOSE

# Prometheus config
cat > /opt/monitoring/prometheus/prometheus.yml << 'PROMCONFIG'
${local.prometheus_config}
PROMCONFIG

# Alertmanager config
cat > /opt/monitoring/alertmanager/alertmanager.yml << 'ALERTCONFIG'
${local.alertmanager_config}
ALERTCONFIG

%{if var.traefik_enabled}
# Traefik static config
cat > /opt/monitoring/traefik/traefik.yml << 'TRAEFIKSTATIC'
${local.traefik_static_config}
TRAEFIKSTATIC

# Traefik dynamic config
cat > /opt/monitoring/traefik/dynamic.yml << 'TRAEFIKDYNAMIC'
${local.traefik_dynamic_config}
TRAEFIKDYNAMIC
%{endif}

%{if var.loki_enabled}
# Loki config
cat > /opt/monitoring/loki/loki-config.yml << 'LOKICONFIG'
${local.loki_config}
LOKICONFIG

# Promtail config
cat > /opt/monitoring/promtail/promtail-config.yml << 'PROMTAILCONFIG'
${local.promtail_config}
PROMTAILCONFIG
%{endif}

# Grafana datasource provisioning
cat > /opt/monitoring/grafana/provisioning/datasources/prometheus.yml << 'DATASOURCE'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
DATASOURCE

%{if var.loki_enabled}
# Grafana datasource Loki
cat > /opt/monitoring/grafana/provisioning/datasources/loki.yml << 'LOKIDATASOURCE'
${local.grafana_datasource_loki}
LOKIDATASOURCE

# Dashboard Logs Overview (Observability folder)
cat > /opt/monitoring/grafana/dashboards/observability/logs-overview.json << 'LOGSDASHBOARD'
${local.dashboard_logs_overview}
LOGSDASHBOARD
%{endif}

# Grafana dashboard provisioning with folders
cat > /opt/monitoring/grafana/provisioning/dashboards/default.yml << 'DASHPROV'
apiVersion: 1
providers:
  - name: 'Infrastructure'
    orgId: 1
    folder: 'Infrastructure'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards/infrastructure
  - name: 'Observability'
    orgId: 1
    folder: 'Observability'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards/observability
  - name: 'Applications'
    orgId: 1
    folder: 'Applications'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards/applications
%{if var.tooling_enabled}
  - name: 'Tooling'
    orgId: 1
    folder: 'Tooling'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards/tooling
%{endif}
DASHPROV

# Demarrer la stack
cd /opt/monitoring
docker compose up -d

echo "=== Stack Monitoring deployee ==="
%{if var.traefik_enabled}
echo "Traefik Dashboard: http://traefik.${var.domain_suffix}"
echo "Grafana: http://grafana.${var.domain_suffix}"
echo "Prometheus: http://prometheus.${var.domain_suffix}"
echo "Alertmanager: http://alertmanager.${var.domain_suffix}"
echo ""
echo "Note: Configure DNS to resolve *.${var.domain_suffix} to ${var.ip_address}"
%{else}
echo "Prometheus: http://${var.ip_address}:9090"
echo "Grafana: http://${var.ip_address}:3000"
echo "Alertmanager: http://${var.ip_address}:9093"
%{endif}
EOT

  # Packages necessaires
  packages = ["qemu-guest-agent", "ca-certificates", "curl", "gnupg"]

  # Cloud-init runcmd
  docker_install_runcmd = [
    "install -m 0755 -d /etc/apt/keyrings",
    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
    "chmod a+r /etc/apt/keyrings/docker.asc",
    "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable\" > /etc/apt/sources.list.d/docker.list",
    "apt-get update",
    "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
    "systemctl enable --now docker",
    "usermod -aG docker ${var.username}",
    "systemctl enable --now qemu-guest-agent"
  ]

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
    ignore_changes = [
      initialization,
      disk[0].size,
      disk[1].size,
    ]
  }
}
