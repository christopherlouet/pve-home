# Scripts d'operation

Index de tous les scripts d'exploitation de l'infrastructure homelab Proxmox VE.

Tous les scripts supportent `--dry-run` (simulation) et `--help` (aide).

## Structure

```
scripts/
├── lib/                     # Bibliotheque commune
│   └── common.sh            # Fonctions partagees (logging, SSH, parsing, dry-run)
├── restore/                 # Restauration d'infrastructure
│   ├── restore-vm.sh        # Restaurer une VM/LXC depuis vzdump
│   ├── restore-tfstate.sh   # Restaurer state Terraform depuis Minio S3
│   ├── rebuild-minio.sh     # Reconstruire le conteneur Minio
│   ├── rebuild-monitoring.sh# Reconstruire la stack monitoring
│   └── verify-backups.sh    # Verifier l'integrite des sauvegardes
├── drift/                   # Detection de drift Terraform
│   └── check-drift.sh       # Comparer l'etat reel vs declare
├── health/                  # Health checks infrastructure
│   └── check-health.sh      # Verifier VMs, monitoring, Minio
├── lifecycle/               # Cycle de vie VMs/LXC
│   ├── snapshot-vm.sh       # Creer/lister/restaurer/supprimer snapshots
│   ├── cleanup-snapshots.sh # Nettoyer les snapshots auto- expires
│   ├── expire-lab-vms.sh    # Arreter les VMs lab expirees
│   └── rotate-ssh-keys.sh   # Ajouter/revoquer des cles SSH
├── systemd/                 # Timers et services systemd
│   ├── pve-drift-check.*    # Detection de drift (06:00 quotidien)
│   ├── pve-health-check.*   # Health checks (toutes les 4h)
│   ├── pve-cleanup-snapshots.* # Nettoyage snapshots (05:00 quotidien)
│   └── pve-expire-lab.*     # Expiration VMs lab (07:00 quotidien)
├── deploy.sh                # Deploiement des scripts sur la VM monitoring
└── post-install-proxmox.sh  # Script post-installation Proxmox
```

## Restauration

Scripts pour restaurer l'infrastructure apres un incident. Documentation complete : [docs/DISASTER-RECOVERY.md](../docs/DISASTER-RECOVERY.md).

| Script | Description | Exemple |
|--------|-------------|---------|
| `restore-vm.sh` | Restaurer une VM/LXC depuis vzdump | `./restore/restore-vm.sh 100 --node pve-prod` |
| `restore-tfstate.sh` | Restaurer state Terraform depuis Minio | `./restore/restore-tfstate.sh --env prod --list` |
| `rebuild-minio.sh` | Reconstruire le conteneur Minio | `./restore/rebuild-minio.sh --force` |
| `rebuild-monitoring.sh` | Reconstruire la stack monitoring | `./restore/rebuild-monitoring.sh --mode restore` |
| `verify-backups.sh` | Verifier l'integrite des sauvegardes | `./restore/verify-backups.sh --full` |

Documentation detaillee : [scripts/restore/README.md](restore/README.md)

## Detection de drift

Compare l'etat reel de l'infrastructure avec la configuration Terraform declaree. Genere des metriques Prometheus et des rapports dans `/var/log/pve-drift/`.

```bash
# Verifier un environnement
./drift/check-drift.sh --env prod

# Verifier tous les environnements
./drift/check-drift.sh --all

# Mode simulation
./drift/check-drift.sh --env prod --dry-run
```

Documentation : [docs/DRIFT-DETECTION.md](../docs/DRIFT-DETECTION.md)

## Health checks

Verifie la sante de l'infrastructure : ping/SSH des VMs, endpoints monitoring (Prometheus, Grafana, Alertmanager), et sante Minio.

```bash
# Verifier un environnement
./health/check-health.sh --env prod

# Verifier tout
./health/check-health.sh --all --force

# Specifier l'utilisateur SSH (defaut: ubuntu)
./health/check-health.sh --env prod --ssh-user root

# Verifier uniquement le monitoring
./health/check-health.sh --all --component monitoring

# Exclure certaines VMs
./health/check-health.sh --env prod --exclude "192.168.1.20,192.168.1.21"
```

**Note** : Les IPs des VMs sont extraites uniquement du bloc `vms = { ... }` dans les fichiers tfvars (les adresses DNS, gateway, etc. sont ignorees). L'utilisateur SSH par defaut est `ubuntu` (cloud-init VMs). L'Alertmanager est ignore si Telegram est desactive.

Documentation : [docs/HEALTH-CHECKS.md](../docs/HEALTH-CHECKS.md)

## Cycle de vie VMs/LXC

Outils pour gerer le cycle de vie complet : snapshots, expiration, mises a jour de securite, rotation SSH.

### Snapshots

```bash
# Creer un snapshot
./lifecycle/snapshot-vm.sh create 100
./lifecycle/snapshot-vm.sh create 100 --name "pre-upgrade"

# Lister les snapshots
./lifecycle/snapshot-vm.sh list 100

# Restaurer
./lifecycle/snapshot-vm.sh rollback 100 --name "pre-upgrade"

# Supprimer
./lifecycle/snapshot-vm.sh delete 100 --name "pre-upgrade"
```

### Nettoyage automatique

Les snapshots prefixes par `auto-` sont supprimes apres 7 jours :

```bash
./lifecycle/cleanup-snapshots.sh
./lifecycle/cleanup-snapshots.sh --max-age 14
```

### Expiration des VMs lab

Les VMs avec un tag `expires:YYYY-MM-DD` sont automatiquement arretees une fois expirees. Ne s'applique qu'a l'environnement lab.

```bash
./lifecycle/expire-lab-vms.sh --dry-run
./lifecycle/expire-lab-vms.sh --force
```

### Rotation SSH

```bash
# Ajouter une cle
./lifecycle/rotate-ssh-keys.sh --add-key ~/.ssh/new_key.pub --env prod

# Revoquer une cle
./lifecycle/rotate-ssh-keys.sh --remove-key "SHA256:abc123..." --env prod
```

Documentation : [docs/VM-LIFECYCLE.md](../docs/VM-LIFECYCLE.md)

## Deploiement sur la VM monitoring

Le script `deploy.sh` provisionne automatiquement la VM monitoring avec les scripts, fichiers tfvars et timers systemd via rsync/SSH.

```bash
# Deployer tout (scripts, tfvars, systemd)
./deploy.sh

# Mode simulation
./deploy.sh --dry-run

# Specifier l'utilisateur SSH
./deploy.sh --ssh-user ubuntu
```

Le script :
1. Detecte l'IP de la VM monitoring depuis `environments/monitoring/terraform.tfvars`
2. Synchronise les scripts et la bibliotheque commune vers `/opt/pve-home/`
3. Deploie les fichiers tfvars de chaque environnement (prod, lab, monitoring)
4. Installe et active les timers systemd

## Timers systemd

Les operations recurentes sont automatisees via des timers systemd :

| Timer | Schedule | Script | Description |
|-------|----------|--------|-------------|
| `pve-cleanup-snapshots` | 05:00 quotidien | `cleanup-snapshots.sh` | Nettoyage snapshots auto- |
| `pve-drift-check` | 06:00 quotidien | `check-drift.sh` | Detection de drift Terraform |
| `pve-expire-lab` | 07:00 quotidien | `expire-lab-vms.sh` | Expiration VMs lab |
| `pve-health-check` | Toutes les 4h | `check-health.sh` | Health checks |

### Installation

L'installation des timers est automatisee par `deploy.sh`. Pour une installation manuelle :

```bash
# Copier les fichiers
sudo cp systemd/pve-*.service systemd/pve-*.timer /etc/systemd/system/

# Activer les timers
sudo systemctl daemon-reload
sudo systemctl enable --now pve-drift-check.timer
sudo systemctl enable --now pve-health-check.timer
sudo systemctl enable --now pve-cleanup-snapshots.timer
sudo systemctl enable --now pve-expire-lab.timer

# Verifier le statut
systemctl list-timers 'pve-*'
```

## Bibliotheque commune

La bibliotheque `lib/common.sh` fournit des fonctions partagees par tous les scripts :

- Logging colore (`log_info`, `log_success`, `log_warn`, `log_error`)
- Parsing d'arguments (`--dry-run`, `--force`, `--help`)
- Execution SSH (`ssh_exec`)
- Verification des prerequis (`check_prereqs`, `check_ssh_access`)
- Parsing de tfvars (`parse_tfvars`, `get_pve_node`, `get_pve_ip`)
- Validation d'entrees (`sanitize_input`, `validate_input`)

Documentation : [scripts/lib/README.md](lib/README.md)

## Metriques Prometheus

Les scripts de drift, health et lifecycle generent des metriques au format textfile collector dans `/var/lib/prometheus/node-exporter/` :

| Metrique | Script | Description |
|----------|--------|-------------|
| `pve_drift_status` | check-drift.sh | 0=ok, 1=drift, 2=erreur |
| `pve_drift_resources_changed` | check-drift.sh | Nombre de ressources en drift |
| `pve_drift_last_check_timestamp` | check-drift.sh | Timestamp du dernier check |
| `pve_health_*` | check-health.sh | Sante par composant |
| `pve_snapshot_cleanup_*` | cleanup-snapshots.sh | Snapshots supprimes |
| `pve_lab_expiration_*` | expire-lab-vms.sh | VMs expirees |

## Tests

Les scripts sont testes avec [BATS](https://github.com/bats-core/bats-core) :

```bash
# Tous les tests
bats tests/

# Par domaine
bats tests/restore/     # 29 tests (common.sh + scripts)
bats tests/drift/       # 13 tests
bats tests/health/      # 13 tests
bats tests/lifecycle/   # 20 tests (snapshot, cleanup, expire, rotate)
```
