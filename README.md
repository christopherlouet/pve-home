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
- **Détection de drift** : Vérification automatique des dérives Terraform avec métriques Prometheus
- **Health checks** : Surveillance de la santé des VMs, monitoring et Minio (SSH automatise via keypair dediee)
- **Deploiement monitoring** : Script `deploy.sh` pour provisionner scripts, tfvars et timers systemd sur la VM monitoring
- **Cycle de vie VMs** : Snapshots, expiration automatique, mises à jour de sécurité, rotation SSH
- **Tests Terraform natifs** : Validation, plan et non-regression des 5 modules avec `terraform test` et `mock_provider`
- **Resilience SSH** : Retry avec backoff exponentiel pour les connexions SSH dans les scripts d'operation
- **CI/CD** : Validation Terraform, tests, et scans de sécurité via GitHub Actions

## Prérequis

- [Proxmox VE 8.x ou 9.x](https://www.proxmox.com/) installé
- [Terraform >= 1.9](https://www.terraform.io/)
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
│   │   │   └── tests/           # Tests natifs Terraform
│   │   ├── lxc/                 # Module conteneur LXC
│   │   │   └── tests/           # Tests natifs Terraform
│   │   ├── backup/              # Module sauvegardes vzdump
│   │   │   └── tests/           # Tests natifs Terraform
│   │   ├── minio/               # Module Minio S3 (backend Terraform)
│   │   │   └── tests/           # Tests natifs Terraform
│   │   └── monitoring-stack/    # Stack Prometheus/Grafana/Alertmanager
│   │       └── tests/           # Tests natifs Terraform
│   └── environments/
│       ├── prod/                # PVE production (workloads)
│       ├── lab/                 # PVE lab/test (workloads)
│       └── monitoring/          # PVE dedie monitoring
├── docs/
│   ├── INSTALLATION-PROXMOX.md
│   ├── BACKUP-RESTORE.md
│   ├── DISASTER-RECOVERY.md
│   ├── DRIFT-DETECTION.md
│   ├── HEALTH-CHECKS.md
│   ├── ALERTING.md
│   └── VM-LIFECYCLE.md
├── scripts/
│   ├── lib/                     # Bibliotheque commune (common.sh)
│   ├── restore/                 # Scripts de restauration
│   ├── drift/                   # Detection de drift Terraform
│   ├── health/                  # Health checks infrastructure
│   ├── lifecycle/               # Cycle de vie VMs/LXC (snapshots, expiration, SSH)
│   └── systemd/                 # Timers et services systemd
├── tests/                       # Tests BATS pour les scripts
│   ├── restore/
│   ├── drift/
│   ├── health/
│   └── lifecycle/
└── .github/workflows/           # CI/CD + Security + Terraform Tests
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
| [Infrastructure README](infrastructure/proxmox/README.md) | Documentation Terraform détaillée (modules, environnements, tests) |
| [Sauvegarde & Restauration](docs/BACKUP-RESTORE.md) | Procédures manuelles et automatisées pour restaurer VMs, state Terraform et composants |
| [Disaster Recovery](docs/DISASTER-RECOVERY.md) | Runbook pas-à-pas pour reconstruction complète après défaillance majeure |
| [Détection de drift](docs/DRIFT-DETECTION.md) | Détection automatique des dérives Terraform avec métriques Prometheus |
| [Health Checks](docs/HEALTH-CHECKS.md) | Vérification de santé de l'infrastructure (VMs, monitoring, Minio) |
| [Alertes Telegram](docs/ALERTING.md) | Configuration des notifications Telegram (création bot, chat_id, troubleshooting) |
| [Cycle de vie VMs](docs/VM-LIFECYCLE.md) | Snapshots, expiration, mises à jour de sécurité, rotation SSH |
| [Index des scripts](scripts/README.md) | Index complet de tous les scripts d'opération |

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

28 alertes reparties en 7 groupes supervisent l'infrastructure :

#### Node alerts (9)

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| `HostDown` | Critical | Host injoignable depuis > 2 min |
| `HighCpuUsage` | Warning | CPU > 85% depuis 5 min |
| `HighMemoryUsage` | Warning | RAM > 85% depuis 5 min |
| `HighDiskUsage` | Warning | Disque > 85% depuis 5 min |
| `DiskAlmostFull` | Critical | Disque > 95% depuis 1 min |
| `NodeFilesystemAlmostOutOfInodes` | Warning | Inodes > 90% depuis 5 min |
| `SystemdServiceFailed` | Warning | Service systemd en echec depuis 5 min |
| `HighLoadAverage` | Warning | Load average (15m) > 2x le nombre de CPUs depuis 10 min |
| `HighNetworkErrors` | Warning | Erreurs reseau > 10/s depuis 5 min |

#### Proxmox alerts (5)

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| `ProxmoxNodeDown` | Critical | Node Proxmox injoignable depuis > 2 min |
| `ProxmoxVMStopped` | Warning | VM arretee depuis > 10 min |
| `ProxmoxHighCpuUsage` | Warning | CPU Proxmox > 90% depuis 10 min |
| `ProxmoxHighMemoryUsage` | Warning | RAM Proxmox > 90% depuis 10 min |
| `ProxmoxStorageAlmostFull` | Warning | Stockage Proxmox > 85% depuis 5 min |

#### Prometheus alerts (3)

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| `PrometheusTargetMissing` | Warning | Target down depuis 5 min |
| `PrometheusConfigReloadFailed` | Critical | Echec du rechargement de la config Prometheus |
| `PrometheusRuleEvaluationFailures` | Warning | Erreurs d'evaluation des regles d'alerte |

#### Backup alerts (3)

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| `GuestsNotBackedUp` | Warning | VMs/CTs sans sauvegarde configuree |
| `BackupStorageAlmostFull` | Warning | Stockage backup > 80% |
| `BackupStorageCritical` | Critical | Stockage backup > 95% |

#### Drift alerts (3)

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| `DriftDetected` | Warning | Drift Terraform detecte sur un environnement |
| `DriftCheckFailed` | Critical | Le check de drift a echoue |
| `DriftCheckStale` | Warning | Aucun check de drift depuis > 48h |

#### Health alerts (2)

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| `InfraHealthCheckFailed` | Warning | Un composant infrastructure est en echec |
| `HealthCheckStale` | Warning | Aucun health check depuis > 8h |

#### Lifecycle alerts (3)

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| `LabVMExpired` | Warning | VMs lab expirees et arretees |
| `SnapshotOlderThanWeek` | Info | Snapshots anciens nettoyes |
| `VMRebootRequired` | Warning | Reboot necessaire depuis > 24h |

Les alertes sont configurées dans `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml`.

Voir [environments/monitoring/terraform.tfvars.example](infrastructure/proxmox/environments/monitoring/terraform.tfvars.example) pour la configuration et [docs/ALERTING.md](docs/ALERTING.md) pour le guide de configuration Telegram.

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

## Scripts d'opération

Des scripts shell automatisent les opérations d'infrastructure depuis votre machine de travail. Tous supportent `--dry-run` et `--help`.

### Restauration

| Script | Description | Usage |
|--------|-------------|-------|
| **restore-vm.sh** | Restaurer une VM/LXC depuis vzdump | `./scripts/restore/restore-vm.sh <vmid> --node <node>` |
| **restore-tfstate.sh** | Restaurer state Terraform depuis Minio | `./scripts/restore/restore-tfstate.sh --env prod --list` |
| **rebuild-minio.sh** | Reconstruire le conteneur Minio | `./scripts/restore/rebuild-minio.sh --force` |
| **rebuild-monitoring.sh** | Reconstruire la stack monitoring | `./scripts/restore/rebuild-monitoring.sh --mode restore` |
| **verify-backups.sh** | Vérifier l'intégrité des sauvegardes | `./scripts/restore/verify-backups.sh --full` |

### Drift & Health

| Script | Description | Usage |
|--------|-------------|-------|
| **check-drift.sh** | Détecter les dérives Terraform | `./scripts/drift/check-drift.sh --env prod` |
| **check-health.sh** | Vérifier la santé de l'infrastructure | `./scripts/health/check-health.sh --all --force` |
| **deploy.sh** | Deployer scripts et timers sur la VM monitoring | `./scripts/deploy.sh` |

### Cycle de vie VMs/LXC

| Script | Description | Usage |
|--------|-------------|-------|
| **snapshot-vm.sh** | Créer/lister/restaurer/supprimer des snapshots | `./scripts/lifecycle/snapshot-vm.sh create 100` |
| **cleanup-snapshots.sh** | Nettoyer les snapshots automatiques expirés | `./scripts/lifecycle/cleanup-snapshots.sh --max-age 7` |
| **expire-lab-vms.sh** | Arrêter les VMs lab expirées | `./scripts/lifecycle/expire-lab-vms.sh --dry-run` |
| **rotate-ssh-keys.sh** | Ajouter/révoquer des clés SSH | `./scripts/lifecycle/rotate-ssh-keys.sh --add-key ~/.ssh/key.pub --env prod` |

Index complet : [scripts/README.md](scripts/README.md) | Disaster Recovery : [docs/DISASTER-RECOVERY.md](docs/DISASTER-RECOVERY.md)

## Tests

Le projet utilise deux frameworks de test complementaires totalisant **~270 tests Terraform** et **254 tests BATS**.

### Tests Terraform (modules)

Les 5 modules sont testes avec le framework natif `terraform test` (>= 1.9) et `mock_provider`, avec 3 types de tests par module :

| Type | Fichier | Description |
|------|---------|-------------|
| **Validation** | `valid_inputs.tftest.hcl` | Validation des variables d'entree (types, bornes, formats) |
| **Plan** | `plan_resources.tftest.hcl` | Verification des ressources generees par `terraform plan` |
| **Non-regression** | `regression.tftest.hcl` | Protection contre la reintroduction de bugs corriges |

```bash
# Tester un module
cd infrastructure/proxmox/modules/vm && terraform init -backend=false && terraform test

# Tester tous les modules
for m in vm lxc backup minio monitoring-stack; do
  (cd infrastructure/proxmox/modules/$m && terraform init -backend=false && terraform test)
done
```

### Tests BATS (scripts shell)

Les scripts shell sont testes avec [BATS](https://github.com/bats-core/bats-core) (254 tests) :

| Domaine | Tests | Couverture |
|---------|-------|------------|
| **restore/** | 169 | Restauration VMs, tfstate, Minio, monitoring, verification |
| **drift/** | 14 | Detection de drift Terraform |
| **health/** | 14 | Health checks infrastructure |
| **lifecycle/** | 21 | Snapshots, expiration, rotation SSH |
| **root** | 36 | deploy.sh, post-install Proxmox |

```bash
# Tous les tests
bats tests/

# Par domaine
bats tests/restore/
bats tests/drift/
bats tests/health/
bats tests/lifecycle/
```

Les tests Terraform sont executes en CI via le job `terraform-test` dans `.github/workflows/ci.yml`.

## Securite

- Les fichiers sensibles (`*.tfvars`, `*.tfstate`) sont exclus du versioning
- Ne jamais commiter de tokens ou cles SSH
- Scans automatiques en CI : [Gitleaks](https://github.com/gitleaks/gitleaks) (secrets), [tfsec](https://github.com/aquasecurity/tfsec) (Terraform), [Checkov](https://www.checkov.io/) (policy-as-code), [Trivy](https://trivy.dev/) (IaC misconfigurations)
- Resultats SARIF uploades dans l'onglet Security de GitHub
- SSH hardening : Fichier `known_hosts` dédié (`~/.ssh/homelab_known_hosts`) avec `StrictHostKeyChecking=yes` par défaut. Mode init disponible via `SSH_INIT_MODE=true` pour les nouveaux hôtes
- Credentials Minio passes via variable d'environnement `MC_HOST_local` (evite l'exposition dans la liste des processus)

## Licence

Ce projet est sous licence [GPL-3.0](LICENSE).
