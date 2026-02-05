#!/bin/bash
set -e

echo "=== Configuration Stack Monitoring ==="

# Creer les repertoires
mkdir -p /opt/monitoring/{prometheus,alertmanager,grafana/provisioning/{datasources,dashboards},grafana/dashboards/{infrastructure,observability,applications},pve-exporter}
mkdir -p /opt/monitoring/prometheus/data
mkdir -p /opt/monitoring/grafana/data
%{if tooling_enabled}
mkdir -p /opt/monitoring/grafana/dashboards/tooling
%{endif}
%{if traefik_enabled}
mkdir -p /opt/monitoring/traefik
%{if tls_enabled}
mkdir -p /opt/monitoring/traefik/certs
%{endif}
%{endif}
%{if loki_enabled}
mkdir -p /opt/monitoring/loki/{chunks,rules,wal,compactor}
mkdir -p /opt/monitoring/promtail
%{endif}

# Permissions pour Prometheus (user 65534 = nobody)
chown -R 65534:65534 /opt/monitoring/prometheus/data

# Permissions pour Grafana (user 472)
chown -R 472:472 /opt/monitoring/grafana/data
chown -R 472:472 /opt/monitoring/grafana/dashboards

%{if loki_enabled}
# Permissions pour Loki (user 10001)
chown -R 10001:10001 /opt/monitoring/loki
%{endif}

# Docker Compose
cat > /opt/monitoring/docker-compose.yml << 'COMPOSE'
${docker_compose_content}
COMPOSE

# Prometheus config
cat > /opt/monitoring/prometheus/prometheus.yml << 'PROMCONFIG'
${prometheus_config}
PROMCONFIG

# Alertmanager config
cat > /opt/monitoring/alertmanager/alertmanager.yml << 'ALERTCONFIG'
${alertmanager_config}
ALERTCONFIG

%{if traefik_enabled}
# Traefik static config
cat > /opt/monitoring/traefik/traefik.yml << 'TRAEFIKSTATIC'
${traefik_static_config}
TRAEFIKSTATIC

# Traefik dynamic config
cat > /opt/monitoring/traefik/dynamic.yml << 'TRAEFIKDYNAMIC'
${traefik_dynamic_config}
TRAEFIKDYNAMIC
%{endif}

%{if loki_enabled}
# Loki config
cat > /opt/monitoring/loki/loki-config.yml << 'LOKICONFIG'
${loki_config}
LOKICONFIG

# Promtail config
cat > /opt/monitoring/promtail/promtail-config.yml << 'PROMTAILCONFIG'
${promtail_config}
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

%{if loki_enabled}
# Grafana datasource Loki
cat > /opt/monitoring/grafana/provisioning/datasources/loki.yml << 'LOKIDATASOURCE'
${grafana_datasource_loki}
LOKIDATASOURCE

# Dashboard Logs Overview (Observability folder)
cat > /opt/monitoring/grafana/dashboards/observability/logs-overview.json << 'LOGSDASHBOARD'
${dashboard_logs_overview}
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
%{if tooling_enabled}
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
%{if traefik_enabled}
echo "Traefik Dashboard: http://traefik.${domain_suffix}"
echo "Grafana: http://grafana.${domain_suffix}"
echo "Prometheus: http://prometheus.${domain_suffix}"
echo "Alertmanager: http://alertmanager.${domain_suffix}"
echo ""
echo "Note: Configure DNS to resolve *.${domain_suffix} to ${ip_address}"
%{else}
echo "Prometheus: http://${ip_address}:9090"
echo "Grafana: http://${ip_address}:3000"
echo "Alertmanager: http://${ip_address}:9093"
%{endif}
