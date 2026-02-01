# Plan d'implementation : Ameliorations v1.1

## Resume

Ajouter 5 alertes Prometheus manquantes, creer des tests de non-regression pour les 4 modules sans couverture, et implementer une fonction retry/backoff dans la bibliotheque de scripts partagee. Complexite globale : moyenne (8 fichiers a creer, 2 a modifier).

## Contexte Technique

| Aspect | Choix |
|--------|-------|
| IaC | Terraform >= 1.9 avec `terraform test` natif |
| Tests TF | `.tftest.hcl` avec `mock_provider` |
| Scripts | Bash (set -euo pipefail) |
| Tests scripts | BATS (Bash Automated Testing System) |
| Monitoring | Prometheus + alerting rules YAML |

## Fichiers Impactes

### A creer (8 fichiers)

| Fichier | Responsabilite | US |
|---------|----------------|----|
| `modules/lxc/tests/regression.tftest.hcl` | Non-regression LXC (tags, description, security updates) | US2 |
| `modules/backup/tests/regression.tftest.hcl` | Non-regression Backup (retention, VMIDs, disabled) | US2 |
| `modules/minio/tests/regression.tftest.hcl` | Non-regression Minio (mount_point size, tags, outputs) | US2 |
| `modules/monitoring-stack/tests/regression.tftest.hcl` | Non-regression Monitoring (SCSI, cloud-init, SSH key) | US2 |

> Note : les 4 fichiers ci-dessus sont dans `infrastructure/proxmox/`

### A modifier (2 fichiers)

| Fichier | Modification | US |
|---------|-------------|----|
| `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` | +5 alertes (node + prometheus) | US1 |
| `scripts/lib/common.sh` | +2 fonctions (retry_with_backoff, ssh_exec_retry) + modifier check_ssh_access | US3 |
| `tests/restore/test_common.bats` | +7 tests BATS pour retry/backoff | US3 |

## Phases d'Implementation

### Phase 1 : Alertes Prometheus [US1]
- [ ] T001 - [US1] Ajouter 5 alertes dans default.yml

### Phase 2 : Tests de non-regression [US2]
- [ ] T002 - [P] [US2] Creer regression.tftest.hcl pour LXC
- [ ] T003 - [P] [US2] Creer regression.tftest.hcl pour Backup
- [ ] T004 - [P] [US2] Creer regression.tftest.hcl pour Minio
- [ ] T005 - [P] [US2] Creer regression.tftest.hcl pour Monitoring-stack
- [ ] T006 - [US2] Valider tous les tests Terraform (5 modules)

### Phase 3 : Retry/backoff [US3]
- [ ] T007 - [US3] Ajouter retry_with_backoff() et ssh_exec_retry() dans common.sh
- [ ] T008 - [US3] Modifier check_ssh_access() pour utiliser retry
- [ ] T009 - [US3] Ajouter tests BATS pour les nouvelles fonctions
- [ ] T010 - [US3] Valider tous les tests BATS

### Phase 4 : Validation globale
- [ ] T011 - Executer tous les tests (Terraform + BATS)
- [ ] T012 - Commit et PR

## Risques et Mitigations

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Alerte PromQL invalide | Prometheus ne charge pas les regles | Syntaxe validee par les tests existants en CI |
| Regression test faux positif | Test echoue alors que le code est correct | Chaque test documente la version du bug et l'assertion exacte |
| retry_with_backoff casse le flux existant | Scripts existants ne fonctionnent plus | La fonction est additive, les appels existants a ssh_exec ne changent pas |

## Criteres de Validation

- [ ] 26+ alertes dans default.yml (vs 21)
- [ ] 5/5 modules ont regression.tftest.hcl
- [ ] `terraform test` passe sur les 5 modules
- [ ] `bats tests/restore/test_common.bats` passe
- [ ] Aucun test existant ne casse
