# Plan d'implémentation : Application Dashboards Grafana

**Branche**: `feature/application-dashboards`
**Date**: 2026-02-04
**Statut**: Draft

---

## Résumé

Ajouter des dashboards Grafana génériques pour monitorer des applications externes (non-Proxmox) déployées sur des VMs. Ces dashboards utilisent les labels standards (`app`, `environment`) pour filtrer et sont réutilisables pour n'importe quelle application.

---

## Contexte Technique

| Aspect | Choix | Notes |
|--------|-------|-------|
| **Format** | JSON Grafana | Compatible Grafana 9+ |
| **Datasource** | Prometheus | UID: `prometheus` |
| **Variables** | `$app`, `$environment` | Filtrage dynamique |
| **Métriques** | Node, PostgreSQL, cAdvisor, Nginx, Blackbox | Exporters standards |

### Contraintes

- Dashboards génériques (pas de nom d'application hardcodé)
- Compatibles avec le provisioning automatique existant
- Labels standards : `app`, `environment`, `instance`

### Exporters ciblés

| Exporter | Port | Métriques clés |
|----------|------|----------------|
| `node_exporter` | 9100 | CPU, mémoire, disque, réseau |
| `postgres_exporter` | 9187 | Connexions, queries, locks, replication |
| cAdvisor | 9080 | CPU/mem containers, network I/O |
| `nginx_exporter` | 9113 | Requests, connections, status codes |
| `blackbox_exporter` | 9115 | HTTP probes, latency, SSL cert |

---

## Fichiers Impactés

### À créer

| Fichier | Responsabilité |
|---------|----------------|
| `files/grafana/dashboards/application-overview.json` | Vue d'ensemble : probes HTTP + résumé services |
| `files/grafana/dashboards/postgresql.json` | Métriques PostgreSQL détaillées |
| `files/grafana/dashboards/docker-containers.json` | Métriques cAdvisor par container |
| `files/grafana/dashboards/http-probes.json` | Blackbox : latence, disponibilité, SSL |

### À modifier

| Fichier | Modification |
|---------|--------------|
| `README.md` | Documenter les nouveaux dashboards |

### Tests

Les dashboards JSON sont validés par :
- Syntaxe JSON valide
- Import manuel dans Grafana (test fonctionnel)

---

## Architecture des Dashboards

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Overview                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ HTTP     │  │ Node     │  │ Database │  │ Containers│        │
│  │ Probes   │  │ Health   │  │ Status   │  │ Status   │        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
│         │            │            │              │              │
│         ▼            ▼            ▼              ▼              │
│  ┌──────────────────────────────────────────────────────┐      │
│  │              Drill-down Dashboards                    │      │
│  │  • HTTP Probes   • PostgreSQL   • Docker Containers   │      │
│  └──────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

### Variables communes

Tous les dashboards utilisent les mêmes variables pour cohérence :

```json
{
  "templating": {
    "list": [
      {
        "name": "app",
        "query": "label_values(up, app)",
        "type": "query"
      },
      {
        "name": "environment",
        "query": "label_values(up{app=\"$app\"}, environment)",
        "type": "query"
      }
    ]
  }
}
```

---

## Phases d'Implémentation

### Phase 1 : Application Overview (P1 - MVP)

**Objectif**: Dashboard principal avec vue d'ensemble de la santé de l'application

| ID | Tâche | Parallélisable |
|----|-------|----------------|
| T001 | Créer `application-overview.json` avec structure de base | |
| T002 | Ajouter panneau HTTP Probes (up/down, latence) | |
| T003 | Ajouter panneau Node Health (CPU, mem, disk) | |
| T004 | Ajouter panneau Database Status (connexions, up) | |
| T005 | Ajouter panneau Containers Status (running, CPU) | |
| T006 | Ajouter liens drill-down vers autres dashboards | |

**Panels prévus** :
- Stat: Services Up/Down
- Stat: HTTP Probe Success Rate
- Stat: Average Latency
- Gauge: CPU Usage
- Gauge: Memory Usage
- Gauge: Disk Usage
- Table: Services Status

**Checkpoint**: Vue d'ensemble fonctionnelle avec filtrage par `$app`.

---

### Phase 2 : HTTP Probes Dashboard (P1)

**Objectif**: Dashboard détaillé des probes Blackbox

| ID | Tâche | Parallélisable |
|----|-------|----------------|
| T007 | [P] Créer `http-probes.json` | |
| T008 | Ajouter panneau Probe Success/Failure | |
| T009 | Ajouter graphe Latency over time | |
| T010 | Ajouter panneau SSL Certificate expiry | |
| T011 | Ajouter table All Probes avec status | |

**Métriques Blackbox** :
- `probe_success` : Succès/échec
- `probe_duration_seconds` : Latence totale
- `probe_http_duration_seconds` : Phases HTTP (DNS, connect, TLS, transfer)
- `probe_ssl_earliest_cert_expiry` : Expiration certificat

**Checkpoint**: Monitoring HTTP complet avec alertes possibles.

---

### Phase 3 : PostgreSQL Dashboard (P2)

**Objectif**: Dashboard métriques PostgreSQL

| ID | Tâche | Parallélisable |
|----|-------|----------------|
| T012 | [P] Créer `postgresql.json` | |
| T013 | Ajouter panneau Connections (active, idle, max) | |
| T014 | Ajouter panneau Transactions (commits, rollbacks) | |
| T015 | Ajouter panneau Cache Hit Ratio | |
| T016 | Ajouter panneau Database Size | |
| T017 | Ajouter panneau Slow Queries / Locks | |

**Métriques postgres_exporter** :
- `pg_stat_activity_count` : Connexions par état
- `pg_stat_database_*` : Stats par base
- `pg_stat_bgwriter_*` : Checkpoints
- `pg_locks_count` : Locks actifs

**Checkpoint**: Visibilité complète sur la santé PostgreSQL.

---

### Phase 4 : Docker Containers Dashboard (P2)

**Objectif**: Dashboard métriques cAdvisor

| ID | Tâche | Parallélisable |
|----|-------|----------------|
| T018 | [P] Créer `docker-containers.json` | |
| T019 | Ajouter panneau Containers Running | |
| T020 | Ajouter graphe CPU Usage par container | |
| T021 | Ajouter graphe Memory Usage par container | |
| T022 | Ajouter graphe Network I/O par container | |
| T023 | Ajouter table Container Status | |

**Métriques cAdvisor** :
- `container_cpu_usage_seconds_total` : CPU
- `container_memory_usage_bytes` : Mémoire
- `container_network_*` : Réseau
- `container_fs_*` : Filesystem

**Filtrage** : Par label `container_label_com_docker_compose_service`

**Checkpoint**: Visibilité sur tous les containers Docker.

---

### Phase 5 : Documentation

| ID | Tâche | Parallélisable |
|----|-------|----------------|
| T024 | [P] Mettre à jour README.md du module | |
| T025 | [P] Ajouter section dashboards dans tfvars.example | |

---

## Dépendances et Ordre d'Exécution

```
Phase 1 (Overview) ──┬──▶ Phase 2 (HTTP Probes) [P]
                     │
                     ├──▶ Phase 3 (PostgreSQL) [P]
                     │
                     └──▶ Phase 4 (Docker) [P]

Phases 2, 3, 4 ──────────▶ Phase 5 (Documentation)
```

**Phases 2, 3, 4 sont parallélisables** - aucune dépendance entre elles.

---

## Estimation

| Phase | Complexité | Fichiers |
|-------|------------|----------|
| Phase 1 - Overview | Moyenne | 1 dashboard (~400 lignes) |
| Phase 2 - HTTP Probes | Simple | 1 dashboard (~300 lignes) |
| Phase 3 - PostgreSQL | Moyenne | 1 dashboard (~500 lignes) |
| Phase 4 - Docker | Moyenne | 1 dashboard (~400 lignes) |
| Phase 5 - Docs | Simple | README update |

**Total** : 4 dashboards JSON + documentation

---

## Risques et Mitigations

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Métriques non disponibles si exporter absent | Moyen | Panels montrent "No data" (acceptable) |
| Labels incohérents entre exporters | Moyen | Documenter les labels requis |
| Dashboards trop complexes | Faible | Garder simple, drill-down pour détails |

---

## Critères de Validation

- [ ] Dashboards JSON valides (syntaxe)
- [ ] Variables `$app` et `$environment` fonctionnelles
- [ ] Liens drill-down corrects
- [ ] Panels affichent les données quand métriques présentes
- [ ] README documenté

---

## Sources d'inspiration

Dashboards Grafana.com populaires (pour référence, pas d'import direct) :
- PostgreSQL: #9628, #455
- cAdvisor: #893, #11600
- Blackbox: #7587

---

**Version**: 1.0 | **Créé**: 2026-02-04
