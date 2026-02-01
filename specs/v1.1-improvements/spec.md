# Specification : Ameliorations v1.1 - Fiabilite et observabilite

**Branche**: `feature/v1.1-improvements`
**Date**: 2026-02-01
**Statut**: Draft

## Resume

Le homelab Proxmox gere par Terraform est fonctionnel et teste (v1.0.0) mais presente trois faiblesses identifiees lors de l'evaluation du projet : le monitoring ne detecte pas certaines pannes courantes (services crashes, charge systeme), les modules Terraform n'ont pas de filet de securite contre la reintroduction de bugs corriges, et les scripts d'operations echouent definitivement a la premiere coupure reseau au lieu de reessayer. Cette feature corrige ces trois points pour ameliorer la fiabilite globale de l'infrastructure.

---

## User Stories (prioritisees)

### US1 - Alertes de monitoring complementaires (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** etre alerte quand un service systemd crash, quand la charge systeme est anormalement elevee, quand des erreurs reseau apparaissent, ou quand Prometheus lui-meme dysfonctionne
**Afin de** detecter les problemes avant qu'ils n'impactent les services et intervenir rapidement

**Pourquoi P1**: Le monitoring est en place mais sous-exploite. Des pannes courantes (service crash, surcharge CPU soutenue, erreurs reseau) passent inapercues. Ces alertes comblent les trous les plus critiques.

**Test independant**: Verifier que le fichier d'alertes contient les nouvelles regles, que leur syntaxe est valide, et que les expressions PromQL referent des metriques existantes.

**Criteres d'acceptation**:

1. **Etant donne** un service systemd en etat "failed" sur un hote monitore, **Quand** l'etat persiste plus de 5 minutes, **Alors** une alerte "SystemdServiceFailed" de severite warning est declenchee.
2. **Etant donne** une charge systeme (load average 15 min) superieure a 2x le nombre de CPUs, **Quand** cette surcharge persiste 10 minutes, **Alors** une alerte "HighLoadAverage" de severite warning est declenchee.
3. **Etant donne** des erreurs reseau (reception + emission) depassant 10 par seconde sur une interface, **Quand** cette situation persiste 5 minutes, **Alors** une alerte "HighNetworkErrors" de severite warning est declenchee.
4. **Etant donne** des echecs d'evaluation de regles Prometheus, **Quand** au moins un echec survient en 5 minutes, **Alors** une alerte "PrometheusRuleEvaluationFailures" de severite warning est declenchee.
5. **Etant donne** les 26 alertes au total (21 existantes + 5 nouvelles en comptant aussi NodeFilesystemAlmostOutOfInodes), **Quand** le systeme de monitoring est en fonctionnement, **Alors** toutes les regles sont chargees sans erreur par Prometheus.

---

### US2 - Tests de non-regression pour tous les modules (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** que chaque module Terraform dispose de tests specifiques documentant les bugs passes et garantissant qu'ils ne reapparaissent pas
**Afin de** pouvoir modifier ou refactorer les modules en confiance, sachant que les bugs corriges sont proteges par des tests

**Pourquoi P1**: Seul le module VM a des tests de non-regression. Les 4 autres modules (LXC, Backup, Minio, Monitoring-stack) n'ont aucune protection contre la reintroduction de bugs historiques (tags, mount_point size, retention format...).

**Test independant**: Executer `terraform test` sur chaque module et verifier que les fichiers regression.tftest.hcl passent tous.

**Criteres d'acceptation**:

1. **Etant donne** le module LXC, **Quand** les tests s'executent, **Alors** les regressions suivantes sont couvertes : preservation des tags, description par defaut "Managed by Terraform", mises a jour de securite conditionnelles au type d'OS.
2. **Etant donne** le module Backup, **Quand** les tests s'executent, **Alors** les regressions suivantes sont couvertes : format de retention (triggers corrects), VMIDs vide produit une chaine vide, mode desactive produit la bonne commande.
3. **Etant donne** le module Minio, **Quand** les tests s'executent, **Alors** les regressions suivantes sont couvertes : taille mount_point avec suffixe "G", preservation des tags, presence des 4 outputs.
4. **Etant donne** le module Monitoring-stack, **Quand** les tests s'executent, **Alors** les regressions suivantes sont couvertes : controleur SCSI virtio-scsi-single, snippet cloud-init sur datastore "local", cle SSH ED25519.
5. **Etant donne** les 5 modules au total, **Quand** la suite de tests complete s'execute, **Alors** 100% des modules ont un fichier regression.tftest.hcl et tous les tests passent.

---

### US3 - Resilience des scripts aux coupures reseau (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** que les scripts d'operations (deploy, health check, drift detection, lifecycle) reessaient automatiquement les connexions SSH echouees avec un delai croissant
**Afin de** eviter les faux positifs et les echecs definitifs causes par des micro-coupures reseau temporaires

**Pourquoi P2**: Les scripts fonctionnent correctement en conditions normales. Le retry est une amelioration de fiabilite pour les cas degrades (reboot node, latence reseau, charge elevee). Moins critique que les alertes et tests.

**Test independant**: Simuler un echec de commande suivi d'un succes, verifier que la fonction de retry reessaie le bon nombre de fois avec un delai croissant.

**Criteres d'acceptation**:

1. **Etant donne** une fonction de retry disponible dans la bibliotheque partagee, **Quand** une commande echoue puis reussit a la 2eme tentative, **Alors** la fonction retourne succes et log les tentatives intermediaires.
2. **Etant donne** une commande qui echoue a toutes les tentatives (3 par defaut), **Quand** le nombre maximum est atteint, **Alors** la fonction retourne une erreur avec un message clair incluant le nombre de tentatives.
3. **Etant donne** le delai entre les tentatives, **Quand** la commande echoue, **Alors** le delai double a chaque tentative (backoff exponentiel : 1s, 2s, 4s).
4. **Etant donne** le mode dry-run actif, **Quand** une commande avec retry est executee, **Alors** la commande n'est pas reellement executee et aucun retry n'a lieu.
5. **Etant donne** la verification d'acces SSH, **Quand** le premier essai de connexion echoue, **Alors** la verification reessaie automatiquement (3 tentatives) avant de declarer l'echec.

---

## Exigences Fonctionnelles

- **EF-001**: Le systeme DOIT fournir au moins 25 regles d'alerte Prometheus couvrant : hotes, Proxmox, Prometheus, backups, drift, health, lifecycle
- **EF-002**: Chaque alerte DOIT avoir un nom, une expression, une duree, une severite (info/warning/critical), un resume et une description
- **EF-003**: Les nouvelles alertes DOIVENT utiliser des metriques deja collectees par les exporteurs en place (node-exporter, pve-exporter, Prometheus)
- **EF-004**: Chaque module Terraform DOIT avoir un fichier de test de non-regression
- **EF-005**: Chaque test de non-regression DOIT documenter en commentaire la version du fix original
- **EF-006**: Les tests de non-regression DOIVENT s'executer en mode plan (sans deploiement reel)
- **EF-007**: La bibliotheque de scripts partagee DOIT fournir une fonction de retry avec backoff exponentiel
- **EF-008**: La fonction de retry DOIT etre compatible avec le mode dry-run existant
- **EF-009**: La verification d'acces SSH DOIT utiliser le retry automatiquement
- **EF-010**: Les tests BATS existants DOIVENT etre etendus pour couvrir les nouvelles fonctions de retry

---

## Cas Limites (Edge Cases)

- Que se passe-t-il si une alerte reference une metrique absente (exporteur pas installe) ? -> L'alerte reste silencieuse (pas de faux positif), Prometheus log un warning
- Que se passe-t-il si un test de regression echoue apres un upgrade du provider Proxmox ? -> Le test detecte le changement, l'administrateur doit investiguer si c'est une regression ou un changement attendu
- Que se passe-t-il si le retry boucle indefiniment ? -> Le nombre maximum de tentatives (3 par defaut) empeche les boucles infinies
- Que se passe-t-il si le backoff depasse un delai raisonnable ? -> Avec 3 tentatives et un backoff x2, le delai max est 4s (1+2+4 = 7s total), ce qui reste raisonnable
- Que se passe-t-il si la commande echoue pour une raison permanente (mauvais mot de passe) ? -> Le retry echoue 3 fois puis retourne l'erreur. Le message indique le nombre de tentatives pour aider au diagnostic

---

## Criteres de Succes (mesurables)

- **CS-001**: 26+ regles d'alerte Prometheus actives (vs 21 actuellement)
- **CS-002**: 5/5 modules ont un fichier regression.tftest.hcl (vs 1/5 actuellement)
- **CS-003**: 100% des tests passent (`terraform test` + `bats`) apres implementation
- **CS-004**: La fonction de retry est couverte par au moins 5 tests BATS
- **CS-005**: Zero regression introduite (tous les tests existants continuent de passer)

---

## Hors Scope (explicitement exclus)

- Ajout de nouveaux exporteurs (blackbox-exporter, snmp-exporter) - phase ulterieure
- Alertes basees sur des metriques applicatives (logs, latence) - necessite des exporteurs supplementaires
- Migration des scripts vers un langage plus robuste (Python, Go) - le bash est suffisant pour le homelab
- Retry sur les commandes Terraform elles-memes - gere par Terraform en interne
- Dashboards Grafana pour les nouvelles alertes - les alertes existantes sont deja dans le dashboard

---

## Hypotheses et Dependances

### Hypotheses
- Les metriques node-exporter (node_systemd_unit_state, node_load15, node_network_*_errs_total) sont disponibles sur tous les hotes monitores
- Le provider mock de Terraform supporte les assertions sur les attributs testes
- BATS est disponible dans l'environnement de test pour les tests de scripts

### Dependances
- v1.0.0 released et taguee (base de code stable)
- Node-exporter installe sur les hotes (deja en place depuis v0.5.0)
- Prometheus collectant les metriques des exporteurs (deja en place)
- scripts/lib/common.sh existant avec ssh_exec et check_ssh_access

---

## Points de Clarification

> Aucun point de clarification majeur. Les 3 axes d'amelioration sont clairs et bases sur l'evaluation du projet v1.0.0.

---

## Checklist de validation

### Completude
- [x] Toutes les user stories ont des criteres d'acceptation
- [x] Les exigences fonctionnelles sont listees
- [x] Les cas limites sont identifies
- [x] Les criteres de succes sont mesurables

### Qualite
- [x] Pas de details d'implementation technique
- [x] Comprehensible par un non-developpeur
- [x] Pas de jargon technique inutile
- [x] Scope clairement delimite

### Testabilite
- [x] Chaque exigence est verifiable
- [x] Criteres d'acceptation precis (Given/When/Then)
- [x] Metriques de succes quantifiables

---

**Version**: 1.0 | **Cree**: 2026-02-01 | **Derniere modification**: 2026-02-01
