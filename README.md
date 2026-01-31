# PVE Home - Infrastructure Proxmox Homelab

Infrastructure as Code pour gérer un homelab Proxmox VE sur Intel NUC avec Terraform.

## Fonctionnalités

- **VMs avec cloud-init** : Provisionnement automatique avec Docker pré-installé
- **Conteneurs LXC** : Support des conteneurs légers avec option nesting
- **Stack Monitoring** : Prometheus, Grafana, Alertmanager sur PVE dédié (monitoring centralisé)
- **Modules réutilisables** : Modules Terraform pour VM, LXC et monitoring
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
│   ├── versions.tf              # Versions de reference (provider + Terraform)
│   ├── _shared/                 # Templates de configuration reutilisables
│   ├── modules/
│   │   ├── vm/                  # Module VM avec cloud-init et Docker
│   │   ├── lxc/                 # Module conteneur LXC
│   │   └── monitoring-stack/    # Stack Prometheus/Grafana/Alertmanager
│   └── environments/
│       ├── prod/                # PVE production (workloads)
│       ├── lab/                 # PVE lab/test (workloads)
│       └── monitoring/          # PVE dedie monitoring
├── docs/
│   └── INSTALLATION-PROXMOX.md
└── .github/workflows/           # CI/CD (Terraform fmt, validate, markdown-lint)
```

## Démarrage rapide

```bash
cd infrastructure/proxmox/environments/prod

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
# VM avec Docker et monitoring activé
"docker-server" = {
  ip            = "192.168.1.20"
  cores         = 4
  memory        = 4096
  disk          = 50
  docker        = true
  node_exporter = true  # Expose les métriques pour Prometheus
  tags          = ["docker", "server", "monitored"]
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

## Stack Monitoring

Le monitoring est déployé sur un **PVE dédié** (`environments/monitoring/`) et supervise tous les autres PVE :

- **Prometheus** : Collecte des métriques (nodes, VMs, LXC, Proxmox)
- **Grafana** : Visualisation et dashboards
- **Alertmanager** : Notifications via Telegram
- **PVE Exporter** : Métriques spécifiques Proxmox

```
PVE Prod (192.168.1.100)  ──┐
PVE Lab  (192.168.1.110)  ──┼── scrape ──> PVE Monitoring (192.168.1.50)
PVE Mon  (192.168.1.50)   ──┘              └─ Prometheus + Grafana + Alertmanager
```

Voir [environments/monitoring/terraform.tfvars.example](infrastructure/proxmox/environments/monitoring/terraform.tfvars.example) pour la configuration.

## Sécurité

- Les fichiers sensibles (`*.tfvars`, `*.tfstate`) sont exclus du versioning
- Ne jamais commiter de tokens ou clés SSH
- Scans optionnels recommandés : [tfsec](https://github.com/aquasecurity/tfsec) et [gitleaks](https://github.com/gitleaks/gitleaks)

## Licence

Ce projet est sous licence [GPL-3.0](LICENSE).
