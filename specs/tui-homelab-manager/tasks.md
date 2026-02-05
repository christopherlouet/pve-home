# Tâches : TUI Homelab Manager

**Input**: Documents de conception depuis `specs/tui-homelab-manager/`
**Prérequis**: plan.md (requis), spec.md (requis pour user stories)

---

## Format des tâches : `[ID] [P?] [US?] Description`

- **[P]** : Peut être exécutée en parallèle (fichiers différents, pas de dépendances)
- **[US1-US9]** : User story associée (pour traçabilité)
- Chemins de fichiers exacts dans les descriptions

---

## Phase 1 : Fondation (Infrastructure TUI)

**Objectif** : Base technique nécessaire à toutes les user stories

**⚠️ CRITIQUE** : Aucune user story ne peut commencer avant la fin de cette phase

- [ ] T001 - Créer la structure `scripts/tui/`, `scripts/tui/lib/`, `scripts/tui/menus/`
- [ ] T002 - [P] Créer `scripts/tui/lib/tui-colors.sh` (définitions couleurs, thème gum)
- [ ] T003 - [P] Créer `scripts/tui/lib/tui-config.sh` (détection local/distant, chemins dynamiques)
- [ ] T004 - Créer `scripts/tui/lib/tui-common.sh` (wrappers gum: menu, confirm, input, spin, table, banner)
- [ ] T005 - Créer `scripts/tui/homelab-manager.sh` (point d'entrée, parsing args, vérification prérequis)
- [ ] T006 - Créer `scripts/tui/menus/main.sh` (menu principal avec 7 catégories, boucle navigation)
- [ ] T007 - [P] Créer `tests/tui/test_homelab-manager.bats` (tests args, help, version, prérequis)
- [ ] T008 - [P] Créer `tests/tui/test_tui-common.bats` (tests fonctions wrapper)

**Checkpoint** : TUI démarre, affiche menu principal, navigue, quitte proprement avec Ctrl+C ou "Quitter".

---

## Phase 2 : US1 - Status/Health (P1 MVP) 🎯

**Objectif** : Voir l'état de santé de toute l'infrastructure en un coup d'œil

**Test indépendant** : Lancer TUI → Status → voir état OK/WARN/FAIL par VM et composant

### Implémentation US1

- [ ] T009 - [US1] Créer `scripts/tui/menus/status.sh` (structure menu status)
- [ ] T010 - [US1] Implémenter sélection environnement (prod/lab/monitoring/tous)
- [ ] T011 - [US1] Intégrer appel à `scripts/health/check-health.sh` avec spinner
- [ ] T012 - [US1] Parser et afficher résultats en tableau coloré (OK=vert, WARN=jaune, FAIL=rouge)
- [ ] T013 - [US1] Implémenter drill-down sur composant en erreur (détails diagnostic)
- [ ] T014 - [US1] Afficher résumé persistent "X/Y composants sains" dans banner
- [ ] T015 - [P] [US1] Créer `tests/tui/test_status.bats` (tests menu status)

**Checkpoint** : US1 fonctionnelle - health check visuel avec couleurs et détails.

---

## Phase 3 : US2 - Snapshots (P1 MVP) 🎯

**Objectif** : Créer, lister, restaurer et supprimer des snapshots de VMs

**Test indépendant** : Créer snapshot → le voir dans liste → restaurer → vérifier état VM

### Implémentation US2

- [ ] T016 - [US2] Créer `scripts/tui/menus/lifecycle.sh` (structure menu lifecycle)
- [ ] T017 - [US2] Implémenter sélection VM depuis tfvars (liste avec IP et nom)
- [ ] T018 - [US2] Implémenter "Créer snapshot" avec input nom + appel `snapshot-vm.sh create`
- [ ] T019 - [US2] Implémenter "Lister snapshots" avec tableau (nom, date, taille)
- [ ] T020 - [US2] Implémenter "Restaurer snapshot" avec sélection + confirmation explicite
- [ ] T021 - [US2] Implémenter "Supprimer snapshot" avec sélection + confirmation explicite
- [ ] T022 - [P] [US2] Créer `tests/tui/test_lifecycle.bats` (tests menu lifecycle)

**Checkpoint** : US2 fonctionnelle - CRUD snapshots complet avec confirmations.

---

## Phase 4 : US3 - Terraform (P1 MVP) 🎯

**Objectif** : Exécuter Terraform plan/apply/output par environnement

**Test indépendant** : Sélectionner env → plan → voir diff → apply ou annuler

### Implémentation US3

- [ ] T023 - [US3] Créer `scripts/tui/menus/terraform.sh` (structure menu terraform)
- [ ] T024 - [US3] Implémenter sélection environnement avec état (configuré/non)
- [ ] T025 - [US3] Implémenter "Plan" avec exécution terraform plan et affichage diff coloré
- [ ] T026 - [US3] Implémenter "Apply" avec confirmation explicite montrant le résumé des changements
- [ ] T027 - [US3] Implémenter "Output" avec affichage outputs terraform formatés
- [ ] T028 - [US3] Implémenter "Init" pour terraform init si nécessaire
- [ ] T029 - [US3] Gestion erreurs terraform avec message complet
- [ ] T030 - [P] [US3] Créer `tests/tui/test_terraform.bats` (tests menu terraform)

**Checkpoint** : US3 fonctionnelle - cycle complet plan/apply par environnement.

---

## Phase 5 : US4 - Déploiement (P2)

**Objectif** : Déployer scripts et timers sur la VM monitoring

**Test indépendant** : Lancer déploiement → voir progression → vérifier scripts sur VM

### Implémentation US4

- [ ] T031 - [US4] Créer `scripts/tui/menus/deploy.sh` (structure menu déploiement)
- [ ] T032 - [US4] Afficher résumé de ce qui sera déployé (scripts, tfvars, timers)
- [ ] T033 - [US4] Intégrer appel à `scripts/deploy.sh` avec progression par étape
- [ ] T034 - [US4] Afficher résultat final avec statut par composant
- [ ] T035 - [P] [US4] Créer `tests/tui/test_deploy_menu.bats`

**Checkpoint** : US4 fonctionnelle.

---

## Phase 6 : US5 - Drift Detection (P2)

**Objectif** : Détecter les changements non planifiés entre Terraform et l'infrastructure réelle

**Test indépendant** : Lancer drift check → voir rapport conformité ou drift détaillé

### Implémentation US5

- [ ] T036 - [US5] Créer `scripts/tui/menus/maintenance.sh` (structure menu maintenance)
- [ ] T037 - [US5] Implémenter sélection environnement ou "tous"
- [ ] T038 - [US5] Intégrer appel à `scripts/drift/check-drift.sh` avec spinner
- [ ] T039 - [US5] Afficher rapport drift (conforme ou liste ressources en drift)
- [ ] T040 - [P] [US5] Créer `tests/tui/test_maintenance.bats`

**Checkpoint** : US5 fonctionnelle.

---

## Phase 7 : US6 - Disaster Recovery (P2)

**Objectif** : Restaurer VMs ou tfstate depuis les sauvegardes

**Test indépendant** : Lister backups → sélectionner → restaurer avec confirmation

### Implémentation US6

- [ ] T041 - [US6] Créer `scripts/tui/menus/disaster.sh` (structure menu DR)
- [ ] T042 - [US6] Implémenter "Lister sauvegardes VM" avec tableau (date, taille, VM)
- [ ] T043 - [US6] Implémenter "Restaurer VM" avec appel `restore-vm.sh` + confirmation
- [ ] T044 - [US6] Implémenter "Lister backups tfstate" par environnement
- [ ] T045 - [US6] Implémenter "Restaurer tfstate" avec appel `restore-tfstate.sh` + confirmation
- [ ] T046 - [US6] Implémenter "Vérifier intégrité backups" avec appel `verify-backups.sh`
- [ ] T047 - [US6] Afficher instructions manuelles en cas d'échec
- [ ] T048 - [P] [US6] Créer `tests/tui/test_disaster.bats`

**Checkpoint** : US6 fonctionnelle.

---

## Phase 8 : US7 - Services (P2)

**Objectif** : Activer/désactiver et démarrer/arrêter les services optionnels

**Test indépendant** : Voir état services → désactiver Harbor → vérifier tfvars mis à jour

### Implémentation US7

- [ ] T049 - [US7] Créer `scripts/tui/menus/services.sh` (structure menu services)
- [ ] T050 - [US7] Implémenter liste services avec état (activé dans tfvars, running)
- [ ] T051 - [US7] Implémenter "Activer/Désactiver" service (modifie tfvars)
- [ ] T052 - [US7] Proposer terraform apply après modification tfvars
- [ ] T053 - [US7] Implémenter "Démarrer/Arrêter" service via SSH (docker compose/systemctl)
- [ ] T054 - [US7] Afficher nouvel état après modification
- [ ] T055 - [P] [US7] Créer `tests/tui/test_services.bats`

**Checkpoint** : US7 fonctionnelle.

---

## Phase 9 : US8 - Post-install Proxmox (P3)

**Objectif** : Assistant guidé pour configurer un nouveau serveur Proxmox

**Test indépendant** : Lancer wizard → suivre étapes → voir résumé final avec tokens

### Implémentation US8

- [ ] T056 - [US8] Créer `scripts/tui/menus/setup.sh` (structure wizard)
- [ ] T057 - [US8] Implémenter wizard multi-étapes avec progression
- [ ] T058 - [US8] Intégrer appel à `post-install-proxmox.sh` par étape
- [ ] T059 - [US8] Permettre de passer les étapes optionnelles avec explication
- [ ] T060 - [US8] Afficher résumé final avec tokens, URLs, infos à noter
- [ ] T061 - [P] [US8] Créer `tests/tui/test_setup.bats`

**Checkpoint** : US8 fonctionnelle.

---

## Phase 10 : US9 - SSH Keys (P3)

**Objectif** : Ajouter ou révoquer des clés SSH sur les VMs

**Test indépendant** : Ajouter clé → vérifier présence sur VMs ciblées

### Implémentation US9

- [ ] T062 - [US9] Ajouter sous-menu "Gérer clés SSH" dans `menus/lifecycle.sh`
- [ ] T063 - [US9] Implémenter "Ajouter clé" avec input chemin .pub + validation
- [ ] T064 - [US9] Implémenter "Révoquer clé" avec sélection fingerprint
- [ ] T065 - [US9] Intégrer appel à `scripts/lifecycle/rotate-ssh-keys.sh`
- [ ] T066 - [P] [US9] Ajouter tests SSH keys dans `tests/tui/test_lifecycle.bats`

**Checkpoint** : US9 fonctionnelle.

---

## Phase 11 : Polish & Documentation

**Objectif** : Finalisation, documentation, validation critères de succès

- [ ] T067 - [P] Créer `scripts/tui/README.md` (documentation utilisateur TUI)
- [ ] T068 - [P] Mettre à jour `scripts/README.md` avec section TUI
- [ ] T069 - [P] Tests d'intégration end-to-end
- [ ] T070 - Refactoring si code dupliqué identifié
- [ ] T071 - Validation CS-001: Temps démarrage < 2s
- [ ] T072 - Validation CS-002: Navigation ≤ 3 clics
- [ ] T073 - Validation CS-003: 100% confirmations destructives
- [ ] T074 - Validation CS-004: Health check < 30s (10 VMs)
- [ ] T075 - Validation CS-005: Zéro secret exposé (audit)
- [ ] T076 - Validation CS-006: Terminal 80x24 minimum
- [ ] T077 - Code review final

**Checkpoint** : Tous les critères de succès validés, documentation complète.

---

## Dépendances et Ordre d'Exécution

### Dépendances entre phases

```
Phase 1 (Fondation)
     │
     ├──▶ Phase 2 (US1 - Status)     🎯 MVP
     │
     ├──▶ Phase 3 (US2 - Snapshots)  🎯 MVP
     │
     └──▶ Phase 4 (US3 - Terraform)  🎯 MVP

Phases 2, 3, 4 complètes
     │
     ├──▶ Phase 5 (US4 - Deploy)
     │
     ├──▶ Phase 6 (US5 - Drift)
     │
     ├──▶ Phase 7 (US6 - DR)
     │
     └──▶ Phase 8 (US7 - Services)

Phases 5-8 complètes
     │
     ├──▶ Phase 9 (US8 - Setup)
     │
     └──▶ Phase 10 (US9 - SSH)

Toutes phases ──▶ Phase 11 (Polish)
```

### Dépendances entre user stories

| Story | Peut commencer après | Dépendances |
|-------|---------------------|-------------|
| US1 (P1) | Phase 1 (Fondation) | Aucune autre story |
| US2 (P1) | Phase 1 (Fondation) | Aucune autre story |
| US3 (P1) | Phase 1 (Fondation) | Aucune autre story |
| US4 (P2) | Phase 1 (Fondation) | Aucune autre story |
| US5 (P2) | Phase 1 (Fondation) | Aucune autre story |
| US6 (P2) | Phase 1 (Fondation) | Aucune autre story |
| US7 (P2) | Phase 1 (Fondation) | Utilise menu Terraform (US3) |
| US8 (P3) | Phase 1 (Fondation) | Aucune autre story |
| US9 (P3) | Phase 3 (US2) | Partage `menus/lifecycle.sh` |

### Opportunités de parallélisation

- **Phase 1** : T002 et T003 en parallèle (fichiers indépendants)
- **Après Phase 1** : US1, US2, US3 peuvent démarrer en parallèle
- **Après Phase 4** : US4, US5, US6, US7 peuvent démarrer en parallèle
- **Phase 11** : T067, T068, T069 en parallèle

---

## Stratégie d'Implémentation

### MVP First (Recommandé)

1. **Phase 1** : Fondation complète
2. **Phase 2** : US1 - Status/Health
3. **Phase 3** : US2 - Snapshots
4. **Phase 4** : US3 - Terraform
5. **STOP** : Valider MVP, démo, feedback

→ **Livrable MVP** : TUI fonctionnel avec 3 fonctions essentielles

### Livraison Incrémentale (Post-MVP)

6. **Phase 5-8** : P2 stories en parallèle
7. **Phase 9-10** : P3 stories
8. **Phase 11** : Polish

---

## Récapitulatif des tâches

| Phase | Nb tâches | User Stories | Priorité |
|-------|-----------|--------------|----------|
| Phase 1 | 8 | Fondation | Bloquant |
| Phase 2 | 7 | US1 | P1 MVP |
| Phase 3 | 7 | US2 | P1 MVP |
| Phase 4 | 8 | US3 | P1 MVP |
| Phase 5 | 5 | US4 | P2 |
| Phase 6 | 5 | US5 | P2 |
| Phase 7 | 8 | US6 | P2 |
| Phase 8 | 7 | US7 | P2 |
| Phase 9 | 6 | US8 | P3 |
| Phase 10 | 5 | US9 | P3 |
| Phase 11 | 11 | Polish | Final |
| **Total** | **77** | **9 US** | |

---

## Notes

- MVP = 30 tâches (Phases 1-4)
- Chaque US testable indépendamment avant de passer à la suivante
- Tests BATS à chaque phase
- Commit après chaque tâche ou groupe logique

**À éviter**:
- Modifier les scripts existants (wrappers uniquement)
- Tâches sans chemin de fichier
- Conflits sur le même fichier (menus séparés)

---

**Version**: 1.0 | **Créé**: 2026-02-05
