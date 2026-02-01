# Taches : Tests d'infrastructure Terraform natifs

**Input**: Documents depuis `specs/terraform-testing/`
**Prerequis**: plan.md (requis), spec.md (requis)

---

## Format : `[ID] [P?] [US?] Description`

---

## Phase 1 : Bump version et setup (bloquant)

**Objectif** : Preparer l'infrastructure de test

- [x] T001 - Modifier `infrastructure/proxmox/versions.tf` - Bump `required_version` a `>= 1.9.0`
- [x] T002 - [P] Verifier et bumper `versions.tf` de chaque environnement (prod, lab, monitoring)
- [x] T003 - Valider `terraform test` sur un module simple (test de fumee)

**Checkpoint** : `terraform test` fonctionne. ✅

---

## Phase 2 : Tests module VM (US1 + US2 + US4 - P1 MVP)

**Objectif** : Couvrir le module le plus complexe

**Test independant** : `cd modules/vm && terraform test`

- [x] T004 - [US1] Creer `modules/vm/tests/valid_inputs.tftest.hcl` - 15 run blocks (template_id, cpu, memory, disk, ip, defauts)
- [x] T005 - [US2] Creer `modules/vm/tests/plan_resources.tftest.hcl` - 14 run blocks (VM, cloud-init, Docker, backup, VLAN, disques)
- [x] T006 - [US4] Creer `modules/vm/tests/regression.tftest.hcl` - 5 run blocks (tags, description v0.7.2)

**Checkpoint** : `terraform test` passe sur module VM. ✅

---

## Phase 3 : Tests module LXC (US1 + US2)

**Objectif** : Couvrir le module LXC

- [x] T007 - [P] [US1] Creer `modules/lxc/tests/valid_inputs.tftest.hcl` - 27 run blocks (os_type, cpu, memory, swap, disk, ip, defauts)
- [x] T008 - [P] [US2] Creer `modules/lxc/tests/plan_resources.tftest.hcl` - 13 run blocks (container, OS, CPU, memory, disk, network, features, nesting, VLAN, description, privileged)

**Checkpoint** : `terraform test` passe sur module LXC. ✅

---

## Phase 4 : Tests modules backup et minio (US1 + US2)

**Objectif** : Couvrir les modules de donnees

- [x] T009 - [P] [US1] Creer `modules/backup/tests/valid_inputs.tftest.hcl` - 20 run blocks (storage_id, schedule, mode, compress, notification, retention, defauts)
- [x] T011 - [P] [US1] Creer `modules/minio/tests/valid_inputs.tftest.hcl` - 23 run blocks (container_id, cpu, memory, disk, data_disk, ip, ports, defauts)
- [x] T012 - [P] [US2] Creer `modules/minio/tests/plan_resources.tftest.hcl` - 12 run blocks (container, OS, CPU, memory, disk, mount, network, tags, description, custom)

**Checkpoint** : `terraform test` passe sur backup et minio. ✅

---

## Phase 5 : Tests module monitoring-stack (US1)

**Objectif** : Couvrir le module le plus large

- [x] T014 - [P] [US1] Creer `modules/monitoring-stack/tests/valid_inputs.tftest.hcl` - 30 run blocks (template_id, vm_config, ip, network_cidr, retention, defauts)

**Checkpoint** : 5/5 modules couverts. CS-001 valide. ✅

---

## Phase 6 : Integration CI (US3 - P2)

**Objectif** : Tests automatiques en CI

- [x] T016 - [US3] Modifier `.github/workflows/ci.yml` - Job `terraform-test`, matrice 5 modules, TF 1.9.8
- [ ] T017 - [US3] Valider CI sur branche (apres push)

**Checkpoint** : PR → tests CI executes.

---

## Phase 7 : Documentation (US5 - P3)

**Objectif** : Documenter la strategie

- [ ] T018 - [P] [US5] Ajouter section testing dans `infrastructure/proxmox/README.md`
- [ ] T019 - Validation finale - Tous tests passent, CI verte

---

## Dependances et Ordre d'Execution

```
Phase 1 (Setup) ──┬──▶ Phase 2 (VM)
                  ├──▶ Phase 3 (LXC)       [parallele]
                  ├──▶ Phase 4 (backup+minio) [parallele]
                  └──▶ Phase 5 (monitoring)  [parallele]

Phases 2-5 ──▶ Phase 6 (CI)
Phase 6 ──▶ Phase 7 (Documentation)
```

| Story | Peut commencer apres | Dependances |
|-------|---------------------|-------------|
| US1 (P1) | Phase 1 | Tests validations sur tous modules |
| US2 (P1) | Phase 1 | Tests plan sur tous modules |
| US3 (P2) | Phases 2-5 | Tous les tests doivent exister |
| US4 (P2) | Phase 1 | Tests regression (vm, minio) |
| US5 (P3) | Phase 6 | CI fonctionnelle |

---

**Version**: 1.1 | **Cree**: 2026-02-01 | **Mis a jour**: 2026-02-01
