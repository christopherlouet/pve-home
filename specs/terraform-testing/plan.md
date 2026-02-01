# Plan d'implementation : Tests d'infrastructure Terraform natifs

**Branche**: `feature/terraform-testing`
**Date**: 2026-02-01
**Spec**: [specs/terraform-testing/spec.md](spec.md)
**Statut**: Draft

---

## Resume

Ajouter des tests natifs Terraform (`.tftest.hcl`) pour les 5 modules existants (vm, lxc, backup, minio, monitoring-stack). Les tests valident les regles de validation des variables, le plan genere (nombre et types de ressources), et les corrections de bugs anterieures (non-regression). La version minimum de Terraform est bumped a >= 1.9.0 pour beneficier des mock providers. Les tests sont integres dans le workflow CI GitHub Actions existant.

---

## Contexte Technique

| Aspect | Choix | Notes |
|--------|-------|-------|
| **IaC** | Terraform >= 1.9.0 | Bump depuis >= 1.5.0 |
| **Provider** | bpg/proxmox ~0.93 | Mock provider en mode test |
| **Framework test** | `terraform test` natif | Disponible depuis TF 1.6, mock providers depuis 1.7 |
| **CI** | GitHub Actions | Workflow `ci.yml` existant a etendre |
| **Fichiers test** | `.tftest.hcl` | Convention Terraform native |

### Contraintes

- Les tests s'executent en mode `plan` uniquement (pas de deploiement reel)
- Les mock providers permettent de tester sans credentials Proxmox ni endpoint reel
- La version 1.9.0 minimum est acceptee (deja installee partout)
- Les tests doivent rester rapides (< 30s par module, < 2 min total)

### Performance attendue

| Metrique | Cible |
|----------|-------|
| Duree par module | < 30 secondes |
| Duree totale (5 modules) | < 2 minutes (CS-003) |
| Couverture validations | 100% (CS-002) |

---

## Verification Conventions

- [x] Respecte les conventions du projet (modules Terraform, snake_case)
- [x] Coherent avec l'architecture existante (tests dans `tests/` ou inline dans modules)
- [x] Pas d'over-engineering (framework natif, pas de Terratest/Go)
- [x] Tests planifies (terraform test)

---

## Structure du Projet

### Documentation

```
specs/terraform-testing/
├── spec.md           # Specification fonctionnelle
├── plan.md           # Ce fichier
└── tasks.md          # Decoupage en taches
```

### Code Source

```
infrastructure/proxmox/
├── versions.tf                            # MODIFIER - Bump >= 1.9.0
├── modules/
│   ├── vm/
│   │   ├── main.tf                        # EXISTANT
│   │   ├── variables.tf                   # EXISTANT
│   │   └── tests/
│   │       ├── valid_inputs.tftest.hcl    # NOUVEAU - Validations entrees
│   │       ├── plan_resources.tftest.hcl  # NOUVEAU - Verification du plan
│   │       └── regression.tftest.hcl      # NOUVEAU - Non-regression
│   ├── lxc/
│   │   └── tests/
│   │       ├── valid_inputs.tftest.hcl    # NOUVEAU
│   │       └── plan_resources.tftest.hcl  # NOUVEAU
│   ├── backup/
│   │   └── tests/
│   │       ├── valid_inputs.tftest.hcl    # NOUVEAU
│   │       └── plan_resources.tftest.hcl  # NOUVEAU
│   ├── minio/
│   │   └── tests/
│   │       ├── valid_inputs.tftest.hcl    # NOUVEAU
│   │       ├── plan_resources.tftest.hcl  # NOUVEAU
│   │       └── regression.tftest.hcl      # NOUVEAU - mount_point size
│   └── monitoring-stack/
│       └── tests/
│           ├── valid_inputs.tftest.hcl    # NOUVEAU
│           └── plan_resources.tftest.hcl  # NOUVEAU

.github/workflows/
└── ci.yml                                 # MODIFIER - Ajouter job terraform-test
```

---

## Fichiers Impactes

### A creer

| Fichier | Responsabilite |
|---------|----------------|
| `modules/vm/tests/valid_inputs.tftest.hcl` | Tests validations : template_id, cpu_cores, memory_mb, disk_size_gb, ip_address, vlan_id |
| `modules/vm/tests/plan_resources.tftest.hcl` | Tests plan : VM, cloud-init, firewall rules, disques additionnels, Docker |
| `modules/vm/tests/regression.tftest.hcl` | Tests non-regression : tags tries, agent timeout |
| `modules/lxc/tests/valid_inputs.tftest.hcl` | Tests validations : hostname, ip, features, mount_points |
| `modules/lxc/tests/plan_resources.tftest.hcl` | Tests plan : LXC container, mount points, features |
| `modules/backup/tests/valid_inputs.tftest.hcl` | Tests validations : schedule, retention, vmids |
| `modules/backup/tests/plan_resources.tftest.hcl` | Tests plan : backup job, terraform_data |
| `modules/minio/tests/valid_inputs.tftest.hcl` | Tests validations : hostname, ip, buckets, credentials |
| `modules/minio/tests/plan_resources.tftest.hcl` | Tests plan : LXC, provisioners, buckets |
| `modules/minio/tests/regression.tftest.hcl` | Tests non-regression : mount_point size drift |
| `modules/monitoring-stack/tests/valid_inputs.tftest.hcl` | Tests validations : prometheus_retention, grafana_password, pve_nodes, telegram config |
| `modules/monitoring-stack/tests/plan_resources.tftest.hcl` | Tests plan : VM, Docker compose, dashboards, alertes |

### A modifier

| Fichier | Modification |
|---------|--------------|
| `infrastructure/proxmox/versions.tf` | Bump `required_version` de `>= 1.5.0` a `>= 1.9.0` |
| `infrastructure/proxmox/modules/*/versions.tf` | Bump `required_version` si present dans les modules |
| `.github/workflows/ci.yml` | Ajouter job `terraform-test` avec matrice sur les 5 modules |

---

## Approche Choisie

### Architecture de test

```
┌─────────────────────────────────────────────────────────────────────┐
│  terraform test                                                      │
│                                                                      │
│  ┌──────────────────────────────────────────────────┐                │
│  │ Mock Provider (bpg/proxmox)                      │                │
│  │                                                  │                │
│  │ - Pas de connexion reelle a Proxmox              │                │
│  │ - Simule les reponses API                        │                │
│  │ - Permet de tester le plan sans infrastructure   │                │
│  └──────────────────────────────────────────────────┘                │
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐         │
│  │ valid_inputs   │  │ plan_resources │  │ regression     │         │
│  │                │  │                │  │                │         │
│  │ - Valeurs      │  │ - Nombre de   │  │ - Tags tries   │         │
│  │   invalides    │  │   ressources  │  │ - mount_point  │         │
│  │ - Valeurs      │  │ - Types       │  │   size         │         │
│  │   limites      │  │ - Attributs   │  │ - Autres bugs  │         │
│  │ - Defauts      │  │   cles        │  │   corriges     │         │
│  └────────────────┘  └────────────────┘  └────────────────┘         │
│                                                                      │
│  Chaque fichier = run block(s) avec variables + assertions           │
│  Mode: command = plan (jamais apply)                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Justification

1. `terraform test` natif (>= 1.7) avec mock providers permet de tester sans infrastructure
2. Fichiers `.tftest.hcl` dans `tests/` par module : convention claire et decouverte automatique
3. Mode `plan` uniquement : rapide, sans effets de bord, executable en CI
4. Separation en 3 categories (validations, plan, regression) : lisibilite et maintenance

### Alternatives considerees

| Alternative | Pourquoi rejetee |
|-------------|------------------|
| Terratest (Go) | Dependance supplementaire (Go), plus complexe, necessiterait un vrai Proxmox pour apply |
| terraform validate uniquement | Deja en place, ne couvre pas la logique metier (validations custom, plan) |
| Tests manuels (plan + review) | Non automatisable, erreur humaine, pas de CI |
| Kitchen-Terraform | Projet abandonne, communaute reduite |

---

## Phases d'Implementation

### Phase 1 : Bump version et setup (bloquant)

**Objectif**: Preparer l'infrastructure de test

- [ ] T001 - Modifier `infrastructure/proxmox/versions.tf` - Bump `required_version` a `>= 1.9.0`
- [ ] T002 - [P] Verifier et bumper les `versions.tf` de chaque module si necessaire
- [ ] T003 - Valider que `terraform test` fonctionne sur un module simple (test de fumee)

**Checkpoint**: `terraform test` s'execute sans erreur sur un module.

### Phase 2 : Tests module VM (US1 + US2 - P1 MVP)

**Objectif**: Couvrir le module le plus complexe en premier

- [ ] T004 - [US1] Creer `modules/vm/tests/valid_inputs.tftest.hcl` - Tests validations : template_id < 100, cpu_cores hors range, memory hors range, disk < 4, ip_address invalide, valeurs par defaut
- [ ] T005 - [US2] Creer `modules/vm/tests/plan_resources.tftest.hcl` - Tests plan : VM creee, cloud-init file, firewall rules, disk backup, Docker optionnel, disques additionnels
- [ ] T006 - [US4] Creer `modules/vm/tests/regression.tftest.hcl` - Tests non-regression : tags tries et dedupliques (v0.7.2)

**Checkpoint**: `terraform test` passe sur le module VM. CS-001 partiel.

### Phase 3 : Tests module LXC (US1 + US2 - P1 MVP)

**Objectif**: Couvrir le module LXC

- [ ] T007 - [P] [US1] Creer `modules/lxc/tests/valid_inputs.tftest.hcl` - Tests validations : hostname, ip, features, mount_points
- [ ] T008 - [P] [US2] Creer `modules/lxc/tests/plan_resources.tftest.hcl` - Tests plan : LXC container, mount points, features nesting

**Checkpoint**: `terraform test` passe sur le module LXC.

### Phase 4 : Tests modules backup et minio (US1 + US2 + US4 - P1/P2)

**Objectif**: Couvrir les modules de donnees

- [ ] T009 - [P] [US1] Creer `modules/backup/tests/valid_inputs.tftest.hcl` - Tests validations : schedule format, retention values, vmids
- [ ] T010 - [P] [US2] Creer `modules/backup/tests/plan_resources.tftest.hcl` - Tests plan : terraform_data backup job
- [ ] T011 - [P] [US1] Creer `modules/minio/tests/valid_inputs.tftest.hcl` - Tests validations : hostname, ip, buckets, credentials
- [ ] T012 - [P] [US2] Creer `modules/minio/tests/plan_resources.tftest.hcl` - Tests plan : LXC, provisioners, buckets
- [ ] T013 - [US4] Creer `modules/minio/tests/regression.tftest.hcl` - Tests non-regression : mount_point size drift (v0.7.2)

**Checkpoint**: `terraform test` passe sur backup et minio.

### Phase 5 : Tests module monitoring-stack (US1 + US2)

**Objectif**: Couvrir le module le plus large

- [ ] T014 - [P] [US1] Creer `modules/monitoring-stack/tests/valid_inputs.tftest.hcl` - Tests validations : prometheus_retention, grafana_password, pve_nodes, telegram config
- [ ] T015 - [P] [US2] Creer `modules/monitoring-stack/tests/plan_resources.tftest.hcl` - Tests plan : VM, Docker compose files, dashboards, alertes

**Checkpoint**: 100% des modules couverts. CS-001 valide.

### Phase 6 : Integration CI (US3 - P2)

**Objectif**: Executer les tests automatiquement en CI

- [ ] T016 - [US3] Modifier `.github/workflows/ci.yml` - Ajouter job `terraform-test` avec matrice sur les 5 modules, Terraform 1.9.x, timeout 5 min
- [ ] T017 - [US3] Valider que le job CI passe sur la branche main

**Checkpoint**: PR avec modification de module → tests executes en CI. CS-004 valide.

### Phase 7 : Documentation (US5 - P3)

**Objectif**: Documenter la strategie de test

- [ ] T018 - [P] [US5] Ajouter section testing dans `infrastructure/proxmox/README.md` - Comment ecrire un test, executer, conventions, exemples
- [ ] T019 - Validation finale - Tous les tests passent, CI verte, documentation a jour

---

## Risques et Mitigations

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| Mock provider ne supporte pas toutes les ressources bpg/proxmox | Eleve | Moyenne | Tester avec `command = plan` qui ne necessite pas de mock complet, fallback sur `override_resource` |
| Bump TF 1.9 casse la compatibilite avec l'infrastructure existante | Eleve | Faible | Tester `terraform plan` sur chaque environnement avant merge |
| Tests flaky en CI (timeout, race condition) | Moyen | Faible | Timeout genereux (5 min), pas de concurrence entre modules |
| Maintenance des tests lors des evolutions de modules | Moyen | Elevee | Tests simples et focalises, convention claire, documentation |

---

## Dependances et Ordre d'Execution

### Dependances entre phases

```
Phase 1 (Setup/bump) ──┬──▶ Phase 2 (VM tests)
                       │
                       ├──▶ Phase 3 (LXC tests) [parallelisable avec Phase 2]
                       │
                       ├──▶ Phase 4 (backup + minio tests) [parallelisable]
                       │
                       └──▶ Phase 5 (monitoring tests) [parallelisable]

Phases 2-5 ──▶ Phase 6 (CI)

Phase 6 ──▶ Phase 7 (Documentation)
```

### Parallelisation

- Phases 2, 3, 4, 5 sont **totalement independantes** et peuvent etre implementees en parallele
- Au sein de chaque phase, les fichiers de test sont independants (taches [P])
- Phase 6 (CI) necessite que tous les tests existent

---

## Criteres de Validation

### Avant de commencer (Gate 1)
- [x] Spec approuvee (spec.md v1.1, clarifications resolues)
- [x] Plan reviewe (ce fichier)
- [ ] Terraform >= 1.9.0 installe localement

### Avant chaque merge (Gate 2)
- [ ] `terraform test` passe pour chaque module modifie
- [ ] `terraform validate` passe
- [ ] terraform-docs a jour

### Avant deploiement (Gate 3)
- [ ] CS-001: 5/5 modules ont des tests
- [ ] CS-002: 100% des validations couvertes
- [ ] CS-003: Tests < 2 minutes total
- [ ] CS-004: Tests passent en CI

---

## Notes

- `terraform test` avec `command = plan` n'execute pas de deploiement : les tests sont rapides et sans risque.
- Les mock providers (TF >= 1.7) permettent de simuler les reponses du provider sans connexion reelle. Pour `bpg/proxmox`, cela signifie qu'on peut tester le plan sans Proxmox accessible.
- Les fichiers `.tftest.hcl` dans un sous-repertoire `tests/` du module sont decouverts automatiquement par `terraform test`.
- Les tests de validation utilisent `expect_failures` pour verifier que les erreurs de validation sont bien declenchees.
- Le bump de version de `>= 1.5.0` a `>= 1.9.0` doit etre fait en premier car il impacte tous les environnements.

---

**Version**: 1.0 | **Cree**: 2026-02-01 | **Derniere modification**: 2026-02-01
