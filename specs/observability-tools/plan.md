# Plan d'implémentation : Outils d'Observabilité Complémentaires

**Branche**: `feature/observability-tools`
**Date**: 2026-02-04
**Spec**: [specs/observability-tools/spec.md](spec.md)
**Statut**: Draft

---

## Résumé

Enrichir la stack monitoring existante sur pve-mon avec trois outils complémentaires :
- **Traefik** : Reverse proxy pour URLs lisibles (grafana.home.lan)
- **Loki + Promtail** : Centralisation des logs de toutes les VMs
- **Uptime Kuma** : Surveillance de disponibilité avec tableau de bord visuel

L'approche consiste à étendre le module `monitoring-stack` existant et ajouter un agent Promtail au module `vm` pour les VMs de production.

---

## Contexte Technique

| Aspect | Choix | Notes |
|--------|-------|-------|
| **Infrastructure** | Terraform + bpg/proxmox | Provider existant |
| **Conteneurs** | Docker Compose | Stack existante à étendre |
| **Reverse Proxy** | Traefik v3.x | Auto-discovery Docker, TLS auto |
| **Logs** | Loki 3.x + Promtail | S'intègre nativement à Grafana |
| **Uptime** | Uptime Kuma | Interface intuitive, notifications multiples |
| **DNS** | *.home.lan | Résolution locale requise |

### Contraintes

- Ressources VM limitées : 4 GB RAM actuellement (350 MB supplémentaires estimés)
- Réseau local uniquement : certificats auto-signés acceptables
- 4 VMs à équiper : monitoring-stack + 3 VMs prod

### Performance attendue

| Métrique | Cible |
|----------|-------|
| Temps de réponse reverse proxy | < 50ms overhead |
| Recherche logs 1h | < 5 secondes |
| Détection panne | < 2 minutes |
| Rétention logs | 7 jours minimum |

---

## Vérification Constitution/Conventions

*GATE: Doit être validé avant de commencer l'implémentation.*

- [x] Respecte les conventions du projet (voir CLAUDE.md)
- [x] Cohérent avec l'architecture existante (module monitoring-stack)
- [x] Pas d'over-engineering (outils standards, configuration minimale)
- [ ] Tests planifiés (Terraform tests + BATS)

---

## Structure du Projet

### Documentation (cette feature)

```
specs/observability-tools/
├── spec.md           # Spécification fonctionnelle ✓
├── plan.md           # Ce fichier
└── tasks.md          # Découpage en tâches
```

### Code Source - Fichiers impactés

```
infrastructure/proxmox/
├── modules/
│   ├── monitoring-stack/
│   │   ├── main.tf                          # MODIFIER - ajouter Traefik, Loki, Uptime Kuma
│   │   ├── variables.tf                     # MODIFIER - nouvelles variables
│   │   ├── outputs.tf                       # MODIFIER - nouvelles URLs
│   │   └── files/
│   │       ├── docker-compose.yml.tpl       # MODIFIER - nouveaux services
│   │       ├── traefik/
│   │       │   ├── traefik.yml.tpl          # CRÉER - config statique Traefik
│   │       │   └── dynamic.yml.tpl          # CRÉER - config dynamique (routes)
│   │       ├── loki/
│   │       │   └── loki-config.yml          # CRÉER - config Loki
│   │       ├── promtail/
│   │       │   └── promtail-config.yml.tpl  # CRÉER - config Promtail local
│   │       ├── uptime-kuma/                 # CRÉER - (config via UI)
│   │       └── grafana/
│   │           ├── provisioning/
│   │           │   └── datasources/
│   │           │       └── loki.yml         # CRÉER - datasource Loki
│   │           └── dashboards/
│   │               └── logs-overview.json   # CRÉER - dashboard logs
│   └── vm/
│       ├── main.tf                          # MODIFIER - option promtail
│       ├── variables.tf                     # MODIFIER - variable install_promtail
│       └── files/
│           └── promtail-agent.yml.tpl       # CRÉER - config agent distant
├── environments/
│   ├── monitoring/
│   │   ├── monitoring.tf                    # MODIFIER - activer nouveaux services
│   │   ├── variables.tf                     # MODIFIER - nouvelles variables
│   │   └── terraform.tfvars                 # MODIFIER - configuration
│   └── prod/
│       ├── main.tf                          # MODIFIER - activer promtail sur VMs
│       └── terraform.tfvars                 # MODIFIER - configuration
└── tests/
    └── (tests Terraform existants à étendre)
```

---

## Approche Choisie

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              RÉSEAU LOCAL 192.168.1.0/24                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    pve-mon (192.168.1.51)                            │   │
│  │                    monitoring-stack VM                               │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                      Docker Compose                          │   │   │
│  │  │  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐ │   │   │
│  │  │  │ Traefik  │   │Prometheus│   │  Loki    │   │  Uptime  │ │   │   │
│  │  │  │ :80/:443 │   │  :9090   │   │  :3100   │   │   Kuma   │ │   │   │
│  │  │  └────┬─────┘   └──────────┘   └────▲─────┘   │  :3001   │ │   │   │
│  │  │       │                              │        └──────────┘ │   │   │
│  │  │       ▼ routes vers                  │                      │   │   │
│  │  │  ┌──────────┐   ┌──────────┐   ┌──────────┐                │   │   │
│  │  │  │ Grafana  │   │Alertmgr  │   │Promtail  │ (local)        │   │   │
│  │  │  │  :3000   │   │  :9093   │   │  :9080   │────────────────┘   │   │
│  │  │  └──────────┘   └──────────┘   └──────────┘                    │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │
│  └─────────────────────────────────────────────────────────────────────────┘
│                                      ▲                                      │
│                                      │ logs                                 │
│  ┌───────────────┐  ┌───────────────┐│ ┌───────────────┐                   │
│  │ prod-alloc-   │  │ prod-alloc-   ││ │ prod-blog-    │                   │
│  │ budget        │  │ ia            ││ │ the           │                   │
│  │ 192.168.1.101 │  │ 192.168.1.102 ││ │ 192.168.1.103 │                   │
│  │ ┌───────────┐ │  │ ┌───────────┐ ││ │ ┌───────────┐ │                   │
│  │ │ Promtail  │─┼──┼─│ Promtail  │─┼┴─┼─│ Promtail  │ │                   │
│  │ │  :9080    │ │  │ │  :9080    │ │  │ │  :9080    │ │                   │
│  │ └───────────┘ │  │ └───────────┘ │  │ └───────────┘ │                   │
│  └───────────────┘  └───────────────┘  └───────────────┘                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

URLs via Traefik (*.home.lan) :
- grafana.home.lan    → :3000
- prometheus.home.lan → :9090
- alertmanager.home.lan → :9093
- uptime.home.lan     → :3001
- loki.home.lan       → :3100 (optionnel)
```

### Justification des choix

| Choix | Justification |
|-------|---------------|
| **Traefik** | Auto-discovery Docker, Let's Encrypt intégré, config dynamique |
| **Loki** | Nativement intégré à Grafana, pas de schéma comme Elasticsearch |
| **Promtail** | Agent léger officiel de Loki, push model simple |
| **Uptime Kuma** | Interface visuelle intuitive, notifications Telegram intégrées |

### Alternatives considérées

| Alternative | Pourquoi rejetée |
|-------------|------------------|
| **Nginx Proxy Manager** | Interface web mais moins d'auto-discovery que Traefik |
| **Elasticsearch + Filebeat** | Trop gourmand en ressources pour homelab |
| **Graylog** | Complexité excessive pour le besoin |
| **Healthchecks.io** | Service externe, pas auto-hébergé |

---

## Fichiers Impactés

### À créer

| Fichier | Responsabilité |
|---------|----------------|
| `modules/monitoring-stack/files/traefik/traefik.yml.tpl` | Configuration statique Traefik |
| `modules/monitoring-stack/files/traefik/dynamic.yml.tpl` | Routes et middlewares |
| `modules/monitoring-stack/files/loki/loki-config.yml` | Configuration Loki |
| `modules/monitoring-stack/files/promtail/promtail-config.yml.tpl` | Config Promtail local |
| `modules/monitoring-stack/files/grafana/provisioning/datasources/loki.yml` | Datasource Loki pour Grafana |
| `modules/monitoring-stack/files/grafana/dashboards/logs-overview.json` | Dashboard logs centralisé |
| `modules/vm/files/promtail-agent.yml.tpl` | Config Promtail pour VMs distantes |

### À modifier

| Fichier | Modification |
|---------|--------------|
| `modules/monitoring-stack/main.tf` | Ajouter setup Traefik, Loki, Uptime Kuma, Promtail |
| `modules/monitoring-stack/variables.tf` | Variables pour nouveaux services |
| `modules/monitoring-stack/outputs.tf` | URLs des nouveaux services |
| `modules/monitoring-stack/files/docker-compose.yml.tpl` | Ajouter services Docker |
| `modules/vm/main.tf` | Option installation Promtail |
| `modules/vm/variables.tf` | Variable `install_promtail`, `loki_url` |
| `environments/monitoring/monitoring.tf` | Activer nouveaux services |
| `environments/monitoring/variables.tf` | Nouvelles variables |
| `environments/prod/main.tf` | Activer Promtail sur VMs |

### Tests à ajouter

| Fichier | Couverture |
|---------|------------|
| `modules/monitoring-stack/tests/traefik.tftest.hcl` | Validation config Traefik |
| `modules/monitoring-stack/tests/loki.tftest.hcl` | Validation config Loki |
| `modules/vm/tests/promtail.tftest.hcl` | Validation option Promtail |
| `tests/integration/observability.bats` | Tests E2E des nouveaux services |

---

## Phases d'Implémentation

### Phase 1 : Fondation (bloquant)

**Objectif**: Préparer les variables et la structure avant d'ajouter les services

- [ ] T001 - Créer structure des dossiers pour nouveaux fichiers de config
- [ ] T002 - Ajouter variables dans `modules/monitoring-stack/variables.tf`
- [ ] T003 - Ajouter variables dans `modules/vm/variables.tf`

**Checkpoint**: Variables prêtes, les user stories peuvent commencer.

### Phase 2 : User Story 1 - Reverse Proxy (P1 - MVP) 🎯

**Objectif**: Accéder aux services via URLs lisibles (*.home.lan)

- [ ] T004 - [P] [US1] Créer `traefik.yml.tpl` - configuration statique
- [ ] T005 - [P] [US1] Créer `dynamic.yml.tpl` - routes vers services existants
- [ ] T006 - [US1] Modifier `docker-compose.yml.tpl` - ajouter service Traefik
- [ ] T007 - [US1] Modifier `main.tf` du module - setup Traefik
- [ ] T008 - [US1] Ajouter outputs URLs Traefik
- [ ] T009 - [US1] Modifier firewall pour ports 80/443
- [ ] T010 - [US1] Test Terraform pour Traefik

**Checkpoint**: US1 fonctionnelle - grafana.home.lan accessible.

### Phase 3 : User Story 2 - Centralisation Logs (P1 - MVP) 🎯

**Objectif**: Consulter les logs de toutes les VMs depuis Grafana

#### 3a - Loki sur monitoring-stack

- [ ] T011 - [P] [US2] Créer `loki-config.yml` - configuration Loki
- [ ] T012 - [P] [US2] Créer `promtail-config.yml.tpl` - Promtail local
- [ ] T013 - [US2] Modifier `docker-compose.yml.tpl` - services Loki + Promtail
- [ ] T014 - [US2] Créer datasource Loki pour Grafana
- [ ] T015 - [P] [US2] Créer dashboard logs-overview.json
- [ ] T016 - [US2] Modifier `main.tf` - setup Loki/Promtail
- [ ] T017 - [US2] Ajouter route Traefik pour Loki (optionnel)
- [ ] T018 - [US2] Modifier firewall pour port 3100

#### 3b - Promtail sur VMs de production

- [ ] T019 - [P] [US2] Créer `promtail-agent.yml.tpl` dans module vm
- [ ] T020 - [US2] Modifier `modules/vm/main.tf` - option install_promtail
- [ ] T021 - [US2] Modifier `modules/vm/variables.tf` - variables Promtail
- [ ] T022 - [US2] Modifier `environments/prod/main.tf` - activer Promtail
- [ ] T023 - [US2] Modifier firewall VMs prod pour port 9080
- [ ] T024 - [US2] Test Terraform pour Loki/Promtail

**Checkpoint**: US2 fonctionnelle - logs visibles dans Grafana.

### Phase 4 : User Story 3 - Surveillance Disponibilité (P2)

**Objectif**: Tableau de bord de statut des services

- [ ] T025 - [P] [US3] Modifier `docker-compose.yml.tpl` - service Uptime Kuma
- [ ] T026 - [US3] Modifier `main.tf` - setup Uptime Kuma
- [ ] T027 - [US3] Ajouter route Traefik pour uptime.home.lan
- [ ] T028 - [US3] Modifier firewall pour port 3001
- [ ] T029 - [US3] Ajouter outputs URLs Uptime Kuma
- [ ] T030 - [US3] Test Terraform pour Uptime Kuma

**Checkpoint**: US3 fonctionnelle - uptime.home.lan accessible.

### Phase 5 : User Story 4 - HTTPS (P3)

**Objectif**: Certificats auto-signés pour HTTPS local

- [ ] T031 - [P] [US4] Générer CA locale dans Terraform (tls_private_key)
- [ ] T032 - [US4] Configurer Traefik pour TLS avec CA locale
- [ ] T033 - [US4] Documenter import CA dans navigateurs
- [ ] T034 - [US4] Test HTTPS

**Checkpoint**: US4 fonctionnelle - https://grafana.home.lan sans warning.

### Phase 6 : Polish & Documentation

- [ ] T035 - [P] Mise à jour README.md
- [ ] T036 - [P] Créer doc DNS configuration (hosts ou dnsmasq)
- [ ] T037 - Tests BATS d'intégration
- [ ] T038 - Mise à jour CHANGELOG.md

---

## Risques et Mitigations

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| RAM insuffisante sur VM monitoring | Élevé | Faible | Monitoring des ressources, augmenter si besoin |
| Résolution DNS *.home.lan | Moyen | Moyenne | Documenter config dnsmasq/hosts, tester avant déploiement |
| Promtail ne peut pas pousser vers Loki | Moyen | Faible | Firewall rules, logs de debug |
| Traefik auto-discovery échoue | Moyen | Faible | Labels Docker explicites sur chaque service |
| Volume de logs trop important | Moyen | Moyenne | Limites d'ingestion Loki, rétention 7j |

---

## Dépendances et Ordre d'Exécution

### Dépendances entre phases

```
Phase 1 (Fondation)
     │
     ├──▶ Phase 2 (US1 - Traefik)
     │         │
     │         ▼
     ├──▶ Phase 3 (US2 - Loki) ◄── dépend de Traefik pour routes
     │         │
     │         ▼
     └──▶ Phase 4 (US3 - Uptime) ◄── dépend de Traefik pour routes
               │
               ▼
         Phase 5 (US4 - HTTPS) ◄── dépend de Traefik
               │
               ▼
         Phase 6 (Polish)
```

### Tâches parallélisables

- **Phase 2** : T004 et T005 en parallèle
- **Phase 3a** : T011, T012, T015 en parallèle
- **Phase 3b** : T019 peut démarrer dès Phase 1 terminée
- **Phase 5** : T031 peut démarrer dès Phase 2 terminée

---

## Critères de Validation

### Avant de commencer (Gate 1)
- [x] Spec approuvée
- [x] Plan reviewé
- [ ] DNS *.home.lan configuré (ou doc fournie)

### Avant chaque merge (Gate 2)
- [ ] Tests Terraform passent
- [ ] terraform fmt OK
- [ ] terraform validate OK

### Avant déploiement (Gate 3)
- [ ] grafana.home.lan accessible
- [ ] Logs de toutes les VMs visibles dans Grafana
- [ ] uptime.home.lan affiche les services
- [ ] Alertes Telegram fonctionnelles
- [ ] Documentation mise à jour

---

## Notes

### Configuration DNS requise

Option 1 - Fichier hosts sur chaque machine :
```
192.168.1.51 grafana.home.lan prometheus.home.lan alertmanager.home.lan uptime.home.lan loki.home.lan
```

Option 2 - Dnsmasq sur routeur :
```
address=/home.lan/192.168.1.51
```

### Ressources Uptime Kuma

La configuration initiale des monitors se fait via l'interface web :
- URL: http://uptime.home.lan
- Ajouter chaque service manuellement au premier démarrage
- Configurer notification Telegram avec le même bot que Alertmanager

---

**Version**: 1.0 | **Créé**: 2026-02-04 | **Dernière modification**: 2026-02-04
