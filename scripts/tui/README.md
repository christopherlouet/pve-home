# TUI Homelab Manager

Interface Terminal (TUI) interactive pour gérer l'infrastructure Proxmox VE homelab.

## Fonctionnalités

- **Status & Health** : Vue d'ensemble de l'infrastructure, health checks
- **Lifecycle** : Gestion des snapshots et cycle de vie des VMs
- **Terraform** : Plan, Apply, Output avec sélection d'environnement
- **Déploiement** : Déployer scripts et timers sur la VM monitoring
- **Maintenance** : Détection de drift Terraform
- **Disaster Recovery** : Restauration VMs, tfstate, vérification backups
- **Services** : Activer/désactiver, démarrer/arrêter les services
- **Configuration** : Préférences du TUI (couleurs, SSH, Terraform)

## Installation

### Prérequis

- Bash 4.0+
- Terraform >= 1.9
- SSH configuré pour les hôtes Proxmox
- [gum](https://github.com/charmbracelet/gum) (optionnel, fallback bash disponible)

### Installation de gum (recommandé)

```bash
# Ubuntu/Debian
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum

# macOS
brew install gum
```

## Utilisation

### Mode interactif

```bash
# Lancer le TUI
./scripts/tui/tui.sh

# Avec un environnement spécifique
./scripts/tui/tui.sh --env prod

# Sans couleurs (pour les terminaux limités)
./scripts/tui/tui.sh --no-color

# Mode simulation (pas de modifications)
./scripts/tui/tui.sh --dry-run
```

### Commandes directes

```bash
# Afficher le statut
./scripts/tui/tui.sh status

# Exécuter terraform plan
./scripts/tui/tui.sh terraform plan

# Vérifier le drift
./scripts/tui/tui.sh drift

# Lister les services
./scripts/tui/tui.sh services

# Afficher la configuration
./scripts/tui/tui.sh config
```

### Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Afficher l'aide |
| `-v, --version` | Afficher la version |
| `-e, --env ENV` | Spécifier l'environnement (prod, lab, monitoring) |
| `-n, --no-color` | Désactiver les couleurs |
| `-d, --dry-run` | Mode simulation |
| `--no-gum` | Forcer le mode sans gum (fallback bash) |

## Navigation

### Raccourcis clavier

| Touche | Action |
|--------|--------|
| `q` | Quitter / Retour |
| `?` | Afficher l'aide |
| `j` / `↓` | Descendre |
| `k` / `↑` | Monter |
| `h` / `←` | Gauche |
| `l` / `→` | Droite |
| `1-9` | Sélection rapide |
| `/` | Recherche |
| `r` | Rafraîchir |

### Navigation vim-like

Le TUI supporte la navigation vim-like par défaut :
- `j/k` pour haut/bas
- `h/l` pour gauche/droite
- `g` pour aller au début
- `G` pour aller à la fin

## Structure

```
scripts/tui/
├── tui.sh                    # Point d'entrée principal
├── lib/
│   ├── tui-colors.sh         # Couleurs et styles ANSI
│   ├── tui-config.sh         # Configuration et variables
│   ├── tui-common.sh         # Fonctions communes (menus, logs)
│   └── tui-keyboard.sh       # Navigation clavier avancée
└── menus/
    ├── main.sh               # Menu principal
    ├── status.sh             # Status & Health
    ├── lifecycle.sh          # Snapshots & Lifecycle
    ├── terraform.sh          # Opérations Terraform
    ├── deploy.sh             # Déploiement
    ├── maintenance.sh        # Drift detection
    ├── disaster.sh           # Disaster Recovery
    ├── services.sh           # Gestion des services
    └── config.sh             # Configuration TUI
```

## Menus

### 1. Status & Health

- Vue d'ensemble de l'infrastructure
- Health checks des VMs et services
- Métriques rapides (CPU, RAM, disque)

### 2. Lifecycle

- Créer/lister/restaurer/supprimer des snapshots
- Nettoyage des snapshots expirés
- Gestion du cycle de vie des VMs lab

### 3. Terraform

- `terraform plan` avec aperçu des changements
- `terraform apply` avec confirmation
- `terraform output` pour voir les outputs
- Sélection d'environnement (prod, lab, monitoring)

### 4. Déploiement

- Déployer scripts sur la VM monitoring
- Mode dry-run pour prévisualiser
- Synchronisation des tfvars et timers systemd

### 5. Maintenance

- Détection de drift Terraform
- Vérification par environnement ou global
- Rapport détaillé des ressources en drift

### 6. Disaster Recovery

- Lister les sauvegardes VM disponibles
- Restaurer une VM depuis vzdump
- Lister/restaurer les versions tfstate
- Vérifier l'intégrité des sauvegardes

### 7. Services

- Lister les services avec leur état
- Activer/désactiver un service (modification tfvars)
- Démarrer/arrêter/redémarrer via SSH
- Proposition de terraform apply après modification

### 8. Configuration

- Environnement par défaut
- Paramètres d'affichage (couleurs, unicode)
- Paramètres SSH (timeout, mode batch)
- Paramètres Terraform (auto-init, auto-approve)
- Niveau de log

## Configuration

Le TUI utilise un fichier de configuration YAML (`.tui-config.yaml`) :

```yaml
# Environnement par défaut
default_environment: "monitoring"

# Paramètres SSH
ssh:
  timeout: 10
  batch_mode: true

# Paramètres d'affichage
display:
  colors: true
  unicode: true
  animations: true

# Paramètres Terraform
terraform:
  auto_init: true
  auto_approve: false
```

## Tests

Le TUI est couvert par **439 tests BATS** :

```bash
# Tous les tests TUI
bats tests/tui/

# Par module
bats tests/tui/test_common.bats      # Fonctions communes
bats tests/tui/test_status.bats      # Menu status
bats tests/tui/test_lifecycle.bats   # Menu lifecycle
bats tests/tui/test_terraform.bats   # Menu terraform
bats tests/tui/test_deploy_menu.bats # Menu deploy
bats tests/tui/test_maintenance.bats # Menu maintenance
bats tests/tui/test_disaster.bats    # Menu disaster
bats tests/tui/test_services.bats    # Menu services
bats tests/tui/test_config_menu.bats # Menu config
bats tests/tui/test_keyboard.bats    # Navigation clavier
bats tests/tui/test_integration.bats # Intégration
```

## Développement

### Ajouter un nouveau menu

1. Créer le fichier `menus/nouveau.sh` avec la fonction `menu_nouveau()`
2. Ajouter le source dans `menus/main.sh`
3. Ajouter l'option dans le menu principal
4. Créer les tests dans `tests/tui/test_nouveau.bats`

### Conventions

- Toutes les fonctions TUI sont préfixées par `tui_` ou appartiennent à un module
- Les couleurs utilisent les variables de `tui-colors.sh`
- Le mode `--dry-run` doit être respecté pour toutes les opérations destructives
- Les confirmations utilisent `tui_confirm()` avant les opérations critiques

## Intégration avec les scripts existants

Le TUI s'intègre avec les scripts d'opération existants :

| Menu TUI | Script sous-jacent |
|----------|-------------------|
| Terraform | `terraform` (direct) |
| Deploy | `scripts/deploy.sh` |
| Drift | `scripts/drift/check-drift.sh` |
| Health | `scripts/health/check-health.sh` |
| Snapshots | `scripts/lifecycle/snapshot-vm.sh` |
| Restore VM | `scripts/restore/restore-vm.sh` |
| Restore tfstate | `scripts/restore/restore-tfstate.sh` |
| Verify backups | `scripts/restore/verify-backups.sh` |

## Changelog

### v1.0.0

- Implémentation complète du TUI avec 11 phases
- 439 tests BATS
- Support gum avec fallback bash
- Navigation vim-like
- Configuration persistante
