# Taches : Detection de drift infrastructure

**Input**: Documents depuis `specs/drift-detection/`
**Prerequis**: plan.md (requis), spec.md (requis)

---

## Format : `[ID] [P?] [US?] Description`

- **[P]** : Parallelisable (fichiers differents, pas de dependances)
- **[US1/US2/US3]** : User story associee

---

## Phase 1 : Script principal de detection (US1 - P1 MVP)

**Objectif** : Detecter le drift sur chaque environnement et generer un rapport

**Test independant** : Modifier manuellement une VM dans Proxmox, executer le script, verifier que le drift est detecte et affiche.

- [ ] T001 - [US1] Creer `scripts/drift/check-drift.sh` - Structure principale avec parsing arguments (`--env`, `--all`, `--dry-run`, `--help`), integration `scripts/lib/common.sh`
- [ ] T002 - [US1] Implementer detection par environnement dans `scripts/drift/check-drift.sh` - `terraform init -backend-config=...` + `terraform plan -detailed-exitcode -no-color` avec analyse code retour (0=conforme, 1=erreur, 2=drift)
- [ ] T003 - [US1] Implementer parsing du plan dans `scripts/drift/check-drift.sh` - Extraire ressources modifiees/ajoutees/supprimees, generer resume structure
- [ ] T004 - [US1] Implementer rapport console dans `scripts/drift/check-drift.sh` - Tableau : environnement | statut | ressources changees | details
- [ ] T005 - [US1] Implementer stockage rapports dans `scripts/drift/check-drift.sh` - Ecriture `/var/log/pve-drift/drift-YYYY-MM-DD-ENV.log`, rotation 30 jours

**Checkpoint** : `./check-drift.sh --all` detecte le drift et affiche un rapport. `--dry-run` fonctionne avec donnees mock.

---

## Phase 2 : Metriques et notifications (US1 - P1 MVP)

**Objectif** : Exposer les resultats en metriques Prometheus et notifier via Telegram

- [ ] T006 - [US1] Implementer generation metriques Prometheus dans `scripts/drift/check-drift.sh` - Fichier textfile `pve_drift.prom` avec `pve_drift_status{env}`, `pve_drift_resources_changed{env}`, `pve_drift_last_check_timestamp{env}`
- [ ] T007 - [US1] Modifier `infrastructure/proxmox/modules/monitoring-stack/main.tf` - Monter repertoire textfile collector dans container node_exporter
- [ ] T008 - [US1] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` - Ajouter groupe `drift-alerts` : `DriftDetected` (warning), `DriftCheckFailed` (critical), `DriftCheckStale` (warning, >48h sans check)

**Checkpoint** : Drift genere alerte Telegram. Metriques visibles dans Prometheus.

---

## Phase 3 : Scheduling systemd (US1 - P1 MVP)

**Objectif** : Execution automatique quotidienne

- [ ] T009 - [P] [US1] Creer `scripts/systemd/pve-drift-check.service` - Type=oneshot, ExecStart=/opt/pve-home/scripts/drift/check-drift.sh --all
- [ ] T010 - [P] [US1] Creer `scripts/systemd/pve-drift-check.timer` - OnCalendar=*-*-* 06:00:00, Persistent=true
- [ ] T011 - [US1] Documenter installation du timer dans `docs/DRIFT-DETECTION.md` - Instructions `systemctl enable/start`

**Checkpoint** : Timer s'execute automatiquement. CS-001 et CS-002 valides.

---

## Phase 4 : Dashboard conformite (US2 - P2)

**Objectif** : Historique visuel de la conformite dans Grafana

**Test independant** : Apres plusieurs executions, consulter le dashboard et verifier l'historique.

- [ ] T012 - [US2] Creer `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/drift-overview.json` - Panels : statut par env (vert/rouge), historique 30j, ressources en drift, timestamp dernier check

**Checkpoint** : Dashboard visible dans Grafana. CS-004 valide.

---

## Phase 5 : Documentation reconciliation (US3 - P3)

**Objectif** : Procedure documentee pour resoudre le drift

- [ ] T013 - [US3] Ajouter section reconciliation dans `docs/DRIFT-DETECTION.md` - Procedure : identifier drift, decider (apply vs import), executer, verifier resolution

**Checkpoint** : Procedure documentee et testable.

---

## Phase 6 : Tests et validation

**Objectif** : Couverture BATS et validation finale

- [ ] T014 - [P] Creer `tests/drift/test_check_drift.bats` - Tests : parsing arguments, analyse code retour terraform, generation metriques, erreurs (credentials, lock, network), dry-run
- [ ] T015 - [P] Finaliser `docs/DRIFT-DETECTION.md` - Documentation complete : installation, configuration, interpretation rapports, troubleshooting
- [ ] T016 - Validation CI - `terraform validate` et `terraform-docs` passent
- [ ] T017 - Test integration manuelle - Drift volontaire → detection → notification → dashboard

---

## Dependances et Ordre d'Execution

```
Phase 1 (Script) ──▶ Phase 2 (Metriques)
     │                    │
     │                    ├──▶ Phase 4 (Dashboard)
     │                    │
     └──▶ Phase 3 (Scheduling)
               │
               └──▶ Phase 5 (Documentation)

Phases 1-5 ──▶ Phase 6 (Tests + Validation)
```

### Dependances entre user stories

| Story | Peut commencer apres | Dependances |
|-------|---------------------|-------------|
| US1 (P1) | Aucune | Script + metriques + scheduling |
| US2 (P2) | Phase 2 (metriques) | Metriques Prometheus necessaires pour Grafana |
| US3 (P3) | Phase 1 (script) | Le script doit exister pour documenter la reconciliation |

---

**Version**: 1.0 | **Cree**: 2026-02-01
