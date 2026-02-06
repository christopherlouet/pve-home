# ADR-004: Tests BATS par analyse statique

## Statut

Accepted

## Contexte

Les scripts shell (restore, lifecycle, health, drift, TUI) dependent d'infrastructure reelle (SSH, Proxmox API, mc client, gum). Les tester de maniere end-to-end necessite un environnement complet.

## Decision

Utiliser **BATS** (Bash Automated Testing System) avec une approche d'**analyse statique** (grep-based) pour tester les scripts sans infrastructure :

- Verifier la presence de fonctions et variables attendues
- Valider la structure (shebang, set -euo pipefail, options)
- Tester les patterns de securite (SHA256, credentials)
- Verifier la coherence des templates (docker-compose, cloud-init)

1023 tests BATS repartis en 7 domaines : TUI (439), restore (226), scripts (211), lifecycle (74), root (37), health (22), drift (14).

## Consequences

### Positif

- **Zero infrastructure requise** : Tests executables partout (local, CI)
- **Rapide** : 1023 tests en < 30 secondes
- **Bonne couverture** : Detecte les regressions structurelles (fonctions manquantes, options supprimees)
- **CI integration** : Shellcheck + BATS dans le meme job

### Negatif

- **Pas de test comportemental** : Ne verifie pas que les scripts fonctionnent reellement
- **Faux positif possible** : Un grep peut matcher du code commente
- **Maintenance** : Les tests doivent etre mis a jour si la structure des scripts change

## Alternatives considerees

1. **Tests E2E avec infra reelle** : Rejete (trop lent, couteux, fragile)
2. **Mocking bash avec bats-mock** : Partiellement utilise, mais complexe pour les cas SSH
3. **Pas de tests shell** : Rejete (les scripts sont critiques pour les operations)
