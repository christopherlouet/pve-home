# Plan d'implementation : Strategie de backup Proxmox

**Branche**: `feature/backup-strategy`
**Date**: 2026-02-01
**Spec**: [specs/backup-strategy/spec.md](spec.md)
**Statut**: Draft

---

## Resume

Mettre en place une strategie de sauvegarde automatisee pour l'infrastructure Proxmox homelab (3 environnements). Les sauvegardes vzdump des VMs/LXC sont planifiees via le scheduler natif Proxmox, configure par Terraform via le provider `bpg/proxmox`. L'etat Terraform est securise via un backend S3 auto-heberge (Minio en conteneur LXC). La supervision des sauvegardes s'integre dans la stack de monitoring existante (Prometheus/Grafana/Alertmanager).

---

## Contexte Technique

| Aspect | Choix | Notes |
|--------|-------|-------|
| **IaC** | Terraform >= 1.5.0 | HCL |
| **Provider** | bpg/proxmox ~0.50 (0.93.0) | Support vzdump backup schedule via API |
| **Proxmox** | PVE 8.x / 9.x | vzdump natif pour les sauvegardes |
| **Backend state** | Minio (S3 compatible) | Deploye en LXC sur un node Proxmox |
| **Monitoring** | Prometheus + Grafana + Alertmanager | Stack existante a etendre |
| **Tests** | terraform validate + terraform plan | Validation IaC |

### Contraintes

- Le provider `bpg/proxmox` ne propose pas de ressource native `backup_schedule`. Les jobs de sauvegarde vzdump seront configures via `proxmox_virtual_environment_cluster_options` ou des scripts post-provisioning.
- Les sauvegardes vzdump sont stockees sur le datastore local de chaque node (pas de PBS).
- Volume estime 50-200 Go, prevoir 400-600 Go d'espace pour la retention.

### Performance attendue

| Metrique | Cible |
|----------|-------|
| RPO (perte de donnees max) | 24 heures (sauvegarde quotidienne) |
| RTO (temps de restauration) | < 15 minutes par VM/LXC |
| Disponibilite monitoring | 99% (stack existante) |

---

## Verification Conventions

- [x] Respecte les conventions du projet (modules Terraform reutilisables, snake_case)
- [x] Coherent avec l'architecture existante (module dans `modules/`, usage dans `environments/`)
- [x] Pas d'over-engineering (vzdump natif, pas de PBS)
- [x] Tests planifies (terraform validate, terraform plan)

---

## Structure du Projet

### Documentation (cette feature)

```
specs/backup-strategy/
├── spec.md           # Specification fonctionnelle
├── plan.md           # Ce fichier
└── tasks.md          # Decoupage en taches
```

### Code Source

```
infrastructure/proxmox/
├── modules/
│   ├── backup/                          # NOUVEAU - Module de sauvegarde vzdump
│   │   ├── main.tf                      # Ressources backup (storage, schedule)
│   │   ├── variables.tf                 # Variables du module
│   │   ├── outputs.tf                   # Sorties du module
│   │   └── README.md                    # Documentation terraform-docs
│   ├── minio/                           # NOUVEAU - Module Minio S3 pour tfstate
│   │   ├── main.tf                      # LXC + installation Minio
│   │   ├── variables.tf                 # Variables du module
│   │   ├── outputs.tf                   # Endpoint, credentials
│   │   └── README.md                    # Documentation terraform-docs
│   ├── monitoring-stack/
│   │   └── files/
│   │       ├── prometheus/alerts/
│   │       │   └── default.yml          # MODIFIER - Ajouter alertes backup
│   │       └── grafana/dashboards/
│   │           └── backup-overview.json # NOUVEAU - Dashboard backup
│   ├── vm/main.tf                       # MODIFIER - Activer backup sur disques
│   └── lxc/main.tf                      # MODIFIER - Activer backup sur disques
├── environments/
│   ├── prod/
│   │   ├── main.tf                      # MODIFIER - Integrer module backup
│   │   ├── backup.tf                    # NOUVEAU - Config backup prod
│   │   ├── variables.tf                 # MODIFIER - Ajouter variables backup
│   │   ├── backend.tf                   # NOUVEAU - Backend S3 Minio
│   │   └── terraform.tfvars.example     # MODIFIER - Exemples backup
│   ├── lab/
│   │   ├── backup.tf                    # NOUVEAU - Config backup lab
│   │   ├── variables.tf                 # MODIFIER - Ajouter variables backup
│   │   ├── backend.tf                   # NOUVEAU - Backend S3 Minio
│   │   └── terraform.tfvars.example     # MODIFIER - Exemples backup
│   └── monitoring/
│       ├── backup.tf                    # NOUVEAU - Config backup monitoring
│       ├── minio.tf                     # NOUVEAU - Deploiement Minio LXC
│       ├── variables.tf                 # MODIFIER - Ajouter variables backup + minio
│       ├── backend.tf                   # NOUVEAU - Backend S3 Minio
│       └── terraform.tfvars.example     # MODIFIER - Exemples backup + minio
├── _shared/
│   └── backend.tf.example              # MODIFIER - Ajouter exemple Minio
└── docs/
    └── BACKUP-RESTORE.md               # NOUVEAU - Procedures de restauration
```

---

## Fichiers Impactes

### A creer

| Fichier | Responsabilite |
|---------|----------------|
| `modules/backup/main.tf` | Configuration vzdump : storage backup dedie, schedule par environnement |
| `modules/backup/variables.tf` | Variables : schedule, retention, node, storage, VMs/LXC a sauvegarder |
| `modules/backup/outputs.tf` | ID du job, storage utilise, prochaine execution |
| `modules/backup/README.md` | Documentation du module (terraform-docs) |
| `modules/minio/main.tf` | Deploiement LXC Minio : conteneur, installation, configuration S3 |
| `modules/minio/variables.tf` | Variables : node, IP, credentials, buckets |
| `modules/minio/outputs.tf` | Endpoint S3, access key, secret key |
| `modules/minio/README.md` | Documentation du module (terraform-docs) |
| `environments/prod/backup.tf` | Instanciation module backup pour prod |
| `environments/lab/backup.tf` | Instanciation module backup pour lab |
| `environments/monitoring/backup.tf` | Instanciation module backup pour monitoring |
| `environments/monitoring/minio.tf` | Instanciation module minio sur node monitoring |
| `environments/*/backend.tf` | Backend S3 Minio pour chaque environnement |
| `modules/monitoring-stack/files/grafana/dashboards/backup-overview.json` | Dashboard Grafana pour supervision backup |
| `docs/BACKUP-RESTORE.md` | Procedures de restauration pas-a-pas |

### A modifier

| Fichier | Modification |
|---------|--------------|
| `modules/vm/main.tf` | Ajouter variable `backup_enabled` et attribut `backup = true` sur les disques |
| `modules/lxc/main.tf` | Ajouter variable `backup_enabled` et attribut sur les disques |
| `modules/monitoring-stack/files/prometheus/alerts/default.yml` | Ajouter groupe d'alertes `backup-alerts` |
| `modules/monitoring-stack/variables.tf` | Ajouter variable pour activer les alertes backup |
| `environments/prod/variables.tf` | Ajouter variables backup (schedule, retention) |
| `environments/prod/terraform.tfvars.example` | Ajouter exemples de configuration backup |
| `environments/lab/variables.tf` | Ajouter variables backup |
| `environments/lab/terraform.tfvars.example` | Ajouter exemples backup |
| `environments/monitoring/variables.tf` | Ajouter variables backup + minio |
| `environments/monitoring/terraform.tfvars.example` | Ajouter exemples backup + minio |
| `_shared/backend.tf.example` | Ajouter section Minio avec commentaires |

### Tests a ajouter

| Fichier | Couverture |
|---------|------------|
| `tests/backup-module/main.tf` | Validation terraform du module backup (validate + plan) |
| `tests/minio-module/main.tf` | Validation terraform du module minio (validate + plan) |

---

## Approche Choisie

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ARCHITECTURE BACKUP                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────┐  ┌──────────────────────┐                  │
│  │  pve-prod             │  │  pve-lab              │                 │
│  │  ┌────────────────┐   │  │  ┌────────────────┐   │                │
│  │  │ VMs / LXCs     │   │  │  │ VMs / LXCs     │   │                │
│  │  └───────┬────────┘   │  │  └───────┬────────┘   │                │
│  │          │ vzdump     │  │          │ vzdump     │                │
│  │          ▼            │  │          ▼            │                │
│  │  ┌────────────────┐   │  │  ┌────────────────┐   │                │
│  │  │ local-backup   │   │  │  │ local-backup   │   │                │
│  │  │ (datastore)    │   │  │  │ (datastore)    │   │                │
│  │  └────────────────┘   │  │  └────────────────┘   │                │
│  └──────────────────────┘  └──────────────────────┘                  │
│                                                                      │
│  ┌──────────────────────────────────────────────┐                    │
│  │  pve-mon                                      │                   │
│  │  ┌────────────────┐  ┌────────────────────┐   │                   │
│  │  │ monitoring VM  │  │ Minio LXC          │   │                   │
│  │  │ ┌────────────┐ │  │ ┌────────────────┐ │   │                   │
│  │  │ │ Prometheus │ │  │ │ S3 buckets:    │ │   │                   │
│  │  │ │ + alertes  │ │  │ │  tfstate-prod  │ │   │                   │
│  │  │ │ backup     │ │  │ │  tfstate-lab   │ │   │                   │
│  │  │ ├────────────┤ │  │ │  tfstate-mon   │ │   │                   │
│  │  │ │ Grafana    │ │  │ └────────────────┘ │   │                   │
│  │  │ │ + dashboard│ │  └────────────────────┘   │                   │
│  │  │ │ backup     │ │                           │                   │
│  │  │ ├────────────┤ │  ┌────────────────────┐   │                   │
│  │  │ │Alertmanager│ │  │ local-backup       │   │                   │
│  │  │ │→ Telegram  │ │  │ (monitoring VMs)   │   │                   │
│  │  │ └────────────┘ │  └────────────────────┘   │                   │
│  │  └────────────────┘                           │                   │
│  └──────────────────────────────────────────────┘                    │
│                                                                      │
│  ┌──────────────────────────────────────────────┐                    │
│  │  Futur (P3 - optionnel)                       │                   │
│  │  ┌────────────────────┐                       │                   │
│  │  │ NAS (NFS)          │                       │                   │
│  │  │ Replication backup │                       │                   │
│  │  └────────────────────┘                       │                   │
│  └──────────────────────────────────────────────┘                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Justification

L'approche vzdump natif + stockage local est choisie car :
1. vzdump est l'outil de sauvegarde integre a Proxmox, sans composant supplementaire
2. Le provider `bpg/proxmox` ne fournit pas de ressource native de schedule backup, mais les jobs vzdump peuvent etre configures via l'API Proxmox ou un `null_resource` avec `remote-exec`
3. Minio en LXC est coherent avec la philosophie auto-hebergee du homelab
4. La stack monitoring existante est etendue (pas de nouveau systeme)

### Alternatives considerees

| Alternative | Pourquoi rejetee |
|-------------|------------------|
| Proxmox Backup Server (PBS) | Service supplementaire a installer et maintenir, surdimensionne pour un homelab single-node |
| Backend S3 AWS | Dependance cloud, cout mensuel, incoherent avec philosophie homelab |
| Backend Consul | Plus complexe a deployer que Minio, moins connu |
| Terraform Cloud | Dependance externe, limites sur le plan gratuit |

---

## Phases d'Implementation

### Phase 1 : Fondation - Module Minio (bloquant pour US2)

**Objectif**: Deployer Minio S3 en LXC pour securiser l'etat Terraform

- [ ] T001 - [US2] Creer `modules/minio/variables.tf` - Variables du module
- [ ] T002 - [US2] Creer `modules/minio/main.tf` - LXC + installation Minio
- [ ] T003 - [US2] Creer `modules/minio/outputs.tf` - Endpoint et credentials
- [ ] T004 - [US2] Creer `modules/minio/README.md` - Documentation terraform-docs
- [ ] T005 - [US2] Creer `environments/monitoring/minio.tf` - Instanciation Minio sur pve-mon
- [ ] T006 - [US2] Modifier `environments/monitoring/variables.tf` - Variables Minio
- [ ] T007 - [US2] Modifier `environments/monitoring/terraform.tfvars.example` - Exemples Minio

**Checkpoint**: Minio deploye, accessible via endpoint S3, buckets crees.

### Phase 2 : Backend Terraform S3 (US2 - P1 MVP)

**Objectif**: Migrer l'etat Terraform vers Minio

- [ ] T008 - [US2] Modifier `_shared/backend.tf.example` - Ajouter section Minio
- [ ] T009 - [P] [US2] Creer `environments/prod/backend.tf` - Backend S3 prod
- [ ] T010 - [P] [US2] Creer `environments/lab/backend.tf` - Backend S3 lab
- [ ] T011 - [P] [US2] Creer `environments/monitoring/backend.tf` - Backend S3 monitoring

**Checkpoint**: `terraform init` reussit avec backend S3, state migre, CS-006 valide.

### Phase 3 : Module Backup vzdump (US1 - P1 MVP)

**Objectif**: Sauvegardes automatiques de toutes les VMs et conteneurs

- [ ] T012 - [US1] Creer `modules/backup/variables.tf` - Variables du module backup
- [ ] T013 - [US1] Creer `modules/backup/main.tf` - Configuration vzdump schedule via API Proxmox
- [ ] T014 - [US1] Creer `modules/backup/outputs.tf` - Sorties du module
- [ ] T015 - [US1] Creer `modules/backup/README.md` - Documentation terraform-docs
- [ ] T016 - [P] [US1] Modifier `modules/vm/main.tf` - Ajouter variable `backup_enabled`, attribut disk backup
- [ ] T017 - [P] [US1] Modifier `modules/lxc/main.tf` - Ajouter variable `backup_enabled`, attribut disk backup
- [ ] T018 - [P] [US1] Creer `environments/prod/backup.tf` - Instanciation backup prod (quotidien)
- [ ] T019 - [P] [US1] Creer `environments/lab/backup.tf` - Instanciation backup lab (hebdomadaire)
- [ ] T020 - [P] [US1] Creer `environments/monitoring/backup.tf` - Instanciation backup monitoring
- [ ] T021 - [US1] Modifier `environments/prod/variables.tf` - Variables backup prod
- [ ] T022 - [US1] Modifier `environments/lab/variables.tf` - Variables backup lab
- [ ] T023 - [US1] Modifier `environments/monitoring/variables.tf` - Variables backup monitoring
- [ ] T024 - [P] [US1] Modifier `environments/prod/terraform.tfvars.example` - Exemples backup
- [ ] T025 - [P] [US1] Modifier `environments/lab/terraform.tfvars.example` - Exemples backup
- [ ] T026 - [P] [US1] Modifier `environments/monitoring/terraform.tfvars.example` - Exemples backup

**Checkpoint**: vzdump schedule actif, sauvegardes quotidiennes prod, CS-001 valide.

### Phase 4 : Retention (US3 - P2)

**Objectif**: Politique de retention configurable par environnement

- [ ] T027 - [US3] Integrer la retention dans `modules/backup/main.tf` - Parametres keep-last, keep-daily, keep-weekly
- [ ] T028 - [US3] Modifier `modules/backup/variables.tf` - Variables retention avec defaults differencies

**Checkpoint**: Retention active, sauvegardes anciennes purgees, CS-004 valide.

### Phase 5 : Supervision (US4 - P2)

**Objectif**: Alertes et dashboard pour les sauvegardes

- [ ] T029 - [US4] Modifier `modules/monitoring-stack/files/prometheus/alerts/default.yml` - Alertes backup
- [ ] T030 - [US4] Creer `modules/monitoring-stack/files/grafana/dashboards/backup-overview.json` - Dashboard
- [ ] T031 - [US4] Modifier `modules/monitoring-stack/variables.tf` - Variable activation alertes backup

**Checkpoint**: Alertes fonctionnelles, dashboard visible, CS-003 valide.

### Phase 6 : Documentation (US5 - P2)

**Objectif**: Procedures de restauration documentees

- [ ] T032 - [P] [US5] Creer `docs/BACKUP-RESTORE.md` - Procedures restauration VM, LXC, tfstate
- [ ] T033 - [P] [US5] Modifier `infrastructure/proxmox/README.md` - Reference vers BACKUP-RESTORE.md

**Checkpoint**: Procedures testables, CS-002 et CS-005 valides.

### Phase 7 : Validation et tests

- [ ] T034 - [P] Creer `tests/backup-module/main.tf` - Test terraform validate module backup
- [ ] T035 - [P] Creer `tests/minio-module/main.tf` - Test terraform validate module minio
- [ ] T036 - Validation CI/CD - Verifier que les workflows existants passent
- [ ] T037 - Test de restauration manuelle - Valider la procedure documentee

---

## Risques et Mitigations

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| Provider bpg/proxmox ne supporte pas schedule vzdump nativement | Eleve | Moyenne | Utiliser `null_resource` + `remote-exec` pour configurer via CLI pvesh, ou API directe |
| Migration tfstate vers S3 corrompt l'etat | Eleve | Faible | Sauvegarder manuellement le tfstate local avant migration, tester avec `terraform plan` |
| Minio LXC indisponible bloque les operations Terraform | Eleve | Faible | Documenter procedure de fallback vers backend local |
| Espace disque insuffisant pour les sauvegardes | Moyen | Moyenne | Politique de retention des la Phase 4, alerte stockage existante (>85%) |
| Sauvegardes vzdump degradent les performances | Faible | Moyenne | Fenetre de sauvegarde nocturne configurable (EF-012) |

---

## Dependances et Ordre d'Execution

### Dependances entre phases

```
Phase 1 (Minio) ──▶ Phase 2 (Backend S3) ──┐
                                             │
Phase 3 (Backup vzdump) ────────────────────┤
                                             │
Phase 4 (Retention) ◄── depend Phase 3 ─────┤
                                             │
Phase 5 (Supervision) ◄── depend Phase 3 ───┤
                                             │
Phase 6 (Documentation) ────────────────────┤
                                             │
                                             ▼
                                      Phase 7 (Validation)
```

### Parallelisation possible

- Phase 1-2 (Minio/Backend) et Phase 3 (Backup) sont **independantes** et peuvent demarrer en parallele
- Phase 4, 5, 6 peuvent demarrer en parallele une fois Phase 3 terminee
- Les taches marquees [P] au sein de chaque phase sont parallelisables

---

## Criteres de Validation

### Avant de commencer (Gate 1)
- [x] Spec approuvee (spec.md v1.1)
- [x] Plan reviewe (ce fichier)
- [ ] Environnements Proxmox accessibles

### Avant chaque merge (Gate 2)
- [ ] `terraform validate` passe pour chaque module
- [ ] `terraform plan` ne montre pas de destruction inattendue
- [ ] terraform-docs genere pour les nouveaux modules

### Avant deploiement (Gate 3)
- [ ] CS-001: 100% des VMs/LXC couvertes par backup
- [ ] CS-002: Restauration testee en < 15 minutes
- [ ] CS-003: Alerte emise en < 10 minutes apres echec
- [ ] CS-004: Stockage backup < 80% capacite
- [ ] CS-005: Procedure documentee executable
- [ ] CS-006: tfstate recuperable sans poste local

---

## Notes

- Le provider `bpg/proxmox` v0.93.0 est utilise. Verifier si une version plus recente ajoute des ressources de backup schedule natives avant d'implementer via `null_resource`.
- La migration du tfstate vers Minio doit etre faite manuellement avec `terraform init -migrate-state` pour chaque environnement.
- Le module Minio est deploye sur le node monitoring (pve-mon) car c'est le seul node dedie aux services d'infrastructure (pas de workloads applicatifs).

---

**Version**: 1.0 | **Cree**: 2026-02-01 | **Derniere modification**: 2026-02-01
