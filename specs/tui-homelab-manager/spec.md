# Spécification : TUI Homelab Manager

**Branche**: `feature/tui-homelab-manager`
**Date**: 2026-02-05
**Statut**: Clarifié

## Résumé

Un gestionnaire interactif en ligne de commande qui centralise toutes les opérations d'administration du homelab Proxmox en un point d'entrée unique. L'utilisateur navigue dans des menus visuels pour vérifier l'état de son infrastructure, gérer les machines virtuelles, déployer des configurations et récupérer après un incident, sans avoir à mémoriser les commandes individuelles.

---

## User Stories (prioritisées)

### US1 - Voir l'état de santé du homelab (Priorité: P1) 🎯 MVP

**En tant que** administrateur du homelab
**Je veux** voir en un coup d'œil l'état de santé de toute mon infrastructure
**Afin de** détecter rapidement les problèmes avant qu'ils n'impactent mes services

**Pourquoi P1**: La visibilité est la base de toute administration. Sans savoir ce qui fonctionne ou non, impossible de prendre des décisions éclairées.

**Test indépendant**: Lancer le TUI, sélectionner "Status", vérifier que tous les composants sont listés avec leur état (OK/WARN/FAIL).

**Critères d'acceptation**:

1. **Étant donné** que je suis dans le menu principal, **Quand** je sélectionne "Status/Health", **Alors** je vois l'état de chaque environnement (prod, lab, monitoring)
2. **Étant donné** que le health check s'exécute, **Quand** une VM est inaccessible, **Alors** elle apparaît en rouge avec le détail du problème
3. **Étant donné** que le health check est terminé, **Quand** je reviens au menu, **Alors** un résumé (X/Y composants sains) reste visible
4. **Étant donné** que je veux plus de détails, **Quand** je sélectionne un composant en erreur, **Alors** je vois les informations de diagnostic

---

### US2 - Gérer les snapshots des VMs (Priorité: P1) 🎯 MVP

**En tant que** administrateur du homelab
**Je veux** créer, lister et restaurer des snapshots depuis une interface guidée
**Afin de** pouvoir revenir en arrière facilement avant/après des modifications risquées

**Pourquoi P1**: Les snapshots sont le filet de sécurité essentiel. Les commandes manuelles sont source d'erreurs (mauvais VMID, mauvais nom de snapshot).

**Test indépendant**: Créer un snapshot via le TUI, le retrouver dans la liste, le restaurer, vérifier que la VM est revenue à l'état précédent.

**Critères d'acceptation**:

1. **Étant donné** que je suis dans le menu "Lifecycle", **Quand** je choisis "Créer un snapshot", **Alors** je peux sélectionner une VM dans une liste et nommer le snapshot
2. **Étant donné** qu'une VM a des snapshots, **Quand** je liste les snapshots, **Alors** je vois le nom, la date et la taille de chaque snapshot
3. **Étant donné** que je veux restaurer un snapshot, **Quand** je confirme la restauration, **Alors** une demande de confirmation explicite apparaît avec le nom de la VM et du snapshot
4. **Étant donné** que la restauration est en cours, **Quand** l'opération se termine, **Alors** un message de succès ou d'erreur est affiché

---

### US3 - Exécuter Terraform sur un environnement (Priorité: P1) 🎯 MVP

**En tant que** administrateur du homelab
**Je veux** lancer Terraform plan/apply sur un environnement depuis le TUI
**Afin de** appliquer des changements d'infrastructure de manière contrôlée et visuelle

**Pourquoi P1**: Terraform est le cœur de l'infrastructure as code. Pouvoir l'exécuter sans quitter le TUI évite les erreurs de répertoire et de contexte.

**Test indépendant**: Sélectionner un environnement, lancer "plan", voir le diff, confirmer ou annuler.

**Critères d'acceptation**:

1. **Étant donné** que je suis dans le menu "Terraform", **Quand** je sélectionne un environnement (prod/lab/monitoring), **Alors** je vois les options plan/apply/output
2. **Étant donné** que je lance un plan, **Quand** des changements sont détectés, **Alors** le diff est affiché de manière lisible (ajouts en vert, suppressions en rouge)
3. **Étant donné** que je veux appliquer les changements, **Quand** je confirme l'apply, **Alors** une confirmation explicite avec résumé des changements est demandée
4. **Étant donné** qu'une erreur Terraform survient, **Quand** l'opération échoue, **Alors** le message d'erreur complet est affiché

---

### US4 - Déployer les scripts sur la VM monitoring (Priorité: P2)

**En tant que** administrateur du homelab
**Je veux** déployer les scripts et timers sur la VM monitoring en un clic
**Afin de** maintenir les outils d'automatisation à jour sans connexion SSH manuelle

**Pourquoi P2**: Important pour la maintenance, mais moins fréquent que les opérations quotidiennes.

**Test indépendant**: Lancer le déploiement, vérifier que les scripts sont présents sur la VM monitoring, que les timers sont actifs.

**Critères d'acceptation**:

1. **Étant donné** que je suis dans le menu "Déploiement", **Quand** je sélectionne "Déployer scripts", **Alors** je vois un résumé de ce qui sera déployé
2. **Étant donné** que le déploiement est en cours, **Quand** chaque étape se termine, **Alors** une progression visuelle indique l'avancement
3. **Étant donné** que le déploiement est terminé, **Quand** je consulte le résultat, **Alors** je vois le statut de chaque composant déployé (scripts, tfvars, timers)

---

### US5 - Détecter le drift d'infrastructure (Priorité: P2)

**En tant que** administrateur du homelab
**Je veux** vérifier si l'infrastructure réelle correspond à ma configuration Terraform
**Afin de** détecter les modifications manuelles non tracées et maintenir la cohérence

**Pourquoi P2**: Important pour la gouvernance, mais exécuté moins souvent (hebdomadaire ou après incidents).

**Test indépendant**: Lancer la détection de drift, voir le rapport des différences entre l'état déclaré et l'état réel.

**Critères d'acceptation**:

1. **Étant donné** que je suis dans le menu "Maintenance", **Quand** je sélectionne "Détecter le drift", **Alors** je peux choisir un environnement ou tous
2. **Étant donné** qu'un drift est détecté, **Quand** le rapport s'affiche, **Alors** les ressources en drift sont listées avec la nature du changement
3. **Étant donné** qu'aucun drift n'est détecté, **Quand** le rapport s'affiche, **Alors** un message de confirmation "Infrastructure conforme" apparaît

---

### US6 - Restaurer après un incident (Priorité: P2)

**En tant que** administrateur du homelab
**Je veux** restaurer des VMs ou l'état Terraform depuis les sauvegardes
**Afin de** récupérer rapidement après un incident majeur

**Pourquoi P2**: Critique en cas de sinistre, mais les incidents sont rares. Le TUI guide dans un moment de stress.

**Test indépendant**: Simuler un scénario de restauration, sélectionner une sauvegarde, restaurer, vérifier le retour à l'état normal.

**Critères d'acceptation**:

1. **Étant donné** que je suis dans le menu "Disaster Recovery", **Quand** je sélectionne "Restaurer VM", **Alors** je vois la liste des sauvegardes disponibles avec leur date
2. **Étant donné** que je choisis une sauvegarde, **Quand** je lance la restauration, **Alors** une confirmation avec avertissements clairs est demandée
3. **Étant donné** que je veux restaurer l'état Terraform, **Quand** je liste les backups tfstate, **Alors** je vois les versions disponibles par environnement
4. **Étant donné** que la restauration échoue, **Quand** je consulte le résultat, **Alors** les instructions de récupération manuelle sont affichées

---

### US7 - Gérer les services optionnels (Priorité: P2)

**En tant que** administrateur du homelab
**Je veux** activer/désactiver et démarrer/arrêter les services optionnels (Harbor, Authentik, etc.)
**Afin de** contrôler quels services tournent sans éditer manuellement les fichiers de configuration

**Pourquoi P2**: Complète le menu Terraform avec une interface dédiée aux services. Utile mais pas essentiel pour le premier usage.

**Test indépendant**: Désactiver Harbor via le TUI, vérifier que le conteneur est arrêté et que tfvars est mis à jour.

**Critères d'acceptation**:

1. **Étant donné** que je suis dans le menu "Services", **Quand** je liste les services, **Alors** je vois chaque service avec son état (activé/désactivé, running/stopped)
2. **Étant donné** qu'un service est activé dans tfvars, **Quand** je choisis "Désactiver", **Alors** le tfvars est modifié et Terraform apply est proposé
3. **Étant donné** qu'un service tourne, **Quand** je choisis "Arrêter", **Alors** le service est stoppé sans modifier tfvars (arrêt temporaire)
4. **Étant donné** qu'un service est arrêté, **Quand** je choisis "Démarrer", **Alors** le service redémarre s'il est activé dans tfvars
5. **Étant donné** que je modifie l'état d'un service, **Quand** l'opération se termine, **Alors** le nouvel état est affiché avec confirmation

---

### US8 - Installation guidée de Proxmox (Priorité: P3)

**En tant que** nouvel utilisateur
**Je veux** configurer mon serveur Proxmox fraîchement installé via un assistant
**Afin de** ne pas oublier d'étapes critiques et avoir une configuration standardisée

**Pourquoi P3**: Utilisé une seule fois par serveur. Important pour l'onboarding mais pas pour l'usage quotidien.

**Test indépendant**: Lancer l'assistant sur un Proxmox vierge, suivre les étapes, vérifier que tout est configuré correctement.

**Critères d'acceptation**:

1. **Étant donné** que je lance le TUI sur un nouveau serveur, **Quand** je sélectionne "Installation initiale", **Alors** un assistant étape par étape me guide
2. **Étant donné** que je suis à une étape de l'assistant, **Quand** une étape est optionnelle, **Alors** je peux la passer avec une explication des conséquences
3. **Étant donné** que l'installation est terminée, **Quand** je consulte le résumé, **Alors** je vois les informations importantes à noter (tokens, URLs, mots de passe générés)

---

### US9 - Gérer les clés SSH des VMs (Priorité: P3)

**En tant que** administrateur du homelab
**Je veux** ajouter ou révoquer des clés SSH sur mes VMs depuis le TUI
**Afin de** gérer les accès sans connexion manuelle à chaque machine

**Pourquoi P3**: Opération occasionnelle (arrivée/départ d'un accès). Peut être fait manuellement en cas de besoin.

**Test indépendant**: Ajouter une clé SSH via le TUI, vérifier qu'elle est présente sur les VMs ciblées.

**Critères d'acceptation**:

1. **Étant donné** que je suis dans le menu "Lifecycle", **Quand** je sélectionne "Gérer les clés SSH", **Alors** je peux choisir d'ajouter ou révoquer
2. **Étant donné** que j'ajoute une clé, **Quand** je fournis le chemin du fichier .pub, **Alors** la clé est validée avant déploiement
3. **Étant donné** que je révoque une clé, **Quand** je sélectionne une clé existante, **Alors** elle est retirée de toutes les VMs de l'environnement choisi

---

## Exigences Fonctionnelles

- **EF-001**: Le système DOIT afficher un menu principal avec les catégories : Status, Lifecycle, Terraform, Services, Déploiement, Maintenance, Disaster Recovery
- **EF-002**: Le système DOIT supporter le mode simulation (dry-run) pour toutes les opérations destructives
- **EF-003**: Le système DOIT afficher des confirmations explicites avant toute opération modifiant l'infrastructure
- **EF-004**: Le système DOIT permettre la navigation au clavier (flèches, entrée, échap pour retour)
- **EF-005**: Le système DOIT afficher les logs des opérations en cours avec indicateur de progression
- **EF-006**: Le système DOIT gérer les erreurs gracieusement sans crash, avec message explicatif
- **EF-007**: Le système DOIT fonctionner en mode non-interactif avec arguments en ligne de commande pour l'automatisation
- **EF-008**: Le système DOIT masquer les secrets (tokens, mots de passe) dans les affichages
- **EF-009**: Le système DOIT détecter automatiquement son contexte d'exécution (local/distant) et adapter les chemins des scripts et fichiers de configuration

## Cas Limites (Edge Cases)

- **Connectivité SSH interrompue** : Que se passe-t-il si la connexion SSH est perdue pendant une opération ?
  → Afficher un message d'erreur clair, proposer de réessayer, ne pas laisser d'état inconsistant

- **Environnement non configuré** : Que se passe-t-il si terraform.tfvars n'existe pas pour un environnement ?
  → Afficher un message "Environnement non configuré" et proposer de créer le fichier

- **Aucune VM dans un environnement** : Comportement quand la liste des VMs est vide ?
  → Afficher "Aucune VM trouvée dans cet environnement" au lieu d'une liste vide

- **Espace disque insuffisant** : Lors d'une sauvegarde ou restauration ?
  → Vérifier l'espace avant l'opération, alerter si insuffisant

- **Opération déjà en cours** : Si l'utilisateur relance une opération pendant qu'une autre tourne ?
  → Détecter les verrous et informer que l'opération précédente est en cours

- **Terminal trop petit** : Si la fenêtre est trop petite pour l'affichage ?
  → Afficher un message demandant d'agrandir le terminal ou proposer un mode compact

## Entités Clés

| Entité | Description | Attributs clés |
|--------|-------------|----------------|
| Environnement | Groupe logique de ressources (prod, lab, monitoring) | nom, chemin tfvars, état (configuré/non) |
| VM | Machine virtuelle Proxmox | id, nom, ip, état (running/stopped), environnement |
| Snapshot | Point de restauration d'une VM | nom, date, taille, vm_id |
| Sauvegarde | Archive vzdump d'une VM | fichier, date, type (full/diff), vm_id |
| Opération | Action en cours d'exécution | type, statut, progression, logs |
| Service | Composant optionnel du homelab (Harbor, Authentik, etc.) | nom, activé (tfvars), running (runtime), vm_hôte |

## Critères de Succès (mesurables)

- **CS-001**: Temps de démarrage du TUI inférieur à 2 secondes
- **CS-002**: Navigation vers n'importe quelle fonction en 3 clics maximum depuis le menu principal
- **CS-003**: 100% des opérations destructives requièrent une confirmation explicite
- **CS-004**: Affichage des résultats de health check en moins de 30 secondes pour 10 VMs
- **CS-005**: Zéro secret affiché en clair dans les logs ou l'interface
- **CS-006**: Le TUI fonctionne sans erreur sur un terminal de 80x24 caractères minimum

## Hors Scope (explicitement exclus)

- **Interface web** : Ce projet est un TUI en ligne de commande uniquement
- **Gestion des utilisateurs Proxmox** : Création/modification des comptes utilisateurs
- **Configuration réseau avancée** : VLANs, bridges, firewall Proxmox
- **Monitoring temps réel** : Graphiques, métriques en direct (utiliser Grafana pour ça)
- **Gestion des templates** : Création/modification des templates VM
- **Gestion multi-cluster** : Un seul cluster Proxmox supporté initialement
- **Installation de Proxmox lui-même** : Post-installation seulement, pas l'installation du système

## Hypothèses et Dépendances

### Hypothèses
- L'utilisateur a un accès SSH configuré vers les nœuds Proxmox
- Les fichiers terraform.tfvars existent pour les environnements à gérer
- Le TUI est exécuté depuis un poste ayant accès réseau au homelab
- L'utilisateur comprend les concepts de base : VM, snapshot, Terraform
- Le terminal supporte les couleurs ANSI et l'UTF-8

### Dépendances
- **gum** (Charm) : Bibliothèque TUI pour l'interface interactive
- **Scripts existants** : Réutilisation de `common.sh`, `check-health.sh`, `snapshot-vm.sh`, etc.
- **Terraform** : Installé et configuré sur le poste d'exécution
- **SSH** : Accès configuré vers les VMs et nœuds Proxmox
- **jq** : Pour le parsing JSON des sorties Terraform et API

## Clarifications

### Session 2026-02-05
- **Q: Contexte d'exécution** → **R: Local + Distant (auto-détection)**
  Le TUI détecte automatiquement s'il s'exécute sur le poste de travail ou sur la VM monitoring et adapte les chemins en conséquence.
- **Q: Scope multi-homelab** → **R: Un seul homelab (MVP)**
  Pas de système de profils. Configuration directe pour un seul homelab avec les 3 environnements logiques (prod, lab, monitoring).
- **Q: Opérations longues** → **R: Bloquante avec progression**
  Les opérations longues (Terraform, restauration) bloquent le TUI avec affichage de la progression en temps réel. Pas d'exécution en arrière-plan.
- **Q: Gestion des services (Harbor, Authentik...)** → **R: Toggle IaC + contrôle opérationnel (P2)**
  Le TUI permet à la fois de modifier tfvars (activer/désactiver) avec Terraform apply, ET de démarrer/arrêter les services temporairement via SSH. Ajouté comme US7.

## Points de Clarification

> Toutes les clarifications ont été résolues dans la session du 2026-02-05.

Aucune question en suspens.
