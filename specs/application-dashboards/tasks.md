# Tâches : Application Dashboards Grafana

**Feature**: Application Dashboards
**Plan**: [plan.md](./plan.md)
**Date**: 2026-02-04

---

## Légende

| Marqueur | Signification |
|----------|---------------|
| `[P]` | Parallélisable (pas de dépendance) |
| `[P1]` | Priorité MVP |
| `[P2]` | Priorité Important |

---

## Phase 1 : Application Overview (P1 - MVP)

**Fichier** : `modules/monitoring-stack/files/grafana/dashboards/application-overview.json`

| ID | Tâche | Dépendance | Statut |
|----|-------|------------|--------|
| T001 | Créer structure JSON de base (metadata, templating, variables $app/$environment) | - | [ ] |
| T002 | Row "Health Summary" : Stats up/down pour chaque service | T001 | [ ] |
| T003 | Row "HTTP Probes" : Success rate, latency moyenne, probes status | T001 | [ ] |
| T004 | Row "Resources" : Gauges CPU, Memory, Disk de la VM | T001 | [ ] |
| T005 | Row "Database" : Connexions actives, transactions/sec | T001 | [ ] |
| T006 | Row "Containers" : Containers running, CPU/mem top 5 | T001 | [ ] |
| T007 | Ajouter liens drill-down vers dashboards détaillés | T002-T006 | [ ] |

**Queries clés** :
```promql
# Services up
count(up{app="$app", environment="$environment"} == 1)

# HTTP Probe success rate
avg(probe_success{app="$app"}) * 100

# Probe latency
avg(probe_duration_seconds{app="$app"})
```

---

## Phase 2 : HTTP Probes Dashboard (P1)

**Fichier** : `modules/monitoring-stack/files/grafana/dashboards/http-probes.json`

| ID | Tâche | Dépendance | Statut |
|----|-------|------------|--------|
| T008 | [P] Créer structure JSON (variables $app, $probe) | - | [ ] |
| T009 | Row "Overview" : Stats success/failure count | T008 | [ ] |
| T010 | Panel "Probe Status" : Table avec tous les probes et status | T008 | [ ] |
| T011 | Panel "Latency Timeline" : Graph probe_duration_seconds | T008 | [ ] |
| T012 | Panel "HTTP Phases" : Stacked graph (DNS, connect, TLS, transfer) | T008 | [ ] |
| T013 | Panel "SSL Certificate Expiry" : Stat avec threshold (30j warning) | T008 | [ ] |
| T014 | Row "Details" : HTTP status codes, redirects | T008 | [ ] |

**Queries clés** :
```promql
# Probe success over time
probe_success{app="$app"}

# Latency by phase
probe_http_duration_seconds{app="$app", phase=~"resolve|connect|tls|transfer"}

# SSL expiry days
(probe_ssl_earliest_cert_expiry{app="$app"} - time()) / 86400
```

---

## Phase 3 : PostgreSQL Dashboard (P2)

**Fichier** : `modules/monitoring-stack/files/grafana/dashboards/postgresql.json`

| ID | Tâche | Dépendance | Statut |
|----|-------|------------|--------|
| T015 | [P] Créer structure JSON (variables $app, $database) | - | [ ] |
| T016 | Row "Overview" : Stats connexions, transactions, uptime | T015 | [ ] |
| T017 | Panel "Connections" : Gauge active/idle/max | T015 | [ ] |
| T018 | Panel "Connections Timeline" : Graph par état | T015 | [ ] |
| T019 | Panel "Transactions" : Graph commits/rollbacks per sec | T015 | [ ] |
| T020 | Panel "Cache Hit Ratio" : Gauge avec threshold | T015 | [ ] |
| T021 | Panel "Database Size" : Stat par database | T015 | [ ] |
| T022 | Row "Performance" : Locks, deadlocks, temp files | T015 | [ ] |
| T023 | Panel "Slow Queries" : Table si pg_stat_statements actif | T015 | [ ] |

**Queries clés** :
```promql
# Connexions par état
pg_stat_activity_count{app="$app", state=~"active|idle|idle in transaction"}

# Transactions per second
rate(pg_stat_database_xact_commit{app="$app"}[1m])

# Cache hit ratio
pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read) * 100

# Database size
pg_database_size_bytes{app="$app"}
```

---

## Phase 4 : Docker Containers Dashboard (P2)

**Fichier** : `modules/monitoring-stack/files/grafana/dashboards/docker-containers.json`

| ID | Tâche | Dépendance | Statut |
|----|-------|------------|--------|
| T024 | [P] Créer structure JSON (variables $app, $container) | - | [ ] |
| T025 | Row "Overview" : Stats containers running/stopped | T024 | [ ] |
| T026 | Panel "CPU Usage" : Graph par container (stacked) | T024 | [ ] |
| T027 | Panel "Memory Usage" : Graph par container | T024 | [ ] |
| T028 | Panel "Memory Limit %" : Gauge usage vs limit | T024 | [ ] |
| T029 | Panel "Network I/O" : Graph RX/TX par container | T024 | [ ] |
| T030 | Panel "Disk I/O" : Graph read/write | T024 | [ ] |
| T031 | Table "Container Status" : Tous containers avec métriques | T024 | [ ] |

**Queries clés** :
```promql
# CPU usage par container (%)
rate(container_cpu_usage_seconds_total{app="$app", name!=""}[1m]) * 100

# Memory usage
container_memory_usage_bytes{app="$app", name!=""}

# Network receive
rate(container_network_receive_bytes_total{app="$app"}[1m])

# Filtrage par compose service
container_label_com_docker_compose_service
```

**Note** : Filtrer par `name!=""` pour exclure les métriques root cgroup.

---

## Phase 5 : Documentation

| ID | Tâche | Dépendance | Statut |
|----|-------|------------|--------|
| T032 | [P] Mettre à jour README.md avec section "Application Dashboards" | - | [ ] |
| T033 | [P] Ajouter exemples de labels requis | - | [ ] |

---

## Ordre d'exécution recommandé

```
T001 ──────────────────────────────────────────────────────┐
  │                                                        │
  ├──▶ T002, T003, T004, T005, T006 (parallèle)           │
  │              │                                         │
  │              ▼                                         │
  │            T007                                        │
  │                                                        │
  ├──▶ T008 ──▶ T009-T014 (Phase 2 - HTTP)          [P]   │
  │                                                        │
  ├──▶ T015 ──▶ T016-T023 (Phase 3 - PostgreSQL)    [P]   │
  │                                                        │
  └──▶ T024 ──▶ T025-T031 (Phase 4 - Docker)        [P]   │
                     │                                     │
                     ▼                                     │
              T032, T033 (Documentation)                   │
```

---

## Checklist finale

- [ ] 4 fichiers JSON créés et valides
- [ ] Variables $app et $environment fonctionnent
- [ ] Dashboards provisionnés automatiquement
- [ ] README à jour
- [ ] Commit sans mention d'application spécifique

---

**Total** : 33 tâches | **Parallélisables** : Phases 2, 3, 4
