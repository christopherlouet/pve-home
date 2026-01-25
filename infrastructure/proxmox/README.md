# Infrastructure Proxmox - Homelab

Gestion de l'infrastructure Proxmox VE avec Terraform sur Intel NUC.

## Structure

```
infrastructure/proxmox/
├── main.tf                    # Configuration provider Proxmox
├── variables.tf               # Variables globales
├── README.md                  # Ce fichier
├── modules/
│   ├── vm/
│   │   └── main.tf           # Module VM avec cloud-init et Docker
│   └── lxc/
│       └── main.tf           # Module conteneur LXC
└── environments/
    └── home/
        ├── main.tf           # Infrastructure homelab
        ├── variables.tf      # Variables de l'environnement
        └── terraform.tfvars.example
```

## Prérequis

1. **Proxmox VE installé** - Voir `docs/INSTALLATION-PROXMOX.md`
2. **Terraform >= 1.5** installé
3. **Token API Proxmox** créé
4. **Template VM cloud-init** (ID 9000) créé
5. **Template LXC** téléchargé

## Démarrage rapide

### 1. Installer Terraform

```bash
# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Ou via tfenv (recommandé)
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
tfenv install latest
tfenv use latest
```

### 2. Configurer les credentials

```bash
cd infrastructure/proxmox/environments/home

# Copier et éditer le fichier de configuration
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

Remplir avec vos informations :
- `proxmox_endpoint` : URL de votre Proxmox (ex: `https://192.168.1.100:8006`)
- `proxmox_api_token` : Token API créé lors de l'installation
- `network_gateway` : Votre routeur/box (ex: `192.168.1.1`)
- `ssh_public_keys` : Votre clé SSH publique

### 3. Initialiser Terraform

```bash
# Initialiser (télécharge le provider)
terraform init

# Vérifier la configuration
terraform validate

# Voir ce qui va être créé
terraform plan
```

### 4. Créer l'infrastructure

```bash
# Appliquer les changements
terraform apply

# Confirmer avec 'yes'
```

## Personnalisation

### Ajouter une VM

Éditer `environments/home/main.tf` et ajouter dans `local.vms` :

```hcl
"ma-nouvelle-vm" = {
  ip       = "192.168.1.15"
  cores    = 2
  memory   = 2048
  disk     = 30
  tags     = ["web", "custom"]
}
```

### VM avec Docker pré-installé

```hcl
"docker-server" = {
  ip       = "192.168.1.20"
  cores    = 4
  memory   = 4096
  disk     = 50
  docker   = true  # Installe Docker + Docker Compose via cloud-init
  tags     = ["docker", "server"]
}
```

### Ajouter un conteneur LXC

Éditer `environments/home/main.tf` et ajouter dans `local.containers` :

```hcl
"mon-service" = {
  ip      = "192.168.1.25"
  cores   = 1
  memory  = 512
  disk    = 10
  nesting = false
  tags    = ["service"]
}
```

### Conteneur avec Docker (nesting)

```hcl
"docker-lxc" = {
  ip      = "192.168.1.30"
  cores   = 2
  memory  = 2048
  disk    = 30
  nesting = true   # Active le support Docker
  tags    = ["docker"]
}
```

## Commandes utiles

```bash
# Voir l'état actuel
terraform show

# Planifier sans appliquer
terraform plan

# Appliquer les changements
terraform apply

# Détruire une ressource spécifique
terraform destroy -target='module.vms["docker"]'

# Détruire tout (attention!)
terraform destroy

# Rafraîchir l'état depuis Proxmox
terraform refresh

# Importer une VM existante
terraform import 'module.vms["legacy"].proxmox_virtual_environment_vm.this' 'pve/qemu/100'
```

## Connexion aux VMs/LXC

Après création, Terraform affiche les commandes SSH :

```bash
# VM (utilisateur ubuntu par défaut)
ssh ubuntu@192.168.1.10

# LXC (utilisateur root par défaut)
ssh root@192.168.1.20
```

## Troubleshooting

### Erreur "connection refused"
- Vérifier que l'IP Proxmox est correcte
- Vérifier que le port 8006 est accessible
- Vérifier que `proxmox_insecure = true` si certificat auto-signé

### Erreur "authentication failed"
- Vérifier le format du token : `user@realm!token-name=secret`
- Vérifier que le token a été créé avec `--privsep=0`
- Vérifier les permissions du rôle

### VM ne démarre pas
- Vérifier que le template existe (ID 9000)
- Vérifier l'espace disque sur le datastore
- Vérifier que VT-x est activé dans le BIOS

### IP non attribuée
- Vérifier que cloud-init fonctionne dans le template
- Vérifier que le QEMU Guest Agent est installé
- Attendre quelques secondes après le démarrage

## Ressources

- [Provider bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Documentation Proxmox VE](https://pve.proxmox.com/wiki/Main_Page)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
