# Module Monitoring Stack

Module Terraform pour deployer une stack de monitoring (Prometheus, Grafana, Alertmanager) sur Proxmox VE.

## Fonctionnalités

- **Prometheus** : Collecte de métriques avec alertes
- **Grafana** : Visualisation avec dashboards pré-configurés
- **Alertmanager** : Notifications Telegram
- **PVE Exporter** : Métriques Proxmox
- **Traefik** : Reverse proxy (optionnel)
- **Loki** : Centralisation des logs (optionnel)
- **Uptime Kuma** : Surveillance de disponibilité (optionnel)

## Configuration Prometheus personnalisée

Pour ajouter des scrape configs avancés (relabel_configs, blackbox, etc.), utiliser la variable `custom_scrape_configs` avec du YAML inline :

```hcl
custom_scrape_configs = <<-YAML
  - job_name: 'mon-app-node-exporter'
    static_configs:
      - targets: ['192.168.1.101:9100']
        labels:
          app: 'mon-app'
          env: 'staging'

  - job_name: 'mon-app-postgres'
    static_configs:
      - targets: ['192.168.1.101:9187']
        labels:
          app: 'mon-app'

  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://mon-app.example.com
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 192.168.1.101:9115
YAML
```

> **Note** : Le YAML doit être indenté avec 2 espaces et commencer au niveau des jobs (tiret `-`).

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.93.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.2.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_file.cloud_config](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_vm.monitoring](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [tls_private_key.health_check](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_scrape_targets"></a> [additional\_scrape\_targets](#input\_additional\_scrape\_targets) | Cibles additionnelles a scraper (VMs avec node\_exporter sur le meme reseau) | <pre>list(object({<br/>    name   = string<br/>    ip     = string<br/>    port   = optional(number, 9100)<br/>    labels = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_backup_alerting_enabled"></a> [backup\_alerting\_enabled](#input\_backup\_alerting\_enabled) | Activer les alertes de supervision des sauvegardes vzdump | `bool` | `true` | no |
| <a name="input_datastore"></a> [datastore](#input\_datastore) | Datastore pour les disques | `string` | `"local-lvm"` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | Serveurs DNS | `list(string)` | <pre>[<br/>  "1.1.1.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | Passerelle reseau | `string` | n/a | yes |
| <a name="input_grafana_admin_password"></a> [grafana\_admin\_password](#input\_grafana\_admin\_password) | Mot de passe admin Grafana | `string` | n/a | yes |
| <a name="input_ip_address"></a> [ip\_address](#input\_ip\_address) | Adresse IP de la VM monitoring (sans CIDR) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Nom de base pour les ressources monitoring | `string` | `"monitoring"` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Bridge reseau Proxmox | `string` | `"vmbr0"` | no |
| <a name="input_network_cidr"></a> [network\_cidr](#input\_network\_cidr) | CIDR du reseau (ex: 24) | `number` | `24` | no |
| <a name="input_prometheus_retention_days"></a> [prometheus\_retention\_days](#input\_prometheus\_retention\_days) | Duree de retention des metriques en jours | `number` | `30` | no |
| <a name="input_prometheus_retention_size"></a> [prometheus\_retention\_size](#input\_prometheus\_retention\_size) | Taille max de retention (ex: 40GB) | `string` | `"40GB"` | no |
| <a name="input_proxmox_nodes"></a> [proxmox\_nodes](#input\_proxmox\_nodes) | Liste des nodes Proxmox a monitorer avec credentials par node | <pre>list(object({<br/>    name        = string<br/>    ip          = string<br/>    token_value = string<br/>  }))</pre> | n/a | yes |
| <a name="input_pve_exporter_token_name"></a> [pve\_exporter\_token\_name](#input\_pve\_exporter\_token\_name) | Nom du token API pour pve-exporter | `string` | `"prometheus"` | no |
| <a name="input_pve_exporter_user"></a> [pve\_exporter\_user](#input\_pve\_exporter\_user) | Utilisateur API pour pve-exporter (format: user@realm) | `string` | `"prometheus@pve"` | no |
| <a name="input_remote_scrape_targets"></a> [remote\_scrape\_targets](#input\_remote\_scrape\_targets) | Cibles distantes a scraper (VMs sur d'autres PVE/reseaux) | <pre>list(object({<br/>    name   = string<br/>    ip     = string<br/>    port   = optional(number, 9100)<br/>    labels = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | Cles SSH publiques | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags pour la VM | `list(string)` | <pre>[<br/>  "terraform",<br/>  "monitoring"<br/>]</pre> | no |
| <a name="input_target_node"></a> [target\_node](#input\_target\_node) | Node Proxmox pour deployer la VM monitoring | `string` | n/a | yes |
| <a name="input_telegram_bot_token"></a> [telegram\_bot\_token](#input\_telegram\_bot\_token) | Token du bot Telegram | `string` | `""` | no |
| <a name="input_telegram_chat_id"></a> [telegram\_chat\_id](#input\_telegram\_chat\_id) | Chat ID Telegram pour les notifications | `string` | `""` | no |
| <a name="input_telegram_enabled"></a> [telegram\_enabled](#input\_telegram\_enabled) | Activer les notifications Telegram | `bool` | `true` | no |
| <a name="input_template_id"></a> [template\_id](#input\_template\_id) | ID du template VM cloud-init | `number` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | Utilisateur cloud-init | `string` | `"ubuntu"` | no |
| <a name="input_vm_config"></a> [vm\_config](#input\_vm\_config) | Configuration des ressources VM | <pre>object({<br/>    cores     = optional(number, 2)<br/>    memory    = optional(number, 4096)<br/>    disk      = optional(number, 30)<br/>    data_disk = optional(number, 50)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_health_check_ssh_public_key"></a> [health\_check\_ssh\_public\_key](#output\_health\_check\_ssh\_public\_key) | Cle SSH publique de la VM monitoring pour les health checks |
| <a name="output_ip_address"></a> [ip\_address](#output\_ip\_address) | Adresse IP de la VM monitoring |
| <a name="output_node_name"></a> [node\_name](#output\_node\_name) | Node Proxmox |
| <a name="output_scrape_targets"></a> [scrape\_targets](#output\_scrape\_targets) | Liste des cibles Prometheus configurees |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | Commande SSH pour se connecter |
| <a name="output_urls"></a> [urls](#output\_urls) | URLs des services monitoring |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | ID de la VM monitoring |
| <a name="output_vm_name"></a> [vm\_name](#output\_vm\_name) | Nom de la VM monitoring |
<!-- END_TF_DOCS -->
