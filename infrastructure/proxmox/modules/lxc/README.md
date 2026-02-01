# Module LXC Proxmox

Module Terraform pour deployer des conteneurs LXC sur Proxmox VE.

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
| [proxmox_virtual_environment_container.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container) | resource |
| [terraform_data.security_updates](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_auto_security_updates"></a> [auto\_security\_updates](#input\_auto\_security\_updates) | Configurer unattended-upgrades pour les mises a jour de securite (Ubuntu/Debian) | `bool` | `true` | no |
| <a name="input_backup_enabled"></a> [backup\_enabled](#input\_backup\_enabled) | Inclure ce conteneur dans les sauvegardes vzdump | `bool` | `true` | no |
| <a name="input_cpu_cores"></a> [cpu\_cores](#input\_cpu\_cores) | Nombre de cores CPU | `number` | `1` | no |
| <a name="input_datastore"></a> [datastore](#input\_datastore) | Datastore pour le rootfs | `string` | `"local-lvm"` | no |
| <a name="input_description"></a> [description](#input\_description) | Description du conteneur | `string` | `"Managed by Terraform"` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Taille du rootfs en GB | `number` | `8` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | Serveurs DNS | `list(string)` | <pre>[<br/>  "1.1.1.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_expiration_days"></a> [expiration\_days](#input\_expiration\_days) | Nombre de jours avant expiration du conteneur (null = pas d'expiration) | `number` | `null` | no |
| <a name="input_fuse"></a> [fuse](#input\_fuse) | Activer FUSE | `bool` | `false` | no |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | Passerelle par défaut | `string` | n/a | yes |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Hostname du conteneur | `string` | n/a | yes |
| <a name="input_ip_address"></a> [ip\_address](#input\_ip\_address) | Adresse IP en notation CIDR | `string` | n/a | yes |
| <a name="input_keyctl"></a> [keyctl](#input\_keyctl) | Activer keyctl | `bool` | `false` | no |
| <a name="input_memory_mb"></a> [memory\_mb](#input\_memory\_mb) | RAM en MB | `number` | `512` | no |
| <a name="input_mount_types"></a> [mount\_types](#input\_mount\_types) | Types de mount autorisés | `list(string)` | `[]` | no |
| <a name="input_mountpoints"></a> [mountpoints](#input\_mountpoints) | Mountpoints additionnels | <pre>list(object({<br/>    volume    = string<br/>    path      = string<br/>    size      = optional(number)<br/>    read_only = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_nesting"></a> [nesting](#input\_nesting) | Activer le nesting (Docker dans LXC) | `bool` | `false` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Bridge réseau | `string` | `"vmbr0"` | no |
| <a name="input_os_type"></a> [os\_type](#input\_os\_type) | Type d'OS (ubuntu, debian, alpine) | `string` | `"ubuntu"` | no |
| <a name="input_root_password"></a> [root\_password](#input\_root\_password) | Mot de passe root (optionnel) | `string` | `null` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | Clés SSH publiques | `list(string)` | n/a | yes |
| <a name="input_start_on_boot"></a> [start\_on\_boot](#input\_start\_on\_boot) | Démarrer automatiquement au boot | `bool` | `true` | no |
| <a name="input_swap_mb"></a> [swap\_mb](#input\_swap\_mb) | Swap en MB | `number` | `512` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags du conteneur | `list(string)` | <pre>[<br/>  "terraform"<br/>]</pre> | no |
| <a name="input_target_node"></a> [target\_node](#input\_target\_node) | Node Proxmox cible | `string` | n/a | yes |
| <a name="input_template_file_id"></a> [template\_file\_id](#input\_template\_file\_id) | ID du template LXC | `string` | n/a | yes |
| <a name="input_unprivileged"></a> [unprivileged](#input\_unprivileged) | Conteneur non privilégié (recommandé) | `bool` | `true` | no |
| <a name="input_vlan_id"></a> [vlan\_id](#input\_vlan\_id) | VLAN ID (null si pas de VLAN) | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_id"></a> [container\_id](#output\_container\_id) | ID du conteneur |
| <a name="output_hostname"></a> [hostname](#output\_hostname) | Hostname du conteneur |
| <a name="output_ipv4_address"></a> [ipv4\_address](#output\_ipv4\_address) | Adresse IPv4 |
| <a name="output_node_name"></a> [node\_name](#output\_node\_name) | Node Proxmox |
<!-- END_TF_DOCS -->
