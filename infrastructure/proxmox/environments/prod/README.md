# Environnement Production

Infrastructure de production deployee sur un node Proxmox VE dedie.

## Objectif

Heberger les workloads de production : VMs applicatives et conteneurs LXC avec firewall, monitoring et sauvegardes automatiques.

## Ressources deployees

| Type | Module | Description |
|------|--------|-------------|
| VMs | `modules/vm` | VMs cloud-init avec Docker optionnel |
| LXC | `modules/lxc` | Conteneurs legers (DNS, services) |
| Backup | `modules/backup` | Sauvegardes vzdump quotidiennes |
| Firewall | inline | Regles par VM (DROP input, regles explicites) |

## Reseau

| Parametre | Valeur par defaut |
|-----------|-------------------|
| Bridge | `vmbr0` |
| Gateway | `192.168.1.1` |
| CIDR | `/24` |
| DNS | `1.1.1.1`, `8.8.8.8` |

## Variables

Les variables sont reparties en 3 fichiers :

| Fichier | Source | Contenu |
|---------|--------|---------|
| `common_variables.tf` | symlink `shared/` | Proxmox endpoint, SSH, reseau |
| `env_variables.tf` | symlink `shared/` | VMs, containers, backup (partage avec lab) |
| `variables.tf` | local | `environment`, `monitoring_ssh_public_key` |

## Deploiement

```bash
# 1. Configurer les variables
cp terraform.tfvars.example terraform.tfvars
# Editer terraform.tfvars avec vos valeurs

# 2. Initialiser
terraform init

# 3. Planifier
terraform plan

# 4. Appliquer
terraform apply
```

## Operations courantes

```bash
# Voir l'etat
terraform output

# Connexion SSH aux VMs
terraform output ssh_commands

# Ajouter une VM : editer terraform.tfvars > vms = { ... }
terraform plan && terraform apply

# Ajouter la cle SSH monitoring (health checks)
# Recuperer depuis l'env monitoring : terraform output health_check_ssh_public_key
# Ajouter dans terraform.tfvars : monitoring_ssh_public_key = "ssh-ed25519 ..."
```

## Sauvegardes

| Parametre | Valeur |
|-----------|--------|
| Frequence | Quotidienne a 01:00 |
| Mode | snapshot (pas d'arret) |
| Compression | zstd |
| Retention | 7 daily, 4 weekly |

## Fichiers

```
prod/
├── main.tf                  # VMs, LXC, firewall, outputs
├── backup.tf                # Jobs vzdump
├── variables.tf             # Variables specifiques prod
├── common_variables.tf      # -> shared/common_variables.tf
├── env_variables.tf         # -> shared/env_variables.tf
├── firewall_locals.tf       # -> shared/firewall_locals.tf
├── provider.tf              # Configuration provider Proxmox
├── backend.tf               # Backend S3 (Minio)
├── versions.tf              # Contraintes de version
├── terraform.tfvars.example # Exemple de configuration
└── tests/                   # Tests d'integration
```
