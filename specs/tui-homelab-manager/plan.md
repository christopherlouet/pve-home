# Plan d'implémentation : TUI Homelab Manager

**Branche**: `feature/tui-homelab-manager`
**Date**: 2026-02-05
**Spec**: [spec.md](./spec.md)
**Statut**: Draft

---

## Résumé

Interface TUI interactive en Bash utilisant `gum` (Charm) pour centraliser l'administration du homelab Proxmox. Réutilise les scripts existants (`common.sh`, `check-health.sh`, `snapshot-vm.sh`, etc.) en les encapsulant dans une navigation par menus visuels.

---

## Contexte Technique

| Aspect | Choix | Notes |
|--------|-------|-------|
| **Langage** | Bash 5.x | Cohérent avec les scripts existants |
| **TUI Framework** | gum (Charm) | Menus, confirmations, spinners, input |
| **Dépendances** | jq, terraform, ssh, mc (minio client) | Déjà utilisées par les scripts existants |
| **Tests** | BATS (Bash Automated Testing System) | Framework déjà en place dans `tests/` |
| **Plateforme** | Linux (Ubuntu 22.04+, Debian 12+) | VM monitoring ou poste de travail |

### Contraintes

- Doit fonctionner sur un terminal 80x24 minimum (EF-006)
- Doit masquer les secrets dans tous les affichages (EF-008)
- Auto-détection du contexte local/distant (EF-009)
- Réutilisation maximale de `scripts/lib/common.sh`

### Performance attendue

| Métrique | Cible | Source |
|----------|-------|--------|
| Temps de démarrage | < 2s | CS-001 |
| Health check (10 VMs) | < 30s | CS-004 |
| Navigation | ≤ 3 clics | CS-002 |

---

## Vérification Constitution/Conventions

*GATE: Doit être validé avant de commencer l'implémentation.*

- [ ] Respecte les conventions du projet (voir CLAUDE.md)
- [ ] Cohérent avec l'architecture existante (`scripts/lib/common.sh`)
- [ ] Pas d'over-engineering (menus simples, réutilisation scripts)
- [ ] Tests planifiés (BATS)

---

## Structure du Projet

### Documentation (cette feature)

```
specs/tui-homelab-manager/
├── spec.md           # Spécification fonctionnelle
├── plan.md           # Ce fichier
└── tasks.md          # Découpage en tâches
```

### Code Source

```
scripts/
├── lib/
│   └── common.sh              # (existant) Fonctions partagées
│
├── tui/
│   ├── homelab-manager.sh     # Point d'entrée principal
│   ├── lib/
│   │   ├── tui-common.sh      # Fonctions TUI (wrappers gum)
│   │   ├── tui-config.sh      # Détection contexte, chemins
│   │   └── tui-colors.sh      # Thème et couleurs
│   └── menus/
│       ├── main.sh            # Menu principal
│       ├── status.sh          # [US1] Health check
│       ├── lifecycle.sh       # [US2] Snapshots
│       ├── terraform.sh       # [US3] Terraform operations
│       ├── services.sh        # [US7] Gestion services
│       ├── deploy.sh          # [US4] Déploiement scripts
│       ├── maintenance.sh     # [US5] Drift detection
│       ├── disaster.sh        # [US6] Disaster recovery
│       ├── setup.sh           # [US8] Post-install Proxmox
│       └── ssh-keys.sh        # [US9] Gestion clés SSH
│
├── health/
│   └── check-health.sh        # (existant) - wrapper TUI appelle
├── lifecycle/
│   └── snapshot-vm.sh         # (existant) - wrapper TUI appelle
├── drift/
│   └── check-drift.sh         # (existant) - wrapper TUI appelle
├── restore/
│   └── *.sh                   # (existants) - wrapper TUI appelle
└── deploy.sh                  # (existant) - wrapper TUI appelle

tests/
├── tui/
│   ├── test_homelab-manager.bats   # Tests point d'entrée
│   ├── test_tui-common.bats        # Tests lib TUI
│   └── test_menus.bats             # Tests navigation menus
└── ...                              # Tests existants
```

---

## Fichiers Impactés

### À créer

| Fichier | Responsabilité |
|---------|----------------|
| `scripts/tui/homelab-manager.sh` | Point d'entrée TUI, parsing args, boucle principale |
| `scripts/tui/lib/tui-common.sh` | Wrappers gum (menu, confirm, input, spin, table) |
| `scripts/tui/lib/tui-config.sh` | Détection local/distant, chemins dynamiques |
| `scripts/tui/lib/tui-colors.sh` | Définitions couleurs, thème |
| `scripts/tui/menus/main.sh` | Menu principal (7 catégories) |
| `scripts/tui/menus/status.sh` | Menu Status/Health [US1] |
| `scripts/tui/menus/lifecycle.sh` | Menu Lifecycle (snapshots, SSH) [US2, US9] |
| `scripts/tui/menus/terraform.sh` | Menu Terraform (plan, apply, output) [US3] |
| `scripts/tui/menus/services.sh` | Menu Services (Harbor, Authentik) [US7] |
| `scripts/tui/menus/deploy.sh` | Menu Déploiement [US4] |
| `scripts/tui/menus/maintenance.sh` | Menu Maintenance (drift) [US5] |
| `scripts/tui/menus/disaster.sh` | Menu Disaster Recovery [US6] |
| `scripts/tui/menus/setup.sh` | Assistant post-install [US8] |
| `scripts/tui/menus/ssh-keys.sh` | Gestion clés SSH [US9] |
| `tests/tui/test_homelab-manager.bats` | Tests point d'entrée |
| `tests/tui/test_tui-common.bats` | Tests fonctions TUI |
| `tests/tui/test_menus.bats` | Tests menus |

### À modifier

| Fichier | Modification |
|---------|--------------|
| `scripts/README.md` | Ajouter documentation TUI |
| `scripts/lib/common.sh` | Éventuellement extraire fonctions réutilisables |

### Tests à ajouter

| Fichier | Couverture |
|---------|------------|
| `tests/tui/test_homelab-manager.bats` | Args, help, version, contexte |
| `tests/tui/test_tui-common.bats` | Wrappers gum, fallbacks |
| `tests/tui/test_menus.bats` | Navigation, sélections |

---

## Approche Choisie

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     homelab-manager.sh                          │
│                     (Point d'entrée)                            │
├─────────────────────────────────────────────────────────────────┤
│  • Parse arguments (--help, --version, --dry-run)               │
│  • Vérifie prérequis (gum, jq, terraform, ssh)                  │
│  • Détecte contexte (local/distant)                             │
│  • Lance menu principal ou commande directe                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        tui-common.sh                            │
│                      (Bibliothèque TUI)                         │
├─────────────────────────────────────────────────────────────────┤
│  • tui_menu()      - Wrapper gum choose                         │
│  • tui_confirm()   - Wrapper gum confirm                        │
│  • tui_input()     - Wrapper gum input                          │
│  • tui_spin()      - Wrapper gum spin                           │
│  • tui_table()     - Affichage tableau formaté                  │
│  • tui_banner()    - Header avec status                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  menus/*.sh   │   │  menus/*.sh   │   │  menus/*.sh   │
│  (Status)     │   │  (Lifecycle)  │   │  (Terraform)  │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────────────────────────────────────────────────────┐
│                    Scripts existants                          │
├───────────────────────────────────────────────────────────────┤
│  check-health.sh │ snapshot-vm.sh │ check-drift.sh │ etc.    │
└───────────────────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────────────────┐
│                      common.sh                                 │
│              (Bibliothèque existante)                          │
└───────────────────────────────────────────────────────────────┘
```

### Justification

1. **Réutilisation** : Les scripts existants sont appelés tels quels (wrappers minces)
2. **Séparation** : Chaque menu dans son fichier = maintenabilité
3. **Testabilité** : Fonctions pures dans `tui-common.sh`, mockables
4. **Progressivité** : Chaque US peut être livrée indépendamment

### Alternatives considérées

| Alternative | Pourquoi rejetée |
|-------------|------------------|
| Python + Textual | Plus de dépendances, réécriture des scripts |
| Go + bubbletea | Binaire à distribuer, perte de la réutilisation Bash |
| whiptail/dialog | Moins moderne visuellement, pas de spinner |
| Refactoring complet des scripts | Over-engineering, risque de régression |

---

## Phases d'Implémentation

### Phase 1 : Fondation (bloquant)

**Objectif**: Infrastructure TUI de base, prérequis pour toutes les US

- [ ] T001 - Créer la structure `scripts/tui/` et sous-dossiers
- [ ] T002 - Implémenter `tui-config.sh` (détection contexte, chemins)
- [ ] T003 - Implémenter `tui-colors.sh` (thème, couleurs)
- [ ] T004 - Implémenter `tui-common.sh` (wrappers gum)
- [ ] T005 - Implémenter `homelab-manager.sh` (point d'entrée, args)
- [ ] T006 - Implémenter `menus/main.sh` (menu principal vide)
- [ ] T007 - Tests BATS pour la fondation

**Checkpoint**: TUI démarre, affiche le menu principal, quitte proprement.

### Phase 2 : US1 - Status/Health (P1 MVP) 🎯

**Objectif**: Voir l'état de santé de l'infrastructure

- [ ] T008 - [US1] Implémenter `menus/status.sh`
- [ ] T009 - [US1] Intégrer `check-health.sh` avec affichage TUI
- [ ] T010 - [US1] Affichage détaillé des erreurs
- [ ] T011 - [US1] Tests BATS pour status

**Checkpoint**: US1 fonctionnelle - health check avec couleurs et détails.

### Phase 3 : US2 - Snapshots (P1 MVP) 🎯

**Objectif**: Gérer les snapshots des VMs

- [ ] T012 - [US2] Implémenter `menus/lifecycle.sh` (structure)
- [ ] T013 - [US2] Créer snapshot avec sélection VM
- [ ] T014 - [US2] Lister snapshots avec tableau
- [ ] T015 - [US2] Restaurer snapshot avec confirmation
- [ ] T016 - [US2] Supprimer snapshot avec confirmation
- [ ] T017 - [US2] Tests BATS pour snapshots

**Checkpoint**: US2 fonctionnelle - CRUD snapshots complet.

### Phase 4 : US3 - Terraform (P1 MVP) 🎯

**Objectif**: Exécuter Terraform depuis le TUI

- [ ] T018 - [US3] Implémenter `menus/terraform.sh`
- [ ] T019 - [US3] Sélection environnement (prod/lab/monitoring)
- [ ] T020 - [US3] Terraform plan avec diff coloré
- [ ] T021 - [US3] Terraform apply avec confirmation
- [ ] T022 - [US3] Terraform output
- [ ] T023 - [US3] Tests BATS pour terraform

**Checkpoint**: US3 fonctionnelle - plan/apply/output par environnement.

### Phase 5 : US4 - Déploiement (P2)

**Objectif**: Déployer scripts sur VM monitoring

- [ ] T024 - [US4] Implémenter `menus/deploy.sh`
- [ ] T025 - [US4] Intégrer `deploy.sh` existant
- [ ] T026 - [US4] Affichage progression par étape
- [ ] T027 - [US4] Tests BATS

**Checkpoint**: US4 fonctionnelle.

### Phase 6 : US5 - Drift Detection (P2)

**Objectif**: Détecter le drift infrastructure

- [ ] T028 - [US5] Implémenter `menus/maintenance.sh`
- [ ] T029 - [US5] Intégrer `check-drift.sh`
- [ ] T030 - [US5] Affichage rapport drift
- [ ] T031 - [US5] Tests BATS

**Checkpoint**: US5 fonctionnelle.

### Phase 7 : US6 - Disaster Recovery (P2)

**Objectif**: Restaurer après incident

- [ ] T032 - [US6] Implémenter `menus/disaster.sh`
- [ ] T033 - [US6] Liste sauvegardes vzdump
- [ ] T034 - [US6] Restauration VM avec confirmation
- [ ] T035 - [US6] Restauration tfstate
- [ ] T036 - [US6] Tests BATS

**Checkpoint**: US6 fonctionnelle.

### Phase 8 : US7 - Services (P2)

**Objectif**: Gérer services optionnels (Harbor, Authentik)

- [ ] T037 - [US7] Implémenter `menus/services.sh`
- [ ] T038 - [US7] Liste services avec état (activé/running)
- [ ] T039 - [US7] Toggle tfvars + terraform apply
- [ ] T040 - [US7] Start/stop services via SSH
- [ ] T041 - [US7] Tests BATS

**Checkpoint**: US7 fonctionnelle.

### Phase 9 : US8 - Post-install Proxmox (P3)

**Objectif**: Assistant installation guidée

- [ ] T042 - [US8] Implémenter `menus/setup.sh`
- [ ] T043 - [US8] Intégrer `post-install-proxmox.sh`
- [ ] T044 - [US8] Wizard étape par étape
- [ ] T045 - [US8] Résumé final avec tokens
- [ ] T046 - [US8] Tests BATS

**Checkpoint**: US8 fonctionnelle.

### Phase 10 : US9 - SSH Keys (P3)

**Objectif**: Gérer clés SSH des VMs

- [ ] T047 - [US9] Implémenter `menus/ssh-keys.sh`
- [ ] T048 - [US9] Intégrer `rotate-ssh-keys.sh`
- [ ] T049 - [US9] Ajouter/révoquer clé
- [ ] T050 - [US9] Tests BATS

**Checkpoint**: US9 fonctionnelle.

### Phase 11 : Polish & Documentation

**Objectif**: Finalisation

- [ ] T051 - [P] Documentation README TUI
- [ ] T052 - [P] Tests d'intégration complets
- [ ] T053 - Refactoring si nécessaire
- [ ] T054 - Validation critères de succès (CS-001 à CS-006)

---

## Risques et Mitigations

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| gum non installé | Élevé | Moyenne | Fallback whiptail/dialog ou mode texte |
| Scripts existants incompatibles | Moyen | Faible | Wrappers adaptateurs, pas de modification directe |
| Terminal trop petit | Faible | Moyenne | Détection taille, mode compact |
| Secrets affichés par erreur | Élevé | Faible | Réutiliser `log_secret()` de common.sh |
| Performance health check | Moyen | Faible | Parallélisation déjà en place dans check-health.sh |

---

## Dépendances et Ordre d'Exécution

### Dépendances entre phases

```
Phase 1 (Fondation) ──┬──▶ Phase 2 (US1 - Status)     🎯 MVP
                      │
                      ├──▶ Phase 3 (US2 - Snapshots)  🎯 MVP
                      │
                      └──▶ Phase 4 (US3 - Terraform)  🎯 MVP

Phases 2, 3, 4 ──────────▶ Phase 5 (US4)
                          Phase 6 (US5)
                          Phase 7 (US6)
                          Phase 8 (US7)

Phases 5-8 ──────────────▶ Phase 9 (US8)
                          Phase 10 (US9)

Toutes phases ───────────▶ Phase 11 (Polish)
```

### Tâches parallélisables

- Après Phase 1 : Phases 2, 3, 4 peuvent démarrer en parallèle
- Après Phase 4 : Phases 5, 6, 7, 8 peuvent démarrer en parallèle
- Les tests [P] peuvent tourner en parallèle

---

## Critères de Validation

### Avant de commencer (Gate 1)
- [ ] Spec approuvée (Clarifié ✅)
- [ ] Plan reviewé
- [ ] gum installé sur poste de dev

### Avant chaque merge (Gate 2)
- [ ] Tests BATS passent
- [ ] shellcheck OK
- [ ] Dry-run fonctionne

### Avant déploiement (Gate 3)
- [ ] CS-001: Démarrage < 2s
- [ ] CS-002: Navigation ≤ 3 clics
- [ ] CS-003: 100% confirmations destructives
- [ ] CS-004: Health check < 30s
- [ ] CS-005: Zéro secret exposé
- [ ] CS-006: Terminal 80x24 OK

---

## Notes

- **MVP** = Phases 1-4 (US1, US2, US3) - Livrable fonctionnel minimal
- Le TUI appelle les scripts existants sans les modifier (principe d'encapsulation)
- Utiliser `gum style` pour un affichage cohérent
- Chaque menu retourne au parent avec Échap ou "Retour"

---

**Version**: 1.0 | **Créé**: 2026-02-05 | **Dernière modification**: 2026-02-05
