version: "3.8"

services:
  prometheus:
    image: prom/prometheus:v2.50.1
    container_name: prometheus
    restart: unless-stopped
    user: "65534:65534"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/alerts/:/etc/prometheus/alerts/:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=${retention_days}d'
      - '--storage.tsdb.retention.size=${retention_size}'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
      - '--web.external-url=http://${monitoring_ip}:9090'
    ports:
      - "9090:9090"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:11.0.0
    container_name: grafana
    restart: unless-stopped
    user: "472:472"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${grafana_admin_password}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://${monitoring_ip}:3000
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
      - GF_ALERTING_ENABLED=false
      - GF_UNIFIED_ALERTING_ENABLED=true
    ports:
      - "3000:3000"
    networks:
      - monitoring
    depends_on:
      - prometheus

%{ if telegram_enabled }
  alertmanager:
    image: prom/alertmanager:v0.27.0
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://${monitoring_ip}:9093'
    ports:
      - "9093:9093"
    networks:
      - monitoring
%{ endif }

  pve-exporter:
    image: prompve/prometheus-pve-exporter:3.7.0
    container_name: pve-exporter
    restart: unless-stopped
    volumes:
      - ./pve-exporter/pve.yml:/etc/prometheus/pve.yml:ro
    ports:
      - "9221:9221"
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: node-exporter
    restart: unless-stopped
    command:
      - '--path.rootfs=/host'
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - '/:/host:ro,rslave'
    ports:
      - "9100:9100"
    networks:
      - monitoring
    pid: host

volumes:
  prometheus_data:
    driver: local
  grafana_data:
    driver: local
%{ if telegram_enabled }
  alertmanager_data:
    driver: local
%{ endif }

networks:
  monitoring:
    driver: bridge
