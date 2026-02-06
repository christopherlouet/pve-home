services:
%{ if traefik_enabled }
  # -------------------------------------------------------------------------
  # Traefik - Reverse Proxy
  # -------------------------------------------------------------------------
  traefik:
    image: traefik:v3.3@sha256:2cd5cc75530c8d07ae0587c743d23eb30cae2436d07017a5ff78498b1a43d09f
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro
%{ if tls_enabled }
      - ./traefik/certs:/etc/traefik/certs:ro
%{ endif }
    networks:
      - monitoring
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.${domain_suffix}`)"
      - "traefik.http.services.traefik.loadbalancer.server.port=8080"
%{ endif }

  # -------------------------------------------------------------------------
  # Prometheus - Metrics Collection
  # -------------------------------------------------------------------------
  prometheus:
    image: prom/prometheus:v3.5.1@sha256:38c3b05c3bc744ff1b0b7b4eb82196026442845e62a1e2073795565da506d7a2
    container_name: prometheus
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    user: "65534:65534"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/alerts/:/etc/prometheus/alerts/:ro
      - ./prometheus/recording/:/etc/prometheus/recording/:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=${retention_days}d'
      - '--storage.tsdb.retention.size=${retention_size}'
      - '--storage.tsdb.wal-compression'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
%{ if traefik_enabled }
      - '--web.external-url=http://prometheus.${domain_suffix}'
%{ else }
      - '--web.external-url=http://${monitoring_ip}:9090'
%{ endif }
    ports:
      - "9090:9090"
    networks:
      - monitoring
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:9090/-/healthy || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
%{ if traefik_enabled }
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.${domain_suffix}`)"
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
%{ endif }

  grafana:
    image: grafana/grafana:12.1.1@sha256:a1701c2180249361737a99a01bc770db39381640e4d631825d38ff4535efa47d
    container_name: grafana
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    user: "472:472"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${grafana_admin_password}
      - GF_USERS_ALLOW_SIGN_UP=false
%{ if traefik_enabled }
      - GF_SERVER_ROOT_URL=http://grafana.${domain_suffix}
%{ else }
      - GF_SERVER_ROOT_URL=http://${monitoring_ip}:3000
%{ endif }
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
      - GF_ALERTING_ENABLED=false
      - GF_UNIFIED_ALERTING_ENABLED=true
    ports:
      - "3000:3000"
    networks:
      - monitoring
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
%{ if traefik_enabled }
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.${domain_suffix}`)"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"
%{ endif }
    depends_on:
      prometheus:
        condition: service_healthy

%{ if telegram_enabled }
  alertmanager:
    image: prom/alertmanager:v0.30.1@sha256:286ad8838533a5a01d89bd09643f43d2b68b65203123b5700e54a8f80ff9c1f4
    container_name: alertmanager
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
%{ if traefik_enabled }
      - '--web.external-url=http://alertmanager.${domain_suffix}'
%{ else }
      - '--web.external-url=http://${monitoring_ip}:9093'
%{ endif }
    ports:
      - "9093:9093"
    networks:
      - monitoring
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:9093/-/healthy || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
%{ if traefik_enabled }
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.alertmanager.rule=Host(`alertmanager.${domain_suffix}`)"
      - "traefik.http.services.alertmanager.loadbalancer.server.port=9093"
%{ endif }
%{ endif }

%{ if loki_enabled }
  # -------------------------------------------------------------------------
  # Loki - Log Aggregation
  # -------------------------------------------------------------------------
  loki:
    image: grafana/loki:3.5.0@sha256:4c431d2e6b9b38718694b31c5d56be7c80dc69c513215fde1aeb5b02cd4e2665
    container_name: loki
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    user: "10001:10001"
    volumes:
      - ./loki/loki-config.yml:/etc/loki/local-config.yaml:ro
      - loki_data:/loki
    command:
      - '-config.file=/etc/loki/local-config.yaml'
    ports:
      - "3100:3100"
    networks:
      - monitoring
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:3100/ready || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
%{ if traefik_enabled }
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.loki.rule=Host(`loki.${domain_suffix}`)"
      - "traefik.http.services.loki.loadbalancer.server.port=3100"
%{ endif }

  # -------------------------------------------------------------------------
  # Promtail - Log Collector (local)
  # -------------------------------------------------------------------------
  promtail:
    image: grafana/promtail:3.5.0@sha256:507dfecd2f0949475d071c124bea1c26fc4f8c1cff0372eee57478d5b1c5fbff
    container_name: promtail
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    volumes:
      - ./promtail/promtail-config.yml:/etc/promtail/config.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/log:/var/log:ro
    command:
      - '-config.file=/etc/promtail/config.yml'
    ports:
      - "9080:9080"
    networks:
      - monitoring
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:9080/ready || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    depends_on:
      loki:
        condition: service_healthy
%{ endif }

%{ if uptime_kuma_enabled }
  # -------------------------------------------------------------------------
  # Uptime Kuma - Status Page
  # -------------------------------------------------------------------------
  uptime-kuma:
    image: louislam/uptime-kuma:1.23.16@sha256:431fee3be822b04861cf0e35daf4beef6b7cb37391c5f26c3ad6e12ce280fe18
    container_name: uptime-kuma
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    volumes:
      - uptime_kuma_data:/app/data
    ports:
      - "3001:3001"
    networks:
      - monitoring
%{ if traefik_enabled }
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.uptime.rule=Host(`uptime.${domain_suffix}`)"
      - "traefik.http.services.uptime.loadbalancer.server.port=3001"
%{ endif }
%{ endif }

  pve-exporter:
    image: prompve/prometheus-pve-exporter:3.7.0@sha256:f5266117e8b3db1fcf1cb3f9206cf7822d9db82fc1740b8f33f3140c9f24cca9
    container_name: pve-exporter
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    volumes:
      - ./pve-exporter/pve.yml:/etc/prometheus/pve.yml:ro
    ports:
      - "9221:9221"
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:v1.10.2@sha256:3ac34ce007accad95afed72149e0d2b927b7e42fd1c866149b945b84737c62c3
    container_name: node-exporter
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
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
%{ if loki_enabled }
  loki_data:
    driver: local
%{ endif }
%{ if uptime_kuma_enabled }
  uptime_kuma_data:
    driver: local
%{ endif }

networks:
  monitoring:
    driver: bridge
