# Module Minio S3

Deploie un conteneur LXC avec Minio S3 pour le stockage de l'etat Terraform.

## Usage

```hcl
module "minio" {
  source = "../../modules/minio"

  hostname    = "minio"
  target_node = "pve-mon"

  ip_address = "192.168.1.200/24"
  gateway    = "192.168.1.1"
  ssh_keys   = var.ssh_public_keys

  minio_root_user     = "minioadmin"
  minio_root_password = var.minio_password

  buckets = ["tfstate-prod", "tfstate-lab", "tfstate-monitoring"]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| proxmox | ~> 0.50 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| hostname | Hostname du conteneur Minio | string | - | yes |
| target_node | Node Proxmox cible | string | - | yes |
| ip_address | Adresse IP en notation CIDR | string | - | yes |
| gateway | Passerelle par defaut | string | - | yes |
| ssh_keys | Cles SSH publiques | list(string) | - | yes |
| minio_root_password | Mot de passe root Minio | string | - | yes |
| minio_root_user | Utilisateur root Minio | string | "minioadmin" | no |
| buckets | Liste des buckets S3 a creer | list(string) | [] | no |
| cpu_cores | Nombre de cores CPU | number | 1 | no |
| memory_mb | RAM en MB | number | 512 | no |
| disk_size_gb | Taille du disque systeme en GB | number | 8 | no |
| data_disk_size_gb | Taille du disque donnees en GB | number | 50 | no |
| datastore | Datastore pour les disques | string | "local-lvm" | no |
| minio_port | Port API Minio | number | 9000 | no |
| minio_console_port | Port console Minio | number | 9001 | no |

## Outputs

| Name | Description |
|------|-------------|
| endpoint_url | URL de l'API S3 Minio |
| console_url | URL de la console Minio |
| container_id | ID du conteneur LXC |
| ip_address | Adresse IP du conteneur |
