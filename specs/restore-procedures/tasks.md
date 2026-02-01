# Taches : Procedures de Restauration Automatisees

**Input**: `specs/restore-procedures/spec.md`, `specs/restore-procedures/plan.md`
**Prerequis**: plan.md (requis), spec.md (requis)

---

## Format des taches : `[ID] [P?] [US?] Description`

- **[P]** : Peut etre executee en parallele (fichiers differents, pas de dependances)
- **[US1..US6]** : User story associee (pour tracabilite)
- Chemins de fichiers exacts inclus dans chaque description

---

## Phase 1 : Fondation (Bibliotheque commune)

**Objectif** : Creer la bibliotheque de fonctions partagees par tous les scripts de restauration

**CRITIQUE** : Aucun script de restauration ne peut commencer avant la fin de cette phase

- [ ] T001 - Creer la structure de repertoires :
  - `scripts/lib/`
  - `scripts/restore/`
  - `tests/restore/`

- [ ] T002 - Implementer les fonctions de base dans `scripts/lib/common.sh` :
  - Couleurs et fonctions de log (`log_info`, `log_success`, `log_warn`, `log_error`)
  - Fonction `confirm()` avec support `--force`
  - Fonction `parse_common_args()` pour `--dry-run`, `--force`, `--help`
  - Header d'usage et `show_help()`
  - Convention : `set -euo pipefail`, `SCRIPT_DIR` detection

- [ ] T003 - Ajouter fonctions SSH et verification prerequis dans `scripts/lib/common.sh` :
  - `ssh_exec()` : execution de commande via SSH sur le noeud PVE
  - `check_ssh_access()` : verification connectivite SSH
  - `check_command()` : verification presence d'un binaire local
  - `check_prereqs()` : verification de tous les prerequis (ssh, terraform, mc, jq)
  - `check_disk_space()` : verification espace disque via pvesh

- [ ] T004 - Ajouter fonctions parse_tfvars et dry_run dans `scripts/lib/common.sh` :
  - `parse_tfvars()` : extraction des valeurs depuis `terraform.tfvars` (grep/sed)
  - `get_pve_node()` : detecter le noeud PVE depuis tfvars
  - `get_pve_ip()` : detecter l'IP du noeud PVE
  - `dry_run()` : wrapper qui affiche la commande sans l'executer en mode `--dry-run`
  - `create_backup_point()` : sauvegarder l'etat actuel avant ecrasement (EF-006)

- [ ] T005 - [P] Ecrire les tests dans `tests/restore/test_common.bats` :
  - Test `log_info`, `log_error` produisent le bon format
  - Test `confirm` retourne 0/1 selon l'input
  - Test `parse_tfvars` extrait correctement les valeurs
  - Test `check_command` detecte commande presente/absente
  - Test `parse_common_args` gere `--dry-run`, `--force`, `--help`

**Checkpoint** : `source scripts/lib/common.sh` fonctionne, tests bats passent.

---

## Phase 2 : US1 - Restaurer VM/LXC (P1 MVP)

**Objectif** : Restaurer une VM ou un conteneur depuis sa derniere sauvegarde vzdump en une commande

**Test independant** : `./scripts/restore/restore-vm.sh <vmid>` sur un VMID de test, verifier VM restauree et accessible en SSH

### Tests US1

- [ ] T006 - [P] [US1] Ecrire les tests dans `tests/restore/test_restore_vm.bats` :
  - Test parsing arguments (vmid requis, --target-id, --date, --dry-run)
  - Test listing sauvegardes (mock SSH/pvesh, format JSON)
  - Test selection sauvegarde la plus recente
  - Test selection par date
  - Test erreur si aucune sauvegarde
  - Test detection type VM vs LXC
  - Test confirmation ecrasement si VMID existe
  - Test mode dry-run (aucune action executee)

### Implementation US1

- [ ] T007 - [US1] Implementer listing sauvegardes dans `scripts/restore/restore-vm.sh` :
  - Parsing arguments : `VMID` (requis), `--node`, `--storage`, `--date`, `--target-id`, `--dry-run`, `--force`
  - `list_backups()` : `pvesh get /nodes/$NODE/storage/$STORAGE/content --content backup --vmid $VMID --output-format json` via SSH
  - Affichage formate : date, taille, type (qemu/lxc)
  - Selection automatique du plus recent si `--date` non specifie
  - Selection par date si `--date YYYY-MM-DD` specifie

- [ ] T008 - [US1] Implementer restauration VM/LXC dans `scripts/restore/restore-vm.sh` :
  - `detect_type()` : determiner si c'est une VM (qemu) ou un LXC depuis le nom du fichier backup
  - `restore_vm()` : `qmrestore <backup-file> <vmid> --start 0` via SSH
  - `restore_lxc()` : `pct restore <ctid> <backup-file> --start 0` via SSH
  - Gestion VMID existant : arreter si running, confirmer ecrasement, detruire puis restaurer
  - `create_backup_point()` avant ecrasement (snapshot ou note)

- [ ] T009 - [US1] Implementer option `--target-id` dans `scripts/restore/restore-vm.sh` :
  - Si `--target-id <new-id>` specifie : restaurer sous le nouveau VMID/CTID
  - Verification que le target-id n'est pas deja utilise
  - Pas d'ecrasement de la VM originale

- [ ] T010 - [US1] Implementer verification post-restauration dans `scripts/restore/restore-vm.sh` :
  - `verify_restore()` : demarrer la VM/LXC, attendre boot (sleep + retry)
  - Test ping vers l'IP (recuperee depuis config VM ou tfvars)
  - Test SSH (timeout 30s)
  - Afficher rapport : fichier restaure, duree, status verification (EF-003)

- [ ] T011 - [US1] Implementer `--dry-run` et `--force` dans `scripts/restore/restore-vm.sh` :
  - Mode `--dry-run` : affiche toutes les commandes sans executer
  - Mode `--force` : skip confirmation interactive
  - Resume pre-execution avec toutes les actions prevues (EF-002)

**Checkpoint** : `./scripts/restore/restore-vm.sh 100` restaure la VM 100, la demarre et confirme la connectivite.

---

## Phase 3 : US2 - Restaurer state Terraform (P1 MVP)

**Objectif** : Restaurer un etat Terraform precedent depuis le backend Minio S3

**Test independant** : Lister les versions, restaurer une version anterieure, verifier avec `terraform plan`

### Tests US2

- [ ] T012 - [P] [US2] Ecrire les tests dans `tests/restore/test_restore_tfstate.bats` :
  - Test parsing arguments (--list, --restore, --env, --fallback, --return)
  - Test listing versions (mock mc)
  - Test restauration version (mock mc cp)
  - Test mode fallback (modification backend.tf)
  - Test mode retour (restauration backend.tf)
  - Test erreur si Minio inaccessible

### Implementation US2

- [ ] T013 - [US2] Implementer mode liste dans `scripts/restore/restore-tfstate.sh` :
  - Parsing arguments : `--env` (prod|lab|monitoring), `--list`, `--restore <version-id>`, `--fallback`, `--return`, `--dry-run`, `--force`
  - `configure_mc()` : configurer alias mc depuis tfvars (minio IP, credentials)
  - `list_versions()` : `mc ls --versions homelab/tfstate-$ENV/terraform.tfstate`
  - Affichage formate : version-id, date, taille

- [ ] T014 - [US2] Implementer restauration version dans `scripts/restore/restore-tfstate.sh` :
  - `restore_version()` : telecharger version (`mc cp --version-id`), uploader comme courante
  - Sauvegarder version actuelle avant ecrasement (EF-006)
  - Executer `terraform init -reconfigure` + `terraform plan` pour verification
  - Afficher rapport avec resultat du plan

- [ ] T015 - [US2] Implementer mode fallback dans `scripts/restore/restore-tfstate.sh` :
  - `fallback_local()` : commenter backend S3 dans `backend.tf`, executer `terraform init -migrate-state`
  - Sauvegarder `backend.tf` original avant modification
  - Verification avec `terraform plan`
  - Message clair sur l'etat temporaire

- [ ] T016 - [US2] Implementer mode retour vers Minio dans `scripts/restore/restore-tfstate.sh` :
  - `return_to_minio()` : verifier healthcheck Minio, restaurer `backend.tf`, executer `terraform init -migrate-state`
  - Verification connectivite Minio avant migration
  - Verification avec `terraform plan` apres migration

**Checkpoint** : `./scripts/restore/restore-tfstate.sh --env prod --list` affiche les versions, `--restore <id>` restaure.

---

## Phase 4 : US3+US4 - Reconstruction Minio et Monitoring (P2)

**Objectif** : Reconstruire les composants critiques de l'infrastructure

### US3 - Reconstruire Minio

- [x] T017 - [P] [US3] Implementer `scripts/restore/rebuild-minio.sh` :
  - Parsing arguments : `--env` (monitoring par defaut), `--dry-run`, `--force`
  - Verification : conteneur Minio absent ou casse (ping, curl healthcheck)
  - Execution : `terraform apply -target=module.minio` depuis l'env monitoring
  - Attente demarrage Minio (healthcheck retry loop)
  - Si state local disponible : upload vers les buckets Minio (`mc cp`)
  - Verification : `terraform init` sur chaque environnement (prod, lab, monitoring)
  - Rapport de reconstruction

- [x] T019 - [US3] Ajouter verifications dans `scripts/restore/rebuild-minio.sh` :
  - `verify_minio()` : healthcheck API (`/minio/health/live`), lister buckets, verifier versioning
  - `verify_terraform_backends()` : `terraform init` sur prod, lab, monitoring
  - Rapport detaille par bucket/environnement

### US4 - Reconstruire Monitoring

- [x] T018 - [P] [US4] Implementer `scripts/restore/rebuild-monitoring.sh` :
  - Parsing arguments : `--mode` (restore|rebuild), `--dry-run`, `--force`
  - Mode restore : `restore-vm.sh` sur le VMID monitoring (reutilisation US1)
  - Mode rebuild : `terraform apply -target=module.monitoring_stack` (si pas de backup)
  - Verification services Docker (via SSH) : Prometheus, Grafana, Alertmanager
  - Rapport de reconstruction

- [x] T020 - [US4] Ajouter verifications dans `scripts/restore/rebuild-monitoring.sh` :
  - `verify_prometheus()` : curl `-/api/v1/targets`, verifier que les targets sont up
  - `verify_grafana()` : curl `/api/health`, verifier status
  - `verify_alertmanager()` : curl `/-/healthy`
  - Rapport avec statut de chaque service

**Checkpoint** : `rebuild-minio.sh` et `rebuild-monitoring.sh` fonctionnels avec verifications. ✅ COMPLETE

---

## Phase 5 : US5 - Verification integrite (P2)

**Objectif** : Verifier periodiquement que les sauvegardes sont valides et restaurables

- [ ] T021 - [US5] Implementer verification vzdump dans `scripts/restore/verify-backups.sh` :
  - Parsing arguments : `--node`, `--storage`, `--vmid` (optionnel), `--dry-run`
  - Lister toutes les sauvegardes via pvesh (SSH)
  - Pour chaque backup : verifier taille non-nulle, checksum si `.notes` disponible
  - Afficher rapport par VMID : nombre de backups, plus recent, taille, statut

- [ ] T022 - [US5] Ajouter verification state Minio dans `scripts/restore/verify-backups.sh` :
  - Pour chaque bucket tfstate-* : lister les versions
  - Telecharger version courante, verifier JSON valide (`jq .`)
  - Verifier taille non-nulle
  - Rapport par environnement

- [ ] T023 - [US5] Generer rapport global dans `scripts/restore/verify-backups.sh` :
  - Format : tableau avec colonnes (Composant, Statut, Dernier backup, Taille, Notes)
  - Code de sortie : 0 si tout OK, 1 si avertissements, 2 si erreurs critiques
  - Option `--json` pour sortie machine-readable (optionnel)

**Checkpoint** : `verify-backups.sh` produit un rapport clair avec statut par composant.

---

## Phase 6 : US6 - Disaster Recovery Runbook (P3)

**Objectif** : Procedure guidee pas-a-pas pour reconstruire toute l'infrastructure depuis zero

- [ ] T024 - [US6] Rediger `docs/DISASTER-RECOVERY.md` :
  - Prerequis : Proxmox VE installe, acces SSH, outils installes
  - Etape 1 : Reconstruire Minio (`rebuild-minio.sh`)
  - Etape 2 : Restaurer state Terraform (`restore-tfstate.sh`)
  - Etape 3 : Reconstruire monitoring (`rebuild-monitoring.sh`)
  - Etape 4 : Restaurer VMs de production (`restore-vm.sh` pour chaque VMID)
  - Etape 5 : Verification finale (`verify-backups.sh --full`)
  - Pour chaque etape : prerequis, commande, verification attendue
  - Checklist de verification finale

- [ ] T025 - [US6] Ajouter mode `--full` dans `scripts/restore/verify-backups.sh` :
  - Verification de tous les composants : vzdump, Minio, monitoring
  - Test connectivite vers toutes les VMs/LXC connues
  - Verification que les sauvegardes automatiques sont actives
  - Rapport DR complet

**Checkpoint** : Runbook DR complet, testable en suivant les etapes.

---

## Phase 7 : Polish & Qualite

**Objectif** : Finalisation, documentation, validation

- [ ] T026 - [P] Mettre a jour `docs/BACKUP-RESTORE.md` :
  - Section "Scripts automatises" avec description de chaque script
  - Liens vers les scripts dans `scripts/restore/`
  - Lien vers le runbook DR

- [ ] T027 - [P] Executer shellcheck sur tous les scripts :
  - `shellcheck scripts/lib/common.sh`
  - `shellcheck scripts/restore/*.sh`
  - Corriger tous les warnings

- [ ] T028 - [P] Validation finale :
  - Executer chaque script en mode `--dry-run`
  - Verifier que l'aide (`--help`) est complete et coherente
  - Verifier les codes de sortie

- [ ] T029 - Code review et PR :
  - Review du code
  - Creer la PR avec description complete

---

## Dependances et Ordre d'Execution

### Dependances entre phases

```
Phase 1 (Fondation/common.sh)
     │
     ├──▶ Phase 2 (US1 - VM/LXC) ─────────┐
     │                                      │
     ├──▶ Phase 3 (US2 - tfstate)           │
     │                                      │
     ├──▶ Phase 4 (US3+US4 - Minio+Monit.) ├──▶ Phase 6 (US6 - DR Runbook)
     │                                      │
     └──▶ Phase 5 (US5 - Verification) ─────┘

Toutes les phases ──▶ Phase 7 (Polish)
```

### Dependances entre user stories

| Story | Peut commencer apres | Dependances |
|-------|---------------------|-------------|
| US1 (P1) | Phase 1 (Fondation) | Aucune autre story |
| US2 (P1) | Phase 1 (Fondation) | Aucune autre story |
| US3 (P2) | Phase 1 (Fondation) | Aucune autre story |
| US4 (P2) | Phase 1 (Fondation) | Reutilise US1 (restore-vm.sh) en mode restore |
| US5 (P2) | Phase 1 (Fondation) | Aucune autre story |
| US6 (P3) | Phase 4+5 (US3+US4+US5) | Reference tous les scripts |

### Opportunites de parallelisation

- **Phase 2 et Phase 3** : independantes, developpables en parallele
- **T017 (Minio) et T018 (Monitoring)** : independants
- **T006, T012** : tests peuvent etre ecrits en parallele
- **Phase 7 (T026, T027, T028)** : toutes parallelisables

---

## Strategie d'Implementation

### MVP First (US1 + US2)

1. Completer Phase 1 : Fondation (common.sh)
2. Completer Phase 2 : US1 (restore-vm.sh) et Phase 3 : US2 (restore-tfstate.sh) en parallele
3. **STOP et VALIDER** : tester sur un VMID reel et un state reel
4. PR avec MVP fonctionnel

### Livraison Incrementale

1. Fondation → Base prete
2. US1 + US2 → MVP (restauration VM + state)
3. US3 + US4 → Reconstruction complete
4. US5 → Verification proactive
5. US6 → Documentation DR
6. Chaque phase ajoute de la valeur sans casser les precedentes

---

## Notes

- **[P]** taches = fichiers differents, pas de dependances
- **[US?]** label = tracabilite vers la user story de la spec
- Chaque script doit etre testable en `--dry-run` avant execution reelle
- Conventions : suivre le style de `scripts/post-install-proxmox.sh` (couleurs, log, set -euo pipefail)
- Commit apres chaque tache ou groupe logique
- Utiliser `bats-core` pour les tests shell (leger, standard)

**A eviter** :
- Over-engineering (pas de framework shell, pas d'abstraction excessive)
- Dupliquer les IPs/credentials (lire depuis tfvars)
- Scripts qui necessitent d'etre sur le noeud PVE (tout via SSH)

---

**Version**: 1.0 | **Cree**: 2026-02-01
