# =============================================================================
# Minio S3 - Backend Terraform State
# =============================================================================
# Conteneur LXC Minio pour stocker l'etat Terraform de facon resiliente.
# Deploye sur le PVE monitoring (pas de workload applicatif).
# =============================================================================

module "minio" {
  source = "../../modules/minio"

  hostname    = "${local.environment}-minio"
  target_node = var.default_node
  description = "Minio S3 - Terraform state backend"

  template_file_id  = var.minio.template_file_id
  cpu_cores         = var.minio.cpu_cores
  memory_mb         = var.minio.memory_mb
  disk_size_gb      = var.minio.disk_size_gb
  data_disk_size_gb = var.minio.data_disk_size_gb
  datastore         = var.default_datastore

  network_bridge = var.network_bridge
  ip_address     = "${var.minio.ip}/24"
  gateway        = var.network_gateway
  dns_servers    = var.network_dns

  ssh_keys = var.ssh_public_keys

  minio_root_user     = var.minio.root_user
  minio_root_password = var.minio.root_password
  minio_port          = var.minio.port
  minio_console_port  = var.minio.console_port

  buckets = var.minio.buckets

  tags = concat(local.common_tags, ["minio", "s3"])
}

# -----------------------------------------------------------------------------
# Firewall Minio
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_firewall_options" "minio" {
  node_name = var.default_node
  vm_id     = module.minio.container_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_rules" "minio" {
  node_name = var.default_node
  vm_id     = module.minio.container_id

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "22"
    comment = "SSH"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = tostring(var.minio.port)
    comment = "Minio API"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = tostring(var.minio.console_port)
    comment = "Minio Console"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "icmp"
    comment = "Ping"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.minio]
}

# -----------------------------------------------------------------------------
# Outputs Minio
# -----------------------------------------------------------------------------

output "minio" {
  description = "Minio S3"
  value = {
    container_id = module.minio.container_id
    endpoint     = module.minio.endpoint_url
    console      = module.minio.console_url
    ip           = var.minio.ip
  }
}
