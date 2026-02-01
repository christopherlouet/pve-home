# Plan d'implementation : Procedures de Restauration Automatisees

**Branche**: `feature/restore-procedures`
**Date**: 2026-02-01
**Spec**: [specs/restore-procedures/spec.md](spec.md)
**Statut**: Draft

---

## Resume

Fournir des scripts shell de restauration executables depuis la machine operateur pour chaque composant de l'infrastructure (VM/LXC, state Terraform, Minio, monitoring). Chaque script verifie les prerequis, demande confirmation, execute la restauration et valide le resultat. Une bibliotheque commune factorise les patterns partages (logging, confirmation, connexion SSH, verification).

---

## Contexte Technique

| Aspect | Choix | Notes |
|--------|-------|-------|
| **Langage** | Bash (POSIX-compatible) | Coherent avec `scripts/post-install-proxmox.sh` |
| **Outils requis** | `ssh`, `terraform`, `mc` (Minio Client), `jq` | Prerequis documentes dans la spec |
| **Proxmox CLI** | `pvesh`, `qmrestore`, `pct restore`, `qm`, `pct` | Commandes executees via SSH sur le noeud |
| **Terraform** | bpg/proxmox ~0.50 | Backend S3 Minio avec versioning |
| **Tests** | shellcheck + bats-core | Validation syntaxique + tests fonctionnels |
| **Plateforme** | Linux (machine operateur) → SSH → Proxmox VE | Scripts executes localement |

### Contraintes

- Scripts executables depuis la machine de l'operateur (pas sur le noeud Proxmox)
- Lecture des `terraform.tfvars` pour les IPs et credentials
- Mode `--dry-run` obligatoire pour chaque script (EF-007)
- Confirmation interactive avant toute operation destructive (EF-002)
- Point de sauvegarde avant ecrasement (EF-006)

### Performance attendue

| Metrique | Cible |
|----------|-------|
| Restauration VM/LXC | < 5 min (hors transfert backup) |
| Restauration state Terraform | < 2 min |
| Reconstruction Minio | < 10 min |
| Reconstruction monitoring | < 15 min |
| Verification integrite | < 5 min |

---

## Verification Constitution/Conventions

- [x] Respecte les conventions du projet (bash, `set -euo pipefail`, couleurs, log functions)
- [x] Coherent avec l'architecture existante (`scripts/`, `docs/`)
- [x] Pas d'over-engineering (scripts shell simples, pas de framework)
- [x] Tests planifies (shellcheck + bats-core)

---

## Structure du Projet

### Documentation (cette feature)

```
specs/restore-procedures/
├── spec.md           # Specification fonctionnelle
├── plan.md           # Ce fichier
└── tasks.md          # Decoupage en taches
```

### Code Source

```
scripts/
├── post-install-proxmox.sh    # Script existant (reference conventions)
├── lib/
│   └── common.sh              # Bibliotheque commune (nouveau)
└── restore/
    ├── restore-vm.sh          # US1 : Restaurer VM/LXC
    ├── restore-tfstate.sh     # US2 : Restaurer state Terraform
    ├── rebuild-minio.sh       # US3 : Reconstruire Minio
    ├── rebuild-monitoring.sh  # US4 : Reconstruire monitoring
    └── verify-backups.sh      # US5 : Verifier integrite

docs/
├── BACKUP-RESTORE.md          # Existant (a mettre a jour)
└── DISASTER-RECOVERY.md       # US6 : Runbook DR (nouveau)

tests/
└── restore/
    ├── test_common.bats       # Tests lib commune
    ├── test_restore_vm.bats   # Tests restore VM
    └── test_restore_tfstate.bats # Tests restore tfstate
```

---

## Fichiers Impactes

### A creer

| Fichier | Responsabilite |
|---------|----------------|
| `scripts/lib/common.sh` | Fonctions partagees : log, confirm, ssh_exec, check_prereqs, dry_run, parse_tfvars |
| `scripts/restore/restore-vm.sh` | Restauration VM/LXC depuis vzdump (US1) |
| `scripts/restore/restore-tfstate.sh` | Restauration state Terraform depuis Minio (US2) |
| `scripts/restore/rebuild-minio.sh` | Reconstruction conteneur Minio (US3) |
| `scripts/restore/rebuild-monitoring.sh` | Reconstruction VM monitoring (US4) |
| `scripts/restore/verify-backups.sh` | Verification integrite sauvegardes (US5) |
| `docs/DISASTER-RECOVERY.md` | Runbook disaster recovery pas-a-pas (US6) |
| `tests/restore/test_common.bats` | Tests unitaires lib commune |
| `tests/restore/test_restore_vm.bats` | Tests restore VM (mocks SSH) |
| `tests/restore/test_restore_tfstate.bats` | Tests restore tfstate (mocks mc) |

### A modifier

| Fichier | Modification |
|---------|--------------|
| `docs/BACKUP-RESTORE.md` | Ajouter liens vers scripts automatises et runbook DR |
| `.gitignore` | Ajouter patterns si necessaire (ex: `*.tfstate.backup`) |

---

## Approche Choisie

### Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    Machine Operateur                              │
│                                                                  │
│  scripts/restore/restore-vm.sh ──┐                               │
│  scripts/restore/restore-tfstate.sh ──┤                          │
│  scripts/restore/rebuild-minio.sh ────┤── scripts/lib/common.sh  │
│  scripts/restore/rebuild-monitoring.sh┤   (log, confirm, ssh,    │
│  scripts/restore/verify-backups.sh ───┘    parse_tfvars, etc.)   │
│         │                                                        │
│         │ SSH                    │ mc (Minio Client)             │
│         ▼                       ▼                                │
│  ┌─────────────┐        ┌──────────────┐                         │
│  │ Noeud PVE   │        │ Minio S3     │                         │
│  │ pvesh       │        │ tfstate-*    │                         │
│  │ qmrestore   │        │ versioning   │                         │
│  │ pct restore │        └──────────────┘                         │
│  └─────────────┘                                                 │
└──────────────────────────────────────────────────────────────────┘
```

### Justification

- **Scripts shell** : coherent avec l'existant (`post-install-proxmox.sh`), pas de dependance additionnelle
- **Bibliotheque commune** : factoriser les patterns repetes (log, SSH, confirmation) sans over-engineering
- **Execution locale via SSH** : l'operateur n'a pas besoin de se connecter manuellement au noeud
- **Lecture tfvars** : evite la duplication des IPs et credentials dans les scripts

### Alternatives considerees

| Alternative | Pourquoi rejetee |
|-------------|------------------|
| Ansible playbooks | Surdimensionne pour un operateur unique, ajoute une dependance |
| Python scripts | Moins naturel pour les commandes systeme, plus lourd |
| Terraform-only | Ne couvre pas la restauration vzdump ni Minio down |

---

## Phases d'Implementation

### Phase 1 : Fondation (bloquant)

**Objectif**: Bibliotheque commune et structure de base

- [ ] T001 - Creer la structure de repertoires `scripts/lib/`, `scripts/restore/`, `tests/restore/`
- [ ] T002 - Implementer `scripts/lib/common.sh` (log, couleurs, confirm, parse_args)
- [ ] T003 - Ajouter fonctions SSH et verification prerequis dans `common.sh`
- [ ] T004 - Ajouter fonctions parse_tfvars et dry_run dans `common.sh`
- [ ] T005 - [P] Tests bats pour `common.sh` dans `tests/restore/test_common.bats`

**Checkpoint**: Lib commune testee et prete, les scripts de restauration peuvent commencer.

### Phase 2 : US1 - Restaurer VM/LXC (P1 MVP)

**Objectif**: Restaurer une VM ou un conteneur depuis vzdump en une commande

- [ ] T006 - [P] [US1] Tests bats pour `restore-vm.sh` dans `tests/restore/test_restore_vm.bats`
- [ ] T007 - [US1] Implementer listing des sauvegardes disponibles (pvesh via SSH)
- [ ] T008 - [US1] Implementer detection automatique VM/LXC et restauration
- [ ] T009 - [US1] Implementer option `--target-id` pour restaurer sous un autre VMID
- [ ] T010 - [US1] Implementer verification post-restauration (ping + SSH)
- [ ] T011 - [US1] Implementer modes `--dry-run` et `--force`

**Checkpoint**: `restore-vm.sh <vmid>` fonctionne de bout en bout.

### Phase 3 : US2 - Restaurer state Terraform (P1 MVP)

**Objectif**: Restaurer un etat Terraform precedent depuis Minio S3

- [ ] T012 - [P] [US2] Tests bats pour `restore-tfstate.sh` dans `tests/restore/test_restore_tfstate.bats`
- [ ] T013 - [US2] Implementer mode liste des versions (mc ls --versions)
- [ ] T014 - [US2] Implementer restauration d'une version selectionnee
- [ ] T015 - [US2] Implementer mode fallback vers backend local
- [ ] T016 - [US2] Implementer mode retour vers Minio

**Checkpoint**: `restore-tfstate.sh --list` et `restore-tfstate.sh --restore <version>` fonctionnent.

### Phase 4 : US3+US4 - Reconstruction Minio et Monitoring (P2)

**Objectif**: Reconstruire les composants critiques depuis zero

- [ ] T017 - [P] [US3] Implementer `rebuild-minio.sh` (terraform apply + buckets + state upload)
- [ ] T018 - [P] [US4] Implementer `rebuild-monitoring.sh` (restore vzdump ou terraform apply)
- [ ] T019 - [US3] Ajouter verification Minio (healthcheck, buckets, terraform init)
- [ ] T020 - [US4] Ajouter verification monitoring (Prometheus, Grafana, Alertmanager)

**Checkpoint**: Reconstruction de Minio et monitoring automatisee et verifiee.

### Phase 5 : US5 - Verification integrite (P2)

**Objectif**: Verifier que les sauvegardes sont valides et restaurables

- [ ] T021 - [US5] Implementer `verify-backups.sh` (verification vzdump : taille, checksum)
- [ ] T022 - [US5] Ajouter verification state Minio (JSON valide, non vide)
- [ ] T023 - [US5] Generer rapport de verification avec statut par composant

**Checkpoint**: `verify-backups.sh` produit un rapport complet.

### Phase 6 : US6 - Disaster Recovery Runbook (P3)

**Objectif**: Procedure guidee pas-a-pas pour reconstruction complete

- [ ] T024 - [US6] Rediger `docs/DISASTER-RECOVERY.md` (runbook pas-a-pas)
- [ ] T025 - [US6] Ajouter script de verification finale dans `verify-backups.sh --full`

**Checkpoint**: Runbook DR complet et testable.

### Phase 7 : Polish & Qualite

- [ ] T026 - [P] Mettre a jour `docs/BACKUP-RESTORE.md` avec liens vers scripts
- [ ] T027 - [P] Shellcheck sur tous les scripts
- [ ] T028 - [P] Validation finale : executer chaque script en `--dry-run`
- [ ] T029 - Code review et PR

---

## Risques et Mitigations

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| SSH non accessible vers PVE | Eleve | Faible | Verification prerequis au debut de chaque script, message d'erreur clair |
| Parsing tfvars fragile | Moyen | Moyenne | Parser simple avec grep/sed, tester avec fichiers reels du projet |
| pvesh format change entre versions PVE | Moyen | Faible | Parser JSON (`--output-format json`), tester sur PVE 8.x |
| Espace disque insuffisant pour restauration | Eleve | Moyenne | Verification prealable via `pvesh get .../storage/.../status` |
| Minio inaccessible pendant restauration state | Eleve | Moyenne | Mode fallback vers backend local (US2 CA3) |

---

## Dependances et Ordre d'Execution

### Dependances entre phases

```
Phase 1 (Fondation/common.sh) ──┬──▶ Phase 2 (US1 - VM/LXC)
                                 │
                                 ├──▶ Phase 3 (US2 - tfstate)
                                 │
                                 ├──▶ Phase 4 (US3+US4 - Minio+Monitoring)
                                 │
                                 └──▶ Phase 5 (US5 - Verification)

Phase 4 (US3+US4) ──▶ Phase 6 (US6 - DR Runbook)

Toutes les phases ──▶ Phase 7 (Polish)
```

### Taches parallelisables

- Phase 2 et Phase 3 peuvent etre developpees en parallele apres Phase 1
- T017 (Minio) et T018 (Monitoring) sont independants
- Tous les tests [P] peuvent etre ecrits en parallele

---

## Criteres de Validation

### Avant de commencer (Gate 1)
- [x] Spec approuvee (specs/restore-procedures/spec.md)
- [ ] Plan reviewe
- [x] Branche feature creee

### Avant chaque merge (Gate 2)
- [ ] Shellcheck passe sans erreur sur tous les scripts
- [ ] Tests bats passent
- [ ] `--dry-run` fonctionne sur chaque script
- [ ] Code review approuvee

### Avant deploiement (Gate 3)
- [ ] Tous les criteres de succes de la spec verifies (CS-001 a CS-007)
- [ ] Documentation a jour (BACKUP-RESTORE.md, DISASTER-RECOVERY.md)
- [ ] Test reel sur au moins un VMID de test

---

**Version**: 1.0 | **Cree**: 2026-02-01 | **Derniere modification**: 2026-02-01
