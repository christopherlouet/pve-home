# Module Tooling Stack

Deploie une VM avec les services d'outillage : Step-ca (PKI), Harbor (Registry), Authentik (SSO), Traefik (Proxy).

## Usage

```hcl
module "tooling" {
  source = "../../modules/tooling-stack"

  target_node = "pve-mon"
  template_id = 9000
  ip_address  = "192.168.1.60"
  gateway     = "192.168.1.1"
  ssh_keys    = var.ssh_public_keys

  domain_suffix = "home.arpa"

  step_ca_enabled  = true
  step_ca_password = var.step_ca_password

  harbor_enabled        = true
  harbor_admin_password = var.harbor_admin_password

  authentik_enabled            = true
  authentik_secret_key         = var.authentik_secret_key
  authentik_bootstrap_password = var.authentik_bootstrap_password

  traefik_enabled = true
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.94.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.94.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.2.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_file.cloud_config](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_vm.tooling](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [random_password.authentik_pg](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.harbor_core_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.harbor_csrf_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.harbor_db](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.harbor_jobservice_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [tls_private_key.root_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.root_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_authentik_bootstrap_email"></a> [authentik\_bootstrap\_email](#input\_authentik\_bootstrap\_email) | Email pour l'admin Authentik | `string` | `"admin@home.arpa"` | no |
| <a name="input_authentik_bootstrap_password"></a> [authentik\_bootstrap\_password](#input\_authentik\_bootstrap\_password) | Mot de passe initial pour l'admin Authentik (akadmin) | `string` | n/a | yes |
| <a name="input_authentik_enabled"></a> [authentik\_enabled](#input\_authentik\_enabled) | Activer Authentik comme fournisseur SSO | `bool` | `true` | no |
| <a name="input_authentik_secret_key"></a> [authentik\_secret\_key](#input\_authentik\_secret\_key) | Cle secrete pour Authentik (min 24 caracteres) | `string` | n/a | yes |
| <a name="input_datastore"></a> [datastore](#input\_datastore) | Datastore pour les disques | `string` | `"local-lvm"` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | Serveurs DNS | `list(string)` | <pre>[<br/>  "1.1.1.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_domain_suffix"></a> [domain\_suffix](#input\_domain\_suffix) | Suffixe de domaine pour les URLs locales (ex: home.arpa) | `string` | `"home.arpa"` | no |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | Passerelle reseau | `string` | n/a | yes |
| <a name="input_harbor_admin_password"></a> [harbor\_admin\_password](#input\_harbor\_admin\_password) | Mot de passe admin Harbor | `string` | n/a | yes |
| <a name="input_harbor_data_volume"></a> [harbor\_data\_volume](#input\_harbor\_data\_volume) | Chemin du volume de donnees Harbor | `string` | `"/data/harbor"` | no |
| <a name="input_harbor_db_password"></a> [harbor\_db\_password](#input\_harbor\_db\_password) | Mot de passe pour la base PostgreSQL Harbor | `string` | `"harbor_db_password_default_change_me"` | no |
| <a name="input_harbor_enabled"></a> [harbor\_enabled](#input\_harbor\_enabled) | Activer Harbor comme registre d'images Docker | `bool` | `true` | no |
| <a name="input_harbor_trivy_enabled"></a> [harbor\_trivy\_enabled](#input\_harbor\_trivy\_enabled) | Activer le scanner de vulnerabilites Trivy dans Harbor | `bool` | `true` | no |
| <a name="input_ip_address"></a> [ip\_address](#input\_ip\_address) | Adresse IP de la VM tooling (sans CIDR) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Nom de base pour les ressources tooling | `string` | `"tooling"` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Bridge reseau Proxmox | `string` | `"vmbr0"` | no |
| <a name="input_network_cidr"></a> [network\_cidr](#input\_network\_cidr) | CIDR du reseau (ex: 24) | `number` | `24` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | Cles SSH publiques | `list(string)` | n/a | yes |
| <a name="input_step_ca_cert_duration"></a> [step\_ca\_cert\_duration](#input\_step\_ca\_cert\_duration) | Duree de validite des certificats (format Go duration, ex: 8760h = 1 an) | `string` | `"8760h"` | no |
| <a name="input_step_ca_enabled"></a> [step\_ca\_enabled](#input\_step\_ca\_enabled) | Activer Step-ca comme autorite de certification interne | `bool` | `true` | no |
| <a name="input_step_ca_password"></a> [step\_ca\_password](#input\_step\_ca\_password) | Mot de passe pour la CA Step-ca | `string` | n/a | yes |
| <a name="input_step_ca_provisioner_name"></a> [step\_ca\_provisioner\_name](#input\_step\_ca\_provisioner\_name) | Nom du provisioner ACME pour Step-ca | `string` | `"acme"` | no |
| <a name="input_step_ca_root_cn"></a> [step\_ca\_root\_cn](#input\_step\_ca\_root\_cn) | Common Name pour le certificat racine CA | `string` | `"Homelab Root CA"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags pour la VM | `list(string)` | <pre>[<br/>  "terraform",<br/>  "tooling"<br/>]</pre> | no |
| <a name="input_target_node"></a> [target\_node](#input\_target\_node) | Node Proxmox pour deployer la VM tooling | `string` | n/a | yes |
| <a name="input_template_id"></a> [template\_id](#input\_template\_id) | ID du template VM cloud-init | `number` | n/a | yes |
| <a name="input_traefik_enabled"></a> [traefik\_enabled](#input\_traefik\_enabled) | Activer Traefik comme reverse proxy pour les services | `bool` | `true` | no |
| <a name="input_username"></a> [username](#input\_username) | Utilisateur cloud-init | `string` | `"ubuntu"` | no |
| <a name="input_vm_config"></a> [vm\_config](#input\_vm\_config) | Configuration des ressources VM | <pre>object({<br/>    cores     = optional(number, 4)<br/>    memory    = optional(number, 6144)<br/>    disk      = optional(number, 30)<br/>    data_disk = optional(number, 100)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_authentik_admin_url"></a> [authentik\_admin\_url](#output\_authentik\_admin\_url) | URL de l'interface admin Authentik |
| <a name="output_authentik_admin_username"></a> [authentik\_admin\_username](#output\_authentik\_admin\_username) | Nom d'utilisateur admin Authentik |
| <a name="output_authentik_enabled"></a> [authentik\_enabled](#output\_authentik\_enabled) | Indique si Authentik est active |
| <a name="output_ca_install_instructions"></a> [ca\_install\_instructions](#output\_ca\_install\_instructions) | Instructions pour installer le certificat racine CA |
| <a name="output_dns_records"></a> [dns\_records](#output\_dns\_records) | Enregistrements DNS a creer pour les services |
| <a name="output_domain_suffix"></a> [domain\_suffix](#output\_domain\_suffix) | Suffixe de domaine utilise |
| <a name="output_harbor_admin_username"></a> [harbor\_admin\_username](#output\_harbor\_admin\_username) | Nom d'utilisateur admin Harbor |
| <a name="output_harbor_enabled"></a> [harbor\_enabled](#output\_harbor\_enabled) | Indique si Harbor est active |
| <a name="output_harbor_registry_url"></a> [harbor\_registry\_url](#output\_harbor\_registry\_url) | URL du registre Harbor pour docker login |
| <a name="output_ip_address"></a> [ip\_address](#output\_ip\_address) | Adresse IP de la VM tooling |
| <a name="output_monitoring_targets"></a> [monitoring\_targets](#output\_monitoring\_targets) | Cibles de monitoring pour Prometheus |
| <a name="output_node_name"></a> [node\_name](#output\_node\_name) | Nom du node Proxmox |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | Commande SSH pour se connecter a la VM |
| <a name="output_step_ca_enabled"></a> [step\_ca\_enabled](#output\_step\_ca\_enabled) | Indique si Step-ca est active |
| <a name="output_step_ca_fingerprint"></a> [step\_ca\_fingerprint](#output\_step\_ca\_fingerprint) | Fingerprint du certificat racine CA (pour step ca bootstrap) |
| <a name="output_step_ca_root_cert"></a> [step\_ca\_root\_cert](#output\_step\_ca\_root\_cert) | Certificat racine CA au format PEM |
| <a name="output_traefik_enabled"></a> [traefik\_enabled](#output\_traefik\_enabled) | Indique si Traefik est active |
| <a name="output_urls"></a> [urls](#output\_urls) | URLs des services deployes |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | ID de la VM tooling dans Proxmox |
| <a name="output_vm_name"></a> [vm\_name](#output\_vm\_name) | Nom de la VM tooling |
<!-- END_TF_DOCS -->

## Documentation associee

- [Tooling Stack](../../../../docs/TOOLING-STACK.md) - Guide complet de la stack outillage
- [PKI Installation](../../../../docs/PKI-INSTALLATION.md) - Installation du certificat racine CA
- [Architecture](../../../../docs/ARCHITECTURE.md) - Vue d'ensemble de l'architecture
- [Testing](../../../../docs/TESTING.md) - Guide des tests Terraform et BATS