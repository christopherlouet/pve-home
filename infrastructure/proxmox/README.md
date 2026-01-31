# Infrastructure Proxmox - Multi-environnement

Gestion d'infrastructure Proxmox VE avec Terraform. Supporte plusieurs instances PVE independantes via des environnements Terraform distincts, avec un monitoring centralise sur un PVE dedie.

## Structure

```
infrastructure/proxmox/
├── versions.tf                    # Versions de reference (provider + Terraform)
├── README.md                      # Ce fichier
├── _shared/
│   ├── backend.tf.example         # Exemple de backend distant (S3, Consul)
│   └── provider.tf.example        # Exemple de configuration provider
├── modules/
│   ├── vm/
│   │   └── main.tf               # Module VM avec cloud-init et Docker
│   ├── lxc/
│   │   └── main.tf               # Module conteneur LXC
│   └── monitoring-stack/
│       ├── main.tf               # Stack Prometheus + Grafana + Alertmanager
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── prod/                      # Instance PVE "production" (workloads)
    │   ├── versions.tf            # Versions Terraform/provider
    │   ├── provider.tf            # Configuration provider Proxmox
    │   ├── main.tf                # VMs, LXC, outputs
    │   ├── variables.tf           # Variables de l'environnement
    │   └── terraform.tfvars.example
    ├── lab/                       # Instance PVE "lab/test" (workloads)
    │   ├── versions.tf
    │   ├── provider.tf
    │   ├── main.tf
    │   ├── variables.tf
    │   └── terraform.tfvars.example
    └── monitoring/                # Instance PVE dediee monitoring
        ├── versions.tf
        ├── provider.tf
        ├── main.tf                # Locals et outputs (pas de workloads)
        ├── monitoring.tf          # Stack monitoring centralisee
        ├── variables.tf
        └── terraform.tfvars.example
```

## Architecture 3 environnements

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   PVE Prod          │     │   PVE Lab            │     │   PVE Monitoring    │
│   192.168.1.100     │     │   192.168.1.110      │     │   192.168.1.50      │
│                     │     │                      │     │                     │
│  ┌───────────────┐  │     │  ┌───────────────┐   │     │  ┌───────────────┐  │
│  │ web-server    │  │     │  │ file-server   │   │     │  │ Prometheus    │  │
│  │ db-server     │  │     │  │ dev-server    │   │     │  │ Grafana       │  │
│  │ ...           │  │     │  │ ...           │   │     │  │ Alertmanager  │  │
│  └───────────────┘  │     │  └───────────────┘   │     │  └───────┬───────┘  │
│                     │     │                      │     │          │          │
└─────────┬───────────┘     └──────────┬───────────┘     └──────────┼──────────┘
          │                            │                            │
          └────────────────────────────┴────────────────────────────┘
                              Scrape metriques
                         (node_exporter, pve-exporter)
```

### Separation des responsabilites

| Environnement | Role | Contenu |
|---------------|------|---------|
| **prod** | Workloads production | VMs applicatives (web-server, db-server, etc.) |
| **lab** | Workloads lab/test | VMs applicatives (file-server, dev-server, etc.) |
| **monitoring** | Monitoring centralise | Stack Prometheus/Grafana/Alertmanager uniquement |

Le PVE monitoring est dedie : il n'heberge aucun workload applicatif. Il supervise tous les nodes Proxmox et toutes les VMs des autres environnements via `remote_targets`.

## Concept multi-environnement

Chaque environnement correspond a une **instance Proxmox separee** (serveur different). Les environnements sont totalement independants :

- **State Terraform isole** : chaque environnement a son propre `terraform.tfstate`
- **Credentials distincts** : chaque instance a son propre `terraform.tfvars`
- **Modules partages** : les modules `vm`, `lxc` et `monitoring-stack` sont communs

### Quand creer un nouvel environnement ?

- Vous avez un second serveur Proxmox (bureau, site distant, lab, etc.)
- Vous voulez isoler completement le state Terraform entre instances

## Prerequis

1. **Proxmox VE installe** - Voir `docs/INSTALLATION-PROXMOX.md`
2. **Terraform >= 1.5** installe
3. **Token API Proxmox** cree
4. **Template VM cloud-init** (ID 9000) cree
5. **Template LXC** telecharge

## Demarrage rapide

### 1. Installer Terraform

```bash
# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Ou via tfenv (recommande)
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
tfenv install latest
tfenv use latest
```

### 2. Configurer un environnement

```bash
cd infrastructure/proxmox/environments/prod

# Copier et editer le fichier de configuration
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

Remplir avec vos informations :
- `proxmox_endpoint` : URL de votre Proxmox (ex: `https://192.168.1.100:8006`)
- `proxmox_api_token` : Token API cree lors de l'installation
- `network_gateway` : Votre routeur/box (ex: `192.168.1.1`)
- `ssh_public_keys` : Votre cle SSH publique

### 3. Initialiser et deployer

```bash
# Initialiser (telecharge le provider)
terraform init

# Verifier la configuration
terraform validate

# Voir ce qui va etre cree
terraform plan

# Appliquer les changements
terraform apply
```

### 4. Deployer le monitoring centralise

```bash
cd infrastructure/proxmox/environments/monitoring

cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Configurer :
# - proxmox_endpoint : URL du PVE dedie monitoring
# - monitoring.proxmox_nodes : TOUS les PVE a superviser
# - remote_targets : VMs des autres PVE a monitorer

terraform init
terraform plan
terraform apply
```

## Creer un nouvel environnement

Pour ajouter une nouvelle instance PVE :

```bash
# Copier un environnement existant comme base
cp -r infrastructure/proxmox/environments/prod infrastructure/proxmox/environments/mon-env

# Editer les fichiers
cd infrastructure/proxmox/environments/mon-env

# Adapter l'environnement par defaut dans variables.tf
# (changer le default de la variable "environment")

# Configurer les credentials
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Initialiser et deployer
terraform init
terraform plan
terraform apply
```

Chaque environnement est autonome : vous pouvez `terraform apply` dans un environnement sans affecter les autres.

Pour que les VMs du nouvel environnement soient monitorees, ajouter leurs IPs dans `remote_targets` de l'environnement monitoring.

## Personnalisation

### Ajouter une VM

Editer `terraform.tfvars` de votre environnement :

```hcl
vms = {
  "ma-nouvelle-vm" = {
    ip     = "192.168.1.15"
    cores  = 2
    memory = 2048
    disk   = 30
    tags   = ["web", "custom"]
  }
}
```

### VM avec Docker pre-installe

```hcl
vms = {
  "docker-server" = {
    ip     = "192.168.1.20"
    cores  = 4
    memory = 4096
    disk   = 50
    docker = true
    tags   = ["docker", "server"]
  }
}
```

### Ajouter un conteneur LXC

```hcl
containers = {
  "mon-service" = {
    ip      = "192.168.1.25"
    cores   = 1
    memory  = 512
    disk    = 10
    nesting = false
    tags    = ["service"]
  }
}
```

### Ajouter une VM distante au monitoring

Dans `environments/monitoring/terraform.tfvars` :

```hcl
remote_targets = [
  {
    name = "ma-nouvelle-vm"
    ip   = "192.168.1.15"
    port = 9100
    labels = {
      app         = "ma-nouvelle-vm"
      type        = "vm"
      environment = "prod"
    }
  },
]
```

## Backend distant (optionnel)

Par defaut, le state est stocke localement. Pour un usage multi-machine, voir `_shared/backend.tf.example` et copier le fichier `backend.tf` dans votre environnement.

## Commandes utiles

```bash
# Se placer dans l'environnement souhaite
cd infrastructure/proxmox/environments/prod

# Voir l'etat actuel
terraform show

# Planifier sans appliquer
terraform plan

# Appliquer les changements
terraform apply

# Detruire une ressource specifique
terraform destroy -target='module.vms["docker"]'

# Detruire tout (attention!)
terraform destroy

# Rafraichir l'etat depuis Proxmox
terraform refresh
```

## Connexion aux VMs/LXC

Apres creation, Terraform affiche les commandes SSH :

```bash
# VM (utilisateur ubuntu par defaut)
ssh ubuntu@192.168.1.10

# LXC (utilisateur root par defaut)
ssh root@192.168.1.20
```

## Troubleshooting

### Erreur "connection refused"
- Verifier que l'IP Proxmox est correcte
- Verifier que le port 8006 est accessible
- Verifier que `proxmox_insecure = true` si certificat auto-signe

### Erreur "authentication failed"
- Verifier le format du token : `user@realm!token-name=secret`
- Verifier que le token a ete cree avec `--privsep=0`
- Verifier les permissions du role

### VM ne demarre pas
- Verifier que le template existe (ID 9000)
- Verifier l'espace disque sur le datastore
- Verifier que VT-x est active dans le BIOS

### IP non attribuee
- Verifier que cloud-init fonctionne dans le template
- Verifier que le QEMU Guest Agent est installe
- Attendre quelques secondes apres le demarrage

### Monitoring ne scrape pas les VMs distantes
- Verifier que node_exporter ecoute sur le port 9100 des VMs cibles
- Verifier que le firewall autorise le trafic sur le port 9100

## Ressources

- [Provider bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Documentation Proxmox VE](https://pve.proxmox.com/wiki/Main_Page)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
