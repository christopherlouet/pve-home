# Spécification : Stack Outillage Homelab (PKI, Registry, SSO)

**Branche**: `feature/homelab-tooling-stack`
**Date**: 2026-02-05
**Statut**: Planifié ✅

## Résumé

Cette spécification définit l'ajout d'une stack d'outillage complète pour le homelab, comprenant :
- Une autorité de certification interne (PKI) pour des certificats TLS valides
- Un registre d'images de conteneurs privé
- Une authentification centralisée (SSO) pour tous les services

L'objectif est de professionnaliser l'infrastructure homelab tout en restant adapté à un usage personnel sur réseau LAN privé.

---

## Analyse de la Demande

### Contexte Actuel

| Ressource | Utilisé | Disponible |
|-----------|---------|------------|
| **RAM** | 16.5 GB | ~12 GB libre (sur 32 GB recommandé) |
| **CPU** | 11 cores | Overcommit acceptable |
| **VMs** | 4 (3 prod + 1 monitoring) | Capacité pour 2-3 VMs supplémentaires |
| **IPs** | 192.168.1.50-103 | ~150 IPs libres |

### Réponse aux Questions Initiales

#### Vault est-il nécessaire pour un homelab personnel ?

**Recommandation : NON, pas nécessaire pour un homelab personnel**

| Critère | Vault | Alternative simple |
|---------|-------|-------------------|
| Secrets Terraform | Overkill | Variables d'environnement + `.tfvars` |
| Secrets applicatifs | Overkill | Docker secrets ou fichiers `.env` |
| Rotation des secrets | Rarement nécessaire | Manuelle acceptable |
| Complexité | Élevée (unseal, backup) | Simple |
| Ressources | 1-2 GB RAM | Aucune |

**Cas où Vault serait justifié** :
- Équipe de plusieurs personnes
- Conformité professionnelle requise
- Rotation automatique des secrets critique

**Pour un homelab personnel** : Les secrets dans des fichiers `.tfvars` (gitignored) ou variables d'environnement suffisent amplement.

#### Une nouvelle instance PVE est-elle nécessaire ?

**Recommandation : NON, l'instance existante suffit**

**Estimation des ressources nécessaires** :

| Service | RAM | CPU | Disque |
|---------|-----|-----|--------|
| Step-ca PKI | 256 MB | 0.5 | 2 GB |
| Harbor | 2-4 GB | 2 | 50 GB (images) |
| Authentik | 1-2 GB | 1 | 10 GB |
| **TOTAL** | **3.5-6.5 GB** | **3.5** | **62 GB** |

**Avec les 12 GB de RAM disponibles**, l'infrastructure actuelle peut accueillir ces services.

**Option recommandée** : Déployer sur le nœud **pve-mon** (monitoring) ou créer une VM dédiée "tooling" sur **pve-prod**.

---

## User Stories (prioritisées)

### US1 - Certificats TLS Internes Valides (Priorité: P1) 🎯 MVP

**En tant que** utilisateur du homelab
**Je veux** des certificats TLS valides pour mes services internes
**Afin de** supprimer les avertissements de sécurité du navigateur et sécuriser les communications entre services

**Pourquoi P1** : Fondation de sécurité. Sans PKI, les autres services (Harbor, Authentik) nécessiteront des exceptions manuelles sur chaque appareil.

**Test indépendant** : Accéder à `https://grafana.home.arpa` sans avertissement de certificat depuis un navigateur configuré avec la CA.

**Critères d'acceptation** :

1. **Étant donné** une autorité de certification interne déployée, **Quand** je demande un certificat pour un nouveau service, **Alors** le certificat est généré automatiquement et valide pour 1 an
2. **Étant donné** la CA installée sur mon appareil, **Quand** j'accède à n'importe quel service `.home.arpa`, **Alors** la connexion est sécurisée sans avertissement
3. **Étant donné** un certificat expirant dans 30 jours, **Quand** le système vérifie les certificats, **Alors** une alerte est envoyée pour renouvellement
4. **Étant donné** Traefik comme reverse proxy, **Quand** un nouveau service est ajouté, **Alors** Traefik obtient automatiquement un certificat valide de la PKI

---

### US2 - Registre d'Images Conteneurs Privé (Priorité: P1) 🎯 MVP

**En tant que** développeur/opérateur du homelab
**Je veux** un registre privé pour stocker mes images Docker
**Afin de** ne pas dépendre de Docker Hub et de contrôler mes images personnalisées

**Pourquoi P1** : Autonomie et sécurité. Les images applicatives (alloc-budget, alloc-ia, blog) peuvent être stockées localement, évitant les limites Docker Hub et gardant le contrôle.

**Test indépendant** : `docker push registry.home.arpa/mon-app:v1` puis `docker pull` sur une autre VM.

**Critères d'acceptation** :

1. **Étant donné** un registre déployé, **Quand** je pousse une image `mon-app:v1`, **Alors** elle est stockée localement et accessible depuis toutes les VMs du homelab
2. **Étant donné** une image poussée, **Quand** je consulte l'interface web du registre, **Alors** je vois la liste des images, tags et tailles
3. **Étant donné** une image contenant des vulnérabilités connues, **Quand** le scan automatique s'exécute, **Alors** un rapport de sécurité est disponible
4. **Étant donné** le registre protégé, **Quand** un utilisateur non authentifié tente un push, **Alors** l'accès est refusé

---

### US3 - Authentification Centralisée (Priorité: P2)

**En tant que** utilisateur du homelab
**Je veux** un point d'authentification unique pour tous mes services
**Afin de** ne pas gérer plusieurs mots de passe et centraliser le contrôle d'accès

**Pourquoi P2** : Confort et sécurité améliorée, mais non bloquant. Les services peuvent fonctionner avec leur auth native en attendant.

**Test indépendant** : Se connecter à Grafana via "Login with Authentik" sans créer de compte Grafana séparé.

**Critères d'acceptation** :

1. **Étant donné** Authentik déployé, **Quand** je me connecte à Grafana, **Alors** je suis redirigé vers Authentik et connecté après authentification
2. **Étant donné** un compte Authentik, **Quand** j'accède à Harbor, Proxmox ou Traefik Dashboard, **Alors** le SSO fonctionne sans reconnexion
3. **Étant donné** un nouvel utilisateur (famille/ami), **Quand** l'admin crée un compte, **Alors** l'utilisateur a accès aux services autorisés selon son groupe
4. **Étant donné** une tentative de connexion échouée 5 fois, **Quand** le système détecte l'anomalie, **Alors** le compte est temporairement verrouillé

---

### US4 - Intégration Monitoring et Alerting (Priorité: P2)

**En tant que** opérateur du homelab
**Je veux** surveiller la santé des nouveaux services (PKI, Registry, SSO)
**Afin de** être alerté en cas de dysfonctionnement

**Pourquoi P2** : Continuité avec l'existant. Le monitoring Prometheus/Grafana est déjà en place.

**Test indépendant** : Voir les métriques Step-ca, Harbor et Authentik dans Grafana.

**Critères d'acceptation** :

1. **Étant donné** les nouveaux services déployés, **Quand** je consulte Grafana, **Alors** je vois des dashboards dédiés (certificats expiring, images stockées, connexions SSO)
2. **Étant donné** un service qui tombe, **Quand** la sonde détecte l'indisponibilité, **Alors** une alerte Telegram est envoyée
3. **Étant donné** un certificat expirant dans 14 jours, **Quand** Prometheus scrape les métriques PKI, **Alors** une alerte préventive est déclenchée

---

### US5 - Provisionnement Infrastructure as Code (Priorité: P3)

**En tant que** opérateur du homelab
**Je veux** déployer les nouveaux services via Terraform
**Afin de** maintenir la cohérence avec l'infrastructure existante et faciliter la reconstruction

**Pourquoi P3** : Bonne pratique mais les services peuvent être déployés manuellement dans un premier temps.

**Test indépendant** : `terraform apply` crée la VM tooling et provisionne les services.

**Critères d'acceptation** :

1. **Étant donné** les modules Terraform existants, **Quand** je lance `terraform apply`, **Alors** une VM "tooling" est créée avec Step-ca, Harbor et Authentik pré-configurés
2. **Étant donné** une destruction accidentelle, **Quand** je relance `terraform apply`, **Alors** l'infrastructure est reconstruite à l'identique
3. **Étant donné** les certificats et données, **Quand** la VM est reconstruite, **Alors** les données persistantes (CA root, images Harbor, comptes Authentik) sont préservées via backup

---

## Exigences Fonctionnelles

### PKI (Autorité de Certification)

- **EF-001**: Le système DOIT générer des certificats TLS valides pour le domaine `*.home.arpa` (RFC 8375)
- **EF-002**: Le système DOIT supporter le protocole ACME pour l'obtention automatique de certificats
- **EF-003**: Le système DOIT permettre l'export de la CA racine pour installation sur les appareils clients
- **EF-004**: Le système DOIT générer des alertes avant expiration des certificats (30, 14, 7 jours)
- **EF-005**: Les clés privées de la CA DOIVENT être sauvegardées et récupérables

### Registre d'Images

- **EF-006**: Le système DOIT permettre push/pull d'images Docker via HTTPS
- **EF-007**: Le système DOIT afficher une interface web de consultation des images
- **EF-008**: Le système DOIT scanner les images pour vulnérabilités connues (CVE)
- **EF-009**: Le système DOIT supporter la suppression automatique des anciennes images (garbage collection)
- **EF-010**: Le stockage DOIT supporter au minimum 50 GB d'images

### Authentification Centralisée

- **EF-011**: Le système DOIT supporter OAuth2/OIDC pour l'intégration avec les services
- **EF-012**: Le système DOIT permettre la création de groupes d'utilisateurs avec permissions
- **EF-013**: Le système DOIT supporter l'authentification 2FA (TOTP)
- **EF-014**: Le système DOIT journaliser les connexions et tentatives échouées
- **EF-015**: Le système DOIT pouvoir s'intégrer avec Grafana, Traefik, Harbor et Proxmox

---

## Cas Limites (Edge Cases)

### PKI
- Que se passe-t-il si la CA expire ? → Régénération et réémission de tous les certificats
- Que se passe-t-il si Step-ca est down ? → Les certificats existants restent valides, seul le renouvellement est bloqué
- Comment gérer les appareils mobiles/IoT qui ne supportent pas les CA custom ? → Exception documentée, accès HTTP ou certificat Let's Encrypt externe

### Registry
- Que se passe-t-il si le disque est plein ? → Alerte + garbage collection automatique
- Que se passe-t-il si Harbor est down pendant un déploiement ? → Pull échoué, retry avec backoff
- Comment gérer les images très volumineuses (>5GB) ? → Quota par projet, compression

### Authentification
- Que se passe-t-il si Authentik est down ? → Les services avec auth native fonctionnent, les autres sont inaccessibles
- Comment récupérer un compte admin verrouillé ? → Procédure de récupération via CLI
- Que se passe-t-il si un invité oublie son mot de passe ? → Reset par admin, pas de self-service email (pas de SMTP)

---

## Entités Clés

| Entité | Description | Attributs clés |
|--------|-------------|----------------|
| **Certificat** | Certificat TLS émis par la PKI | cn, san, expiry, issuer |
| **Image** | Image Docker stockée dans le registre | name, tag, size, vulnerabilities, pushed_at |
| **Utilisateur** | Compte dans Authentik | username, email, groups, 2fa_enabled |
| **Groupe** | Ensemble d'utilisateurs avec permissions | name, permissions, members |
| **Service** | Application intégrée au SSO | name, oauth_client_id, allowed_groups |

---

## Critères de Succès (mesurables)

- **CS-001**: 100% des services internes accessibles en HTTPS sans avertissement navigateur
- **CS-002**: Temps d'obtention d'un nouveau certificat < 5 secondes
- **CS-003**: Disponibilité du registre > 99% (max 87h de downtime/an)
- **CS-004**: Temps de connexion SSO < 3 secondes
- **CS-005**: Espace de stockage images utilisé < 80% du quota
- **CS-006**: Zéro vulnérabilité critique non traitée dans les images > 7 jours

---

## Architecture Cible

```
┌─────────────────────────────────────────────────────────────────┐
│                        VM TOOLING                                │
│                    (192.168.1.60, 4GB RAM, 2 cores)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │   Step-ca    │  │   Harbor     │  │  Authentik   │           │
│  │   (PKI)      │  │  (Registry)  │  │    (SSO)     │           │
│  │   :443       │  │   :5000      │  │   :9000      │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│         │                  │                  │                  │
│         └──────────────────┼──────────────────┘                  │
│                            │                                     │
│                    ┌───────▼───────┐                             │
│                    │    Traefik    │  (reverse proxy existant)   │
│                    │   :80/:443    │                             │
│                    └───────────────┘                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Services Consommateurs                                          │
│  ───────────────────────                                         │
│  • Grafana (SSO + cert TLS)                                      │
│  • Traefik Dashboard (SSO + cert TLS)                            │
│  • Proxmox (cert TLS)                                            │
│  • VMs applicatives (docker pull depuis Harbor)                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Hors Scope (explicitement exclus)

- **Vault** : Non nécessaire pour un homelab personnel (voir justification ci-dessus)
- **LDAP standalone** : Authentik inclut déjà un provider LDAP si nécessaire
- **Let's Encrypt public** : Les services sont internes, pas d'exposition internet
- **Kubernetes** : Hors scope de cette spécification (future itération)
- **Backup externalisé** : Utilisation du backup vzdump existant
- **Haute disponibilité** : Un seul nœud suffit pour un homelab personnel
- **Multi-tenant Harbor** : Un seul projet/namespace suffit

---

## Hypothèses et Dépendances

### Hypothèses

1. Le serveur Proxmox a au minimum 32 GB de RAM (12 GB disponibles)
2. Le domaine `home.arpa` est résolu par le DNS local (OPNsense ou Pi-hole)
3. L'utilisateur accepte d'installer la CA racine sur ses appareils personnels
4. Les services applicatifs existants supportent les variables d'environnement pour la config registry
5. Le réseau LAN est considéré comme de confiance (pas de chiffrement inter-services obligatoire)

### Dépendances

- **Traefik** : Déjà déployé dans la stack monitoring, sera réutilisé
- **DNS interne** : Doit résoudre `*.home.arpa` vers l'IP de la VM tooling
- **Prometheus/Grafana** : Existants, intégration des métriques des nouveaux services
- **Telegram Bot** : Existant, réutilisation pour les alertes

---

## Points de Clarification

> Session de clarification terminée le 2026-02-05

1. ~~[CLARIFICATION NÉCESSAIRE]~~ **RÉSOLU** : Domaine interne → `*.home.arpa` (RFC 8375)

2. ~~[CLARIFICATION NÉCESSAIRE]~~ **RÉSOLU** : Déploiement sur **pve-mon** (centralisation outillage infra). Prévoir upgrade RAM + disque sur ce nœud.

3. ~~[CLARIFICATION NÉCESSAIRE]~~ **RÉSOLU** : Intégration SSO progressive
   - **Phase 1** : Grafana + Harbor (intégration native simple, fallback local possible)
   - **Phase 2** : Traefik Dashboard + Proxmox (après stabilisation)

---

## Prochaines Étapes

1. **Clarifier** les 3 points ci-dessus → `/work:work-clarify`
2. **Planifier** l'implémentation → `/work:work-plan`
3. **Implémenter** en TDD les modules Terraform → `/dev:dev-tdd`

---

## Estimation de Ressources

| Composant | RAM | CPU | Disque | Justification |
|-----------|-----|-----|--------|---------------|
| Step-ca | 256 MB | 0.5 | 2 GB | Service léger, peu de requêtes |
| Harbor (minimal) | 2 GB | 1 | 50 GB | Registry + scanner Trivy |
| Authentik | 1.5 GB | 1 | 10 GB | SSO + PostgreSQL intégré |
| Overhead Docker | 512 MB | - | - | Runtime containers |
| **VM Tooling** | **4.5 GB** | **2.5** | **62 GB** | Arrondi à 6 GB RAM, 4 cores |

**Impact sur l'infrastructure existante** :
- RAM après déploiement : 16.5 + 6 = 22.5 GB (70% de 32 GB)
- Marge restante : ~9.5 GB pour futures extensions

---

## Clarifications

### Session 2026-02-05

| Question | Décision | Justification |
|----------|----------|---------------|
| Domaine interne | `*.home.arpa` | RFC 8375, réservé usage privé, évite conflits mDNS avec `.local` |
| Placement VM tooling | **pve-mon** | Centralise l'outillage infra, upgrade RAM + disque prévu |
| Intégration SSO | **Progressive** | Phase 1: Grafana + Harbor / Phase 2: Traefik + Proxmox |

### Décisions complémentaires

- **Vault** : Non nécessaire pour un homelab personnel (secrets dans `.tfvars` gitignored)
- **Nouveau nœud PVE** : Non nécessaire, pve-mon suffit avec upgrade matériel
