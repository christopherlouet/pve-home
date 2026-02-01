# Taches : Gestion du cycle de vie des VMs

**Input**: Documents depuis `specs/vm-lifecycle/`
**Prerequis**: plan.md (requis), spec.md (requis)

---

## Format : `[ID] [P?] [US?] Description`

---

## Phase 1 : Mises a jour de securite automatiques (US1 - P1 MVP)

**Objectif** : Configurer unattended-upgrades sur nouvelles VMs et LXC

**Test independant** : Deployer une VM, verifier que unattended-upgrades est installe et configure pour securite uniquement.

- [ ] T001 - [US1] Modifier `infrastructure/proxmox/modules/vm/variables.tf` - Ajouter `auto_security_updates` (bool, default true)
- [ ] T002 - [US1] Modifier `infrastructure/proxmox/modules/vm/main.tf` - Etendre cloud-init : installer unattended-upgrades, configurer securite-only, no auto-reboot
- [ ] T003 - [US1] Modifier `infrastructure/proxmox/modules/lxc/variables.tf` - Ajouter `auto_security_updates` (bool, default true)
- [ ] T004 - [US1] Modifier `infrastructure/proxmox/modules/lxc/main.tf` - Provisioner unattended-upgrades sur LXC
- [ ] T005 - [US1] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` - Alerte `VMRebootRequired`

**Checkpoint** : Nouvelles VMs/LXC deployes avec mises a jour securite. CS-001, CS-002.

---

## Phase 2 : Snapshots pre-operation (US2 - P1 MVP)

**Objectif** : Gestion snapshots avec nettoyage automatique

**Test independant** : Creer snapshot, modifier VM, rollback, verifier retour etat initial.

- [ ] T006 - [US2] Creer `scripts/lifecycle/snapshot-vm.sh` - create/list/rollback/delete, integration `common.sh`, `--dry-run`
- [ ] T007 - [US2] Creer `scripts/lifecycle/cleanup-snapshots.sh` - Supprimer snapshots > 7j (configurable `--max-age`), notification
- [ ] T008 - [P] [US2] Creer `scripts/systemd/pve-cleanup-snapshots.service` - Type=oneshot
- [ ] T009 - [P] [US2] Creer `scripts/systemd/pve-cleanup-snapshots.timer` - 05:00 quotidien, Persistent=true
- [ ] T010 - [US2] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` - Alerte `SnapshotOlderThanWeek`

**Checkpoint** : Snapshots fonctionnels, nettoyage auto. CS-003, CS-006.

---

## Phase 3 : Expiration VMs de lab (US3 - P2)

**Objectif** : Arreter automatiquement VMs lab expirees

**Test independant** : VM lab avec expiration 1j, attendre, verifier arret.

- [ ] T011 - [US3] Modifier `infrastructure/proxmox/modules/vm/variables.tf` - Ajouter `expiration_days` (number, default null, > 0)
- [ ] T012 - [US3] Modifier `infrastructure/proxmox/modules/vm/main.tf` - Tag `expires:YYYY-MM-DD` si expiration definie
- [ ] T013 - [US3] Modifier `infrastructure/proxmox/modules/lxc/variables.tf` - Ajouter `expiration_days`
- [ ] T014 - [US3] Modifier `infrastructure/proxmox/modules/lxc/main.tf` - Tag expiration
- [ ] T015 - [US3] Modifier `infrastructure/proxmox/environments/lab/variables.tf` - `default_expiration_days` (14)
- [ ] T016 - [US3] Creer `scripts/lifecycle/expire-lab-vms.sh` - Scanner tags, comparer dates, arreter expirees, protection prod, metriques textfile
- [ ] T017 - [P] [US3] Creer `scripts/systemd/pve-expire-lab.service` - Type=oneshot
- [ ] T018 - [P] [US3] Creer `scripts/systemd/pve-expire-lab.timer` - 07:00 quotidien
- [ ] T019 - [US3] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` - Alerte `LabVMExpired`

**Checkpoint** : VMs lab expirees arretees. CS-004.

---

## Phase 4 : Rotation cles SSH (US4 - P2)

**Objectif** : Deploiement et revocation centralisee des cles SSH

**Test independant** : Ajouter nouvelle cle, verifier acces, revoquer ancienne, verifier non-acces.

- [ ] T020 - [US4] Creer `scripts/lifecycle/rotate-ssh-keys.sh` - `--add-key`, `--remove-key`, `--env`, `--all`, `--dry-run`, rapport
- [ ] T021 - [US4] Implementer anti-lockout dans `scripts/lifecycle/rotate-ssh-keys.sh` - Verifier acces nouvelle cle AVANT suppression ancienne

**Checkpoint** : Rotation sans lockout. CS-005.

---

## Phase 5 : Tests et documentation

**Objectif** : Couverture BATS et documentation

- [ ] T022 - [P] Creer `tests/lifecycle/test_snapshot_vm.bats` - create, list, rollback, delete, dry-run, erreurs
- [ ] T023 - [P] Creer `tests/lifecycle/test_expire_lab.bats` - detection, protection prod, notification
- [ ] T024 - [P] Creer `tests/lifecycle/test_rotate_ssh.bats` - ajout, suppression, anti-lockout, dry-run
- [ ] T025 - [P] Creer `tests/lifecycle/test_cleanup_snapshots.bats` - detection, suppression, dry-run
- [ ] T026 - [P] Creer `docs/VM-LIFECYCLE.md` - Mises a jour, snapshots, expiration, rotation, troubleshooting
- [ ] T027 - Validation CI - `terraform validate`, `terraform-docs`
- [ ] T028 - Test integration manuelle - Deploy VM → unattended-upgrades → snapshot → rollback → expiration → rotation

---

## Dependances et Ordre d'Execution

```
Phase 1 (Mises a jour) ──┐
                          │
Phase 2 (Snapshots) ─────┤──▶ Phase 5 (Tests + docs)
                          │
Phase 3 (Expiration) ─────┤
                          │
Phase 4 (Rotation SSH) ───┘
```

### Parallelisation

- Phases 1, 2, 3, 4 sont **totalement independantes**
- T008/T009 (systemd cleanup) parallelisables
- T017/T018 (systemd expire) parallelisables
- T022/T023/T024/T025 (tests BATS) parallelisables

| Story | Peut commencer apres | Dependances |
|-------|---------------------|-------------|
| US1 (P1) | Aucune | Phase 1 |
| US2 (P1) | Aucune | Phase 2 |
| US3 (P2) | Aucune | Phase 3 |
| US4 (P2) | Aucune | Phase 4 |
| US5 (P3) | Phases 1-4 | Necessite metriques pour dashboard |

---

**Version**: 1.0 | **Cree**: 2026-02-01
