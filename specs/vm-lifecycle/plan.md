# Plan d'implementation : Gestion du cycle de vie des VMs

**Branche**: `feature/vm-lifecycle`
**Date**: 2026-02-01
**Spec**: [specs/vm-lifecycle/spec.md](spec.md)
**Statut**: Draft

---

## Resume

Ajouter une gestion du cycle de vie pour les VMs et conteneurs LXC : mises a jour de securite automatiques (via cloud-init + unattended-upgrades), snapshots pre-operation avec rollback et nettoyage automatique, expiration des VMs de lab (14 jours par defaut), et rotation centralisee des cles SSH. L'implementation combine des modifications du cloud-init dans les modules Terraform (VM, LXC), des scripts shell pour les operations de maintenance, et des alertes Prometheus pour les notifications.

---

## Contexte Technique

| Aspect | Choix | Notes |
|--------|-------|-------|
| **IaC** | Terraform >= 1.5.0 | Modules vm et lxc a modifier |
| **Mises a jour** | unattended-upgrades (VMs) + apt cron (LXC) | Package Debian/Ubuntu natif |
| **Snapshots** | API Proxmox (pvesh) | Snapshots QEMU via SSH |
| **Expiration** | Tags Proxmox + script cron | Tag `expires:YYYY-MM-DD` |
| **Rotation SSH** | Script shell + SSH | Deploiement centralise |
| **Notifications** | Alertmanager + Telegram | Systeme existant |
| **Tests** | BATS | Framework existant |

### Contraintes

- Les VMs utilisent Ubuntu (unattended-upgrades disponible)
- Les LXC partagent le kernel de l'hote : pas de mise a jour kernel cote conteneur
- Le QEMU Guest Agent doit etre actif pour les snapshots consistents (deja `agent_enabled = true` par defaut)
- L'expiration ne s'applique qu'a l'environnement lab (protection production)
- La rotation de cles doit verifier la connectivite avant de supprimer l'ancienne cle (anti-lockout)

### Performance attendue

| Metrique | Cible |
|----------|-------|
| Delai application correctif securite | < 24 heures (CS-002) |
| Creation snapshot | < 10 secondes (CS-003) |
| Rollback snapshot | < 30 secondes (CS-003) |
| Rotation cles SSH (toutes machines) | < 5 minutes (CS-005) |

---

## Verification Conventions

- [x] Respecte les conventions du projet (modules Terraform, scripts shell avec `common.sh`)
- [x] Coherent avec l'architecture existante (cloud-init dans modules, scripts dans `scripts/`)
- [x] Pas d'over-engineering (unattended-upgrades natif, pas d'Ansible)
- [x] Tests planifies (BATS)

---

## Structure du Projet

### Documentation

```
specs/vm-lifecycle/
├── spec.md           # Specification fonctionnelle
├── plan.md           # Ce fichier
└── tasks.md          # Decoupage en taches
```

### Code Source

```
infrastructure/proxmox/
├── modules/
│   ├── vm/
│   │   ├── main.tf                        # MODIFIER - cloud-init unattended-upgrades
│   │   ├── variables.tf                   # MODIFIER - variables lifecycle
│   │   └── templates/
│   │       └── cloud-init-userdata.yaml   # MODIFIER - Ajouter config unattended-upgrades
│   └── lxc/
│       ├── main.tf                        # MODIFIER - provisioner unattended-upgrades
│       └── variables.tf                   # MODIFIER - variables lifecycle

scripts/
├── lib/
│   └── common.sh                          # EXISTANT
├── lifecycle/
│   ├── snapshot-vm.sh                     # NOUVEAU - Gestion snapshots
│   ├── expire-lab-vms.sh                  # NOUVEAU - Expiration VMs lab
│   ├── rotate-ssh-keys.sh                 # NOUVEAU - Rotation cles SSH
│   └── cleanup-snapshots.sh              # NOUVEAU - Nettoyage snapshots anciens
├── systemd/
│   ├── pve-expire-lab.service            # NOUVEAU
│   ├── pve-expire-lab.timer              # NOUVEAU - Quotidien
│   ├── pve-cleanup-snapshots.service     # NOUVEAU
│   └── pve-cleanup-snapshots.timer       # NOUVEAU - Quotidien

infrastructure/proxmox/
├── modules/monitoring-stack/
│   └── files/
│       └── prometheus/alerts/
│           └── default.yml                # MODIFIER - Alertes lifecycle

tests/
└── lifecycle/
    ├── test_snapshot_vm.bats              # NOUVEAU
    ├── test_expire_lab.bats               # NOUVEAU
    ├── test_rotate_ssh.bats               # NOUVEAU
    └── test_cleanup_snapshots.bats        # NOUVEAU
```

---

## Fichiers Impactes

### A creer

| Fichier | Responsabilite |
|---------|----------------|
| `scripts/lifecycle/snapshot-vm.sh` | Creer/lister/rollback/supprimer snapshots via pvesh API |
| `scripts/lifecycle/expire-lab-vms.sh` | Scanner les VMs lab expirees, les arreter, notifier |
| `scripts/lifecycle/rotate-ssh-keys.sh` | Deployer nouvelles cles SSH, verifier acces, rapport |
| `scripts/lifecycle/cleanup-snapshots.sh` | Supprimer snapshots > 7 jours (configurable) |
| `scripts/systemd/pve-expire-lab.service` | Service systemd expiration |
| `scripts/systemd/pve-expire-lab.timer` | Timer quotidien 07:00 |
| `scripts/systemd/pve-cleanup-snapshots.service` | Service systemd nettoyage |
| `scripts/systemd/pve-cleanup-snapshots.timer` | Timer quotidien 05:00 |
| `tests/lifecycle/test_snapshot_vm.bats` | Tests BATS snapshot |
| `tests/lifecycle/test_expire_lab.bats` | Tests BATS expiration |
| `tests/lifecycle/test_rotate_ssh.bats` | Tests BATS rotation SSH |
| `tests/lifecycle/test_cleanup_snapshots.bats` | Tests BATS nettoyage |

### A modifier

| Fichier | Modification |
|---------|--------------|
| `infrastructure/proxmox/modules/vm/variables.tf` | Ajouter : `auto_security_updates` (bool, default true), `expiration_days` (number, default null), `additional_ssh_keys` (list) |
| `infrastructure/proxmox/modules/vm/main.tf` | Modifier cloud-init : ajouter package unattended-upgrades, configuration /etc/apt/apt.conf.d/50unattended-upgrades |
| `infrastructure/proxmox/modules/lxc/variables.tf` | Ajouter : `auto_security_updates` (bool, default true), `expiration_days` (number, default null) |
| `infrastructure/proxmox/modules/lxc/main.tf` | Ajouter provisioner post-creation pour configurer unattended-upgrades |
| `infrastructure/proxmox/environments/lab/variables.tf` | Ajouter variable `default_expiration_days` (default 14) |
| `infrastructure/proxmox/environments/lab/terraform.tfvars.example` | Ajouter exemple expiration |
| `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` | Ajouter alertes : `VMRebootRequired`, `LabVMExpired`, `SnapshotOlderThanWeek` |

---

## Approche Choisie

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  CYCLE DE VIE DES VMs                                                │
│                                                                      │
│  ┌──────────────────────────────────────────────────┐                │
│  │ DEPLOIEMENT (Terraform + cloud-init)             │                │
│  │                                                  │                │
│  │ VM/LXC deploye avec:                             │                │
│  │ - unattended-upgrades configure                  │                │
│  │ - tag expires:YYYY-MM-DD (si lab)                │                │
│  │ - cles SSH initiales                             │                │
│  └──────────────────────────────────────────────────┘                │
│                           │                                          │
│              ┌────────────┼────────────┐                             │
│              ▼            ▼            ▼                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                  │
│  │ MISES A JOUR │ │  SNAPSHOTS   │ │  EXPIRATION  │                  │
│  │              │ │              │ │  (lab only)  │                  │
│  │ unattended-  │ │ snapshot-vm  │ │ expire-lab-  │                  │
│  │ upgrades     │ │ .sh          │ │ vms.sh       │                  │
│  │ (automatique)│ │ (manuel +    │ │ (systemd     │                  │
│  │              │ │  cleanup     │ │  timer)      │                  │
│  │              │ │  auto)       │ │              │                  │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘                  │
│         │                │                │                          │
│         ▼                ▼                ▼                          │
│  ┌──────────────────────────────────────────────────┐                │
│  │ ROTATION CLES SSH (rotate-ssh-keys.sh)           │                │
│  │ - Deploie nouvelles cles                         │                │
│  │ - Verifie acces avant suppression ancienne       │                │
│  │ - Execution manuelle ou planifiee                │                │
│  └──────────────────────────────────────────────────┘                │
│                           │                                          │
│                           ▼                                          │
│  ┌──────────────────────────────────────────────────┐                │
│  │ ALERTES (Prometheus + Alertmanager)               │                │
│  │ - VMRebootRequired (reboot necessaire post-maj)  │                │
│  │ - LabVMExpired (VM lab arrivee a expiration)     │                │
│  │ - SnapshotOlderThanWeek (snapshot ancien)        │                │
│  └──────────────────────────────────────────────────┘                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Justification

1. **unattended-upgrades via cloud-init** : configuration au deploiement, pas de second outil (Ansible)
2. **Tags Proxmox pour l'expiration** : visible dans l'interface, queryable via API, pas de base de donnees externe
3. **Scripts shell pour les operations** : coherent avec l'existant, testable avec BATS
4. **Pas de redemarrage automatique** : trop risque, notification pour action humaine

### Alternatives considerees

| Alternative | Pourquoi rejetee |
|-------------|------------------|
| Ansible pour les mises a jour | Dependance supplementaire, le cloud-init suffit pour la configuration initiale |
| Watchtower pour Docker | Hors scope (cycle de vie des conteneurs Docker, pas des VMs) |
| Proxmox Scheduled Snapshots | Pas assez flexible (pas de nettoyage automatique, pas de naming custom) |
| TTL au niveau Terraform (lifecycle) | Terraform ne supporte pas nativement l'expiration temporelle |

---

## Phases d'Implementation

### Phase 1 : Mises a jour de securite automatiques (US1 - P1 MVP)

**Objectif**: Configurer unattended-upgrades sur toutes les nouvelles VMs et LXC

- [ ] T001 - [US1] Modifier `modules/vm/variables.tf` - Ajouter variable `auto_security_updates` (bool, default true)
- [ ] T002 - [US1] Modifier `modules/vm/main.tf` - Etendre cloud-init : installer et configurer unattended-upgrades (security only, no auto-reboot, mail-on-error)
- [ ] T003 - [US1] Modifier `modules/lxc/variables.tf` - Ajouter variable `auto_security_updates` (bool, default true)
- [ ] T004 - [US1] Modifier `modules/lxc/main.tf` - Ajouter provisioner pour installer et configurer unattended-upgrades sur les LXC
- [ ] T005 - [US1] Modifier `modules/monitoring-stack/files/prometheus/alerts/default.yml` - Ajouter alerte `VMRebootRequired` (node_reboot_required == 1 pendant > 24h)

**Checkpoint**: Nouvelles VMs/LXC deployees avec mises a jour de securite automatiques. CS-001 et CS-002 valides.

### Phase 2 : Snapshots pre-operation (US2 - P1 MVP)

**Objectif**: Script de gestion des snapshots avec nettoyage automatique

- [ ] T006 - [US2] Creer `scripts/lifecycle/snapshot-vm.sh` - Commandes : create (--name, --description), list, rollback (--name), delete (--name). Integration `common.sh`, support `--dry-run`
- [ ] T007 - [US2] Creer `scripts/lifecycle/cleanup-snapshots.sh` - Lister snapshots via pvesh, supprimer ceux > 7 jours (configurable via --max-age), notification des suppressions
- [ ] T008 - [P] [US2] Creer `scripts/systemd/pve-cleanup-snapshots.service` - Type=oneshot, ExecStart cleanup-snapshots.sh --all
- [ ] T009 - [P] [US2] Creer `scripts/systemd/pve-cleanup-snapshots.timer` - OnCalendar=*-*-* 05:00:00, Persistent=true
- [ ] T010 - [US2] Modifier `modules/monitoring-stack/files/prometheus/alerts/default.yml` - Ajouter alerte `SnapshotOlderThanWeek`

**Checkpoint**: `snapshot-vm.sh create/rollback/delete` fonctionne. Nettoyage automatique. CS-003 et CS-006 valides.

### Phase 3 : Expiration VMs de lab (US3 - P2)

**Objectif**: Arreter automatiquement les VMs de lab expirees

- [ ] T011 - [US3] Modifier `modules/vm/variables.tf` - Ajouter variable `expiration_days` (number, default null, validation > 0)
- [ ] T012 - [US3] Modifier `modules/vm/main.tf` - Calculer la date d'expiration et ajouter tag `expires:YYYY-MM-DD` si `expiration_days` est defini
- [ ] T013 - [US3] Modifier `modules/lxc/variables.tf` - Ajouter variable `expiration_days` (number, default null)
- [ ] T014 - [US3] Modifier `modules/lxc/main.tf` - Meme logique de tag d'expiration
- [ ] T015 - [US3] Modifier `environments/lab/variables.tf` - Ajouter `default_expiration_days` (default 14)
- [ ] T016 - [US3] Creer `scripts/lifecycle/expire-lab-vms.sh` - Scanner VMs avec tag `expires:`, comparer avec date courante, arreter les expirees (pas supprimer), verifier que l'environnement est `lab` (protection prod), notifier via textfile metrics
- [ ] T017 - [P] [US3] Creer `scripts/systemd/pve-expire-lab.service` - Type=oneshot
- [ ] T018 - [P] [US3] Creer `scripts/systemd/pve-expire-lab.timer` - OnCalendar=*-*-* 07:00:00, Persistent=true
- [ ] T019 - [US3] Modifier `modules/monitoring-stack/files/prometheus/alerts/default.yml` - Ajouter alerte `LabVMExpired`

**Checkpoint**: VMs de lab expirees arretees automatiquement. CS-004 valide.

### Phase 4 : Rotation cles SSH (US4 - P2)

**Objectif**: Deployer et revoquer des cles SSH de maniere centralisee

- [ ] T020 - [US4] Creer `scripts/lifecycle/rotate-ssh-keys.sh` - Arguments : `--add-key`, `--remove-key`, `--env`, `--all`, `--dry-run`. Pour chaque machine : deployer nouvelle cle, verifier acces SSH avec nouvelle cle, supprimer ancienne cle si demande (anti-lockout), rapport final
- [ ] T021 - [US4] Implementer anti-lockout dans `scripts/lifecycle/rotate-ssh-keys.sh` - Verifier acces SSH avec la nouvelle cle AVANT de supprimer l'ancienne. Si echec, conserver l'ancienne et signaler l'erreur

**Checkpoint**: Rotation de cles fonctionne sur toutes les machines sans lockout. CS-005 valide.

### Phase 5 : Tests et documentation

**Objectif**: Couverture BATS et documentation

- [ ] T022 - [P] Creer `tests/lifecycle/test_snapshot_vm.bats` - Tests : create, list, rollback, delete, dry-run, erreurs
- [ ] T023 - [P] Creer `tests/lifecycle/test_expire_lab.bats` - Tests : detection expiration, protection prod, notification
- [ ] T024 - [P] Creer `tests/lifecycle/test_rotate_ssh.bats` - Tests : ajout cle, suppression, anti-lockout, dry-run
- [ ] T025 - [P] Creer `tests/lifecycle/test_cleanup_snapshots.bats` - Tests : detection anciens snapshots, suppression, dry-run
- [ ] T026 - [P] Creer `docs/VM-LIFECYCLE.md` - Documentation : mises a jour, snapshots, expiration, rotation SSH, troubleshooting
- [ ] T027 - Validation CI - `terraform validate` et `terraform-docs` passent
- [ ] T028 - Test integration manuelle - Deployer VM, verifier unattended-upgrades, creer snapshot, rollback, expiration lab

---

## Risques et Mitigations

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| unattended-upgrades casse un service apres mise a jour | Eleve | Faible | Securite-only (pas de maj majeures), snapshot pre-operation (US2) pour rollback |
| Tag d'expiration modifie manuellement dans Proxmox (contournement) | Moyen | Faible | Le script verifie le tag a chaque execution, pas de cache |
| Rotation SSH lockout malgre la verification | Eleve | Tres faible | Anti-lockout obligatoire (T021), dry-run avant execution, rapport d'erreur |
| Snapshots non nettoyes saturent le stockage | Moyen | Moyenne | Nettoyage automatique (T007), alerte SnapshotOlderThanWeek, alerte disk >85% existante |
| cloud-init re-execute lors du reboot (reconfigure unattended-upgrades) | Faible | Faible | cloud-init s'execute uniquement au premier boot (comportement par defaut) |
| Expiration arrete une VM critique du lab | Moyen | Moyenne | Tag `no-expire` pour exclure, notification avant arret, VM arretee pas supprimee |

---

## Dependances et Ordre d'Execution

### Dependances entre phases

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

- Phases 1, 2, 3, 4 sont **totalement independantes** et peuvent etre implementees en parallele
- Au sein de Phase 2 : T008/T009 (systemd) parallelisables
- Au sein de Phase 3 : T017/T018 (systemd) parallelisables
- Phase 5 (tests) : les 4 fichiers BATS sont parallelisables

### Dependances externes

- Feature `drift-detection` et `health-checks` : partagent le pattern systemd timer et les alertes Prometheus. Coordonner les horaires et le fichier `default.yml`.

---

## Criteres de Validation

### Avant de commencer (Gate 1)
- [x] Spec approuvee (spec.md v1.1, clarifications resolues)
- [x] Plan reviewe (ce fichier)
- [ ] Acces SSH aux VMs et aux nodes Proxmox

### Avant chaque merge (Gate 2)
- [ ] `terraform validate` passe
- [ ] Tests BATS passent
- [ ] terraform-docs a jour

### Avant deploiement (Gate 3)
- [ ] CS-001: 100% VMs prod avec mises a jour securite
- [ ] CS-002: Correctifs appliques < 24h
- [ ] CS-003: Snapshot < 10s, rollback < 30s
- [ ] CS-004: VMs lab expirees arretees < 24h
- [ ] CS-005: Rotation SSH < 5 min
- [ ] CS-006: Aucun snapshot > 7 jours sans justification

---

## Notes

- `unattended-upgrades` est le package standard Debian/Ubuntu pour les mises a jour automatiques. La configuration cible uniquement `${distro_id}:${distro_codename}-security` (pas les updates classiques).
- Les snapshots Proxmox sont "crash-consistent". Le QEMU Guest Agent (actif par defaut) permet des snapshots "application-consistent" en gelant le filesystem (fsfreeze).
- Le tag `expires:YYYY-MM-DD` est un pattern simple qui fonctionne avec l'API Proxmox (`pvesh get /nodes/.../qemu --output-format json` + filtre sur tags).
- La protection production est implementee en verifiant le tag `environment:prod` avant toute operation d'expiration. Si le tag est absent, le script refuse d'agir.
- La rotation de cles SSH modifie `~/.ssh/authorized_keys` directement via SSH. Pour les futures VMs, les cles sont geres par Terraform (variable `ssh_keys`).

---

**Version**: 1.0 | **Cree**: 2026-02-01 | **Derniere modification**: 2026-02-01
