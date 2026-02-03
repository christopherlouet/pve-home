# =============================================================================
# Module Monitoring Stack - Main
# =============================================================================
# Deploie une VM avec la stack de monitoring complete:
# - Prometheus (collecte metriques)
# - Grafana (visualisation)
# - Alertmanager (alertes Telegram)
# - PVE Exporter (metriques Proxmox)
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
  })

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
    proxmox_nodes        = var.proxmox_nodes
    scrape_targets       = local.all_scrape_targets
    monitoring_ip        = var.ip_address
    alertmanager_enabled = var.telegram_enabled
  })

  # Dashboards Grafana
  dashboard_node_exporter     = file("${path.module}/files/grafana/dashboards/node-exporter.json")
  dashboard_pve_exporter      = file("${path.module}/files/grafana/dashboards/pve-exporter.json")
  dashboard_prometheus        = file("${path.module}/files/grafana/dashboards/prometheus.json")
  dashboard_nodes_overview    = file("${path.module}/files/grafana/dashboards/nodes-overview.json")
  dashboard_backup_overview   = file("${path.module}/files/grafana/dashboards/backup-overview.json")
  dashboard_alerting_overview = file("${path.module}/files/grafana/dashboards/alerting-overview.json")

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
mkdir -p /opt/monitoring/{prometheus,alertmanager,grafana/provisioning/{datasources,dashboards},grafana/dashboards,pve-exporter}
mkdir -p /opt/monitoring/prometheus/data
mkdir -p /opt/monitoring/grafana/data

# Permissions pour Prometheus (user 65534 = nobody)
chown -R 65534:65534 /opt/monitoring/prometheus/data

# Permissions pour Grafana (user 472)
chown -R 472:472 /opt/monitoring/grafana/data
chown -R 472:472 /opt/monitoring/grafana/dashboards

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

# Grafana dashboard provisioning
cat > /opt/monitoring/grafana/provisioning/dashboards/default.yml << 'DASHPROV'
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards
DASHPROV

# Demarrer la stack
cd /opt/monitoring
docker compose up -d

echo "=== Stack Monitoring deployee ==="
echo "Prometheus: http://${var.ip_address}:9090"
echo "Grafana: http://${var.ip_address}:3000"
echo "Alertmanager: http://${var.ip_address}:9093"
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
    write_files = [
      {
        path        = "/opt/setup-monitoring.sh"
        permissions = "0755"
        content     = local.monitoring_setup_script
      },
      {
        path        = "/opt/monitoring/grafana/dashboards/node-exporter.json"
        permissions = "0644"
        content     = local.dashboard_node_exporter
      },
      {
        path        = "/opt/monitoring/grafana/dashboards/pve-exporter.json"
        permissions = "0644"
        content     = local.dashboard_pve_exporter
      },
      {
        path        = "/opt/monitoring/grafana/dashboards/prometheus.json"
        permissions = "0644"
        content     = local.dashboard_prometheus
      },
      {
        path        = "/opt/monitoring/grafana/dashboards/nodes-overview.json"
        permissions = "0644"
        content     = local.dashboard_nodes_overview
      },
      {
        path        = "/opt/monitoring/grafana/dashboards/backup-overview.json"
        permissions = "0644"
        content     = local.dashboard_backup_overview
      },
      {
        path        = "/opt/monitoring/grafana/dashboards/alerting-overview.json"
        permissions = "0644"
        content     = local.dashboard_alerting_overview
      },
      {
        path        = "/opt/monitoring/prometheus/alerts/default.yml"
        permissions = "0644"
        content     = file("${path.module}/files/prometheus/alerts/default.yml")
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
    ]
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
