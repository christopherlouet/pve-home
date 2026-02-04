# =============================================================================
# Promtail Agent Configuration
# =============================================================================
# Remote log collector for VMs
# Sends logs to central Loki server
# =============================================================================

server:
  http_listen_port: 9080
  grpc_listen_port: 0
  log_level: info

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: ${loki_url}/loki/api/v1/push

# -----------------------------------------------------------------------------
# Scrape Configurations
# -----------------------------------------------------------------------------

scrape_configs:
  # ---------------------------------------------------------------------------
  # Docker Container Logs (if Docker is installed)
  # ---------------------------------------------------------------------------
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      # Keep container name as label
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      # Add container ID
      - source_labels: ['__meta_docker_container_id']
        target_label: 'container_id'
      # Add image name
      - source_labels: ['__meta_docker_container_image']
        target_label: 'image'
      # Add compose service name if available
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: 'service'
      # Add compose project name
      - source_labels: ['__meta_docker_container_label_com_docker_compose_project']
        target_label: 'project'
    pipeline_stages:
      # Parse Docker JSON logs
      - docker: {}
      # Add static labels
      - static_labels:
          hostname: ${hostname}
          environment: ${environment}

  # ---------------------------------------------------------------------------
  # System Logs
  # ---------------------------------------------------------------------------
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: system
          hostname: ${hostname}
          environment: ${environment}
          __path__: /var/log/*.log

  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          hostname: ${hostname}
          environment: ${environment}
          __path__: /var/log/syslog
    pipeline_stages:
      - regex:
          expression: '^(?P<timestamp>\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<host>\S+)\s+(?P<process>[^\[]+)(?:\[(?P<pid>\d+)\])?\s*:\s*(?P<message>.*)$'
      - labels:
          host:
          process:

  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          hostname: ${hostname}
          environment: ${environment}
          __path__: /var/log/auth.log
    pipeline_stages:
      - regex:
          expression: '^(?P<timestamp>\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<host>\S+)\s+(?P<process>[^\[]+)(?:\[(?P<pid>\d+)\])?\s*:\s*(?P<message>.*)$'
      - labels:
          host:
          process:

  # ---------------------------------------------------------------------------
  # Journal Logs (systemd)
  # ---------------------------------------------------------------------------
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: journal
        hostname: ${hostname}
        environment: ${environment}
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal_priority_keyword']
        target_label: 'level'
