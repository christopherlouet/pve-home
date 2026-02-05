# Tâches : Outils d'Observabilité Complémentaires

**Input**: Documents de conception depuis `specs/observability-tools/`
**Prérequis**: plan.md (requis), spec.md (requis)

---

## Format des tâches : `[ID] [P?] [US?] Description`

- **[P]** : Peut être exécutée en parallèle (fichiers différents, pas de dépendances)
- **[US1/US2/US3/US4]** : User story associée (pour traçabilité)
- Chemins de fichiers exacts inclus dans les descriptions

---

## Phase 1 : Fondation (Infrastructure partagée)

**Objectif** : Préparer les variables et la structure de fichiers

**CRITIQUE** : Cette phase doit être complète avant toute user story.

- [ ] T001 - Créer structure dossiers dans `infrastructure/proxmox/modules/monitoring-stack/files/`:
  - `traefik/`
  - `loki/`
  - `promtail/`

- [ ] T002 - [P] Ajouter variables dans `infrastructure/proxmox/modules/monitoring-stack/variables.tf`:
  - `traefik_enabled` (bool, default true)
  - `loki_enabled` (bool, default true)
  - `uptime_kuma_enabled` (bool, default true)
  - `domain_suffix` (string, default "home.lan")
  - `loki_retention_days` (number, default 7)
  - `tls_enabled` (bool, default false)

- [ ] T003 - [P] Ajouter variables dans `infrastructure/proxmox/modules/vm/variables.tf`:
  - `install_promtail` (bool, default false)
  - `loki_url` (string, default "")
  - `promtail_scrape_configs` (list, default [])

**Checkpoint** : Variables prêtes - les user stories peuvent commencer.

---

## Phase 2 : User Story 1 - Reverse Proxy Traefik (P1) 🎯 MVP

**Objectif** : Accéder aux services via URLs lisibles (grafana.home.lan)

**Test indépendant** : `curl -H "Host: grafana.home.lan" http://192.168.1.51` retourne Grafana

### Configuration Traefik

- [ ] T004 - [P] [US1] Créer `infrastructure/proxmox/modules/monitoring-stack/files/traefik/traefik.yml.tpl`:
  ```yaml
  # Configuration statique Traefik
  - entryPoints: web (80), websecure (443)
  - providers: docker, file
  - api: dashboard enabled
  - log: level INFO
  ```

- [ ] T005 - [P] [US1] Créer `infrastructure/proxmox/modules/monitoring-stack/files/traefik/dynamic.yml.tpl`:
  ```yaml
  # Routes pour services existants
  - grafana.${domain} → grafana:3000
  - prometheus.${domain} → prometheus:9090
  - alertmanager.${domain} → alertmanager:9093
  - traefik.${domain} → api@internal (dashboard)
  ```

### Intégration Docker Compose

- [ ] T006 - [US1] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/docker-compose.yml.tpl`:
  - Ajouter service traefik avec:
    - image: traefik:v3.3
    - ports: 80:80, 443:443, 8080:8080
    - volumes: /var/run/docker.sock, configs
    - networks: monitoring
    - labels pour dashboard
  - Ajouter labels Traefik sur services existants (grafana, prometheus, alertmanager)

### Terraform

- [ ] T007 - [US1] Modifier `infrastructure/proxmox/modules/monitoring-stack/main.tf`:
  - Ajouter template pour traefik.yml
  - Ajouter template pour dynamic.yml
  - Ajouter write_files dans cloud_config
  - Conditionner sur var.traefik_enabled

- [ ] T008 - [US1] Modifier `infrastructure/proxmox/modules/monitoring-stack/outputs.tf`:
  - Ajouter `traefik_dashboard_url`
  - Ajouter `service_urls` map avec tous les *.home.lan

### Firewall et Environnement

- [ ] T009 - [US1] Modifier `infrastructure/proxmox/environments/monitoring/monitoring.tf`:
  - Ajouter règle firewall port 80 (HTTP)
  - Ajouter règle firewall port 443 (HTTPS)
  - Ajouter règle firewall port 8080 (Traefik dashboard, optionnel)

### Tests

- [ ] T010 - [US1] Créer `infrastructure/proxmox/modules/monitoring-stack/tests/traefik.tftest.hcl`:
  - Test validation variables traefik
  - Test génération config traefik
  - Test outputs URLs

**Checkpoint** : US1 fonctionnelle - `grafana.home.lan` accessible via Traefik.

---

## Phase 3 : User Story 2 - Centralisation Logs (P1) 🎯 MVP

**Objectif** : Consulter les logs de toutes les VMs depuis Grafana

**Test indépendant** : Dans Grafana > Explore > Loki, voir les logs de monitoring-stack et VMs prod

### 3a - Loki + Promtail sur monitoring-stack

#### Configuration Loki

- [ ] T011 - [P] [US2] Créer `infrastructure/proxmox/modules/monitoring-stack/files/loki/loki-config.yml`:
  ```yaml
  # Configuration Loki
  - auth_enabled: false
  - server: http_listen_port 3100
  - ingester: chunk_idle_period, retention
  - schema_config: v13, tsdb
  - storage_config: filesystem /loki/chunks
  - limits_config: ingestion_rate_mb, retention_period
  - compactor: retention_enabled true
  ```

- [ ] T012 - [P] [US2] Créer `infrastructure/proxmox/modules/monitoring-stack/files/promtail/promtail-config.yml.tpl`:
  ```yaml
  # Promtail local sur monitoring-stack
  - server: http_listen_port 9080
  - positions: /tmp/positions.yaml
  - clients: url http://loki:3100/loki/api/v1/push
  - scrape_configs:
    - job: docker (via /var/run/docker.sock)
    - job: system (/var/log/*.log)
  ```

#### Intégration Grafana

- [ ] T014 - [US2] Créer `infrastructure/proxmox/modules/monitoring-stack/files/grafana/provisioning/datasources/loki.yml`:
  ```yaml
  # Datasource Loki pour Grafana
  - name: Loki
  - type: loki
  - url: http://loki:3100
  - isDefault: false
  ```

- [ ] T015 - [P] [US2] Créer `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/logs-overview.json`:
  - Panel: Logs par VM (hostname selector)
  - Panel: Erreurs récentes (level=error)
  - Panel: Volume de logs par service
  - Panel: Recherche full-text

#### Docker Compose

- [ ] T013 - [US2] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/docker-compose.yml.tpl`:
  - Ajouter service loki avec:
    - image: grafana/loki:3.5.0
    - ports: 3100:3100
    - volumes: config, data
    - networks: monitoring
  - Ajouter service promtail avec:
    - image: grafana/promtail:3.5.0
    - ports: 9080:9080
    - volumes: /var/run/docker.sock, /var/log, config
    - networks: monitoring
  - Ajouter labels Traefik sur loki (optionnel)

#### Terraform monitoring-stack

- [ ] T016 - [US2] Modifier `infrastructure/proxmox/modules/monitoring-stack/main.tf`:
  - Ajouter templates pour loki-config.yml
  - Ajouter templates pour promtail-config.yml
  - Ajouter datasource Loki dans write_files
  - Ajouter dashboard logs-overview dans write_files
  - Conditionner sur var.loki_enabled

- [ ] T017 - [US2] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/traefik/dynamic.yml.tpl`:
  - Ajouter route loki.${domain} → loki:3100

- [ ] T018 - [US2] Modifier `infrastructure/proxmox/environments/monitoring/monitoring.tf`:
  - Ajouter règle firewall port 3100 (Loki API)
  - Ajouter règle firewall port 9080 (Promtail, pour debug)

### 3b - Promtail Agent sur VMs de production

#### Configuration Agent

- [ ] T019 - [P] [US2] Créer `infrastructure/proxmox/modules/vm/files/promtail-agent.yml.tpl`:
  ```yaml
  # Agent Promtail pour VMs distantes
  - server: http_listen_port 9080
  - positions: /tmp/positions.yaml
  - clients: url ${loki_url}/loki/api/v1/push
  - scrape_configs:
    - job: docker (/var/run/docker.sock)
    - job: system (/var/log/syslog, /var/log/auth.log)
  - external_labels:
    - hostname: ${hostname}
    - environment: ${environment}
  ```

#### Module VM

- [ ] T020 - [US2] Modifier `infrastructure/proxmox/modules/vm/main.tf`:
  - Ajouter local promtail_runcmd pour installer Promtail via Docker
  - Ajouter template promtail-agent.yml dans write_files
  - Conditionner sur var.install_promtail

- [ ] T021 - [US2] Modifier `infrastructure/proxmox/modules/vm/variables.tf`:
  - Compléter validation pour install_promtail
  - Ajouter variable loki_url avec validation URL

#### Environnement Production

- [ ] T022 - [US2] Modifier `infrastructure/proxmox/environments/prod/main.tf`:
  - Ajouter `install_promtail = true` dans module.vms
  - Ajouter `loki_url = "http://192.168.1.51:3100"` dans module.vms

- [ ] T023 - [US2] Modifier `infrastructure/proxmox/environments/prod/main.tf`:
  - Ajouter règle firewall port 9080 (Promtail metrics) sur VMs prod

#### Tests

- [ ] T024 - [US2] Créer tests Terraform:
  - `infrastructure/proxmox/modules/monitoring-stack/tests/loki.tftest.hcl`
  - `infrastructure/proxmox/modules/vm/tests/promtail.tftest.hcl`

**Checkpoint** : US2 fonctionnelle - Logs de toutes les VMs visibles dans Grafana.

---

## Phase 4 : User Story 3 - Surveillance Disponibilité (P2)

**Objectif** : Tableau de bord de statut des services

**Test indépendant** : Accéder à `uptime.home.lan` et voir les services avec indicateurs vert/rouge

### Uptime Kuma

- [ ] T025 - [P] [US3] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/docker-compose.yml.tpl`:
  - Ajouter service uptime-kuma avec:
    - image: louislam/uptime-kuma:1
    - ports: 3001:3001
    - volumes: /app/data
    - networks: monitoring
    - labels Traefik pour uptime.${domain}

- [ ] T026 - [US3] Modifier `infrastructure/proxmox/modules/monitoring-stack/main.tf`:
  - Ajouter création dossier /opt/monitoring/uptime-kuma
  - Conditionner sur var.uptime_kuma_enabled

- [ ] T027 - [US3] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/traefik/dynamic.yml.tpl`:
  - Ajouter route uptime.${domain} → uptime-kuma:3001

- [ ] T028 - [US3] Modifier `infrastructure/proxmox/environments/monitoring/monitoring.tf`:
  - Ajouter règle firewall port 3001 (Uptime Kuma)

- [ ] T029 - [US3] Modifier `infrastructure/proxmox/modules/monitoring-stack/outputs.tf`:
  - Ajouter `uptime_kuma_url` dans outputs

### Tests

- [ ] T030 - [US3] Créer `infrastructure/proxmox/modules/monitoring-stack/tests/uptime-kuma.tftest.hcl`:
  - Test validation variable uptime_kuma_enabled
  - Test outputs URL

**Checkpoint** : US3 fonctionnelle - `uptime.home.lan` accessible.

---

## Phase 5 : User Story 4 - HTTPS Local (P3)

**Objectif** : Certificats auto-signés pour HTTPS sans warning

**Test indépendant** : `https://grafana.home.lan` accessible après import CA

### Génération CA

- [ ] T031 - [P] [US4] Modifier `infrastructure/proxmox/modules/monitoring-stack/main.tf`:
  - Ajouter ressource `tls_private_key.ca` pour générer CA
  - Ajouter ressource `tls_self_signed_cert.ca` pour certificat CA
  - Conditionner sur var.tls_enabled

### Configuration Traefik TLS

- [ ] T032 - [US4] Modifier `infrastructure/proxmox/modules/monitoring-stack/files/traefik/traefik.yml.tpl`:
  - Ajouter configuration TLS avec CA locale
  - Ajouter redirection HTTP → HTTPS

- [ ] T033 - [US4] Modifier `infrastructure/proxmox/modules/monitoring-stack/outputs.tf`:
  - Ajouter output `ca_certificate` pour distribution aux clients

### Tests

- [ ] T034 - [US4] Créer tests HTTPS:
  - Test génération certificat CA
  - Documentation import CA navigateur

**Checkpoint** : US4 fonctionnelle - HTTPS sans warning après import CA.

---

## Phase 6 : Polish & Documentation

**Objectif** : Finalisation et documentation

- [ ] T035 - [P] Mise à jour `README.md`:
  - Section "Observability Stack" avec Traefik, Loki, Uptime Kuma
  - URLs disponibles via *.home.lan
  - Schéma d'architecture mis à jour

- [ ] T036 - [P] Créer `docs/DNS-CONFIGURATION.md`:
  - Option 1: /etc/hosts sur chaque machine
  - Option 2: dnsmasq sur routeur
  - Option 3: Pi-hole/AdGuard
  - Troubleshooting DNS

- [ ] T037 - Créer `tests/integration/observability.bats`:
  - Test accès Traefik dashboard
  - Test route grafana.home.lan
  - Test ingestion logs Loki
  - Test Uptime Kuma API

- [ ] T038 - Mise à jour `CHANGELOG.md`:
  - Feature: Traefik reverse proxy
  - Feature: Loki + Promtail log aggregation
  - Feature: Uptime Kuma status page
  - Feature: HTTPS local (optionnel)

---

## Dépendances et Ordre d'Exécution

### Dépendances entre phases

```
Phase 1 (Fondation)
     │
     ├──▶ Phase 2 (US1 - Traefik) ◄── DOIT être terminée avant Phase 3-5
     │         │
     │         ▼
     ├──▶ Phase 3a (US2 - Loki/Promtail local)
     │         │
     │         ├──▶ Phase 3b (US2 - Promtail VMs prod)
     │         │
     │         ▼
     ├──▶ Phase 4 (US3 - Uptime Kuma)
     │
     └──▶ Phase 5 (US4 - HTTPS) ◄── Optionnel, peut être fait plus tard

Toutes les phases ──▶ Phase 6 (Polish)
```

### Dépendances entre tâches

| Tâche | Dépend de | Peut paralléliser avec |
|-------|-----------|------------------------|
| T004, T005 | T001, T002 | T004 ↔ T005 |
| T006 | T004, T005 | - |
| T007 | T006 | - |
| T011, T012, T015 | T001, T002 | T011 ↔ T012 ↔ T015 |
| T013 | T011, T012 | - |
| T019 | T003 | T011, T012 |
| T020 | T019 | - |
| T025 | T002, T006 | T019 |
| T031 | T007 | T025 |

### Opportunités de parallélisation

1. **Après Phase 1** : T004 + T005 + T011 + T012 + T015 + T019 peuvent démarrer ensemble
2. **Après Phase 2** : T025 (Uptime Kuma) + T031 (TLS) peuvent démarrer en parallèle de Phase 3b
3. **Phase 6** : T035 + T036 en parallèle

---

## Stratégie d'Implémentation Recommandée

### MVP First (US1 + US2 uniquement)

1. Compléter Phase 1 (Setup variables)
2. Compléter Phase 2 (Traefik)
3. **STOP et VALIDER** : grafana.home.lan fonctionne
4. Compléter Phase 3a (Loki local)
5. **STOP et VALIDER** : logs monitoring visibles dans Grafana
6. Compléter Phase 3b (Promtail VMs)
7. **STOP et VALIDER** : logs de TOUTES les VMs visibles
8. Optionnel : Phase 4 + 5

### Estimation de Complexité

| Phase | Complexité | Fichiers | Lignes estimées |
|-------|------------|----------|-----------------|
| Phase 1 | Simple | 2 | ~50 |
| Phase 2 | Moyenne | 6 | ~200 |
| Phase 3a | Moyenne | 6 | ~250 |
| Phase 3b | Simple | 3 | ~100 |
| Phase 4 | Simple | 4 | ~80 |
| Phase 5 | Moyenne | 3 | ~100 |
| Phase 6 | Simple | 4 | ~200 |

**Total estimé** : ~1000 lignes de code/config

---

## Notes

- **[P]** = fichiers différents, pas de conflits
- **[US?]** = traçabilité vers la user story
- Commit après chaque tâche ou groupe logique
- Tester `terraform plan` après chaque modification de .tf
- Les phases 4 et 5 sont optionnelles pour le MVP

**À éviter** :
- Modifier docker-compose.yml.tpl pour plusieurs services en même temps
- Oublier les labels Traefik sur les nouveaux services
- Négliger les règles firewall

---

**Version**: 1.0 | **Créé**: 2026-02-04
