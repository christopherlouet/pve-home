# =============================================================================
# Module Backup Proxmox - Homelab
# =============================================================================
# Configure les jobs de sauvegarde vzdump via l'API Proxmox.
# Utilise terraform_data + provisioner pour appeler pvesh car le provider
# bpg/proxmox ne fournit pas de ressource native pour les backup schedules.
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  vmids_str = length(var.vmids) > 0 ? join(",", var.vmids) : ""

  # Construire les options de retention
  retention_opts = join(" ", compact([
    var.retention.keep_daily > 0 ? "--keep-daily ${var.retention.keep_daily}" : "",
    var.retention.keep_weekly > 0 ? "--keep-weekly ${var.retention.keep_weekly}" : "",
    var.retention.keep_monthly > 0 ? "--keep-monthly ${var.retention.keep_monthly}" : "",
  ]))

  # Construire la commande pvesh pour creer le job de backup
  create_command = var.enabled ? join(" ", compact([
    "pvesh create /cluster/backup",
    "--schedule '${var.schedule}'",
    "--storage ${var.storage_id}",
    "--mode ${var.mode}",
    "--compress ${var.compress}",
    "--node ${var.target_node}",
    "--enabled 1",
    local.vmids_str != "" ? "--vmid ${local.vmids_str}" : "--all 1",
    "--notification-mode ${var.notification_mode}",
    var.mail_to != "" ? "--mailto ${var.mail_to}" : "",
    local.retention_opts,
    "--notes-template '${var.notes_template}'",
  ])) : "echo 'Backup job disabled'"

  # Commande de suppression pour le cleanup
  delete_command = "pvesh get /cluster/backup --output-format json | python3 -c \"import sys,json; jobs=json.load(sys.stdin); [print(j.get('id','')) for j in jobs if '${var.target_node}' in j.get('node','') and '${var.storage_id}' in j.get('storage','')]\" | while read id; do [ -n \"$id\" ] && pvesh delete /cluster/backup/$id; done"

  # Endpoint sans le schema pour le host SSH
  proxmox_host = replace(replace(var.proxmox_endpoint, "https://", ""), ":8006", "")
}

# -----------------------------------------------------------------------------
# Backup Job via API Proxmox
# -----------------------------------------------------------------------------

resource "terraform_data" "backup_job" {
  triggers_replace = [
    var.schedule,
    var.storage_id,
    var.mode,
    var.compress,
    var.target_node,
    var.enabled,
    local.vmids_str,
    var.retention.keep_daily,
    var.retention.keep_weekly,
    var.retention.keep_monthly,
  ]

  provisioner "remote-exec" {
    inline = [
      "set -euo pipefail",
      # Supprimer les anciens jobs pour ce node/storage avant de recreer
      local.delete_command,
      # Creer le nouveau job
      local.create_command,
    ]

    connection {
      type  = "ssh"
      host  = local.proxmox_host
      user  = "root"
      agent = true
    }
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "pvesh get /cluster/backup --output-format json | python3 -c \"import sys,json; jobs=json.load(sys.stdin); [print(j.get('id','')) for j in jobs]\" | while read id; do [ -n \"$id\" ] && pvesh delete /cluster/backup/$id || true; done",
    ]

    connection {
      type  = "ssh"
      host  = self.triggers_replace[4] # target_node IP from triggers
      user  = "root"
      agent = true
    }
  }
}
