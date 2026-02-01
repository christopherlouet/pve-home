# Taches v1.1 - Ameliorations fiabilite et observabilite

## Phase 1 : Alertes Prometheus [US1]

### T001 - [US1] Ajouter 5 alertes Prometheus
**Fichier**: `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml`
**Action**: Ajouter dans les groupes existants :

Groupe `node-alerts` (+3) :
- `SystemdServiceFailed` : `node_systemd_unit_state{state="failed"} == 1` (5m, warning)
- `HighLoadAverage` : `node_load15 / count without(cpu,mode)(node_cpu_seconds_total{mode="idle"}) > 2` (10m, warning)
- `HighNetworkErrors` : `rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m]) > 10` (5m, warning)

Groupe `prometheus-alerts` (+1) :
- `PrometheusRuleEvaluationFailures` : `increase(prometheus_rule_evaluation_failures_total[5m]) > 0` (5m, warning)

Groupe `node-alerts` (+1) :
- `NodeFilesystemAlmostOutOfInodes` : inodes usage > 90% (5m, warning)

---

## Phase 2 : Tests de non-regression [US2] [P]

> Les 4 taches T002-T005 sont parallelisables.

### T002 - [P] [US2] Regression LXC
**Fichier**: `infrastructure/proxmox/modules/lxc/tests/regression.tftest.hcl`
**Tests** (~5 runs) :
- v0.7.2 : Tags preservation (concat preserves provided tags)
- v0.7.2 : Default description = "Managed by Terraform"
- v0.7.2 : Custom description preserved
- v0.9.0 : auto_security_updates count = 0 quand os_type != ubuntu/debian
- v0.9.0 : auto_security_updates count = 1 quand os_type = ubuntu et flag actif

### T003 - [P] [US2] Regression Backup
**Fichier**: `infrastructure/proxmox/modules/backup/tests/regression.tftest.hcl`
**Tests** (~4 runs) :
- v0.7.0 : retention triggers (keep_daily=7 par defaut en position [7])
- v0.7.0 : VMIDs vide = string vide "" (pas null)
- v0.7.0 : enabled=false ne change pas les triggers de retention
- v0.7.0 : schedule par defaut = "01:00" en position [0]

### T004 - [P] [US2] Regression Minio
**Fichier**: `infrastructure/proxmox/modules/minio/tests/regression.tftest.hcl`
**Tests** (~5 runs) :
- v0.7.2 : mount_point size avec suffixe "G" (pas nombre nu)
- v0.7.2 : tags preserves tels quels
- v1.0.0 : output endpoint_url existe
- v1.0.0 : output console_url existe
- v1.0.0 : output container_id existe

### T005 - [P] [US2] Regression Monitoring-stack
**Fichier**: `infrastructure/proxmox/modules/monitoring-stack/tests/regression.tftest.hcl`
**Tests** (~4 runs) :
- v0.4.0 : SCSI hardware = "virtio-scsi-single"
- v0.5.0 : cloud-config snippet datastore = "local"
- v0.9.0 : SSH keypair algorithm = "ED25519"
- v0.7.2 : default description via tags/VM name

### T006 - [US2] Validation tests Terraform
**Commande**: `terraform test` sur les 5 modules
**Critere**: 100% pass, compteur total affiche

---

## Phase 3 : Retry/backoff [US3]

### T007 - [US3] Fonctions retry dans common.sh
**Fichier**: `scripts/lib/common.sh`
**Action**: Ajouter apres la section SSH (ligne ~145) :
- `retry_with_backoff(max_attempts, command...)` - retry generique avec backoff x2
- `ssh_exec_retry(node, command)` - wrapper ssh_exec avec 3 tentatives

### T008 - [US3] Modifier check_ssh_access
**Fichier**: `scripts/lib/common.sh`
**Action**: Remplacer l'appel SSH direct par `retry_with_backoff 3 ssh ...` dans check_ssh_access()

### T009 - [US3] Tests BATS retry
**Fichier**: `tests/restore/test_common.bats`
**Tests** (+7) :
- retry_with_backoff existe
- retry_with_backoff reussit au 1er essai
- retry_with_backoff reussit au 2eme essai
- retry_with_backoff echoue apres max tentatives
- retry_with_backoff respecte le DRY_RUN (non applicable, la commande sous-jacente gere)
- ssh_exec_retry existe
- check_ssh_access utilise retry (verify function definition)

### T010 - [US3] Validation tests BATS
**Commande**: `bats tests/restore/test_common.bats`
**Critere**: 100% pass

---

## Phase 4 : Validation globale

### T011 - Validation complete
- `terraform test` sur les 5 modules
- `bats tests/restore/test_common.bats`
- Comptage total des tests

### T012 - Commit et PR
- Branche: `feature/v1.1-improvements`
- Commit: `feat: add alerts, regression tests, retry/backoff for v1.1`
- PR vers main

---

## Ordre d'execution

```
Phase 1 (T001) ──────────────────────────────────────────────────▶ T011
                                                                    │
Phase 2 (T002 + T003 + T004 + T005 en parallele) ──▶ T006 ────────▶│
                                                                    │
Phase 3 (T007 ──▶ T008 ──▶ T009 ──▶ T010) ────────────────────────▶│
                                                                    ▼
                                                                  T012
```

Les 3 phases sont independantes et pourraient etre faites en parallele.
