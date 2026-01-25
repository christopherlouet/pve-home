# =============================================================================
# Variables globales du projet
# =============================================================================

# -----------------------------------------------------------------------------
# Infrastructure
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Environnement (home, dev, prod)"
  type        = string
  default     = "home"
}

variable "default_node" {
  description = "Node Proxmox par défaut"
  type        = string
  default     = "pve"
}

# -----------------------------------------------------------------------------
# Templates
# -----------------------------------------------------------------------------

variable "vm_template_id" {
  description = "ID du template VM cloud-init (créé lors de l'installation)"
  type        = number
  default     = 9000
}

variable "lxc_template" {
  description = "Template LXC Ubuntu (24.04 recommandé pour PVE 9.x)"
  type        = string
  default     = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
}

# -----------------------------------------------------------------------------
# Réseau
# -----------------------------------------------------------------------------

variable "network_bridge" {
  description = "Bridge réseau Proxmox"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Passerelle réseau (votre routeur/box)"
  type        = string
}

variable "network_dns" {
  description = "Serveurs DNS"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------

variable "ssh_public_keys" {
  description = "Clés SSH publiques autorisées pour les VMs/LXC"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# Stockage
# -----------------------------------------------------------------------------

variable "default_datastore" {
  description = "Datastore par défaut pour les disques"
  type        = string
  default     = "local-lvm"
}
