# PVE Home - Infrastructure Proxmox Homelab

Infrastructure as Code pour gérer un homelab Proxmox VE sur Intel NUC avec Terraform.

## Fonctionnalités

- **VMs avec cloud-init** : Provisionnement automatique avec Docker pré-installé
- **Conteneurs LXC** : Support des conteneurs légers avec option nesting
- **Sauvegardes automatiques** : Vzdump quotidien/hebdomadaire avec rétention configurable par environnement
- **State Terraform sécurisé** : Backend S3 Minio avec versioning pour récupération en cas d'erreur
- **Stack Monitoring** : Prometheus, Grafana, Alertmanager sur PVE dédié avec dashboards et alertes backup
- **Scripts de restauration** : Restauration automatisée de VMs, state Terraform et composants critiques
- **Modules réutilisables** : Modules Terraform pour VM, LXC, backup, Minio et monitoring
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
│   │   ├── backup/              # Module sauvegardes vzdump
│   │   ├── minio/               # Module Minio S3 (backend Terraform)
│   │   └── monitoring-stack/    # Stack Prometheus/Grafana/Alertmanager
│   └── environments/
│       ├── prod/                # PVE production (workloads)
│       ├── lab/                 # PVE lab/test (workloads)
│       └── monitoring/          # PVE dedie monitoring
├── docs/
│   ├── INSTALLATION-PROXMOX.md
│   ├── BACKUP-RESTORE.md
│   └── DISASTER-RECOVERY.md
├── scripts/
│   ├── lib/                     # Bibliotheque commune
│   └── restore/                 # Scripts de restauration
└── .github/workflows/           # CI/CD + Security (fmt, validate, tfsec, Checkov, Trivy)
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
| [Infrastructure README](infrastructure/proxmox/README.md) | Documentation Terraform détaillée (modules, environnements) |
| [Sauvegarde & Restauration](docs/BACKUP-RESTORE.md) | Procédures manuelles et automatisées pour restaurer VMs, state Terraform et composants |
| [Disaster Recovery](docs/DISASTER-RECOVERY.md) | Runbook pas-à-pas pour reconstruction complète après défaillance majeure |

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

## Sauvegardes et Restauration

L'infrastructure supporte des sauvegardes automatiques de toutes les VMs et conteneurs via **vzdump** natif Proxmox, avec versioning du state Terraform via **Minio S3**.

### Architecture des sauvegardes

```
PVE Prod (192.168.1.100)  ──┐     ┌─────────────────────┐
  VMs/LXC                  ├─→ vzdump quotidien       │
                           │   (storage local)        │
PVE Lab (192.168.1.110)   ──┤                         │
  VMs/LXC                  │   PVE Monitoring        │
                           │   (192.168.1.50)        │
PVE Mon (192.168.1.50)    ──┤                         │
  Monitoring + Minio      │   ┌─────────────────────┐│
                           │   │ Minio S3 (LXC)      ││
                           └──→│ tfstate buckets     ││
                               │ (versioning actif)  ││
                               └─────────────────────┘│
```

### Politique de rétention par environnement

| Environnement | Schedule | Rétention | Storage |
|---------------|----------|-----------|---------|
| **prod** | Quotidien 01:00 | 7 daily, 4 weekly | local |
| **lab** | Dimanche 03:00 | 3 weekly | local |
| **monitoring** | Quotidien 02:00 | 7 daily | local |

Pour les procédures de restauration détaillées et les scripts automatisés, voir [docs/BACKUP-RESTORE.md](docs/BACKUP-RESTORE.md) et [docs/DISASTER-RECOVERY.md](docs/DISASTER-RECOVERY.md).

## Monitoring & Alertes

Le monitoring est déployé sur un **PVE dédié** (`environments/monitoring/`) et supervise tous les autres PVE :

- **Prometheus** : Collecte des métriques (nodes, VMs, LXC, Proxmox, sauvegardes)
- **Grafana** : Visualisation avec dashboards auto-provisionnés
- **Alertmanager** : Notifications via Telegram
- **PVE Exporter** : Métriques spécifiques Proxmox (un module par node)
- **Node Exporter** : Métriques système (CPU, RAM, disque, réseau) sur la VM et les hosts PVE

```
PVE Prod (192.168.1.100)  ──┐
PVE Lab  (192.168.1.110)  ──┼── scrape ──> PVE Monitoring (192.168.1.50)
PVE Mon  (192.168.1.50)   ──┘              └─ Prometheus + Grafana + Alertmanager
```

### Dashboards Grafana

5 dashboards sont auto-provisionnés au déploiement :

| Dashboard | Source | Description |
|-----------|--------|-------------|
| **Nodes Overview** | Custom | Vue d'ensemble de tous les noeuds (CPU, RAM, Disk, Network) |
| **Node Exporter Full** | [#1860](https://grafana.com/grafana/dashboards/1860) | Métriques détaillées par noeud (CPU, disque, réseau) |
| **PVE Exporter** | [#10347](https://grafana.com/grafana/dashboards/10347) | VMs, LXC, stockage, statut par node Proxmox |
| **Backup Overview** | Custom | Supervision des sauvegardes (espace, alertes, statut) |
| **Prometheus** | [#3662](https://grafana.com/grafana/dashboards/3662) | Self-monitoring (targets, règles, samples) |

Les dashboards sont stockés dans `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/` et déployés via le provisioning Grafana.

### Alertes Prometheus

Les alertes suivantes supervisent l'infrastructure et les sauvegardes :

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| `BackupJobFailed` | Critical | Un job vzdump a échoué dans les dernières 24h |
| `BackupJobMissing` | Warning | Aucune sauvegarde réussie depuis 48h |
| `BackupStorageAlmostFull` | Warning | Stockage backup utilisé à plus de 80% |

Les alertes sont configurées dans `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml`.

Voir [environments/monitoring/terraform.tfvars.example](infrastructure/proxmox/environments/monitoring/terraform.tfvars.example) pour la configuration.

## Modules Terraform

Les modules réutilisables permettent de provisionner l'infrastructure rapidement :

| Module | Localisation | Description |
|--------|--------------|-------------|
| **vm** | `modules/vm/` | VM Proxmox avec cloud-init, Docker optionnel |
| **lxc** | `modules/lxc/` | Conteneur LXC léger |
| **backup** | `modules/backup/` | Sauvegardes automatiques vzdump avec scheduling |
| **minio** | `modules/minio/` | Conteneur Minio S3 pour backend Terraform (versioning) |
| **monitoring-stack** | `modules/monitoring-stack/` | Stack Prometheus + Grafana + Alertmanager |

Documentation complète : [infrastructure/proxmox/README.md](infrastructure/proxmox/README.md)

## Scripts de Restauration

Des scripts shell automatisent les opérations de restauration et diagnostic depuis votre machine de travail :

| Script | Localisation | Description | Usage |
|--------|--------------|-------------|-------|
| **restore-vm.sh** | `scripts/restore/` | Restaurer une VM/LXC depuis vzdump | `./scripts/restore/restore-vm.sh <vmid> --node <node-name>` |
| **restore-tfstate.sh** | `scripts/restore/` | Restaurer state Terraform depuis Minio | `./scripts/restore/restore-tfstate.sh --env prod --list` |
| **rebuild-minio.sh** | `scripts/restore/` | Reconstruire le conteneur Minio | `./scripts/restore/rebuild-minio.sh --force` |
| **rebuild-monitoring.sh** | `scripts/restore/` | Reconstruire la stack monitoring | `./scripts/restore/rebuild-monitoring.sh --mode restore` |
| **verify-backups.sh** | `scripts/restore/` | Vérifier l'intégrité des sauvegardes | `./scripts/restore/verify-backups.sh --full` |

Tous les scripts supportent `--dry-run` pour un test sans risque et `--help` pour l'aide détaillée.

Documentation complète : [docs/DISASTER-RECOVERY.md](docs/DISASTER-RECOVERY.md)

## Securite

- Les fichiers sensibles (`*.tfvars`, `*.tfstate`) sont exclus du versioning
- Ne jamais commiter de tokens ou cles SSH
- Scans automatiques en CI : [Gitleaks](https://github.com/gitleaks/gitleaks) (secrets), [tfsec](https://github.com/aquasecurity/tfsec) (Terraform), [Checkov](https://www.checkov.io/) (policy-as-code), [Trivy](https://trivy.dev/) (IaC misconfigurations)
- Resultats SARIF uploades dans l'onglet Security de GitHub

## Licence

Ce projet est sous licence [GPL-3.0](LICENSE).
