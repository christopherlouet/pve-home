# =============================================================================
# Module Tooling Stack - Main
# =============================================================================
# Stack d'outillage: Step-ca (PKI) + Harbor (Registry) + Authentik (SSO)
# Deploye sur une VM dediee avec Docker Compose
# =============================================================================

# -----------------------------------------------------------------------------
# TLS Resources for Step-ca (Root CA)
# -----------------------------------------------------------------------------

resource "tls_private_key" "root_ca" {
  count       = var.step_ca_enabled ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "root_ca" {
  count           = var.step_ca_enabled ? 1 : 0
  private_key_pem = tls_private_key.root_ca[0].private_key_pem

  subject {
    common_name  = var.step_ca_root_cn
    organization = "Homelab"
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]

  is_ca_certificate = true
}

# -----------------------------------------------------------------------------
# Random resources for secrets
# -----------------------------------------------------------------------------

resource "random_password" "harbor_db" {
  count   = var.harbor_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "authentik_pg" {
  count   = var.authentik_enabled ? 1 : 0
  length  = 32
  special = false
}

# -----------------------------------------------------------------------------
# Step-ca Configuration
# -----------------------------------------------------------------------------

locals {
  # Step-ca configuration object
  step_ca_config = var.step_ca_enabled ? {
    ca_name          = "Homelab CA"
    dns_names        = ["pki.${var.domain_suffix}", var.ip_address, "localhost", "127.0.0.1"]
    address          = "0.0.0.0:8443"
    provisioner_name = var.step_ca_provisioner_name
    provisioner_type = "ACME"
    cert_duration    = var.step_ca_cert_duration
    root_cn          = var.step_ca_root_cn
    root_key_type    = "EC"
    root_key_curve   = "P-384"
  } : null

  # Harbor configuration object
  harbor_config = var.harbor_enabled ? {
    hostname          = "registry.${var.domain_suffix}"
    external_url      = var.traefik_enabled ? "https://registry.${var.domain_suffix}" : "http://${var.ip_address}:8080"
    internal_tls      = var.traefik_enabled ? false : true
    data_volume       = var.harbor_data_volume
    storage_type      = "filesystem"
    storage_path      = "${var.harbor_data_volume}/registry"
    database_type     = "postgresql"
    db_host           = "harbor-db"
    db_port           = 5432
    db_name           = "registry"
    db_username       = "postgres"
    trivy_enabled     = var.harbor_trivy_enabled
    csrf_key          = var.harbor_enabled ? random_password.harbor_db[0].result : ""
    core_secret       = var.harbor_enabled ? random_password.harbor_db[0].result : ""
    jobservice_secret = var.harbor_enabled ? random_password.harbor_db[0].result : ""
  } : null

  # Authentik configuration object
  authentik_config = var.authentik_enabled ? {
    hostname         = "auth.${var.domain_suffix}"
    external_url     = var.traefik_enabled ? "https://auth.${var.domain_suffix}" : "http://${var.ip_address}:9000"
    db_type          = "postgresql"
    db_host          = "authentik-db"
    db_port          = 5432
    db_name          = "authentik"
    db_username      = "authentik"
    redis_host       = "authentik-redis"
    redis_port       = 6379
    bootstrap_email  = var.authentik_bootstrap_email
    email_enabled    = false
    error_reporting  = false
    avatars          = "none"
    outpost_traefik  = var.traefik_enabled
    forward_auth_url = "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
    server_port      = 9000
    metrics_port     = 9300
  } : null

  # Authentik OAuth/OIDC provider configurations for integrated services
  authentik_oauth_providers = var.authentik_enabled ? merge(
    # Grafana OAuth2 provider
    {
      grafana = {
        name         = "Grafana"
        client_id    = "grafana"
        redirect_uri = var.traefik_enabled ? "https://grafana.${var.domain_suffix}/login/generic_oauth" : "http://${var.ip_address}:3000/login/generic_oauth"
        scopes       = ["openid", "profile", "email"]
        protocol     = "oauth2"
      }
    },
    # Harbor OIDC provider (if Harbor is enabled)
    var.harbor_enabled ? {
      harbor = {
        name         = "Harbor"
        client_id    = "harbor"
        redirect_uri = var.traefik_enabled ? "https://registry.${var.domain_suffix}/c/oidc/callback" : "http://${var.ip_address}:8080/c/oidc/callback"
        scopes       = ["openid", "profile", "email", "groups"]
        protocol     = "oidc"
      }
    } : {},
    # Proxmox OIDC provider (for future Phase 2 SSO)
    {
      proxmox = {
        name         = "Proxmox VE"
        client_id    = "proxmox"
        redirect_uri = "https://pve.${var.domain_suffix}:8006"
        scopes       = ["openid", "profile", "email"]
        protocol     = "oidc"
      }
    },
    # Traefik Dashboard (for future Phase 2 SSO with ForwardAuth)
    var.traefik_enabled ? {
      traefik = {
        name         = "Traefik Dashboard"
        client_id    = "traefik"
        redirect_uri = "https://traefik.${var.domain_suffix}"
        scopes       = ["openid", "profile", "email"]
        protocol     = "forward_auth"
      }
    } : {}
  ) : {}

  # Traefik configuration object
  traefik_config = var.traefik_enabled ? {
    acme_enabled  = var.step_ca_enabled
    acme_server   = "https://127.0.0.1:8443/acme/acme/directory"
    acme_email    = "admin@${var.domain_suffix}"
    dashboard     = true
    entrypoints   = ["web", "websecure"]
    providers     = ["docker", "file"]
    log_level     = "INFO"
    metrics_port  = 8082
    insecure_skip = true # Skip TLS verification for internal Step-ca
  } : null

  # Traefik routes for each service
  traefik_routes = var.traefik_enabled ? merge(
    var.step_ca_enabled ? {
      pki = {
        host    = "pki.${var.domain_suffix}"
        port    = 8443
        service = "step-ca"
        tls     = true
      }
    } : {},
    var.harbor_enabled ? {
      registry = {
        host    = "registry.${var.domain_suffix}"
        port    = 8080
        service = "harbor-core"
        tls     = true
      }
    } : {},
    var.authentik_enabled ? {
      auth = {
        host    = "auth.${var.domain_suffix}"
        port    = 9000
        service = "authentik-server"
        tls     = true
      }
    } : {},
    {
      traefik = {
        host    = "traefik.${var.domain_suffix}"
        port    = 8080
        service = "api@internal"
        tls     = true
      }
    }
  ) : {}

  # Docker Compose services list
  docker_compose_services = compact([
    var.step_ca_enabled ? "step-ca" : "",
    var.traefik_enabled ? "traefik" : "",
    var.harbor_enabled ? "harbor-core" : "",
    var.harbor_enabled ? "harbor-db" : "",
    var.harbor_enabled ? "harbor-registry" : "",
    var.harbor_enabled ? "harbor-portal" : "",
    var.harbor_enabled ? "harbor-jobservice" : "",
    var.harbor_enabled && var.harbor_trivy_enabled ? "harbor-trivy" : "",
    var.authentik_enabled ? "authentik-server" : "",
    var.authentik_enabled ? "authentik-worker" : "",
    var.authentik_enabled ? "authentik-db" : "",
    var.authentik_enabled ? "authentik-redis" : "",
  ])

  # Docker Compose volumes list
  docker_compose_volumes = compact([
    var.step_ca_enabled ? "step-ca-data" : "",
    var.traefik_enabled ? "traefik-certs" : "",
    var.harbor_enabled ? "harbor-data" : "",
    var.harbor_enabled ? "harbor-db-data" : "",
    var.authentik_enabled ? "authentik-db-data" : "",
    var.authentik_enabled ? "authentik-redis-data" : "",
  ])
}

# -----------------------------------------------------------------------------
# Cloud-init Configuration
# -----------------------------------------------------------------------------

locals {
  # Services configuration for cloud-init
  services_config = {
    step_ca = {
      enabled          = var.step_ca_enabled
      password         = var.step_ca_password
      provisioner_name = var.step_ca_provisioner_name
      cert_duration    = var.step_ca_cert_duration
      root_cn          = var.step_ca_root_cn
    }
    harbor = {
      enabled        = var.harbor_enabled
      admin_password = var.harbor_admin_password
      db_password    = var.harbor_enabled ? random_password.harbor_db[0].result : ""
      trivy_enabled  = var.harbor_trivy_enabled
      data_volume    = var.harbor_data_volume
    }
    authentik = {
      enabled            = var.authentik_enabled
      secret_key         = var.authentik_secret_key
      bootstrap_password = var.authentik_bootstrap_password
      bootstrap_email    = var.authentik_bootstrap_email
      pg_password        = var.authentik_enabled ? random_password.authentik_pg[0].result : ""
    }
    traefik = {
      enabled = var.traefik_enabled
    }
  }

  # Cloud-init user-data
  cloud_init_user_data = <<-EOT
    #cloud-config
    hostname: ${var.name}
    fqdn: ${var.name}.${var.domain_suffix}
    manage_etc_hosts: true

    users:
      - name: ${var.username}
        groups: [adm, cdrom, dip, plugdev, lxd, sudo, docker]
        lock_passwd: true
        shell: /bin/bash
        ssh_authorized_keys:
          ${indent(6, join("\n", [for key in var.ssh_keys : "- ${key}"]))}

    package_update: true
    package_upgrade: true

    packages:
      - docker.io
      - docker-compose
      - curl
      - jq
      - htop
      - vim

    runcmd:
      - systemctl enable docker
      - systemctl start docker
      - usermod -aG docker ${var.username}
      # Mount data disk
      - |
        if [ -b /dev/sdb ]; then
          mkfs.ext4 -F /dev/sdb
          mkdir -p /data
          echo '/dev/sdb /data ext4 defaults 0 2' >> /etc/fstab
          mount /data
          chown ${var.username}:${var.username} /data
        fi
      # Create service directories
      - mkdir -p /data/step-ca /data/harbor /data/authentik /data/traefik
      - chown -R ${var.username}:${var.username} /data

    write_files:
      - path: /etc/docker/daemon.json
        content: |
          {
            "log-driver": "json-file",
            "log-opts": {
              "max-size": "10m",
              "max-file": "3"
            }
          }

    final_message: "Tooling VM ready after $UPTIME seconds"
  EOT
}

# -----------------------------------------------------------------------------
# Cloud-init Snippet
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.target_node

  source_raw {
    data      = local.cloud_init_user_data
    file_name = "${var.name}-cloud-init.yaml"
  }
}

# -----------------------------------------------------------------------------
# Virtual Machine
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "tooling" {
  name        = var.name
  description = "Tooling Stack: Step-ca PKI, Harbor Registry, Authentik SSO"
  tags        = var.tags
  node_name   = var.target_node

  on_boot = true
  started = true

  clone {
    vm_id = var.template_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.vm_config.cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_config.memory
  }

  # System disk (cloned from template)
  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.vm_config.disk
    file_format  = "raw"
  }

  # Data disk for Harbor images and service data
  disk {
    datastore_id = var.datastore
    interface    = "scsi1"
    size         = var.vm_config.data_disk
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address}/${var.network_cidr}"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  lifecycle {
    ignore_changes = [
      clone,
      initialization,
    ]
  }
}
