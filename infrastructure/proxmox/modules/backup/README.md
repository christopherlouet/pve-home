# Module Backup Proxmox

Configure les jobs de sauvegarde vzdump automatiques via l'API Proxmox.

## Usage

```hcl
module "backup" {
  source = "../../modules/backup"

  target_node = "pve-prod"
  storage_id  = "local"

  schedule = "01:00"
  mode     = "snapshot"
  compress = "zstd"

  proxmox_endpoint  = var.proxmox_endpoint
  proxmox_api_token = var.proxmox_api_token

  retention = {
    keep_daily   = 7
    keep_weekly  = 4
    keep_monthly = 0
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| proxmox | ~> 0.50 |

## Fonctionnement

Le provider `bpg/proxmox` ne fournit pas de ressource native pour les backup
schedules Proxmox. Ce module utilise `terraform_data` avec `remote-exec` pour
appeler `pvesh` (CLI API Proxmox) et configurer les jobs vzdump.

Le job est recree si l'un des parametres change (schedule, storage, mode, etc.).
A la destruction, les jobs associes sont supprimes.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| target_node | Node Proxmox cible | string | - | yes |
| proxmox_endpoint | URL de l'API Proxmox | string | - | yes |
| proxmox_api_token | Token API Proxmox | string | - | yes |
| storage_id | Storage pour les sauvegardes | string | "local" | no |
| schedule | Horaire (format Proxmox) | string | "01:00" | no |
| mode | Mode de sauvegarde | string | "snapshot" | no |
| compress | Algorithme compression | string | "zstd" | no |
| vmids | IDs VM/LXC a sauvegarder | list(number) | [] | no |
| enabled | Activer le job | bool | true | no |
| retention | Politique de retention | object | 7 daily | no |

## Outputs

| Name | Description |
|------|-------------|
| job_id | ID du resource Terraform |
| storage_id | Storage utilise |
| schedule | Horaire configure |
| target_node | Node cible |
| enabled | Etat du job |
| retention | Politique de retention |
