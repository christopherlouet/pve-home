# Plan d'Implémentation : Stack Outillage Homelab (PKI, Registry, SSO)

**Date**: 2026-02-05
**Branche**: `feature/homelab-tooling-stack`
**Complexité**: Complexe (> 10 fichiers, 3 services, intégrations multiples)

## Résumé

Déployer une nouvelle VM "tooling" sur pve-mon contenant Step-ca (PKI), Harbor (Registry), et Authentik (SSO). L'approche suit le pattern existant du module `monitoring-stack` : une VM cloud-init avec Docker Compose, provisionné via Terraform.

---

## Contexte Technique

| Aspect | Choix | Justification |
|--------|-------|---------------|
| IaC | Terraform (bpg/proxmox) | Cohérence avec l'existant |
| Conteneurisation | Docker Compose | Pattern monitoring-stack |
| PKI | Step-ca (smallstep) | ACME intégré, léger, Go |
| Registry | Harbor | UI, scan Trivy, OIDC natif |
| SSO | Authentik | OAuth2/OIDC, moderne, UI soignée |
| Domaine | `*.home.arpa` | RFC 8375, résolution locale |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            PVE-MON (upgrade RAM + disque)                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────┐  ┌─────────────────────────────────┐  │
│  │ VM: monitoring-stack            │  │ VM: tooling-stack (NOUVELLE)    │  │
│  │ IP: 192.168.1.51               │  │ IP: 192.168.1.60                │  │
│  │                                 │  │                                 │  │
│  │ ┌─────────┐ ┌─────────┐        │  │ ┌─────────┐ ┌─────────┐         │  │
│  │ │Prometheus│ │ Grafana │        │  │ │ Step-ca │ │ Harbor  │         │  │
│  │ └─────────┘ └─────────┘        │  │ │ (PKI)   │ │(Registry)│        │  │
│  │ ┌─────────┐ ┌─────────┐        │  │ │ :8443   │ │ :443    │         │  │
│  │ │Alertmgr │ │ Traefik │        │  │ └─────────┘ └─────────┘         │  │
│  │ └─────────┘ └─────────┘        │  │ ┌─────────────────────┐         │  │
│  │ ┌─────────┐ ┌─────────┐        │  │ │     Authentik       │         │  │
│  │ │  Loki   │ │ Uptime  │        │  │ │       (SSO)         │         │  │
│  │ └─────────┘ └─────────┘        │  │ │       :9000         │         │  │
│  └─────────────────────────────────┘  │ └─────────────────────┘         │  │
│                                        │ ┌─────────────────────┐         │  │
│  ┌─────────────────────────────────┐  │ │   Traefik local     │         │  │
│  │ LXC: minio                      │  │ │     :80/:443        │         │  │
│  │ IP: 192.168.1.52               │  │ └─────────────────────┘         │  │
│  │ Buckets: tfstate-*             │  │                                 │  │
│  └─────────────────────────────────┘  └─────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Fichiers Impactés

### À Créer (Nouveau module tooling-stack)

| Fichier | Responsabilité | US |
|---------|----------------|-----|
| `modules/tooling-stack/main.tf` | VM + cloud-init + Docker Compose | US5 |
| `modules/tooling-stack/variables.tf` | Variables du module | US5 |
| `modules/tooling-stack/outputs.tf` | Outputs (IPs, URLs, clés) | US5 |
| `modules/tooling-stack/files/docker-compose.yml.tpl` | Orchestration Step-ca, Harbor, Authentik | US1,US2,US3 |
| `modules/tooling-stack/files/step-ca/ca.json.tpl` | Configuration Step-ca (ACME, durée certs) | US1 |
| `modules/tooling-stack/files/step-ca/defaults.json.tpl` | Defaults Step-ca (CA-URL, fingerprint) | US1 |
| `modules/tooling-stack/files/harbor/harbor.yml.tpl` | Configuration Harbor (DB, storage, auth) | US2 |
| `modules/tooling-stack/files/authentik/docker-compose.yml.tpl` | Authentik + PostgreSQL + Redis | US3 |
| `modules/tooling-stack/files/traefik/traefik.yml.tpl` | Config Traefik avec ACME Step-ca | US1 |
| `modules/tooling-stack/files/traefik/dynamic.yml.tpl` | Routes dynamiques (pki, registry, auth) | US1,US2,US3 |
| `modules/tooling-stack/tests/basic.tftest.hcl` | Tests Terraform du module | US5 |
| `modules/tooling-stack/tests/validation.tftest.hcl` | Tests validation inputs | US5 |
| `modules/tooling-stack/tests/integration.tftest.hcl` | Tests intégration | US5 |

### À Créer (Environnement monitoring)

| Fichier | Responsabilité | US |
|---------|----------------|-----|
| `environments/monitoring/tooling.tf` | Instance du module tooling-stack | US5 |

### À Créer (Dashboards Grafana)

| Fichier | Responsabilité | US |
|---------|----------------|-----|
| `modules/monitoring-stack/files/grafana/dashboards/tooling/step-ca.json` | Dashboard PKI (certs, expiry) | US4 |
| `modules/monitoring-stack/files/grafana/dashboards/tooling/harbor.json` | Dashboard Registry (images, scans) | US4 |
| `modules/monitoring-stack/files/grafana/dashboards/tooling/authentik.json` | Dashboard SSO (logins, failures) | US4 |

### À Créer (Alertes Prometheus)

| Fichier | Responsabilité | US |
|---------|----------------|-----|
| `modules/monitoring-stack/files/prometheus/alerts/tooling.yml` | Alertes Step-ca, Harbor, Authentik | US4 |

### À Créer (Documentation)

| Fichier | Responsabilité | US |
|---------|----------------|-----|
| `docs/TOOLING-STACK.md` | Guide d'utilisation PKI/Registry/SSO | US1,US2,US3 |
| `docs/PKI-INSTALLATION.md` | Procédure installation CA sur clients | US1 |

### À Créer (Scripts)

| Fichier | Responsabilité | US |
|---------|----------------|-----|
| `scripts/tooling/export-ca.sh` | Export CA racine (PEM, DER, P12) | US1 |
| `scripts/tooling/harbor-gc.sh` | Garbage collection Harbor | US2 |
| `scripts/restore/rebuild-tooling.sh` | Reconstruction stack tooling | US5 |

### À Modifier

| Fichier | Modification | US |
|---------|--------------|-----|
| `environments/monitoring/variables.tf` | Ajouter variables tooling | US5 |
| `environments/monitoring/terraform.tfvars` | Ajouter config tooling | US5 |
| `environments/monitoring/backup.tf` | Ajouter backup VM tooling | US5 |
| `modules/monitoring-stack/files/prometheus.yml.tpl` | Ajouter scrape targets tooling | US4 |
| `modules/monitoring-stack/files/grafana/provisioning/dashboards/default.yml` | Ajouter folder Tooling | US4 |
| `modules/monitoring-stack/variables.tf` | Ajouter variable dashboards tooling | US4 |
| `modules/monitoring-stack/main.tf` | Ajouter dashboards tooling | US4 |

---

## Phases d'Implémentation

### Phase 0 : Préparation (bloquant)

Prérequis matériel et réseau avant déploiement.

- [ ] **T001** - Upgrade RAM pve-mon (minimum 32 GB recommandé)
- [ ] **T002** - Ajout disque/extension stockage pve-mon (minimum 200 GB supplémentaires)
- [ ] **T003** - Configuration DNS : `*.home.arpa` → résolution locale (OPNsense/Pi-hole)

### Phase 1 : Module Terraform tooling-stack [US5] (fondation)

Créer le module Terraform réutilisable.

- [ ] **T004** - [US5] `modules/tooling-stack/variables.tf` - Variables du module
- [ ] **T005** - [US5] `modules/tooling-stack/outputs.tf` - Outputs du module
- [ ] **T006** - [US5] `modules/tooling-stack/main.tf` - Ressources VM + cloud-init
- [ ] **T007** - [P] [US5] Tests Terraform `modules/tooling-stack/tests/*.tftest.hcl`

### Phase 2 : Step-ca PKI [US1] 🎯 MVP

Déployer l'autorité de certification interne.

- [ ] **T008** - [US1] `files/step-ca/ca.json.tpl` - Configuration CA (ACME, provisioners)
- [ ] **T009** - [US1] `files/step-ca/defaults.json.tpl` - Defaults (CA-URL, fingerprint)
- [ ] **T010** - [US1] Section Step-ca dans `docker-compose.yml.tpl`
- [ ] **T011** - [US1] `files/traefik/traefik.yml.tpl` - ACME via Step-ca
- [ ] **T012** - [US1] `files/traefik/dynamic.yml.tpl` - Route pki.home.arpa
- [ ] **T013** - [US1] `scripts/tooling/export-ca.sh` - Export CA racine
- [ ] **T014** - [US1] `docs/PKI-INSTALLATION.md` - Guide installation CA clients

### Phase 3 : Harbor Registry [US2] 🎯 MVP

Déployer le registre d'images Docker.

- [ ] **T015** - [US2] `files/harbor/harbor.yml.tpl` - Configuration Harbor
- [ ] **T016** - [US2] Section Harbor dans `docker-compose.yml.tpl` (ou script install)
- [ ] **T017** - [US2] `files/traefik/dynamic.yml.tpl` - Route registry.home.arpa
- [ ] **T018** - [US2] `scripts/tooling/harbor-gc.sh` - Garbage collection
- [ ] **T019** - [P] [US2] Test push/pull image vers registry

### Phase 4 : Authentik SSO [US3] - Phase 1 (Grafana + Harbor)

Déployer le SSO et intégrer les premiers services.

- [ ] **T020** - [US3] `files/authentik/docker-compose.yml.tpl` - Authentik + deps
- [ ] **T021** - [US3] Section Authentik dans `docker-compose.yml.tpl` principal
- [ ] **T022** - [US3] `files/traefik/dynamic.yml.tpl` - Route auth.home.arpa
- [ ] **T023** - [US3] Configuration OAuth2 provider Grafana
- [ ] **T024** - [US3] Configuration OIDC provider Harbor
- [ ] **T025** - [P] [US3] Test login SSO Grafana
- [ ] **T026** - [P] [US3] Test login SSO Harbor

### Phase 5 : Intégration Monitoring [US4]

Ajouter métriques, dashboards et alertes.

- [ ] **T027** - [P] [US4] Dashboard Grafana `step-ca.json`
- [ ] **T028** - [P] [US4] Dashboard Grafana `harbor.json`
- [ ] **T029** - [P] [US4] Dashboard Grafana `authentik.json`
- [ ] **T030** - [US4] Alertes Prometheus `alerts/tooling.yml`
- [ ] **T031** - [US4] Modification `prometheus.yml.tpl` - scrape targets
- [ ] **T032** - [US4] Modification provisioning dashboards Grafana

### Phase 6 : Déploiement et Documentation [US5]

Finaliser le déploiement et documenter.

- [ ] **T033** - [US5] `environments/monitoring/tooling.tf` - Instance module
- [ ] **T034** - [US5] `environments/monitoring/variables.tf` - Variables tooling
- [ ] **T035** - [US5] `environments/monitoring/terraform.tfvars` - Config tooling
- [ ] **T036** - [US5] `environments/monitoring/backup.tf` - Backup VM tooling
- [ ] **T037** - [US5] `scripts/restore/rebuild-tooling.sh` - Script reconstruction
- [ ] **T038** - [US5] `docs/TOOLING-STACK.md` - Documentation complète
- [ ] **T039** - [US5] `terraform apply` et validation end-to-end

### Phase 7 (Future) : SSO Phase 2 (Traefik + Proxmox)

Hors scope MVP, à planifier après stabilisation.

- [ ] **T040** - [US3] ForwardAuth Traefik Dashboard
- [ ] **T041** - [US3] OIDC Realm Proxmox

---

## Dépendances entre Phases

```
Phase 0 (Prérequis matériel)
    │
    ▼
Phase 1 (Module Terraform) ─────────────────────────────────────┐
    │                                                           │
    ├──────────────┬──────────────┬──────────────┐             │
    ▼              ▼              ▼              │             │
Phase 2        Phase 3        Phase 4           │             │
(Step-ca)      (Harbor)       (Authentik)       │             │
    │              │              │              │             │
    │              └──────────────┼──────────────┘             │
    │                             │                            │
    ▼                             ▼                            │
    └─────────────────────────────┼────────────────────────────┘
                                  │
                                  ▼
                            Phase 5 (Monitoring)
                                  │
                                  ▼
                            Phase 6 (Déploiement)
                                  │
                                  ▼
                            Phase 7 (SSO Phase 2) [Future]
```

---

## Risques et Mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| RAM insuffisante sur pve-mon | Moyenne | Bloquant | Phase 0 : upgrade obligatoire avant déploiement |
| Complexité Harbor (nombreux containers) | Haute | Moyen | Utiliser le script d'installation Harbor officiel plutôt que compose custom |
| Incompatibilité Step-ca / Traefik | Faible | Moyen | Step-ca ACME est standard, bien documenté |
| Perte données CA si VM détruite | Haute | Critique | Backup vzdump + export clés CA hors VM |
| Authentik down = services inaccessibles | Moyenne | Moyen | Garder fallback auth locale sur Grafana/Harbor |

---

## Critères de Validation

### Phase 2 (Step-ca) ✓
- [ ] `curl https://pki.home.arpa/health` retourne `ok`
- [ ] Certificat obtenu via ACME en < 5 secondes
- [ ] CA racine exportable et installable sur navigateur

### Phase 3 (Harbor) ✓
- [ ] `docker login registry.home.arpa` réussit
- [ ] `docker push/pull registry.home.arpa/test:v1` fonctionne
- [ ] UI Harbor accessible sur `https://registry.home.arpa`
- [ ] Scan vulnérabilités actif (Trivy)

### Phase 4 (Authentik) ✓
- [ ] UI Authentik accessible sur `https://auth.home.arpa`
- [ ] Login Grafana via SSO fonctionne
- [ ] Login Harbor via OIDC fonctionne

### Phase 5 (Monitoring) ✓
- [ ] Dashboards visibles dans Grafana (folder Tooling)
- [ ] Métriques Step-ca/Harbor/Authentik scrapées
- [ ] Alertes déclenchées si service down

### Phase 6 (Déploiement) ✓
- [ ] `terraform plan` sans erreur
- [ ] `terraform apply` crée la VM tooling
- [ ] VM démarre et services accessibles
- [ ] Backup vzdump configuré

---

## Estimation

| Phase | Complexité | Fichiers |
|-------|------------|----------|
| Phase 0 | Simple | 0 (matériel) |
| Phase 1 | Moyenne | 4 |
| Phase 2 | Moyenne | 7 |
| Phase 3 | Complexe | 4 |
| Phase 4 | Complexe | 7 |
| Phase 5 | Moyenne | 6 |
| Phase 6 | Simple | 6 |
| **TOTAL** | **Complexe** | **~34 fichiers** |

---

## Prochaines Étapes

1. Valider le plan → Utilisateur
2. Commencer par Phase 0 (prérequis matériel)
3. Implémenter Phase 1-6 en TDD → `/dev:dev-tdd`
4. Créer PR → `/work:work-pr`
