# Environnement Lab

Infrastructure de test et experimentation deployee sur un node Proxmox VE dedie.

## Objectif

Environnement isole pour tester des configurations, valider des changements avant la prod, et experimenter avec de nouvelles technologies.

## Ressources deployees

| Type | Module | Description |
|------|--------|-------------|
| VMs | `modules/vm` | VMs cloud-init avec Docker optionnel |
| LXC | `modules/lxc` | Conteneurs legers |
| Backup | `modules/backup` | Sauvegardes vzdump hebdomadaires |

## Reseau

| Parametre | Valeur par defaut |
|-----------|-------------------|
| Bridge | `vmbr0` |
| Gateway | `192.168.1.1` |
| CIDR | `/24` |
| DNS | `1.1.1.1`, `8.8.8.8` |

## Variables

| Fichier | Source | Contenu |
|---------|--------|---------|
| `common_variables.tf` | symlink `shared/` | Proxmox endpoint, SSH, reseau |
| `env_variables.tf` | symlink `shared/` | VMs, containers, backup (partage avec prod) |
| `variables.tf` | local | `environment` |

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

# Ajouter une VM de test
# Editer terraform.tfvars > vms = { "test-vm" = { ip = "...", ... } }
terraform plan && terraform apply

# Detruire une VM de test
# Retirer l'entree de terraform.tfvars > vms
terraform plan && terraform apply
```

## Sauvegardes

| Parametre | Valeur |
|-----------|--------|
| Frequence | Hebdomadaire (dimanche 03:00) |
| Mode | snapshot |
| Compression | zstd |
| Retention | 3 weekly |

## Fichiers

```
lab/
├── main.tf                  # VMs, LXC, outputs
├── backup.tf                # Jobs vzdump
├── variables.tf             # Variables specifiques lab
├── common_variables.tf      # -> shared/common_variables.tf
├── env_variables.tf         # -> shared/env_variables.tf
├── provider.tf              # Configuration provider Proxmox
├── backend.tf               # Backend S3 (Minio)
├── versions.tf              # Contraintes de version
├── terraform.tfvars.example # Exemple de configuration
└── tests/                   # Tests d'integration
```
