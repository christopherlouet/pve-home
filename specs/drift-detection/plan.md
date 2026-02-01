# Plan d'implementation : Detection de drift infrastructure

**Branche**: `feature/drift-detection`
**Date**: 2026-02-01
**Spec**: [specs/drift-detection/spec.md](spec.md)
**Statut**: Draft

---

## Resume

Mettre en place un systeme de detection automatique des ecarts entre l'etat Terraform declare et l'infrastructure Proxmox reelle. Le systeme s'execute comme un script shell local via cron/systemd timer sur le node monitoring, execute `terraform plan` sur chaque environnement (prod, lab, monitoring), analyse le resultat, et notifie via Alertmanager/Telegram en cas de drift ou d'erreur. Les resultats sont stockes localement et exposes comme metriques pour le dashboard Grafana existant.

---

## Contexte Technique

| Aspect | Choix | Notes |
|--------|-------|-------|
| **IaC** | Terraform >= 1.5.0 | HCL, provider bpg/proxmox ~0.93 |
| **Execution** | Script shell (bash) | Execute sur le node monitoring |
| **Scheduling** | systemd timer | Plus fiable que cron, journalisation native |
| **Notification** | Alertmanager + Telegram | Systeme existant |
| **Metriques** | Prometheus textfile collector | Expose les resultats via node_exporter |
| **Tests** | BATS | Framework existant dans `tests/` |

### Contraintes

- Pas d'acces reseau depuis la CI GitHub Actions vers le homelab
- Le script s'execute localement sur le node monitoring qui heberge Minio et la stack de supervision
- Les credentials Proxmox sont dans des fichiers `.tfvars` proteges sur le node monitoring
- `terraform plan` necessite un lock sur le state S3 (Minio) : pas d'execution concurrente

### Performance attendue

| Metrique | Cible |
|----------|-------|
| Duree du scan par environnement | < 5 minutes |
| Duree totale (3 environnements) | < 15 minutes |
| Delai de notification | < 1 minute apres detection |
| Frequence de scan | 1 fois par jour (configurable) |

---

## Verification Conventions

- [x] Respecte les conventions du projet (scripts shell avec `common.sh`, BATS tests)
- [x] Coherent avec l'architecture existante (scripts dans `scripts/`, tests dans `tests/`)
- [x] Pas d'over-engineering (script shell + systemd timer, pas de service dedie)
- [x] Tests planifies (BATS)

---

## Structure du Projet

### Documentation

```
specs/drift-detection/
├── spec.md           # Specification fonctionnelle
├── plan.md           # Ce fichier
└── tasks.md          # Decoupage en taches
```

### Code Source

```
scripts/
├── lib/
│   └── common.sh                          # EXISTANT - Librairie commune
├── drift/
│   └── check-drift.sh                     # NOUVEAU - Script principal de detection
├── restore/                               # EXISTANT
└── systemd/
    ├── pve-drift-check.service            # NOUVEAU - Service systemd
    └── pve-drift-check.timer              # NOUVEAU - Timer systemd

infrastructure/proxmox/
├── modules/monitoring-stack/
│   └── files/
│       ├── prometheus/alerts/
│       │   └── default.yml                # MODIFIER - Ajouter alertes drift
│       └── grafana/dashboards/
│           └── drift-overview.json        # NOUVEAU - Dashboard conformite

tests/
└── drift/
    └── test_check_drift.bats              # NOUVEAU - Tests BATS
```

---

## Fichiers Impactes

### A creer

| Fichier | Responsabilite |
|---------|----------------|
| `scripts/drift/check-drift.sh` | Script principal : execute `terraform plan` par environnement, analyse le resultat, genere les metriques, notifie si drift |
| `scripts/systemd/pve-drift-check.service` | Unite systemd pour executer le script |
| `scripts/systemd/pve-drift-check.timer` | Timer systemd (quotidien par defaut, configurable) |
| `tests/drift/test_check_drift.bats` | Tests BATS : parsing du plan, generation de metriques, gestion des erreurs |
| `infrastructure/proxmox/modules/monitoring-stack/files/grafana/dashboards/drift-overview.json` | Dashboard Grafana : historique de conformite par environnement |

### A modifier

| Fichier | Modification |
|---------|--------------|
| `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml` | Ajouter groupe `drift-alerts` : `DriftDetected`, `DriftCheckFailed`, `DriftCheckStale` |
| `infrastructure/proxmox/modules/monitoring-stack/main.tf` | Monter le fichier de metriques textfile dans le container node_exporter |

### Tests a ajouter

| Fichier | Couverture |
|---------|------------|
| `tests/drift/test_check_drift.bats` | Parsing plan output, generation metriques Prometheus, gestion erreurs (credentials, network, lock), mode dry-run |

---

## Approche Choisie

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  NODE MONITORING                                                     │
│                                                                      │
│  ┌────────────────────┐                                              │
│  │ systemd timer      │  quotidien 06:00                             │
│  │ pve-drift-check    │──────────────────┐                           │
│  └────────────────────┘                  │                           │
│                                          ▼                           │
│  ┌────────────────────────────────────────────────────────┐          │
│  │ check-drift.sh                                         │          │
│  │                                                        │          │
│  │  pour chaque env (prod, lab, monitoring):              │          │
│  │    1. cd environments/$env                             │          │
│  │    2. terraform plan -detailed-exitcode                │          │
│  │    3. si exitcode=2 → drift detecte                    │          │
│  │    4. generer metriques prometheus (textfile)           │          │
│  │    5. stocker rapport dans /var/log/pve-drift/          │          │
│  │                                                        │          │
│  └───────┬─────────────────────────────┬──────────────────┘          │
│          │                             │                             │
│          ▼                             ▼                             │
│  ┌───────────────────┐  ┌──────────────────────────────┐             │
│  │ /var/lib/node_exp/ │  │ /var/log/pve-drift/          │            │
│  │ pve_drift.prom     │  │ drift-2026-02-01-prod.log    │            │
│  │ (metriques)        │  │ drift-2026-02-01-lab.log     │            │
│  └────────┬──────────┘  └──────────────────────────────┘             │
│           │                                                          │
│           ▼                                                          │
│  ┌────────────────────┐  ┌────────────────────┐                      │
│  │ node_exporter      │  │ Alertmanager       │                      │
│  │ (textfile collector)│  │ → Telegram         │                      │
│  └────────┬───────────┘  └────────┬───────────┘                      │
│           │                       │                                  │
│           ▼                       │                                  │
│  ┌────────────────────┐           │                                  │
│  │ Prometheus         │───────────┘                                  │
│  │ + alertes drift    │                                              │
│  └────────┬───────────┘                                              │
│           │                                                          │
│           ▼                                                          │
│  ┌────────────────────┐                                              │
│  │ Grafana            │                                              │
│  │ drift-overview     │                                              │
│  └────────────────────┘                                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Justification

L'approche script local + systemd timer est choisie car :
1. Pas d'acces CI vers le homelab (decision clarifiee)
2. Le node monitoring a deja Terraform, Minio, et les `.tfvars` configures
3. systemd timer offre journalisation native (`journalctl`), retry, et persistance des timers manques
4. Les metriques textfile s'integrent sans composant supplementaire dans la stack Prometheus/node_exporter existante
5. Coherent avec les scripts existants (`verify-backups.sh`, `restore-vm.sh`)

### Alternatives considerees

| Alternative | Pourquoi rejetee |
|-------------|------------------|
| GitHub Actions scheduled + self-hosted runner | Decision clarifiee : pas d'acces CI vers le homelab |
| GitHub Actions + VPN/tunnel | Complexite de maintenance du tunnel, point de defaillance supplementaire |
| Cron job | systemd timer est plus robuste (journalisation, persistance des executions manquees) |
| Outil dedie (Spacelift, env0, Atlantis) | Surdimensionne pour un homelab, dependance externe |

---

## Phases d'Implementation

### Phase 1 : Script principal de detection (US1 - P1 MVP)

**Objectif**: Detecter le drift sur chaque environnement et generer un rapport

- [ ] T001 - [US1] Creer `scripts/drift/check-drift.sh` - Structure principale, parsing arguments (`--env`, `--all`, `--dry-run`, `--help`)
- [ ] T002 - [US1] Implementer la detection par environnement - `terraform init` + `terraform plan -detailed-exitcode` avec analyse du code retour (0=conforme, 1=erreur, 2=drift)
- [ ] T003 - [US1] Implementer le parsing du plan - Extraire les ressources modifiees, ajoutees, supprimees depuis la sortie `terraform plan`
- [ ] T004 - [US1] Implementer le rapport console - Tableau structure (environnement, statut, ressources impactees, details)
- [ ] T005 - [US1] Implementer le stockage des rapports - Ecriture dans `/var/log/pve-drift/` avec rotation (30 jours)

**Checkpoint**: `./check-drift.sh --all` detecte le drift et affiche un rapport. `--dry-run` fonctionne.

### Phase 2 : Metriques et notifications (US1 - P1 MVP)

**Objectif**: Exposer les resultats en metriques Prometheus et notifier via Telegram

- [ ] T006 - [US1] Implementer la generation des metriques Prometheus - Fichier textfile `/var/lib/node_exporter/textfile_collector/pve_drift.prom` avec metriques : `pve_drift_status{env}` (0=conforme, 1=drift, 2=erreur), `pve_drift_resources_changed{env}`, `pve_drift_last_check_timestamp{env}`
- [ ] T007 - [US1] Modifier `modules/monitoring-stack/main.tf` - Monter le repertoire textfile dans le container node_exporter
- [ ] T008 - [US1] Modifier `modules/monitoring-stack/files/prometheus/alerts/default.yml` - Ajouter alertes `DriftDetected` (severity: warning), `DriftCheckFailed` (severity: critical), `DriftCheckStale` (severity: warning, si dernier check > 48h)

**Checkpoint**: Un drift genere une alerte Telegram. Les metriques sont visibles dans Prometheus.

### Phase 3 : Scheduling systemd (US1 - P1 MVP)

**Objectif**: Execution automatique quotidienne sans intervention

- [ ] T009 - [P] [US1] Creer `scripts/systemd/pve-drift-check.service` - Unite systemd (Type=oneshot, ExecStart=check-drift.sh --all)
- [ ] T010 - [P] [US1] Creer `scripts/systemd/pve-drift-check.timer` - Timer systemd (OnCalendar=*-*-* 06:00:00, Persistent=true)
- [ ] T011 - [US1] Documenter l'installation du timer - Instructions dans le README ou un script d'installation

**Checkpoint**: Le timer s'execute automatiquement, CS-001 et CS-002 valides.

### Phase 4 : Dashboard conformite (US2 - P2)

**Objectif**: Historique visuel de la conformite dans Grafana

- [ ] T012 - [US2] Creer `modules/monitoring-stack/files/grafana/dashboards/drift-overview.json` - Dashboard avec : statut par environnement (vert/rouge), historique sur 30 jours, nombre de ressources en drift, dernier check timestamp

**Checkpoint**: Dashboard visible dans Grafana, CS-004 valide.

### Phase 5 : Documentation reconciliation (US3 - P3)

**Objectif**: Procedure documentee pour resoudre le drift

- [ ] T013 - [US3] Ajouter section reconciliation dans `docs/DRIFT-DETECTION.md` - Procedure : identifier le drift, decider (apply ou import), executer, verifier

**Checkpoint**: Procedure documentee et testable.

### Phase 6 : Tests et validation

**Objectif**: Couverture BATS et validation finale

- [ ] T014 - [P] Creer `tests/drift/test_check_drift.bats` - Tests : parsing arguments, analyse code retour terraform, generation metriques, gestion erreurs (credentials, lock, network), mode dry-run
- [ ] T015 - [P] Creer `docs/DRIFT-DETECTION.md` - Documentation complete : installation, configuration, interpretation des rapports, reconciliation
- [ ] T016 - Validation CI - Verifier que `terraform validate` et `terraform-docs` passent sur les fichiers modifies
- [ ] T017 - Test integration manuelle - Introduire un drift volontaire, verifier detection + notification + dashboard

---

## Risques et Mitigations

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| `terraform plan` prend un lock sur le state et bloque un apply concurrent | Moyen | Moyenne | Executer le scan en dehors des heures de maintenance (06:00), lock timeout configurable |
| Les credentials Proxmox expirent et le scan echoue silencieusement | Eleve | Faible | Alerte `DriftCheckFailed` distincte, rotation des tokens documentee |
| Faux positifs frequents (drift du provider, pas de modification manuelle) | Moyen | Moyenne | Documenter les drifts connus a ignorer, envisager un filtre dans le script |
| Le node monitoring est redemarrage pendant le scan | Faible | Faible | systemd timer Persistent=true rattrape les executions manquees |
| Espace disque des rapports non maitrise | Faible | Faible | Rotation des rapports (30 jours), alerte disque existante (>85%) |

---

## Dependances et Ordre d'Execution

### Dependances entre phases

```
Phase 1 (Script principal) ──▶ Phase 2 (Metriques + notifications)
                               │
                               ├──▶ Phase 3 (Scheduling) [peut demarrer apres Phase 1]
                               │
                               └──▶ Phase 4 (Dashboard) [depend des metriques Phase 2]

Phase 3 ──▶ Phase 5 (Documentation)

Phases 1-5 ──▶ Phase 6 (Tests et validation)
```

### Parallelisation possible

- Phase 3 (systemd) peut demarrer des que Phase 1 est terminee
- Les taches T009/T010 (fichiers systemd) sont parallelisables
- Les taches T014/T015 (tests + docs) sont parallelisables
- Phase 4 (dashboard) necessite Phase 2 (metriques) pour etre testable

---

## Criteres de Validation

### Avant de commencer (Gate 1)
- [x] Spec approuvee (spec.md v1.0, clarifications resolues)
- [x] Plan reviewe (ce fichier)
- [ ] Node monitoring accessible avec Terraform installe

### Avant chaque merge (Gate 2)
- [ ] `terraform validate` passe pour les modules modifies
- [ ] Tests BATS passent
- [ ] terraform-docs a jour pour les modules modifies

### Avant deploiement (Gate 3)
- [ ] CS-001: Detection quotidienne sur chaque environnement
- [ ] CS-002: Drift notifie dans les 24 heures
- [ ] CS-004: Historique consultable sur 30 jours
- [ ] CS-005: Scan < 5 minutes par environnement

---

## Notes

- `terraform plan -detailed-exitcode` retourne : 0 (pas de changement), 1 (erreur), 2 (changements detectes). C'est le mecanisme central de la detection.
- Le textfile collector de node_exporter lit les fichiers `.prom` dans un repertoire configure. C'est le moyen le plus simple d'exposer des metriques custom sans service supplementaire.
- systemd timer avec `Persistent=true` garantit que si le node est eteint a l'heure prevue, le scan s'execute au prochain demarrage.
- Le scan ne doit jamais executer `terraform apply` : detection uniquement (EF-008).

---

**Version**: 1.0 | **Cree**: 2026-02-01 | **Derniere modification**: 2026-02-01
