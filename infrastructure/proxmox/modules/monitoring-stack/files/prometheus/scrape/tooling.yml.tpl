# =============================================================================
# Prometheus Scrape Configuration - Tooling Stack
# =============================================================================
# Add these scrape configs to prometheus.yml via custom_scrape_configs
# Variables: tooling_ip, step_ca_enabled, harbor_enabled, authentik_enabled, traefik_enabled
# =============================================================================

%{ if step_ca_enabled ~}
  # -------------------------------------------------------------------------
  # Step-ca PKI - Certificate Authority Metrics
  # -------------------------------------------------------------------------
  - job_name: 'step-ca'
    scheme: https
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ['${tooling_ip}:9290']
        labels:
          instance: 'step-ca'
          service: 'pki'
          environment: 'homelab'

%{ endif ~}
%{ if harbor_enabled ~}
  # -------------------------------------------------------------------------
  # Harbor Registry - Container Registry Metrics
  # -------------------------------------------------------------------------
  - job_name: 'harbor'
    scheme: http
    static_configs:
      - targets: ['${tooling_ip}:9090']
        labels:
          instance: 'harbor'
          service: 'registry'
          environment: 'homelab'
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'harbor_(.*)'
        target_label: __name__
        replacement: 'harbor_$1'

%{ endif ~}
%{ if authentik_enabled ~}
  # -------------------------------------------------------------------------
  # Authentik SSO - Authentication Metrics
  # -------------------------------------------------------------------------
  - job_name: 'authentik'
    scheme: http
    static_configs:
      - targets: ['${tooling_ip}:9300']
        labels:
          instance: 'authentik'
          service: 'sso'
          environment: 'homelab'
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'authentik_(.*)'
        target_label: __name__
        replacement: 'authentik_$1'

%{ endif ~}
%{ if traefik_enabled ~}
  # -------------------------------------------------------------------------
  # Traefik Tooling - Reverse Proxy Metrics
  # -------------------------------------------------------------------------
  - job_name: 'traefik-tooling'
    scheme: http
    static_configs:
      - targets: ['${tooling_ip}:8082']
        labels:
          instance: 'traefik-tooling'
          service: 'proxy'
          environment: 'homelab'

%{ endif ~}
  # -------------------------------------------------------------------------
  # Node Exporter on Tooling VM
  # -------------------------------------------------------------------------
  - job_name: 'tooling-node'
    scheme: http
    static_configs:
      - targets: ['${tooling_ip}:9100']
        labels:
          instance: 'tooling'
          role: 'tooling'
          environment: 'homelab'

  # -------------------------------------------------------------------------
  # cAdvisor on Tooling VM (Docker container metrics)
  # -------------------------------------------------------------------------
  - job_name: 'tooling-cadvisor'
    scheme: http
    static_configs:
      - targets: ['${tooling_ip}:8080']
        labels:
          instance: 'tooling'
          role: 'tooling'
          environment: 'homelab'
