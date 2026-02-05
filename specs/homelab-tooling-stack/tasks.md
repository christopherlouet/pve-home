# Tâches : Stack Outillage Homelab (PKI, Registry, SSO)

**Date**: 2026-02-05
**Branche**: `feature/homelab-tooling-stack`
**Total tâches**: 41

---

## Légende

| Marqueur | Signification |
|----------|---------------|
| `[P]` | Parallélisable (pas de dépendance directe) |
| `[US1]` | User Story 1 - PKI/Certificats TLS |
| `[US2]` | User Story 2 - Registry Harbor |
| `[US3]` | User Story 3 - SSO Authentik |
| `[US4]` | User Story 4 - Monitoring/Alerting |
| `[US5]` | User Story 5 - Infrastructure as Code |

---

## Phase 0 : Prérequis Matériel (bloquant)

> Actions manuelles avant déploiement Terraform

| ID | Tâche | Dépendances | Statut |
|----|-------|-------------|--------|
| T001 | Upgrade RAM pve-mon (32 GB minimum recommandé) | - | ☐ |
| T002 | Ajout disque/extension stockage pve-mon (≥200 GB pour Harbor) | - | ☐ |
| T003 | Configuration DNS `*.home.arpa` → IP tooling (OPNsense/Pi-hole) | - | ☐ |

**Validation Phase 0** :
- [ ] `nslookup pki.home.arpa` résout vers 192.168.1.60
- [ ] `free -h` sur pve-mon montre ≥ 24 GB RAM disponible
- [ ] `df -h` montre ≥ 200 GB disponibles

---

## Phase 1 : Module Terraform tooling-stack [US5]

> Création du module réutilisable

| ID | Tâche | Fichier | Dépendances | Statut |
|----|-------|---------|-------------|--------|
| T004 | [US5] Créer variables du module | `infrastructure/proxmox/modules/tooling-stack/variables.tf` | T001-T003 | ✅ |
| T005 | [US5] Créer outputs du module | `infrastructure/proxmox/modules/tooling-stack/outputs.tf` | T004 | ✅ |
| T006 | [US5] Créer ressources VM + cloud-init | `infrastructure/proxmox/modules/tooling-stack/main.tf` | T004, T005 | ✅ |
| T007 | [P] [US5] Créer tests Terraform | `infrastructure/proxmox/modules/tooling-stack/tests/*.tftest.hcl` | T006 | ✅ |

**Validation Phase 1** :
- [x] `terraform validate` passe dans le module
- [x] `terraform test` passe (138 tests)

---

## Phase 2 : Step-ca PKI [US1] 🎯 MVP

> Autorité de certification interne avec ACME

| ID | Tâche | Fichier | Dépendances | Statut |
|----|-------|---------|-------------|--------|
| T008 | [US1] Configuration CA Step-ca | `infrastructure/proxmox/modules/tooling-stack/files/step-ca/ca.json.tpl` | T006 | ✅ |
| T009 | [US1] Defaults Step-ca | `infrastructure/proxmox/modules/tooling-stack/files/step-ca/defaults.json.tpl` | T008 | ✅ |
| T010 | [US1] Section Step-ca Docker Compose | `infrastructure/proxmox/modules/tooling-stack/files/docker-compose.yml.tpl` | T009 | ✅ |
| T011 | [US1] Config Traefik ACME Step-ca | `infrastructure/proxmox/modules/tooling-stack/files/traefik/traefik.yml.tpl` | T010 | ✅ |
| T012 | [US1] Route Traefik pki.home.arpa | `infrastructure/proxmox/modules/tooling-stack/files/traefik/dynamic.yml.tpl` | T011 | ✅ |
| T013 | [US1] Script export CA racine | `scripts/tooling/export-ca.sh` | T010 | ✅ |
| T014 | [US1] Documentation installation CA | `docs/TOOLING-STACK.md` | T013 | ✅ |

**Validation Phase 2** :
- [x] Configuration Step-ca intégrée dans cloud-init
- [x] Certificat root CA généré via TLS provider
- [x] Instructions CA incluses dans outputs Terraform

---

## Phase 3 : Harbor Registry [US2] 🎯 MVP

> Registre d'images Docker privé avec scan Trivy

| ID | Tâche | Fichier | Dépendances | Statut |
|----|-------|---------|-------------|--------|
| T015 | [US2] Configuration Harbor | `infrastructure/proxmox/modules/tooling-stack/files/harbor/harbor.yml.tpl` | T006 | ✅ |
| T016 | [US2] Section Harbor Docker Compose | `infrastructure/proxmox/modules/tooling-stack/files/docker-compose.yml.tpl` | T015, T010 | ✅ |
| T017 | [US2] Route Traefik registry.home.arpa | `infrastructure/proxmox/modules/tooling-stack/files/traefik/dynamic.yml.tpl` | T016, T012 | ✅ |
| T018 | [US2] Script garbage collection Harbor | `scripts/tooling/harbor-gc.sh` | T016 | ✅ |
| T019 | [P] [US2] Test push/pull image | (test manuel) | T017 | ⏸️ |

**Validation Phase 3** :
- [x] Configuration Harbor intégrée dans cloud-init
- [x] Route Traefik configurée pour registry.home.arpa
- [x] Script GC Harbor créé
- [ ] Tests manuels (requiert déploiement)

---

## Phase 4 : Authentik SSO [US3]

> Authentification centralisée (Phase 1 : Grafana + Harbor)

| ID | Tâche | Fichier | Dépendances | Statut |
|----|-------|---------|-------------|--------|
| T020 | [US3] Docker Compose Authentik | `infrastructure/proxmox/modules/tooling-stack/files/authentik/docker-compose.yml.tpl` | T006 | ✅ |
| T021 | [US3] Intégration Authentik compose principal | `infrastructure/proxmox/modules/tooling-stack/files/docker-compose.yml.tpl` | T020, T016 | ✅ |
| T022 | [US3] Route Traefik auth.home.arpa | `infrastructure/proxmox/modules/tooling-stack/files/traefik/dynamic.yml.tpl` | T021, T017 | ✅ |
| T023 | [US3] Config OAuth2 Grafana | (configuration Authentik + Grafana env vars) | T022 | ⏸️ |
| T024 | [US3] Config OIDC Harbor | (configuration Authentik + Harbor auth) | T022 | ⏸️ |
| T025 | [P] [US3] Test login SSO Grafana | (test manuel) | T023 | ⏸️ |
| T026 | [P] [US3] Test login SSO Harbor | (test manuel) | T024 | ⏸️ |

**Validation Phase 4** :
- [x] Configuration Authentik intégrée dans cloud-init
- [x] Route Traefik configurée pour auth.home.arpa
- [ ] SSO Grafana (Phase 2 - après déploiement)
- [ ] SSO Harbor (Phase 2 - après déploiement)

---

## Phase 5 : Intégration Monitoring [US4]

> Dashboards Grafana et alertes Prometheus

| ID | Tâche | Fichier | Dépendances | Statut |
|----|-------|---------|-------------|--------|
| T027 | [P] [US4] Dashboard Step-ca | `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/tooling/step-ca.json` | T010 | ✅ |
| T028 | [P] [US4] Dashboard Harbor | `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/tooling/harbor.json` | T016 | ✅ |
| T029 | [P] [US4] Dashboard Authentik | `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/tooling/authentik.json` | T021 | ✅ |
| T030 | [US4] Alertes Prometheus tooling | `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/tooling.yml` | T027-T029 | ✅ |
| T031 | [US4] Scrape targets Prometheus | `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/scrape/tooling.yml.tpl` | T030 | ✅ |
| T032 | [US4] Provisioning dashboards Grafana | `infrastructure/proxmox/modules/monitoring-stack/files/grafana/provisioning/dashboards/default.yml` | T027-T029 | ✅ |

**Validation Phase 5** :
- [x] 3 dashboards Grafana créés (Step-ca, Harbor, Authentik)
- [x] 10 alertes Prometheus configurées (tooling.yml)
- [x] Config scrape Prometheus avec template conditionnel
- [x] Provisioning dashboards avec dossier Tooling
- [x] Variables tooling_* dans monitoring-stack module
- [x] Tests monitoring-stack pour intégration tooling (14 tests)

---

## Phase 6 : Déploiement et Documentation [US5]

> Finalisation et mise en production

| ID | Tâche | Fichier | Dépendances | Statut |
|----|-------|---------|-------------|--------|
| T033 | [US5] Instance module tooling | `infrastructure/proxmox/environments/monitoring/tooling.tf` | T007 | ✅ |
| T034 | [US5] Variables tooling | `infrastructure/proxmox/environments/monitoring/variables.tf` | T033 | ✅ |
| T035 | [US5] Config terraform.tfvars | `infrastructure/proxmox/environments/monitoring/terraform.tfvars.example` | T034 | ✅ |
| T036 | [US5] Backup VM tooling | (inclus dans backup.tf existant via vm_ids dynamique) | T033 | ✅ |
| T037 | [US5] Script reconstruction | `scripts/restore/rebuild-tooling.sh` | T033 | ✅ |
| T038 | [US5] Documentation complète | `docs/TOOLING-STACK.md` | T014, T018 | ✅ |
| T039 | [US5] Déploiement final | `terraform apply` | T035, T036 | ⏸️ |

**Validation Phase 6** :
- [x] `terraform validate` passe dans environments/monitoring
- [x] Instance module avec count conditionnel
- [x] Variables tooling complètes (VM, Step-ca, Harbor, Authentik)
- [x] Firewall dynamique selon services activés
- [x] Config terraform.tfvars.example documentée
- [x] Script rebuild-tooling.sh créé
- [x] Documentation TOOLING-STACK.md complète (~380 lignes)
- [ ] `terraform apply` (déploiement réel - phase suivante)

---

## Phase 7 (Future) : SSO Phase 2

> Hors scope MVP - après stabilisation

| ID | Tâche | Fichier | Dépendances | Statut |
|----|-------|---------|-------------|--------|
| T040 | [US3] ForwardAuth Traefik Dashboard | (config Traefik + Authentik) | Phase 4 stable | ☐ |
| T041 | [US3] OIDC Realm Proxmox | (config Proxmox + Authentik) | Phase 4 stable | ☐ |

---

## Résumé Exécution

### Tâches par priorité

| Priorité | User Stories | Tâches | Complétées | % |
|----------|--------------|--------|------------|---|
| 🎯 MVP (P1) | US1 + US2 | T008-T019 | 11/12 | 92% |
| P2 | US3 + US4 | T020-T032 | 9/13 | 69% |
| P3 | US5 | T004-T007, T033-T039 | 10/11 | 91% |
| Future | - | T040-T041 | 0/2 | 0% |

**Total : 30/38 tâches complétées (79%)**

### Tâches en attente de déploiement

Les tâches suivantes nécessitent un déploiement réel pour être validées :
- T019 : Test push/pull Harbor
- T023-T026 : Configuration SSO et tests manuels
- T039 : Déploiement final `terraform apply`

### État des modules

| Module | Tests | Statut |
|--------|-------|--------|
| tooling-stack | 138 tests | ✅ Complet |
| monitoring-stack | 87 tests (+14 tooling) | ✅ Intégration OK |

---

## Checklist Finale

### Code et configuration
- [x] Module Terraform tooling-stack créé et testé (138 tests)
- [x] Intégration monitoring-stack (dashboards, alertes, scrape)
- [x] Variables conditionnelles (master switch + services individuels)
- [x] Firewall dynamique selon services activés
- [x] Documentation complète (TOOLING-STACK.md)
- [x] Script de reconstruction (rebuild-tooling.sh)

### À valider après déploiement
- [ ] Tous les services accessibles en HTTPS sans warning (CS-001)
- [ ] Certificat obtenu en < 5 secondes (CS-002)
- [ ] Registry dispo > 99% (CS-003)
- [ ] SSO login < 3 secondes (CS-004)
- [ ] Stockage images < 80% (CS-005)
- [ ] Zéro CVE critique > 7 jours (CS-006)
