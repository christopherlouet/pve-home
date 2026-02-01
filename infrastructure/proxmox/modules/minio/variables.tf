# =============================================================================
# Module Minio - Variables
# =============================================================================

variable "hostname" {
  description = "Hostname du conteneur Minio"
  type        = string
}

variable "description" {
  description = "Description du conteneur"
  type        = string
  default     = "Minio S3 - Managed by Terraform"
}

variable "target_node" {
  description = "Node Proxmox cible"
  type        = string
}

variable "container_id" {
  description = "ID du conteneur (null pour auto-attribution)"
  type        = number
  default     = null
}

variable "template_file_id" {
  description = "ID du template LXC (ex: local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst)"
  type        = string
  default     = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "cpu_cores" {
  description = "Nombre de cores CPU"
  type        = number
  default     = 1
}

variable "memory_mb" {
  description = "RAM en MB"
  type        = number
  default     = 512
}

variable "disk_size_gb" {
  description = "Taille du disque systeme en GB"
  type        = number
  default     = 8
}

variable "data_disk_size_gb" {
  description = "Taille du disque donnees Minio en GB"
  type        = number
  default     = 50
}

variable "datastore" {
  description = "Datastore pour les disques"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Bridge reseau"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN ID (null si pas de VLAN)"
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Adresse IP en notation CIDR (ex: 192.168.1.200/24)"
  type        = string
}

variable "gateway" {
  description = "Passerelle par defaut"
  type        = string
}

variable "dns_servers" {
  description = "Serveurs DNS"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "ssh_keys" {
  description = "Cles SSH publiques"
  type        = list(string)
}

variable "minio_root_user" {
  description = "Utilisateur root Minio"
  type        = string
  default     = "minioadmin"
}

variable "minio_root_password" {
  description = "Mot de passe root Minio"
  type        = string
  sensitive   = true
}

variable "minio_port" {
  description = "Port API Minio"
  type        = number
  default     = 9000
}

variable "minio_console_port" {
  description = "Port console Minio"
  type        = number
  default     = 9001
}

variable "buckets" {
  description = "Liste des buckets S3 a creer"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags du conteneur"
  type        = list(string)
  default     = ["terraform", "minio", "s3"]
}

variable "start_on_boot" {
  description = "Demarrer automatiquement au boot"
  type        = bool
  default     = true
}
