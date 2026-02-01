# Taches : Strategie de backup Proxmox

**Input**: `specs/backup-strategy/plan.md`, `specs/backup-strategy/spec.md`
**Prerequis**: Plan valide, spec clarifiee

---

## Format : `[ID] [P?] [US?] Description`

- **[P]** : Parallelisable (fichiers differents, pas de dependances)
- **[US1-US6]** : User story associee
- Chemins relatifs depuis `infrastructure/proxmox/`

---

## Phase 1 : Module Minio S3 (bloquant Phase 2)

**Objectif** : Deployer Minio en LXC pour heberger l'etat Terraform

- [ ] T001 - [US2] Creer `modules/minio/variables.tf` - Variables : target_node, container_id, hostname, ip_address, gateway, dns, cpu_cores, memory_mb, disk_size_gb, minio_root_user, minio_root_password (sensitive), buckets (list), datastore, network_bridge, ssh_keys
- [ ] T002 - [US2] Creer `modules/minio/main.tf` - Deployer LXC via module lxc existant, provisionner Minio via cloud-init (download binary, systemd service, creation buckets), configurer firewall (port 9000 API, 9001 console)
- [ ] T003 - [US2] Creer `modules/minio/outputs.tf` - Sorties : endpoint_url, console_url, container_id, ip_address
- [ ] T004 - [US2] Creer `modules/minio/README.md` - Documentation terraform-docs compatible
- [ ] T005 - [US2] Creer `environments/monitoring/minio.tf` - Instancier module minio sur pve-mon, definir 3 buckets (tfstate-prod, tfstate-lab, tfstate-monitoring)
- [ ] T006 - [US2] Modifier `environments/monitoring/variables.tf` - Ajouter bloc variable `minio` avec sous-champs (ip, credentials, etc.)
- [ ] T007 - [US2] Modifier `environments/monitoring/terraform.tfvars.example` - Ajouter exemples Minio avec placeholders pour credentials

**Checkpoint** : `terraform apply` deploie Minio, `curl http://<minio-ip>:9000/minio/health/live` retourne OK.

---

## Phase 2 : Backend Terraform S3 (US2 - P1 MVP)

**Objectif** : Migrer l'etat Terraform local vers Minio S3

**Prerequis** : Phase 1 terminee, Minio accessible

- [ ] T008 - [US2] Modifier `_shared/backend.tf.example` - Ajouter section Minio S3 documentee avec commentaires d'usage
- [ ] T009 - [P] [US2] Creer `environments/prod/backend.tf` - Backend S3 : endpoint Minio, bucket `tfstate-prod`, key `terraform.tfstate`, region `us-east-1`
- [ ] T010 - [P] [US2] Creer `environments/lab/backend.tf` - Backend S3 : bucket `tfstate-lab`
- [ ] T011 - [P] [US2] Creer `environments/monitoring/backend.tf` - Backend S3 : bucket `tfstate-monitoring`

**Checkpoint** : `terraform init -migrate-state` reussit pour chaque environnement, `terraform plan` lit l'etat depuis Minio. CS-006 valide.

---

## Phase 3 : Module Backup vzdump (US1 - P1 MVP)

**Objectif** : Sauvegardes automatiques vzdump pour toutes les VMs/LXC

**Prerequis** : Aucun (peut demarrer en parallele de Phase 1-2)

### Fondation module

- [ ] T012 - [US1] Creer `modules/backup/variables.tf` - Variables : target_node, schedule_cron, storage_id, mode (snapshot/suspend/stop), compress (zstd/lzo/gzip), notification_mode, mail_to, vmids (list), retention (objet keep_last/keep_daily/keep_weekly), enabled (bool)
- [ ] T013 - [US1] Creer `modules/backup/main.tf` - Configurer le job vzdump schedule via Proxmox API. Approche : `null_resource` + `remote-exec` utilisant `pvesh create /cluster/backup` ou resource Terraform native si disponible dans le provider. Inclure la gestion du storage directory de type `backup` si necessaire.
- [ ] T014 - [US1] Creer `modules/backup/outputs.tf` - Sorties : job_id, storage_id, schedule, next_run
- [ ] T015 - [US1] Creer `modules/backup/README.md` - Documentation terraform-docs

### Activation backup sur les modules existants

- [ ] T016 - [P] [US1] Modifier `modules/vm/main.tf` - Ajouter variable `backup_enabled` (default true), configurer `disk.backup = var.backup_enabled` sur le disque principal et les disques additionnels
- [ ] T017 - [P] [US1] Modifier `modules/lxc/main.tf` - Ajouter variable `backup_enabled` (default true), configurer `disk.backup = var.backup_enabled` sur le rootfs et mount points

### Integration par environnement

- [ ] T018 - [P] [US1] Creer `environments/prod/backup.tf` - Instancier module backup : schedule quotidien (1:00 AM), mode snapshot, retention prod (7 daily), lister les VM IDs via outputs du module vm
- [ ] T019 - [P] [US1] Creer `environments/lab/backup.tf` - Instancier module backup : schedule hebdomadaire (dimanche 3:00 AM), mode snapshot, retention lab (3 weekly)
- [ ] T020 - [P] [US1] Creer `environments/monitoring/backup.tf` - Instancier module backup : schedule quotidien (2:00 AM), mode snapshot, retention (7 daily)

### Variables par environnement

- [ ] T021 - [P] [US1] Modifier `environments/prod/variables.tf` - Ajouter variable `backup` (schedule, retention, enabled, storage)
- [ ] T022 - [P] [US1] Modifier `environments/lab/variables.tf` - Idem avec defaults adaptes lab
- [ ] T023 - [P] [US1] Modifier `environments/monitoring/variables.tf` - Idem monitoring

### Exemples tfvars

- [ ] T024 - [P] [US1] Modifier `environments/prod/terraform.tfvars.example` - Section backup avec exemples
- [ ] T025 - [P] [US1] Modifier `environments/lab/terraform.tfvars.example` - Section backup
- [ ] T026 - [P] [US1] Modifier `environments/monitoring/terraform.tfvars.example` - Section backup

**Checkpoint** : `pvesh get /cluster/backup` retourne les jobs configures, vzdump s'execute au prochain schedule. CS-001 valide.

---

## Phase 4 : Retention (US3 - P2)

**Objectif** : Politique de retention configurable par environnement

**Prerequis** : Phase 3 terminee (module backup fonctionnel)

- [ ] T027 - [US3] Integrer retention dans `modules/backup/main.tf` - Parametres vzdump : `keep-last`, `keep-daily`, `keep-weekly`, `keep-monthly`. Defaults : prod (keep-daily=7, keep-weekly=4), lab (keep-last=3), monitoring (keep-daily=7).
- [ ] T028 - [US3] Modifier `modules/backup/variables.tf` - Variable `retention` de type objet avec defaults sensibles par profil

**Checkpoint** : Apres N+1 sauvegardes, les anciennes sont purgees. `pvesh get /cluster/backup/<id>` confirme la politique. CS-004 valide.

---

## Phase 5 : Supervision backup (US4 - P2)

**Objectif** : Alertes et dashboard pour les sauvegardes

**Prerequis** : Phase 3 terminee (sauvegardes actives)

- [ ] T029 - [US4] Modifier `modules/monitoring-stack/files/prometheus/alerts/default.yml` - Ajouter groupe `backup-alerts` :
  - `BackupJobFailed` : alerte si le dernier vzdump a echoue (critical)
  - `BackupJobMissing` : alerte si aucune sauvegarde depuis 48h (warning)
  - `BackupStorageAlmostFull` : alerte si stockage backup > 80% (warning)
- [ ] T030 - [US4] Creer `modules/monitoring-stack/files/grafana/dashboards/backup-overview.json` - Dashboard avec : statut derniere sauvegarde par VM, taille totale par environnement, historique succes/echec, espace disque backup
- [ ] T031 - [US4] Modifier `modules/monitoring-stack/variables.tf` - Ajouter variable `backup_alerting_enabled` (default true)

**Checkpoint** : Alertes visibles dans Alertmanager, dashboard Grafana fonctionnel. CS-003 valide.

---

## Phase 6 : Documentation restauration (US5 - P2)

**Objectif** : Procedures de restauration testees et documentees

**Prerequis** : Phase 3 terminee (sauvegardes disponibles)

- [ ] T032 - [P] [US5] Creer `docs/BACKUP-RESTORE.md` - Procedures pas-a-pas :
  1. Restaurer une VM depuis vzdump (`qmrestore`)
  2. Restaurer un conteneur LXC depuis vzdump (`pct restore`)
  3. Restaurer un etat Terraform depuis Minio (versioning S3)
  4. Fallback : revenir au backend local si Minio est indisponible
  5. Diagnostiquer un echec de sauvegarde
- [ ] T033 - [P] [US5] Modifier `infrastructure/proxmox/README.md` - Ajouter section "Sauvegardes" avec lien vers `docs/BACKUP-RESTORE.md`

**Checkpoint** : Procedure suivie de bout en bout, restauration reussie. CS-002 et CS-005 valides.

---

## Phase 7 : Validation et tests

**Objectif** : Validation globale de la solution

**Prerequis** : Toutes les phases precedentes

- [ ] T034 - [P] Creer `tests/backup-module/main.tf` - Configuration minimale pour `terraform validate` du module backup
- [ ] T035 - [P] Creer `tests/minio-module/main.tf` - Configuration minimale pour `terraform validate` du module minio
- [ ] T036 - Verifier CI/CD - `terraform fmt`, `terraform validate`, tfsec, Checkov, Trivy passent sans regression
- [ ] T037 - Test de restauration complet - Executer la procedure BACKUP-RESTORE.md sur un workload de test

**Checkpoint** : Tous les criteres de succes CS-001 a CS-006 valides.

---

## Dependances et Ordre d'Execution

### Dependances entre phases

```
Phase 1 (Minio) ──▶ Phase 2 (Backend S3)
                                          ──▶ Phase 7 (Validation)
Phase 3 (Backup vzdump) ──┬──▶ Phase 4 (Retention)
                           ├──▶ Phase 5 (Supervision)
                           └──▶ Phase 6 (Documentation)
```

### Dependances entre user stories

| Story | Peut commencer apres | Dependances |
|-------|---------------------|-------------|
| US1 (backup vzdump) | Immediatement | Aucune |
| US2 (backend tfstate) | Immediatement | US1 non requise |
| US3 (retention) | US1 terminee | Module backup fonctionnel |
| US4 (supervision) | US1 terminee | Sauvegardes actives pour avoir des metriques |
| US5 (documentation) | US1 + US2 terminees | Procedures a documenter doivent exister |
| US6 (distant NFS) | Hors scope MVP | Future iteration |

### Opportunites de parallelisation

```
                    ┌──▶ Phase 1 + 2 (Minio + Backend S3) [US2]
Demarrage ─────────┤
                    └──▶ Phase 3 (Backup vzdump) [US1]

Apres Phase 3 ────┬──▶ Phase 4 (Retention) [US3]
                   ├──▶ Phase 5 (Supervision) [US4]
                   └──▶ Phase 6 (Documentation) [US5]

Toutes terminees ──▶ Phase 7 (Validation)
```

---

## Strategie d'Implementation

### MVP First (Phase 1-3)

1. Demarrer Phase 1 + Phase 3 en parallele
2. Phase 2 des que Phase 1 terminee
3. **STOP et VALIDER** : vzdump fonctionne, tfstate sur Minio
4. Deployer le MVP

### Incremental (Phase 4-6)

5. Phase 4, 5, 6 en parallele
6. Phase 7 pour validation globale
7. Merge et release

---

## Resume des taches par complexite

| Complexite | Taches | Estimation fichiers |
|------------|--------|---------------------|
| **Simple** | T001, T003-T004, T008-T011, T014-T015, T024-T026, T028, T031, T033 | 1-2 fichiers, < 50 lignes |
| **Moyenne** | T002, T005-T007, T012-T013, T016-T023, T027, T029-T030, T032, T034-T035 | 2-3 fichiers, 50-200 lignes |
| **Complexe** | T013 (vzdump schedule via API/remote-exec), T036-T037 (validation complete) | Recherche provider + tests manuels |

**Total** : 37 taches, ~25 fichiers impactes (15 nouveaux, 10 modifies)

---

**Version**: 1.0 | **Cree**: 2026-02-01
