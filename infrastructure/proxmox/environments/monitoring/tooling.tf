# =============================================================================
# Tooling Stack Configuration
# =============================================================================
# Stack outillage homelab: Step-ca (PKI), Harbor (Registry), Authentik (SSO)
# Deployee sur un PVE dedie, services internes partages.
# =============================================================================

module "tooling" {
  source = "../../modules/tooling-stack"
  count  = var.tooling.enabled ? 1 : 0

  name        = "tooling-stack"
  target_node = var.tooling.node != null ? var.tooling.node : var.default_node
  template_id = var.vm_template_id

  vm_config = {
    cores     = var.tooling.vm.cores
    memory    = var.tooling.vm.memory
    disk      = var.tooling.vm.disk
    data_disk = var.tooling.vm.data_disk
  }

  datastore      = var.default_datastore
  ip_address     = var.tooling.vm.ip
  network_cidr   = 24
  gateway        = var.network_gateway
  dns_servers    = var.network_dns
  network_bridge = var.network_bridge
  ssh_keys       = var.ssh_public_keys

  # Domaine (RFC 8375 pour homelab)
  domain_suffix = var.tooling.domain_suffix

  # Step-ca PKI
  step_ca_enabled          = var.tooling.step_ca.enabled
  step_ca_password         = var.tooling.step_ca.password
  step_ca_provisioner_name = var.tooling.step_ca.provisioner_name
  step_ca_cert_duration    = var.tooling.step_ca.cert_duration

  # Harbor Registry
  harbor_enabled        = var.tooling.harbor.enabled
  harbor_admin_password = var.tooling.harbor.admin_password
  harbor_trivy_enabled  = var.tooling.harbor.trivy_enabled

  # Authentik SSO
  authentik_enabled            = var.tooling.authentik.enabled
  authentik_secret_key         = var.tooling.authentik.secret_key
  authentik_bootstrap_password = var.tooling.authentik.bootstrap_password
  authentik_bootstrap_email    = var.tooling.authentik.bootstrap_email

  # Traefik Reverse Proxy
  traefik_enabled = var.tooling.traefik_enabled

  tags = sort(distinct(concat(local.common_tags, ["tooling", "pki", "registry", "sso"])))
}

# -----------------------------------------------------------------------------
# Integration Monitoring Stack
# -----------------------------------------------------------------------------
# Injecte la config scrape tooling dans Prometheus
# Les dashboards et alertes sont inclus via les variables tooling_* du module monitoring
# -----------------------------------------------------------------------------

locals {
  # Generer la config scrape tooling si le module est deploye
  tooling_scrape_config = var.tooling.enabled ? templatefile("${path.module}/../../modules/monitoring-stack/files/prometheus/scrape/tooling.yml.tpl", {
    tooling_ip        = var.tooling.vm.ip
    step_ca_enabled   = var.tooling.step_ca.enabled
    harbor_enabled    = var.tooling.harbor.enabled
    authentik_enabled = var.tooling.authentik.enabled
    traefik_enabled   = var.tooling.traefik_enabled
  }) : ""

  # Combiner avec les custom_scrape_configs existants
  combined_scrape_configs = var.tooling.enabled ? join("\n", compact([
    var.custom_scrape_configs,
    local.tooling_scrape_config
  ])) : var.custom_scrape_configs
}

# -----------------------------------------------------------------------------
# Firewall Tooling
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_firewall_options" "tooling" {
  count     = var.tooling.enabled ? 1 : 0
  node_name = module.tooling[0].node_name
  vm_id     = module.tooling[0].vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

# Regles firewall: presets partages (shared/firewall_locals.tf) + services tooling
resource "proxmox_virtual_environment_firewall_rules" "tooling" {
  count     = var.tooling.enabled ? 1 : 0
  node_name = module.tooling[0].node_name
  vm_id     = module.tooling[0].vm_id

  # Regles de base partagees (SSH, HTTP, HTTPS, Node Exporter, Ping)
  dynamic "rule" {
    for_each = local.firewall_rules_base
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = rule.value.proto
      dport   = rule.value.dport
      comment = rule.value.comment
    }
  }

  # Tooling-specific static rules
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "8082"
    comment = "Traefik Dashboard"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "8080"
    comment = "cAdvisor"
  }

  # Step-ca ACME (conditional)
  dynamic "rule" {
    for_each = var.tooling.step_ca.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = "tcp"
      dport   = "8443"
      comment = "Step-ca CA API"
    }
  }

  dynamic "rule" {
    for_each = var.tooling.step_ca.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = "tcp"
      dport   = "9290"
      comment = "Step-ca Metrics"
    }
  }

  # Harbor Registry (conditional)
  dynamic "rule" {
    for_each = var.tooling.harbor.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = "tcp"
      dport   = "9090"
      comment = "Harbor Metrics"
    }
  }

  # Authentik SSO (conditional)
  dynamic "rule" {
    for_each = var.tooling.authentik.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = "tcp"
      dport   = "9000"
      comment = "Authentik Web"
    }
  }

  dynamic "rule" {
    for_each = var.tooling.authentik.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = "tcp"
      dport   = "9300"
      comment = "Authentik Metrics"
    }
  }

  depends_on = [proxmox_virtual_environment_firewall_options.tooling]
}

# -----------------------------------------------------------------------------
# Outputs Tooling
# -----------------------------------------------------------------------------

output "tooling" {
  description = "Stack tooling (PKI, Registry, SSO)"
  value = var.tooling.enabled ? {
    vm_id   = module.tooling[0].vm_id
    vm_name = module.tooling[0].vm_name
    ip      = module.tooling[0].ip_address
    urls    = module.tooling[0].urls
    ssh     = module.tooling[0].ssh_command
    services = {
      step_ca   = var.tooling.step_ca.enabled
      harbor    = var.tooling.harbor.enabled
      authentik = var.tooling.authentik.enabled
      traefik   = var.tooling.traefik_enabled
    }
  } : null
}

output "tooling_ca_instructions" {
  description = "Instructions pour installer le certificat CA"
  value       = var.tooling.enabled && var.tooling.step_ca.enabled ? module.tooling[0].ca_install_instructions : null
}
