# Taches : Health checks automatises

**Input**: Documents depuis `specs/health-checks/`
**Prerequis**: plan.md (requis), spec.md (requis)

---

## Format : `[ID] [P?] [US?] Description`

---

## Phase 1 : Structure et verifications VM/LXC (US1 - P1 MVP)

**Objectif** : Verifier la sante des VMs et LXC deployes

**Test independant** : Arreter une VM, executer le health check, verifier qu'elle est reportee comme down.

- [ ] T001 - [US1] Creer `scripts/health/check-health.sh` - Structure principale, parsing arguments (`--env`, `--all`, `--component`, `--exclude`, `--timeout`, `--dry-run`, `--help`), integration `scripts/lib/common.sh`
- [ ] T002 - [US1] Implementer discovery VMs/LXC dans `scripts/health/check-health.sh` - Lecture IPs/noms depuis `terraform output -json` ou fichier inventaire
- [ ] T003 - [US1] Implementer verifications VM/LXC dans `scripts/health/check-health.sh` - ping, SSH, statut Proxmox API, Docker service, QEMU Guest Agent
- [ ] T004 - [US1] Implementer rapport console dans `scripts/health/check-health.sh` - Tableau colore : composant | type | statut | detail | duree

**Checkpoint** : `./check-health.sh --env prod` verifie toutes les VMs prod.

---

## Phase 2 : Verifications monitoring et Minio (US2 + US3 - P1 MVP)

**Objectif** : Verifier la stack monitoring et le backend Minio

- [ ] T005 - [US2] Implementer verifications monitoring dans `scripts/health/check-health.sh` - Prometheus `:9090/-/ready`, Grafana `:3000/api/health`, Alertmanager `:9093/-/ready`, scrape targets status
- [ ] T006 - [US3] Implementer verifications Minio dans `scripts/health/check-health.sh` - Endpoint `:9000/minio/health/live`, buckets `mc ls`, state files `mc stat`, validite JSON
- [ ] T007 - [US1] Implementer exclusions dans `scripts/health/check-health.sh` - Fichier `/etc/pve-health/exclusions.conf` ou flag `--exclude`

**Checkpoint** : `./check-health.sh --all` verifie VMs + monitoring + Minio.

---

## Phase 3 : Metriques et notifications (US4 - P2)

**Objectif** : Execution periodique avec alertes

- [ ] T008 - [US4] Implementer generation metriques Prometheus dans `scripts/health/check-health.sh` - Fichier textfile `pve_health.prom`
- [ ] T009 - [US4] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` - Groupe `health-alerts` : `InfraHealthCheckFailed`, `HealthCheckStale`
- [ ] T010 - [P] [US4] Creer `scripts/systemd/pve-health-check.service` - Type=oneshot
- [ ] T011 - [P] [US4] Creer `scripts/systemd/pve-health-check.timer` - Toutes les 4 heures, Persistent=true

**Checkpoint** : Health check periodique avec alertes Telegram.

---

## Phase 4 : Dashboard Grafana (US5 - P3)

**Objectif** : Vue d'ensemble dans Grafana

- [ ] T012 - [US5] Creer `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/health-overview.json` - Statut par composant, historique, duree checks

**Checkpoint** : Dashboard visible dans Grafana.

---

## Phase 5 : Tests et validation

**Objectif** : Couverture BATS et documentation

- [ ] T013 - [P] Creer `tests/health/test_check_health.bats` - Parsing, verifications mock, timeouts, exclusions, metriques, dry-run
- [ ] T014 - [P] Creer `docs/HEALTH-CHECKS.md` - Installation, utilisation, configuration, troubleshooting
- [ ] T015 - Validation CI - `terraform validate` et `terraform-docs`
- [ ] T016 - Test integration manuelle - VM arretee → detection → alerte

---

## Dependances et Ordre d'Execution

```
Phase 1 (VM/LXC) ──▶ Phase 2 (Monitoring + Minio)
                          │
                          ├──▶ Phase 3 (Metriques)
                          │         │
                          │         └──▶ Phase 4 (Dashboard)
                          │
                          └──▶ Phase 5 (Tests)
```

| Story | Peut commencer apres | Dependances |
|-------|---------------------|-------------|
| US1 (P1) | Aucune | Phase 1 |
| US2 (P1) | Phase 1 | Structure du script |
| US3 (P1) | Phase 1 | Structure du script |
| US4 (P2) | Phase 2 | Script complet |
| US5 (P3) | Phase 3 | Metriques Prometheus |

---

**Version**: 1.0 | **Cree**: 2026-02-01
