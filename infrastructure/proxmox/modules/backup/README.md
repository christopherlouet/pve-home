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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.94.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [terraform_data.backup_job](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_compress"></a> [compress](#input\_compress) | Algorithme de compression : zstd (recommande), lzo, gzip, none | `string` | `"zstd"` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Activer le job de sauvegarde | `bool` | `true` | no |
| <a name="input_mail_to"></a> [mail\_to](#input\_mail\_to) | Adresse email pour les notifications (vide = pas de mail) | `string` | `""` | no |
| <a name="input_mode"></a> [mode](#input\_mode) | Mode de sauvegarde : snapshot (pas d'interruption), suspend (pause breve), stop (arret complet) | `string` | `"snapshot"` | no |
| <a name="input_notes_template"></a> [notes\_template](#input\_notes\_template) | Template pour les notes de sauvegarde | `string` | `"{{guestname}} - Backup automatique"` | no |
| <a name="input_notification_mode"></a> [notification\_mode](#input\_notification\_mode) | Mode de notification Proxmox : auto, legacy-sendmail, notification-system | `string` | `"auto"` | no |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | URL de l'API Proxmox (ex: https://192.168.1.100:8006) | `string` | n/a | yes |
| <a name="input_retention"></a> [retention](#input\_retention) | Politique de retention des sauvegardes | <pre>object({<br/>    keep_daily   = optional(number, 7)<br/>    keep_weekly  = optional(number, 0)<br/>    keep_monthly = optional(number, 0)<br/>  })</pre> | <pre>{<br/>  "keep_daily": 7,<br/>  "keep_monthly": 0,<br/>  "keep_weekly": 0<br/>}</pre> | no |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | Horaire de sauvegarde au format Proxmox (ex: '01:00' pour 1h du matin quotidien, 'sun 03:00' pour dimanche 3h) | `string` | `"01:00"` | no |
| <a name="input_storage_id"></a> [storage\_id](#input\_storage\_id) | ID du storage pour les sauvegardes (ex: local, backup-store) | `string` | `"local"` | no |
| <a name="input_target_node"></a> [target\_node](#input\_target\_node) | Node Proxmox cible pour les sauvegardes | `string` | n/a | yes |
| <a name="input_vmids"></a> [vmids](#input\_vmids) | Liste des VM/LXC IDs a sauvegarder (vide = toutes les VMs du node) | `list(number)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Etat du job de backup |
| <a name="output_job_id"></a> [job\_id](#output\_job\_id) | ID du resource terraform\_data pour le job de backup |
| <a name="output_retention"></a> [retention](#output\_retention) | Politique de retention configuree |
| <a name="output_schedule"></a> [schedule](#output\_schedule) | Horaire de sauvegarde configure |
| <a name="output_storage_id"></a> [storage\_id](#output\_storage\_id) | Storage utilise pour les sauvegardes |
| <a name="output_target_node"></a> [target\_node](#output\_target\_node) | Node Proxmox cible |
<!-- END_TF_DOCS -->

## Documentation associee

- [Backup & Restore](../../../../docs/BACKUP-RESTORE.md) - Procedures de sauvegarde et restauration
- [Disaster Recovery](../../../../docs/DISASTER-RECOVERY.md) - Plan de reprise apres sinistre
- [Testing](../../../../docs/TESTING.md) - Guide des tests Terraform et BATS