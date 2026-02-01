# Bibliothèque commune pour les scripts de restauration

Ce répertoire contient les fonctions partagées utilisées par tous les scripts de restauration dans `scripts/restore/`.

## Fichiers

- **`common.sh`** : Bibliothèque de fonctions utilitaires

## Usage

```bash
#!/bin/bash
source "$(dirname "$0")/../lib/common.sh"

# Les fonctions sont maintenant disponibles
log_info "Demarrage du script..."
check_prereqs || exit 1

# Parsing des arguments communs
parse_common_args "$@"

# Mode dry-run
dry_run echo 'Cette commande sera executee seulement si DRY_RUN=false'
```

## Fonctions disponibles

### Logging

- `log_info <message>` : Affiche un message d'information (bleu)
- `log_success <message>` : Affiche un message de succès (vert)
- `log_warn <message>` : Affiche un avertissement (jaune)
- `log_error <message>` : Affiche une erreur (rouge)

### Confirmation et arguments

- `confirm <message>` : Demande confirmation à l'utilisateur (retourne 0 si oui, 1 si non). Automatiquement oui si `FORCE_MODE=true`
- `parse_common_args "$@"` : Parse les arguments `--dry-run`, `--force`, `--help`
- `show_help` : Affiche l'aide générique (à surcharger dans vos scripts)

### Vérification des prérequis

- `check_command <cmd>` : Vérifie qu'une commande existe (retourne 0 si présente)
- `check_prereqs` : Vérifie que tous les outils requis sont installés (ssh, terraform, mc, jq)
- `check_ssh_access <node>` : Vérifie la connectivité SSH vers un nœud
- `check_disk_space <node> <storage> [required_mb]` : Vérifie l'espace disque disponible

### SSH

- `ssh_exec <node> <command>` : Execute une commande SSH sur un nœud (supporte dry-run)

### Terraform.tfvars

- `parse_tfvars <file> <key>` : Extrait une valeur depuis un fichier tfvars
- `get_pve_node [tfvars_file]` : Récupère le nom du nœud PVE
- `get_pve_ip [tfvars_file]` : Récupère l'IP du nœud PVE

### Dry-run et sauvegarde

- `dry_run <command>` : Execute une commande seulement si `DRY_RUN=false`, sinon affiche la commande
- `create_backup_point <component> [backup_dir]` : Crée un point de sauvegarde avant une opération destructive

## Variables globales

Après `source common.sh`, les variables suivantes sont disponibles :

- `DRY_RUN` : `true` ou `false` (défaut: `false`)
- `FORCE_MODE` : `true` ou `false` (défaut: `false`)
- `SCRIPT_DIR` : Chemin absolu du répertoire contenant `common.sh`
- `RED`, `GREEN`, `YELLOW`, `BLUE`, `NC` : Codes couleur ANSI

## Tests

Les tests BATS sont disponibles dans `tests/restore/test_common.bats` :

```bash
# Lancer les tests
bats tests/restore/test_common.bats

# Avec verbose
bats -t tests/restore/test_common.bats
```

Tous les tests doivent passer (29 tests).

## Conventions

- Utilise `set -euo pipefail` pour un comportement strict
- Toutes les fonctions supportent le mode `DRY_RUN`
- Les fonctions retournent 0 en cas de succès, 1 en cas d'erreur
- Les messages d'erreur sont écrits sur stderr via `log_error`
- Pas de `sudo` : les scripts sont exécutés en tant qu'utilisateur normal, SSH en root vers le nœud PVE

## Validation

Shellcheck doit passer sans erreur :

```bash
shellcheck scripts/lib/common.sh
```
