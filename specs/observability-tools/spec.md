# Spécification : Outils d'Observabilité Complémentaires

**Branche**: `feature/observability-tools`
**Date**: 2026-02-04
**Statut**: Draft
**Input**: Top 3 outils recommandés pour homelab : Traefik, Loki, Uptime Kuma - déployés sur pve-mon

---

## Résumé

Enrichir la stack d'observabilité du homelab avec trois outils complémentaires :
- Un point d'entrée centralisé pour accéder à tous les services avec des URLs lisibles et HTTPS automatique
- Une centralisation des logs pour investiguer les problèmes sans se connecter à chaque machine
- Une surveillance de la disponibilité des services avec alertes visuelles

Ces outils s'intègrent à la VM monitoring-stack existante sur pve-mon (192.168.1.51) pour centraliser toute l'observabilité.

---

## User Stories (prioritisées)

### US1 - Accès simplifié aux services (Priorité: P1) 🎯 MVP

**En tant que** administrateur du homelab
**Je veux** accéder à mes services via des noms lisibles (ex: grafana.home.lan)
**Afin de** ne plus avoir à mémoriser les ports et IPs de chaque service

**Pourquoi P1**: Sans point d'entrée centralisé, chaque nouveau service nécessite de retenir une IP:port différente. C'est la base pour rendre le homelab utilisable au quotidien.

**Test indépendant**: Depuis un navigateur sur le réseau local, accéder à `grafana.home.lan` et voir l'interface Grafana.

**Critères d'acceptation**:

1. **Étant donné** un service Grafana accessible sur le port 3000, **Quand** j'accède à `grafana.home.lan`, **Alors** je suis redirigé vers l'interface Grafana
2. **Étant donné** un service Prometheus sur le port 9090, **Quand** j'accède à `prometheus.home.lan`, **Alors** je vois l'interface Prometheus
3. **Étant donné** un service Alertmanager sur le port 9093, **Quand** j'accède à `alertmanager.home.lan`, **Alors** je vois l'interface Alertmanager
4. **Étant donné** une URL inconnue, **Quand** j'accède à `unknown.home.lan`, **Alors** je vois une page d'erreur claire indiquant que le service n'existe pas

---

### US2 - Centralisation des logs (Priorité: P1) 🎯 MVP

**En tant que** administrateur du homelab
**Je veux** consulter les logs de toutes mes VMs depuis un seul endroit
**Afin de** diagnostiquer les problèmes sans me connecter en SSH à chaque machine

**Pourquoi P1**: Actuellement, pour investiguer un problème, il faut se connecter en SSH à chaque VM et parser les logs manuellement. Centraliser les logs est essentiel pour le diagnostic rapide.

**Test indépendant**: Depuis Grafana, visualiser les logs de toutes les VMs (monitoring-stack, prod-alloc-budget, prod-alloc-ia, prod-blog-the).

**Critères d'acceptation**:

1. **Étant donné** un service qui écrit dans ses logs, **Quand** j'ouvre la section Logs dans Grafana, **Alors** je vois les logs de ce service avec timestamp et niveau de log
2. **Étant donné** un problème sur une VM, **Quand** je filtre par hostname dans Grafana, **Alors** je vois uniquement les logs de cette VM
3. **Étant donné** un message d'erreur spécifique, **Quand** je recherche ce texte dans Grafana, **Alors** je trouve toutes les occurrences avec leur contexte
4. **Étant donné** des logs générés il y a 7 jours, **Quand** je consulte cette période, **Alors** les logs sont toujours disponibles

---

### US3 - Surveillance de disponibilité (Priorité: P2)

**En tant que** administrateur du homelab
**Je veux** voir en un coup d'oeil si mes services sont en ligne
**Afin de** détecter les pannes avant qu'elles n'impactent mon usage

**Pourquoi P2**: Les alertes Telegram existantes notifient déjà des pannes, mais un tableau de bord visuel de disponibilité apporte une vue d'ensemble immédiate.

**Test indépendant**: Accéder à une page de statut montrant tous les services avec leur état actuel.

**Critères d'acceptation**:

1. **Étant donné** un service en ligne, **Quand** j'ouvre le tableau de bord de statut, **Alors** je vois un indicateur vert pour ce service
2. **Étant donné** un service arrêté, **Quand** j'ouvre le tableau de bord de statut, **Alors** je vois un indicateur rouge pour ce service avec la durée de l'indisponibilité
3. **Étant donné** un historique de disponibilité, **Quand** je consulte un service, **Alors** je vois son uptime en pourcentage sur les 30 derniers jours
4. **Étant donné** un service qui devient indisponible, **Quand** cette indisponibilité dure plus de 2 minutes, **Alors** je reçois une notification

---

### US4 - Certificats HTTPS automatiques (Priorité: P3)

**En tant que** administrateur du homelab
**Je veux** accéder à mes services en HTTPS sans avertissement du navigateur
**Afin de** sécuriser mes connexions et éviter les messages d'erreur de certificat

**Pourquoi P3**: Sur un réseau local privé, HTTPS n'est pas critique pour la sécurité. C'est un confort pour éviter les avertissements navigateur.

**Test indépendant**: Accéder à `https://grafana.home.lan` sans avertissement de certificat.

**Critères d'acceptation**:

1. **Étant donné** un navigateur configuré pour faire confiance à l'autorité locale, **Quand** j'accède à `https://grafana.home.lan`, **Alors** la connexion est sécurisée sans avertissement
2. **Étant donné** un nouveau service ajouté, **Quand** son nom est configuré, **Alors** un certificat est automatiquement généré pour lui

---

## Cas Limites (Edge Cases)

- Que se passe-t-il quand le collecteur de logs n'arrive pas à joindre une VM ?
  → Les logs de cette VM ne sont pas collectés mais les autres VMs ne sont pas impactées. Une alerte est générée.

- Comment le système gère-t-il une VM qui génère énormément de logs ?
  → Un quota par VM limite l'ingestion pour protéger l'espace disque.

- Que se passe-t-il si le service de statut lui-même tombe en panne ?
  → Les alertes Telegram existantes continuent de fonctionner car elles sont gérées par Alertmanager.

- Comportement avec un service qui répond mais avec des erreurs ?
  → Le service de statut vérifie le code HTTP. Un code 5xx est considéré comme une panne.

---

## Exigences Fonctionnelles

- **EF-001**: Le système DOIT router les requêtes vers le bon service en fonction du nom de domaine
- **EF-002**: Le système DOIT collecter les logs de toutes les VMs du homelab (monitoring-stack, prod-alloc-budget, prod-alloc-ia, prod-blog-the)
- **EF-003**: Le système DOIT permettre de rechercher dans les logs par texte, service, niveau de log et période
- **EF-004**: Le système DOIT vérifier périodiquement la disponibilité des services configurés
- **EF-005**: Le système DOIT conserver les logs pendant au moins 7 jours
- **EF-006**: Le système DOIT conserver l'historique de disponibilité pendant au moins 30 jours
- **EF-007**: Le système DOIT s'intégrer avec les notifications Telegram existantes
- **EF-008**: Le système DOIT déployer un agent de collecte de logs sur chaque VM de production

---

## Entités Clés

| Entité | Ce qu'elle représente | Attributs clés | Relations |
|--------|----------------------|----------------|-----------|
| Service | Un service supervisé | nom, url, port, domaine | Logs, Statuts |
| Log | Une entrée de journal | timestamp, message, niveau, source | Service |
| Statut | Un état de disponibilité | horodatage, durée, résultat | Service |
| Route | Une redirection vers un service | domaine, cible | Service |

---

## Critères de Succès (mesurables)

- **CS-001**: Accès à n'importe quel service existant via son nom en moins de 2 secondes
- **CS-002**: Recherche dans les logs de la dernière heure retourne les résultats en moins de 5 secondes
- **CS-003**: Temps entre une panne et sa détection inférieur à 2 minutes
- **CS-004**: Uptime du système de monitoring lui-même supérieur à 99.5%
- **CS-005**: Espace disque utilisé par les logs inférieur à 10 GB sur 7 jours

---

## Hors Scope (explicitement exclus)

- Authentification centralisée (SSO) pour les services - future itération
- Certificats publics Let's Encrypt (nécessite domaine public) - uniquement certificats locaux auto-signés
- Haute disponibilité de la stack monitoring - un seul noeud suffit pour un homelab
- Collecte des logs Proxmox VE eux-mêmes - hors périmètre initial
- Collecte des logs des applications dans les conteneurs Docker (uniquement logs système et Docker daemon)

---

## Hypothèses et Dépendances

### Hypothèses

- Le réseau local utilise un DNS qui peut résoudre `*.home.lan` vers la VM monitoring (ou configuration hosts locale)
- Les ressources de la VM monitoring (4 GB RAM, 30+50 GB disk) sont suffisantes pour les nouveaux services
- Les navigateurs sur le réseau accepteront les certificats auto-signés après configuration initiale

### Dépendances

- Stack monitoring existante (Prometheus, Grafana, Alertmanager) sur pve-mon (192.168.1.51)
- Docker Compose déjà installé et fonctionnel sur la VM monitoring
- Module Terraform monitoring-stack existant pour étendre la configuration
- Accès SSH depuis monitoring vers les VMs prod pour déployer les agents de collecte
- Module VM existant pour ajouter l'agent de logs aux VMs de production

---

## Points de Clarification

- ~~[CLARIFICATION NÉCESSAIRE]: Domaine à utiliser pour les URLs locales~~ → **Résolu : `*.home.lan`**
- ~~[CLARIFICATION NÉCESSAIRE]: Les VMs de production doivent-elles envoyer leurs logs~~ → **Résolu : Oui, toutes les VMs (monitoring + prod)**

---

## Architecture Recommandée : pve-mon

**Pourquoi déployer sur pve-mon ?**

| Critère | pve-mon (recommandé) | pve-prod |
|---------|---------------------|----------|
| Cohérence | Centralise toute l'observabilité | Mélange workloads et infra |
| Impact | Aucun impact sur les VMs applicatives | Risque de surcharge |
| Maintenance | Une seule VM à maintenir pour l'infra | Dispersion des outils |
| Intégration Grafana | Déjà présent, ajout de datasources | Duplication de Grafana |
| Réseau | Accès à toutes les IPs du homelab | Idem |

**Ressources actuelles de monitoring-stack :**
- 2 cores, 4 GB RAM, 30 GB système + 50 GB données
- Services actuels : Prometheus, Grafana, Alertmanager, Node Exporter, PVE Exporter

**Estimation pour les nouveaux services :**
- Reverse proxy : ~50 MB RAM, CPU négligeable
- Collecteur de logs : ~200 MB RAM, 10 GB stockage additionnel
- Surveillance disponibilité : ~100 MB RAM, stockage négligeable

**Total estimé : ~350 MB RAM supplémentaire** → Largement dans les capacités actuelles.

---

## Checklist de validation

### Complétude
- [x] Toutes les user stories ont des critères d'acceptation
- [x] Aucun détail d'implémentation (langages, frameworks, APIs)
- [x] Focus sur la valeur utilisateur et les besoins métier
- [x] Compréhensible par un non-développeur

### Exigences
- [x] Pas de marqueur [CLARIFICATION NÉCESSAIRE] non résolu (tous résolus)
- [x] Exigences testables et non ambiguës
- [x] Critères de succès mesurables
- [x] Critères technology-agnostic

### Prêt pour planification
- [x] Toutes les exigences fonctionnelles ont des critères clairs
- [x] User stories couvrent les flux principaux
- [x] La feature apporte une valeur mesurable

---

**Version**: 1.0 | **Créé**: 2026-02-04 | **Dernière modification**: 2026-02-04
