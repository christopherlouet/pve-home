# Module VM Proxmox

Module Terraform pour deployer des VMs sur Proxmox VE via cloud-init.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_file.cloud_config](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_vm.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_disks"></a> [additional\_disks](#input\_additional\_disks) | Disques additionnels | <pre>list(object({<br/>    size         = number<br/>    datastore_id = optional(string, "local-lvm")<br/>    interface    = optional(string, "scsi")<br/>  }))</pre> | `[]` | no |
| <a name="input_additional_packages"></a> [additional\_packages](#input\_additional\_packages) | Packages supplementaires a installer via cloud-init | `list(string)` | `[]` | no |
| <a name="input_agent_enabled"></a> [agent\_enabled](#input\_agent\_enabled) | Activer QEMU Guest Agent | `bool` | `true` | no |
| <a name="input_auto_security_updates"></a> [auto\_security\_updates](#input\_auto\_security\_updates) | Installer et configurer unattended-upgrades pour les mises a jour de securite | `bool` | `true` | no |
| <a name="input_backup_enabled"></a> [backup\_enabled](#input\_backup\_enabled) | Inclure les disques de cette VM dans les sauvegardes vzdump | `bool` | `true` | no |
| <a name="input_cpu_cores"></a> [cpu\_cores](#input\_cpu\_cores) | Nombre de cores CPU | `number` | `2` | no |
| <a name="input_cpu_type"></a> [cpu\_type](#input\_cpu\_type) | Type de CPU (host, kvm64, etc.) | `string` | `"host"` | no |
| <a name="input_datastore"></a> [datastore](#input\_datastore) | Datastore pour le disque | `string` | `"local-lvm"` | no |
| <a name="input_description"></a> [description](#input\_description) | Description de la VM | `string` | `"Managed by Terraform"` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Taille du disque système en GB | `number` | `20` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | Serveurs DNS | `list(string)` | <pre>[<br/>  "1.1.1.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_expiration_days"></a> [expiration\_days](#input\_expiration\_days) | Nombre de jours avant expiration de la VM (null = pas d'expiration) | `number` | `null` | no |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | Passerelle par défaut | `string` | n/a | yes |
| <a name="input_install_docker"></a> [install\_docker](#input\_install\_docker) | Installer Docker via cloud-init | `bool` | `false` | no |
| <a name="input_install_qemu_agent"></a> [install\_qemu\_agent](#input\_install\_qemu\_agent) | Installer QEMU Guest Agent via cloud-init | `bool` | `true` | no |
| <a name="input_ip_address"></a> [ip\_address](#input\_ip\_address) | Adresse IP en notation CIDR (ex: 192.168.1.10/24) | `string` | n/a | yes |
| <a name="input_memory_mb"></a> [memory\_mb](#input\_memory\_mb) | RAM en MB | `number` | `2048` | no |
| <a name="input_name"></a> [name](#input\_name) | Nom de la VM | `string` | n/a | yes |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Bridge réseau | `string` | `"vmbr0"` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | Clés SSH publiques | `list(string)` | n/a | yes |
| <a name="input_start_on_boot"></a> [start\_on\_boot](#input\_start\_on\_boot) | Démarrer automatiquement au boot du node | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags de la VM | `list(string)` | <pre>[<br/>  "terraform"<br/>]</pre> | no |
| <a name="input_target_node"></a> [target\_node](#input\_target\_node) | Node Proxmox cible | `string` | n/a | yes |
| <a name="input_template_id"></a> [template\_id](#input\_template\_id) | ID du template à cloner | `number` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | Utilisateur cloud-init | `string` | `"ubuntu"` | no |
| <a name="input_vlan_id"></a> [vlan\_id](#input\_vlan\_id) | VLAN ID (null si pas de VLAN) | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ipv4_address"></a> [ipv4\_address](#output\_ipv4\_address) | Adresse IPv4 |
| <a name="output_mac_address"></a> [mac\_address](#output\_mac\_address) | Adresse MAC |
| <a name="output_name"></a> [name](#output\_name) | Nom de la VM |
| <a name="output_node_name"></a> [node\_name](#output\_node\_name) | Node Proxmox |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | ID de la VM |
<!-- END_TF_DOCS -->
