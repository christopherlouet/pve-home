# Sauvegardes et Restauration - Proxmox VE Homelab

Guide des procedures de sauvegarde et restauration pour l'infrastructure Proxmox VE.

## Architecture des sauvegardes

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   PVE Prod          │     │   PVE Lab            │     │   PVE Monitoring    │
│   192.168.1.100     │     │   192.168.1.110      │     │   192.168.1.50      │
│                     │     │                      │     │                     │
│  vzdump quotidien   │     │  vzdump hebdo        │     │  vzdump quotidien   │
│  01:00, 7j retain   │     │  dim 03:00, 3 sem    │     │  02:00, 7j retain   │
│  storage: local     │     │  storage: local      │     │  storage: local     │
└─────────────────────┘     └──────────────────────┘     │                     │
                                                         │  Minio S3 (LXC)    │
                                                         │  tfstate buckets    │
                                                         └─────────────────────┘
```

## 1. Restaurer une VM depuis vzdump

### Lister les sauvegardes disponibles

```bash
# Se connecter au node Proxmox
ssh root@<ip-pve>

# Lister toutes les sauvegardes sur le storage local
pvesh get /nodes/<node>/storage/local/content --content backup

# Filtrer par VM ID
pvesh get /nodes/<node>/storage/local/content --content backup --vmid <vmid>
```

### Restaurer une VM

```bash
# Restaurer avec le meme VMID (ecrase la VM existante)
qmrestore /var/lib/vz/dump/vzdump-qemu-<vmid>-<date>.vma.zst <vmid>

# Restaurer avec un nouveau VMID
qmrestore /var/lib/vz/dump/vzdump-qemu-<vmid>-<date>.vma.zst <nouveau-vmid>

# Restaurer sur un storage specifique
qmrestore /var/lib/vz/dump/vzdump-qemu-<vmid>-<date>.vma.zst <vmid> --storage local-lvm

# Restaurer sans demarrer automatiquement
qmrestore /var/lib/vz/dump/vzdump-qemu-<vmid>-<date>.vma.zst <vmid> --start 0
```

### Verification post-restauration

```bash
# Verifier que la VM est listee
qm list

# Demarrer la VM
qm start <vmid>

# Verifier l'etat
qm status <vmid>

# Tester la connectivite
ping <ip-vm>
ssh ubuntu@<ip-vm>
```

## 2. Restaurer un conteneur LXC depuis vzdump

### Lister les sauvegardes LXC

```bash
ssh root@<ip-pve>

# Lister les sauvegardes de type lxc
pvesh get /nodes/<node>/storage/local/content --content backup --vmid <ctid>
```

### Restaurer un conteneur

```bash
# Restaurer avec le meme CTID
pct restore <ctid> /var/lib/vz/dump/vzdump-lxc-<ctid>-<date>.tar.zst

# Restaurer avec un nouveau CTID
pct restore <nouveau-ctid> /var/lib/vz/dump/vzdump-lxc-<ctid>-<date>.tar.zst

# Restaurer sur un storage specifique
pct restore <ctid> /var/lib/vz/dump/vzdump-lxc-<ctid>-<date>.tar.zst --storage local-lvm

# Restaurer sans demarrer
pct restore <ctid> /var/lib/vz/dump/vzdump-lxc-<ctid>-<date>.tar.zst --start 0
```

### Verification post-restauration

```bash
# Verifier le conteneur
pct list

# Demarrer
pct start <ctid>

# Verifier le statut
pct status <ctid>

# Tester
ping <ip-lxc>
ssh root@<ip-lxc>
```

## 3. Restaurer un etat Terraform depuis Minio

### Script automatise (recommande)

Le script `scripts/restore/restore-tfstate.sh` automatise toutes les operations de restauration du state Terraform.

```bash
# Lister les versions disponibles
./scripts/restore/restore-tfstate.sh --env monitoring --list

# Restaurer une version specifique
./scripts/restore/restore-tfstate.sh --env monitoring --restore <version-id>

# Mode fallback (si Minio est indisponible)
./scripts/restore/restore-tfstate.sh --env monitoring --fallback

# Retour au backend Minio apres reparation
./scripts/restore/restore-tfstate.sh --env monitoring --return

# Mode dry-run (afficher les actions sans executer)
./scripts/restore/restore-tfstate.sh --env monitoring --list --dry-run

# Aide complete
./scripts/restore/restore-tfstate.sh --help
```

**Avantages du script**:
- Configuration automatique du client mc depuis terraform.tfvars
- Sauvegarde automatique de la version courante avant restauration (EF-006)
- Verification avec `terraform plan` apres restauration
- Support du mode dry-run pour tester sans risque
- Gestion des erreurs avec messages clairs

### Procedure manuelle (si script indisponible)

#### Prerequis

Le backend Minio S3 avec versioning active permet de restaurer les versions precedentes du state Terraform.

#### Lister les versions du state

```bash
# Configurer le client mc (Minio Client)
mc alias set homelab http://<minio-ip>:9000 minioadmin <password>

# Lister les versions du fichier state
mc ls --versions homelab/tfstate-prod/terraform.tfstate
mc ls --versions homelab/tfstate-lab/terraform.tfstate
mc ls --versions homelab/tfstate-monitoring/terraform.tfstate
```

#### Restaurer une version precedente

```bash
# Telecharger une version specifique
mc cp --version-id <version-id> homelab/tfstate-prod/terraform.tfstate ./terraform.tfstate.backup

# Verifier le contenu
terraform show -json ./terraform.tfstate.backup | python3 -m json.tool | head -50

# Uploader comme version courante
mc cp ./terraform.tfstate.backup homelab/tfstate-prod/terraform.tfstate
```

#### Verification

```bash
cd infrastructure/proxmox/environments/prod

# Reinitialiser le backend
terraform init -reconfigure

# Verifier l'etat
terraform plan
# → Aucun changement si le state est coherent avec l'infra
```

## 4. Fallback : revenir au backend local si Minio est indisponible

Si le conteneur Minio est inaccessible, vous pouvez temporairement revenir au backend local.

### Script automatise (recommande)

```bash
# Basculer vers le backend local (si Minio indisponible)
./scripts/restore/restore-tfstate.sh --env monitoring --fallback

# Le script:
# 1. Sauvegarde backend.tf original (backend.tf.minio-backup)
# 2. Remplace backend.tf par un backend local vide
# 3. Execute 'terraform init -migrate-state'
# 4. Verifie avec 'terraform plan'

# Une fois Minio retabli, retour au backend S3:
./scripts/restore/restore-tfstate.sh --env monitoring --return

# Le script:
# 1. Verifie que Minio est accessible (healthcheck)
# 2. Restore backend.tf depuis le backup
# 3. Execute 'terraform init -migrate-state'
# 4. Supprime le fichier backup
```

### Procedure manuelle (si script indisponible)

#### Procedure de fallback

```bash
cd infrastructure/proxmox/environments/<env>

# 1. Commenter le backend S3 dans backend.tf
# Remplacer le contenu par:
# terraform {
#   # Backend S3 Minio temporairement desactive
# }

# 2. Migrer vers le backend local
terraform init -migrate-state
# → Repondre "yes" pour copier l'etat vers le backend local

# 3. Verifier
terraform plan
```

#### Retour au backend Minio apres reparation

```bash
# 1. Verifier que Minio est accessible
curl http://<minio-ip>:9000/minio/health/live

# 2. Decommenter le backend S3 dans backend.tf

# 3. Migrer vers le backend S3
terraform init -migrate-state
# → Repondre "yes" pour copier l'etat vers Minio
```

## 5. Diagnostiquer un echec de sauvegarde

### Verifier les logs vzdump

```bash
ssh root@<ip-pve>

# Logs du dernier job vzdump
journalctl -u vzdump --since "24 hours ago"

# Logs detailles dans /var/log
ls -la /var/log/vzdump/
cat /var/log/vzdump/vzdump-*.log
```

### Verifier les jobs de sauvegarde configures

```bash
# Lister tous les jobs de sauvegarde
pvesh get /cluster/backup --output-format json-pretty

# Verifier un job specifique
pvesh get /cluster/backup/<job-id>

# Lancer un job manuellement pour tester
vzdump <vmid> --storage local --mode snapshot --compress zstd
```

### Verifier l'espace disque

```bash
# Espace sur le storage de sauvegarde
pvesh get /nodes/<node>/storage/local/status

# Espace disque systeme
df -h /var/lib/vz/dump/
```

### Verifier via Prometheus/Grafana

1. Ouvrir Grafana (`http://<monitoring-ip>:3000`)
2. Aller dans le dashboard **Backup Overview**
3. Verifier :
   - Le pourcentage d'utilisation du storage backup
   - Les alertes actives dans le panneau "Active Backup Alerts"
   - L'historique d'utilisation du stockage

### Alertes Prometheus

Les alertes suivantes sont configurees :

| Alerte | Severite | Description |
|--------|----------|-------------|
| `BackupJobFailed` | Critical | Un job vzdump a echoue dans les dernieres 24h |
| `BackupJobMissing` | Warning | Aucune sauvegarde reussie depuis 48h |
| `BackupStorageAlmostFull` | Warning | Stockage backup utilise a plus de 80% |

Verifier dans Alertmanager (`http://<monitoring-ip>:9093`) si des alertes sont actives.

## 6. Politique de retention

### Configuration par environnement

| Environnement | Schedule | Retention |
|---------------|----------|-----------|
| **prod** | Quotidien 01:00 | 7 daily, 4 weekly |
| **lab** | Dimanche 03:00 | 3 weekly |
| **monitoring** | Quotidien 02:00 | 7 daily |

### Purge manuelle

```bash
# Lister les sauvegardes anciennes
pvesh get /nodes/<node>/storage/local/content --content backup

# Supprimer une sauvegarde specifique
pvesh delete /nodes/<node>/storage/local/content/backup/<backup-volume-id>
```

## 7. Bonnes pratiques

- **Tester regulierement** la restauration sur une VM de test
- **Monitorer** l'espace disque du storage backup via Grafana
- **Documenter** les VMID et CTID de chaque environnement
- **Conserver** une copie locale du state Terraform en plus de Minio
- **Verifier** les alertes Prometheus apres chaque modification de la configuration backup
