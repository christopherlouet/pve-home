# Scripts de Restauration

Scripts automatises pour restaurer l'infrastructure homelab en cas d'incident.

## Scripts disponibles

### restore-vm.sh - Restaurer une VM/LXC (US1)

Restaure une VM ou un conteneur depuis sa derniere sauvegarde vzdump.

```bash
# Restaurer la VM 100 depuis le dernier backup
./restore-vm.sh 100

# Restaurer depuis un backup specifique
./restore-vm.sh 100 --date 2026-01-15

# Restaurer vers un nouveau VMID
./restore-vm.sh 100 --target-id 200

# Mode dry-run (simulation)
./restore-vm.sh 100 --dry-run

# Mode force (sans confirmation)
./restore-vm.sh 100 --force
```

**Options:**
- `<vmid>` : VMID ou CTID a restaurer (requis)
- `--node NODE` : Noeud Proxmox cible
- `--storage STORAGE` : Storage Proxmox (defaut: local)
- `--date YYYY-MM-DD` : Date de la sauvegarde a restaurer
- `--target-id VMID` : Restaurer vers un nouveau VMID
- `--dry-run` : Simuler sans executer
- `--force` : Pas de confirmation

### restore-tfstate.sh - Restaurer state Terraform (US2)

⚠️ **Non encore implemente** - Phase 3

Restaure un etat Terraform precedent depuis le backend Minio S3.

### rebuild-minio.sh - Reconstruire Minio (US3)

Reconstruit le conteneur Minio et ses buckets S3 depuis zero.

```bash
# Reconstruction Minio (mode dry-run recommande d'abord)
./rebuild-minio.sh --dry-run
./rebuild-minio.sh --force

# Specifier un environnement different
./rebuild-minio.sh --env prod
```

**Options:**
- `--env ENV` : Environnement Terraform (defaut: monitoring)
- `--dry-run` : Simuler sans executer
- `--force` : Pas de confirmation

**Verifications effectuees:**
- Healthcheck API Minio (`/minio/health/live`)
- Buckets et versioning (`mc ls`, `mc version info`)
- Backends Terraform (`terraform init` sur prod, monitoring)

### rebuild-monitoring.sh - Reconstruire Monitoring (US4)

Reconstruit la VM monitoring et ses services (Prometheus, Grafana, Alertmanager).

```bash
# Mode restore (depuis backup vzdump) - par defaut
./rebuild-monitoring.sh --vmid 9001 --dry-run
./rebuild-monitoring.sh --vmid 9001 --force

# Mode rebuild (depuis zero via Terraform)
./rebuild-monitoring.sh --mode rebuild --dry-run
./rebuild-monitoring.sh --mode rebuild --force
```

**Options:**
- `--mode MODE` : restore (defaut) ou rebuild
- `--node NODE` : Noeud Proxmox cible
- `--vmid VMID` : VMID de la VM monitoring (requis en mode restore)
- `--dry-run` : Simuler sans executer
- `--force` : Pas de confirmation

**Modes:**
- `restore` : Restaure depuis le dernier backup vzdump (appelle `restore-vm.sh`)
- `rebuild` : Reconstruit depuis zero via Terraform (historique metriques perdu)

**Verifications effectuees:**
- Services Docker (`docker ps`)
- Healthchecks HTTP:
  - Prometheus: `http://<ip>:9090/-/healthy`
  - Grafana: `http://<ip>:3000/api/health`
  - Alertmanager: `http://<ip>:9093/-/healthy`

## Workflow recommande

### Reconstruction complete apres disaster

1. **Reconstruire Minio** (backend Terraform)
   ```bash
   ./rebuild-minio.sh --force
   ```

2. **Restaurer state Terraform** (une fois Minio up)
   ```bash
   ./restore-tfstate.sh --env prod --list
   ./restore-tfstate.sh --env prod --restore <version-id>
   ```

3. **Reconstruire monitoring**
   ```bash
   ./rebuild-monitoring.sh --vmid 9001 --force
   ```

4. **Restaurer VMs de production**
   ```bash
   ./restore-vm.sh 100 --force
   ./restore-vm.sh 101 --force
   ```

## Bonnes pratiques

### Toujours utiliser --dry-run d'abord

```bash
./rebuild-minio.sh --dry-run
# Verifier la sortie, puis executer
./rebuild-minio.sh --force
```

### Verifier les prerequisites

Avant d'executer les scripts:
- Acces SSH aux noeuds Proxmox configure (cle SSH)
- Outils installes: `ssh`, `terraform`, `mc`, `jq`, `curl`
- Configuration Terraform valide (`terraform.tfvars` present)

### En cas d'erreur

Les scripts gerent les erreurs et affichent des messages clairs.
Si une erreur survient:

1. Lire le message d'erreur (indique l'action qui a echoue)
2. Corriger le probleme (acces SSH, espace disque, etc.)
3. Relancer le script (les scripts sont idempotents)

### Logs et rapports

Chaque script affiche:
- Resume pre-execution avec actions prevues
- Progression detaillee
- Rapport final avec duree et statut

## Support

- Documentation complete: `docs/DISASTER-RECOVERY.md`
- Spec technique: `specs/restore-procedures/spec.md`
- Plan d'implementation: `specs/restore-procedures/plan.md`

## Cycle TDD

Ces scripts ont ete developpes en suivant le cycle TDD strict:
1. **RED**: Tests ecrits en premier (echouent)
2. **GREEN**: Implementation minimale (tests passent)
3. **REFACTOR**: Amelioration du code (tests passent toujours)

Tests disponibles dans `tests/restore/`.
