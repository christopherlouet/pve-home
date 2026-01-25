# PVE Home - Infrastructure Proxmox Homelab

Infrastructure as Code pour gérer un homelab Proxmox VE sur Intel NUC avec Terraform.

## Fonctionnalités

- **VMs avec cloud-init** : Provisionnement automatique avec Docker pré-installé
- **Conteneurs LXC** : Support des conteneurs légers avec option nesting
- **Modules réutilisables** : Modules Terraform pour VM et LXC
- **CI/CD** : Validation Terraform et scans de sécurité via GitHub Actions

## Prérequis

- [Proxmox VE 8.x ou 9.x](https://www.proxmox.com/) installé
- [Terraform >= 1.5](https://www.terraform.io/)
- Template VM cloud-init (Ubuntu) créé sur Proxmox
- Token API Proxmox avec les permissions appropriées

## Structure du projet

```
pve-home/
├── infrastructure/proxmox/
│   ├── modules/
│   │   ├── vm/           # Module VM avec cloud-init et Docker
│   │   └── lxc/          # Module conteneur LXC
│   └── environments/
│       └── home/         # Configuration homelab
├── docs/
│   └── INSTALLATION-PROXMOX.md
└── .github/workflows/    # CI/CD (Terraform fmt, validate, tfsec)
```

## Démarrage rapide

```bash
cd infrastructure/proxmox/environments/home

# Copier et configurer les variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Initialiser et déployer
terraform init
terraform plan
terraform apply
```

## Documentation

| Document | Description |
|----------|-------------|
| [Installation Proxmox](docs/INSTALLATION-PROXMOX.md) | Guide d'installation complet de Proxmox VE |
| [Infrastructure README](infrastructure/proxmox/README.md) | Documentation Terraform détaillée |

## Exemple de configuration

```hcl
# VM avec Docker pré-installé
"docker-server" = {
  ip     = "192.168.1.20"
  cores  = 4
  memory = 4096
  disk   = 50
  docker = true
  tags   = ["docker", "server"]
}

# Conteneur LXC léger
"nginx" = {
  ip      = "192.168.1.30"
  cores   = 1
  memory  = 512
  disk    = 8
  nesting = false
  tags    = ["proxy"]
}
```

## Sécurité

- Les fichiers sensibles (`*.tfvars`, `*.tfstate`) sont exclus du versioning
- Scans automatiques avec [tfsec](https://github.com/aquasecurity/tfsec) et [gitleaks](https://github.com/gitleaks/gitleaks)
- Ne jamais commiter de tokens ou clés SSH

## Licence

Usage personnel - Homelab
