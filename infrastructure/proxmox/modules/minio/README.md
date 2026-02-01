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

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_container.minio](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container) | resource |
| [terraform_data.minio_install](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_buckets"></a> [buckets](#input\_buckets) | Liste des buckets S3 a creer | `list(string)` | `[]` | no |
| <a name="input_container_id"></a> [container\_id](#input\_container\_id) | ID du conteneur (null pour auto-attribution) | `number` | `null` | no |
| <a name="input_cpu_cores"></a> [cpu\_cores](#input\_cpu\_cores) | Nombre de cores CPU | `number` | `1` | no |
| <a name="input_data_disk_size_gb"></a> [data\_disk\_size\_gb](#input\_data\_disk\_size\_gb) | Taille du disque donnees Minio en GB | `number` | `50` | no |
| <a name="input_datastore"></a> [datastore](#input\_datastore) | Datastore pour les disques | `string` | `"local-lvm"` | no |
| <a name="input_description"></a> [description](#input\_description) | Description du conteneur | `string` | `"Minio S3 - Managed by Terraform"` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Taille du disque systeme en GB | `number` | `8` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | Serveurs DNS | `list(string)` | <pre>[<br/>  "1.1.1.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | Passerelle par defaut | `string` | n/a | yes |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Hostname du conteneur Minio | `string` | n/a | yes |
| <a name="input_ip_address"></a> [ip\_address](#input\_ip\_address) | Adresse IP en notation CIDR (ex: 192.168.1.200/24) | `string` | n/a | yes |
| <a name="input_memory_mb"></a> [memory\_mb](#input\_memory\_mb) | RAM en MB | `number` | `512` | no |
| <a name="input_minio_console_port"></a> [minio\_console\_port](#input\_minio\_console\_port) | Port console Minio | `number` | `9001` | no |
| <a name="input_minio_port"></a> [minio\_port](#input\_minio\_port) | Port API Minio | `number` | `9000` | no |
| <a name="input_minio_root_password"></a> [minio\_root\_password](#input\_minio\_root\_password) | Mot de passe root Minio | `string` | n/a | yes |
| <a name="input_minio_root_user"></a> [minio\_root\_user](#input\_minio\_root\_user) | Utilisateur root Minio | `string` | `"minioadmin"` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Bridge reseau | `string` | `"vmbr0"` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | Cles SSH publiques | `list(string)` | n/a | yes |
| <a name="input_start_on_boot"></a> [start\_on\_boot](#input\_start\_on\_boot) | Demarrer automatiquement au boot | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags du conteneur | `list(string)` | <pre>[<br/>  "terraform",<br/>  "minio",<br/>  "s3"<br/>]</pre> | no |
| <a name="input_target_node"></a> [target\_node](#input\_target\_node) | Node Proxmox cible | `string` | n/a | yes |
| <a name="input_template_file_id"></a> [template\_file\_id](#input\_template\_file\_id) | ID du template LXC (ex: local:vztmpl/debian-13-standard\_13.1-2\_amd64.tar.zst) | `string` | `"local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"` | no |
| <a name="input_vlan_id"></a> [vlan\_id](#input\_vlan\_id) | VLAN ID (null si pas de VLAN) | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_console_url"></a> [console\_url](#output\_console\_url) | URL de la console Minio |
| <a name="output_container_id"></a> [container\_id](#output\_container\_id) | ID du conteneur LXC |
| <a name="output_endpoint_url"></a> [endpoint\_url](#output\_endpoint\_url) | URL de l'API S3 Minio |
| <a name="output_ip_address"></a> [ip\_address](#output\_ip\_address) | Adresse IP du conteneur |
<!-- END_TF_DOCS -->