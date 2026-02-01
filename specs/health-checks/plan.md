# Plan d'implementation : Health checks automatises

**Branche**: `feature/health-checks`
**Date**: 2026-02-01
**Spec**: [specs/health-checks/spec.md](spec.md)
**Statut**: Draft

---

## Resume

Ajouter un script de verification de sante de l'infrastructure Proxmox, executable apres un `terraform apply` (post-deploiement) ou periodiquement via systemd timer sur le node monitoring. Le script verifie la connectivite (ping, SSH), le statut des VMs/LXC dans Proxmox, les services Docker, la stack monitoring (Prometheus, Grafana, Alertmanager), et le backend Minio S3. Les resultats sont affiches en console, exposes en metriques Prometheus (textfile collector), et declenchent des notifications Telegram via Alertmanager en cas d'echec.

---

## Contexte Technique

| Aspect | Choix | Notes |
|--------|-------|-------|
| **IaC** | Terraform >= 1.5.0 | Provider bpg/proxmox ~0.93 |
| **Execution** | Script shell (bash) | Depuis poste admin (post-deploy) ou node monitoring (periodique) |
| **Scheduling** | systemd timer | Pour l'execution periodique sur le node monitoring |
| **Metriques** | Prometheus textfile collector | Meme approche que la drift detection |
| **Notification** | Alertmanager + Telegram | Systeme existant |
| **Tests** | BATS | Framework existant |

### Contraintes

- Le script doit fonctionner depuis deux contextes : poste administrateur (post-deploy) et node monitoring (periodique)
- Les health checks doivent etre non-intrusifs (lecture seule, pas de modification)
- Timeout configurable par verification pour eviter les blocages
- Le script existant `verify-backups.sh` (639 lignes) couvre deja la verification des backups : ne pas dupliquer

### Performance attendue

| Metrique | Cible |
|----------|-------|
| Duree health check complet | < 2 minutes (CS-002) |
| Duree par verification unitaire | < 10 secondes |
| Timeout par defaut | 5 secondes |

---

## Verification Conventions

- [x] Respecte les conventions du projet (scripts shell avec `common.sh`, BATS tests)
- [x] Coherent avec l'architecture existante (`scripts/`, `tests/`)
- [x] Pas d'over-engineering (script shell, pas de framework de health check)
- [x] Tests planifies (BATS)

---

## Structure du Projet

### Documentation

```
specs/health-checks/
├── spec.md           # Specification fonctionnelle
├── plan.md           # Ce fichier
└── tasks.md          # Decoupage en taches
```

### Code Source

```
scripts/
├── lib/
│   └── common.sh                          # EXISTANT - Librairie commune
├── health/
│   └── check-health.sh                    # NOUVEAU - Script principal
├── systemd/
│   ├── pve-health-check.service           # NOUVEAU - Service systemd
│   └── pve-health-check.timer             # NOUVEAU - Timer systemd
├── drift/                                 # EXISTANT/NOUVEAU (feature drift-detection)
└── restore/                               # EXISTANT

infrastructure/proxmox/
├── modules/monitoring-stack/
│   └── files/
│       ├── prometheus/alerts/
│       │   └── default.yml                # MODIFIER - Ajouter alertes health
│       └── grafana/dashboards/
│           └── health-overview.json       # NOUVEAU - Dashboard sante

tests/
└── health/
    └── test_check_health.bats             # NOUVEAU - Tests BATS
```

---

## Fichiers Impactes

### A creer

| Fichier | Responsabilite |
|---------|----------------|
| `scripts/health/check-health.sh` | Script principal : verifications ping, SSH, Proxmox API, Docker, monitoring, Minio |
| `scripts/systemd/pve-health-check.service` | Unite systemd pour execution periodique |
| `scripts/systemd/pve-health-check.timer` | Timer systemd (toutes les 4 heures par defaut) |
| `tests/health/test_check_health.bats` | Tests BATS : parsing, verifications, erreurs, dry-run |
| `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/health-overview.json` | Dashboard sante globale |

### A modifier

| Fichier | Modification |
|---------|--------------|
| `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` | Ajouter groupe `health-alerts` : `InfraHealthCheckFailed`, `HealthCheckStale` |
| `infrastructure/proxmox/modules/monitoring-stack/main.tf` | S'assurer que le textfile collector est monte (peut etre deja fait par drift-detection) |

### Tests a ajouter

| Fichier | Couverture |
|---------|------------|
| `tests/health/test_check_health.bats` | Chaque type de verification, gestion des timeouts, exclusions, dry-run, generation metriques |

---

## Approche Choisie

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  check-health.sh                                                     │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │ VM/LXC Checks    │  │ Monitoring Checks│  │ Minio Checks     │   │
│  │                  │  │                  │  │                  │   │
│  │ - ping           │  │ - Prometheus     │  │ - endpoint S3    │   │
│  │ - SSH            │  │   :9090/ready    │  │ - buckets exist  │   │
│  │ - Proxmox status │  │ - Grafana        │  │ - state valid    │   │
│  │ - Docker service │  │   :3000/api/     │  │                  │   │
│  │ - QEMU agent     │  │ - Alertmanager   │  │                  │   │
│  │                  │  │   :9093/ready    │  │                  │   │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘   │
│           │                     │                     │              │
│           └─────────────────────┼─────────────────────┘              │
│                                 │                                    │
│                                 ▼                                    │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ Report Engine                                                │    │
│  │                                                              │    │
│  │ - Console output (tableau colore)                            │    │
│  │ - Metriques Prometheus (textfile .prom)                      │    │
│  │ - Exit code (0=OK, 1=warning, 2=critical)                   │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Justification

1. Script shell unique avec modules de verification : coherent avec `verify-backups.sh` et `check-drift.sh`
2. Verifications independantes : chaque check peut echouer sans bloquer les autres
3. Metriques textfile : meme pattern que la drift detection, pas de service supplementaire
4. Composition avec les scripts existants : `check-health.sh` peut appeler `verify-backups.sh --quick` pour un health check complet

### Alternatives considerees

| Alternative | Pourquoi rejetee |
|-------------|------------------|
| Blackbox exporter Prometheus | Necessite un service supplementaire, le script shell est plus simple et plus flexible |
| Health check dans Terraform (provisioner) | Ne couvre pas l'execution periodique, couple au deploiement |
| Uptime Kuma / Gatus | Service supplementaire a deployer et maintenir, surdimensionne pour un homelab |

---

## Phases d'Implementation

### Phase 1 : Structure et verifications VM/LXC (US1 - P1 MVP)

**Objectif**: Verifier la sante des VMs et LXC deployes

- [ ] T001 - [US1] Creer `scripts/health/check-health.sh` - Structure principale, parsing arguments (`--env`, `--all`, `--component`, `--exclude`, `--timeout`, `--dry-run`, `--help`), integration `common.sh`
- [ ] T002 - [US1] Implementer discovery des VMs/LXC dans `scripts/health/check-health.sh` - Lire les IPs et noms depuis les outputs Terraform (`terraform output -json`) ou depuis un fichier d'inventaire
- [ ] T003 - [US1] Implementer verifications VM/LXC dans `scripts/health/check-health.sh` - ping (avec timeout), SSH (avec timeout), statut Proxmox API (`pvesh get /nodes/.../qemu|lxc`), service Docker (`ssh vm docker info`), QEMU Guest Agent
- [ ] T004 - [US1] Implementer rapport console dans `scripts/health/check-health.sh` - Tableau colore : composant | type | statut | detail | duree

**Checkpoint**: `./check-health.sh --env prod` verifie toutes les VMs de prod et affiche un rapport.

### Phase 2 : Verifications monitoring et Minio (US2 + US3 - P1 MVP)

**Objectif**: Verifier la stack monitoring et le backend Minio

- [ ] T005 - [US2] Implementer verifications monitoring dans `scripts/health/check-health.sh` - Prometheus (`curl :9090/-/ready`), Grafana (`curl :3000/api/health`), Alertmanager (`curl :9093/-/ready`), scrape targets (`curl :9090/api/v1/targets` et verifier targets up)
- [ ] T006 - [US3] Implementer verifications Minio dans `scripts/health/check-health.sh` - Endpoint S3 (`curl :9000/minio/health/live`), buckets (`mc ls`), state files (`mc stat` sur chaque bucket tfstate), validite JSON du state
- [ ] T007 - [US1] Implementer mecanisme d'exclusion dans `scripts/health/check-health.sh` - Fichier d'exclusion `/etc/pve-health/exclusions.conf` ou flag `--exclude vm-name`

**Checkpoint**: `./check-health.sh --all` verifie VMs + monitoring + Minio. CS-001 valide.

### Phase 3 : Metriques et notifications (US4 - P2)

**Objectif**: Execution periodique avec metriques et alertes

- [ ] T008 - [US4] Implementer generation metriques Prometheus dans `scripts/health/check-health.sh` - Fichier textfile `pve_health.prom` : `pve_health_status{component,env}` (0=ok, 1=warning, 2=critical), `pve_health_check_duration_seconds`, `pve_health_last_check_timestamp`
- [ ] T009 - [US4] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` - Ajouter groupe `health-alerts` : `InfraHealthCheckFailed` (critical), `HealthCheckStale` (warning, >8h sans check)
- [ ] T010 - [P] [US4] Creer `scripts/systemd/pve-health-check.service` - Type=oneshot, ExecStart=check-health.sh --all
- [ ] T011 - [P] [US4] Creer `scripts/systemd/pve-health-check.timer` - OnCalendar=*-*-* 00/4:00:00 (toutes les 4h), Persistent=true

**Checkpoint**: Health check periodique avec alertes Telegram. CS-004 partiel.

### Phase 4 : Dashboard Grafana (US5 - P3)

**Objectif**: Vue d'ensemble de la sante dans Grafana

- [ ] T012 - [US5] Creer `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/health-overview.json` - Panels : statut par composant (vert/rouge), historique, duree des checks, derniere verification

**Checkpoint**: Dashboard visible dans Grafana.

### Phase 5 : Tests et validation

**Objectif**: Couverture BATS et documentation

- [ ] T013 - [P] Creer `tests/health/test_check_health.bats` - Tests : parsing arguments, chaque type de verification (mock), timeouts, exclusions, generation metriques, dry-run
- [ ] T014 - [P] Creer `docs/HEALTH-CHECKS.md` - Documentation : installation, utilisation post-deploy, configuration periodique, interpretation, troubleshooting
- [ ] T015 - Validation CI - `terraform validate` et `terraform-docs` passent
- [ ] T016 - Test integration manuelle - Arreter une VM, executer health check, verifier detection + alerte

---

## Risques et Mitigations

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| Health check trop lent (timeout accumules) | Moyen | Moyenne | Verifications en parallele (background jobs), timeout court (5s), CS-002 < 2 min |
| Faux positifs sur VMs lentes au demarrage | Moyen | Elevee | Retry configurable, grace period apres deploy |
| Discovery des VMs echoue si terraform output indisponible | Eleve | Faible | Fallback sur fichier d'inventaire statique |
| Conflit avec health checks de la drift detection (deux timers) | Faible | Moyenne | Decaler les horaires (drift 06:00, health 00:00/04:00/08:00...) |

---

## Dependances et Ordre d'Execution

### Dependances entre phases

```
Phase 1 (VM/LXC checks) ──▶ Phase 2 (Monitoring + Minio)
                                │
                                ├──▶ Phase 3 (Metriques + scheduling)
                                │         │
                                │         └──▶ Phase 4 (Dashboard)
                                │
                                └──▶ Phase 5 (Tests + docs)
```

### Dependances entre user stories

| Story | Peut commencer apres | Dependances |
|-------|---------------------|-------------|
| US1 (P1) | Aucune | Phase 1 |
| US2 (P1) | Phase 1 (structure du script) | Ajoute des checks a la structure |
| US3 (P1) | Phase 1 (structure du script) | Ajoute des checks a la structure |
| US4 (P2) | Phase 2 (toutes verifications) | Necessite le script complet |
| US5 (P3) | Phase 3 (metriques) | Necessite les metriques Prometheus |

### Dependances externes

- Feature `drift-detection` : partage le pattern textfile collector et les fichiers systemd. Si implementee en parallele, coordonner le montage du repertoire textfile dans `monitoring-stack/main.tf`.

---

## Criteres de Validation

### Avant de commencer (Gate 1)
- [x] Spec approuvee (spec.md v1.1, clarifications resolues)
- [x] Plan reviewe (ce fichier)
- [ ] Acces SSH aux VMs et au node monitoring

### Avant chaque merge (Gate 2)
- [ ] `terraform validate` passe
- [ ] Tests BATS passent
- [ ] terraform-docs a jour

### Avant deploiement (Gate 3)
- [ ] CS-001: 100% VMs inaccessibles detectees
- [ ] CS-002: Health check complet < 2 minutes
- [ ] CS-005: Tests BATS couvrent les verifications

---

## Notes

- Le script `verify-backups.sh` existe deja et couvre les verifications de backup. `check-health.sh` peut l'appeler en mode rapide (`verify-backups.sh --quick` si on ajoute ce mode) pour un health check complet sans dupliquer la logique.
- Les verifications monitoring utilisent les endpoints de sante natifs : `/ready` pour Prometheus/Alertmanager, `/api/health` pour Grafana. Pas de parsing de metriques complexe.
- Pour Minio, `mc` (Minio client) est le meilleur outil. Le script doit verifier sa presence ou fournir un fallback `curl`.

---

**Version**: 1.0 | **Cree**: 2026-02-01 | **Derniere modification**: 2026-02-01
