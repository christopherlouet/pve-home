# Specification : Gestion du cycle de vie des VMs

**Branche**: `feature/vm-lifecycle`
**Date**: 2026-02-01
**Statut**: Draft
**Input**: Gerer le cycle de vie complet des VMs : mises a jour, rotation des cles, expiration des VMs de lab, snapshots pre-upgrade

---

## Resume

Les VMs et conteneurs LXC sont actuellement deployes une fois via Terraform et cloud-init, puis ne beneficient d'aucune gestion de cycle de vie automatisee. Les packages ne sont pas mis a jour automatiquement, les cles SSH ne sont jamais rotees, les VMs de lab persistent indefiniment meme quand elles ne sont plus utilisees, et aucun snapshot n'est pris avant une operation risquee (upgrade de version, modification de configuration). Cette feature ajoute une gestion structuree du cycle de vie couvrant les mises a jour systeme, la rotation des credentials, l'expiration automatique des ressources temporaires, et les snapshots de securite.

---

## User Stories (prioritisees)

### US1 - Mettre a jour automatiquement les packages systeme (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** que les VMs et conteneurs appliquent automatiquement les mises a jour de securite
**Afin de** reduire la surface d'attaque sans devoir me connecter manuellement a chaque machine pour mettre a jour les packages

**Pourquoi P1**: Les mises a jour de securite non appliquees sont la cause principale de compromission des systemes. C'est la mesure de securite la plus impactante pour un effort minimal.

**Test independant**: Deployer une VM, attendre un cycle de mise a jour, verifier que les packages de securite sont a jour (`apt list --upgradable` ne retourne aucun package de securite).

**Criteres d'acceptation**:

1. **Etant donne** une VM nouvellement deployee, **Quand** la configuration automatique est appliquee, **Alors** les mises a jour de securite automatiques sont activees (pas les mises a jour majeures).
2. **Etant donne** une VM avec mises a jour automatiques activees, **Quand** une mise a jour de securite est disponible, **Alors** elle est appliquee automatiquement dans les 24 heures sans intervention.
3. **Etant donne** une mise a jour necessitant un redemarrage, **Quand** la mise a jour est appliquee, **Alors** le systeme notifie l'administrateur qu'un redemarrage est necessaire (sans redemarrer automatiquement).
4. **Etant donne** les VMs de production, **Quand** les mises a jour automatiques sont activees, **Alors** seules les mises a jour de securite sont appliquees (pas les mises a jour de version majeure des packages).

---

### US2 - Prendre un snapshot avant les operations risquees (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** pouvoir prendre un snapshot d'une VM avant une operation risquee (upgrade OS, modification de configuration, mise a jour de service)
**Afin de** pouvoir revenir a l'etat precedent en quelques secondes si l'operation echoue, sans attendre une restauration depuis la sauvegarde vzdump

**Pourquoi P1**: Les snapshots Proxmox sont quasi-instantanes et permettent un rollback immediat. C'est le filet de securite le plus rapide pour les operations de maintenance. Contrairement aux sauvegardes vzdump (restauration en minutes), un rollback snapshot prend quelques secondes.

**Test independant**: Prendre un snapshot d'une VM, effectuer une modification destructive, rollback vers le snapshot, verifier que la VM revient a l'etat initial.

**Criteres d'acceptation**:

1. **Etant donne** une VM en cours d'execution, **Quand** l'administrateur demande un snapshot via le script, **Alors** un snapshot est cree avec un nom et une description (date, raison) lisibles.
2. **Etant donne** un snapshot existant, **Quand** l'administrateur lance un rollback, **Alors** la VM revient a l'etat du snapshot en moins de 30 secondes.
3. **Etant donne** un snapshot cree avant une operation, **Quand** l'operation reussit, **Alors** l'administrateur peut supprimer le snapshot pour liberer l'espace.
4. **Etant donne** un snapshot vieux de plus de 7 jours, **Quand** le nettoyage automatique s'execute, **Alors** le snapshot est supprime avec une notification (les snapshots anciens degradent les performances).

---

### US3 - Expirer automatiquement les VMs de lab (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** pouvoir definir une date d'expiration sur les VMs de l'environnement lab
**Afin de** eviter l'accumulation de VMs de test oubliees qui consomment des ressources (CPU, RAM, disque) inutilement

**Pourquoi P2**: Le lab est par nature temporaire, mais les VMs persistent indefiniment. Le nettoyage manuel est facilement oublie. L'automatisation evite le gaspillage de ressources.

**Test independant**: Creer une VM de lab avec une expiration de 1 jour, attendre l'echeance, verifier que la VM est arretee et signalee pour suppression.

**Criteres d'acceptation**:

1. **Etant donne** une VM de lab, **Quand** l'administrateur definit une date d'expiration (ex: 7 jours, 30 jours), **Alors** la date est enregistree comme metadata de la VM.
2. **Etant donne** une VM arrivee a expiration, **Quand** le processus de nettoyage s'execute, **Alors** la VM est arretee (pas supprimee) et une notification est envoyee a l'administrateur.
3. **Etant donne** une VM arretee pour expiration, **Quand** l'administrateur decide de la conserver, **Alors** il peut prolonger la date d'expiration.
4. **Etant donne** une VM arretee pour expiration depuis plus de 7 jours sans prolongation, **Quand** le nettoyage s'execute, **Alors** la VM est marquee comme candidate a la suppression (mais pas supprimee automatiquement).
5. **Etant donne** une VM de production, **Quand** l'expiration est configuree, **Alors** le systeme refuse d'appliquer l'expiration sur les VMs de production (protection).

---

### US4 - Roter les cles SSH periodiquement (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** pouvoir mettre a jour les cles SSH autorisees sur toutes les VMs et conteneurs de maniere centralisee
**Afin de** revoquer l'acces si une cle est compromise et de maintenir une bonne hygiene de securite sans reconfigurer chaque machine manuellement

**Pourquoi P2**: La rotation des credentials est une bonne pratique de securite. Pour un homelab, le risque est modere mais la capacite de revoquer une cle rapidement est importante en cas de compromission.

**Test independant**: Ajouter une nouvelle cle SSH via le script de rotation, verifier que la nouvelle cle permet l'acces et que l'ancienne cle (si revoquee) ne fonctionne plus.

**Criteres d'acceptation**:

1. **Etant donne** un ensemble de VMs/LXC deployes, **Quand** l'administrateur execute le script de rotation des cles, **Alors** les cles SSH autorisees sont mises a jour sur toutes les machines avec les nouvelles cles fournies.
2. **Etant donne** une rotation de cles, **Quand** le script s'execute, **Alors** il verifie que l'acces SSH fonctionne avec la nouvelle cle avant de supprimer l'ancienne (pas de lock-out).
3. **Etant donne** une rotation echouee sur une machine, **Quand** le script detecte l'echec, **Alors** l'ancienne cle est conservee sur cette machine et l'echec est signale dans le rapport.
4. **Etant donne** la source de verite des cles SSH (variable Terraform), **Quand** les cles sont mises a jour dans la configuration, **Alors** le prochain `terraform apply` propage les nouvelles cles aux machines existantes via cloud-init ou provisioner.

---

### US5 - Surveiller l'age des VMs et l'etat des mises a jour (Priorite: P3)

**En tant qu'** administrateur homelab
**Je veux** voir dans un tableau de bord l'age de chaque VM, la date de derniere mise a jour, et les VMs necessitant un redemarrage
**Afin de** avoir une vision d'ensemble de la "fraicheur" de mon infrastructure et prioriser les actions de maintenance

**Pourquoi P3**: Le tableau de bord apporte de la visibilite mais les fonctionnalites operationnelles (US1-US4) sont prioritaires. L'information peut aussi etre obtenue manuellement.

**Test independant**: Consulter le tableau de bord, verifier que chaque VM affiche sa date de creation, la date de derniere mise a jour, et un indicateur de redemarrage necessaire.

**Criteres d'acceptation**:

1. **Etant donne** des VMs deployees, **Quand** l'administrateur consulte le tableau de bord, **Alors** il voit pour chaque VM : nom, date de creation, age, date derniere mise a jour, indicateur de redemarrage necessaire.
2. **Etant donne** une VM necessitant un redemarrage, **Quand** le tableau de bord est consulte, **Alors** un indicateur visuel distingue cette VM des autres.

---

## Cas Limites (Edge Cases)

- Que se passe-t-il si une mise a jour de securite casse un service critique ? -> Les mises a jour automatiques concernent uniquement les packages de securite (pas les mises a jour majeures). Un snapshot pre-upgrade (US2) permet le rollback.
- Que se passe-t-il si une VM de lab arrivee a expiration execute un service utilise par d'autres VMs ? -> La VM est arretee, pas supprimee. La notification permet a l'administrateur de reagir. Un tag "critical-dependency" peut exclure une VM de l'expiration.
- Que se passe-t-il si la rotation de cles SSH echoue au milieu de l'execution (reseau coupe) ? -> Le script traite chaque machine independamment. L'echec d'une machine n'impacte pas les autres. Un rapport final liste les succes et echecs.
- Que se passe-t-il si l'espace disque est insuffisant pour prendre un snapshot ? -> Le script verifie l'espace disponible avant de creer le snapshot et avertit si l'espace est inferieur a un seuil.
- Que se passe-t-il si un snapshot est pris pendant une ecriture disque intensive ? -> Les snapshots Proxmox sont "crash-consistent". Pour les applications critiques (bases de donnees), un freeze QEMU Guest Agent est recommande (gere par Proxmox automatiquement si l'agent est actif).
- Que se passe-t-il si l'administrateur oublie de supprimer les snapshots anciens ? -> Le nettoyage automatique (US2, critere 4) supprime les snapshots de plus de 7 jours avec notification.
- Que se passe-t-il si la rotation de cles est lancee sur une VM eteinte ? -> Le script detecte l'etat de la VM et ignore les machines eteintes avec un avertissement dans le rapport.

---

## Exigences Fonctionnelles

- **EF-001**: Le systeme DOIT configurer les mises a jour de securite automatiques lors du deploiement initial (cloud-init)
- **EF-002**: Le systeme DOIT limiter les mises a jour automatiques aux correctifs de securite (pas de mise a jour de version majeure)
- **EF-003**: Le systeme DOIT notifier l'administrateur quand un redemarrage est necessaire apres mise a jour
- **EF-004**: Le systeme DOIT permettre de prendre un snapshot avec un nom et une description via un script
- **EF-005**: Le systeme DOIT permettre le rollback vers un snapshot nomme
- **EF-006**: Le systeme DOIT supprimer automatiquement les snapshots de plus de 7 jours (configurable)
- **EF-007**: Le systeme DOIT supporter l'expiration configurable des VMs de lab (en jours)
- **EF-008**: Le systeme DOIT arreter (pas supprimer) les VMs expirees et notifier l'administrateur
- **EF-009**: Le systeme DOIT refuser l'expiration sur les VMs de production (protection)
- **EF-010**: Le systeme DOIT permettre la mise a jour centralisee des cles SSH sur toutes les machines
- **EF-011**: Le systeme DOIT verifier la connectivite avec la nouvelle cle avant de supprimer l'ancienne
- **EF-012**: Le systeme DOIT s'integrer avec la librairie shell existante (`scripts/lib/common.sh`)
- **EF-013**: Le systeme DOIT supporter le mode `--dry-run` pour toutes les operations destructives
- **EF-014**: Le systeme DOIT etre testable via le framework BATS existant

---

## Entites Cles

| Entite | Ce qu'elle represente | Attributs cles | Relations |
|--------|----------------------|----------------|-----------|
| VM/LXC | Une machine virtuelle ou un conteneur gere | nom, IP, environnement, date creation, date expiration, tags | Deploye dans un environnement |
| Snapshot | Une capture instantanee de l'etat d'une VM | nom, description, date, VM source, taille | Appartient a une VM |
| Politique de mise a jour | Les regles d'application des mises a jour | type (securite uniquement), frequence, redemarrage auto | S'applique a un environnement |
| Politique d'expiration | Les regles de duree de vie des VMs de lab | duree par defaut, grace period, environnements concernes | S'applique aux VMs de lab |
| Cle SSH | Une cle d'acces autorisee | cle publique, proprietaire, date ajout | Deployee sur les VMs/LXC |

---

## Criteres de Succes (mesurables)

- **CS-001**: 100% des VMs de production ont les mises a jour de securite automatiques activees
- **CS-002**: Le delai entre la publication d'un correctif de securite et son application ne depasse pas 24 heures
- **CS-003**: Un snapshot est cree en moins de 10 secondes, un rollback en moins de 30 secondes
- **CS-004**: Aucune VM de lab expiree ne reste active plus de 24 heures apres sa date d'expiration
- **CS-005**: La rotation de cles SSH s'execute sur toutes les machines accessibles en moins de 5 minutes
- **CS-006**: Aucun snapshot de plus de 7 jours n'existe sans justification explicite

---

## Hors Scope (explicitement exclus)

- Gestion de configuration avancee (Ansible, Puppet, Chef) - le cloud-init et les scripts suffisent pour un homelab
- Mise a jour automatique du kernel avec redemarrage automatique - trop risque sans validation humaine
- Rotation automatique des tokens API Proxmox - gere manuellement, cadence differente
- Patching applicatif dans les VMs (Docker images, bases de donnees) - necessite une gestion specifique par application
- Migration live de VMs entre nodes - hors perimetre du cycle de vie
- Gestion des certificats TLS - pas de TLS dans l'infrastructure actuelle
- Template rotation (construction automatique de nouveaux templates avec Packer) - feature separee

---

## Hypotheses et Dependances

### Hypotheses
- Les VMs utilisent Ubuntu comme OS (package `unattended-upgrades` disponible)
- Le QEMU Guest Agent est actif sur les VMs (necessaire pour les snapshots consistents)
- Le node monitoring peut acceder a toutes les VMs via SSH pour la rotation de cles
- L'espace disque des nodes est suffisant pour stocker les snapshots temporaires (quelques Go par snapshot)
- Les VMs de lab sont identifiables via un tag ou un attribut d'environnement

### Dependances
- Module VM existant (`modules/vm/`) a etendre pour cloud-init
- Module LXC existant (`modules/lxc/`) a etendre
- Librairie shell commune `scripts/lib/common.sh`
- Framework BATS pour les tests
- Systeme de notification existant (Alertmanager + Telegram) pour les alertes
- API Proxmox (pvesh) pour la gestion des snapshots

---

## Points de Clarification

- ~~[RESOLU]~~ Les mises a jour automatiques et la rotation de cles s'appliquent aux VMs ET aux LXC. Les LXC partagent le kernel de l'hote (pas de mise a jour kernel cote conteneur) mais les packages userland doivent etre maintenus a jour.
- ~~[RESOLU]~~ La duree d'expiration par defaut des VMs de lab est de 14 jours. Compromis entre nettoyage regulier et flexibilite pour les cycles de dev/test.

### Session 2026-02-01
- Q: Mises a jour sur LXC aussi ? -> R: Oui, VMs + LXC. Les LXC recoivent les mises a jour userland (pas kernel, gere par l'hote).
- Q: Duree d'expiration par defaut du lab ? -> R: 14 jours. Configurable par VM.

---

## Checklist de validation

### Completude
- [x] Toutes les user stories ont des criteres d'acceptation
- [x] Aucun detail d'implementation (langages, frameworks, APIs)
- [x] Focus sur la valeur utilisateur et les besoins metier
- [x] Comprehensible par un non-developpeur

### Exigences
- [x] Pas de marqueur [CLARIFICATION NECESSAIRE] non resolu (max 3 autorises)
- [x] Exigences testables et non ambigues
- [x] Criteres de succes mesurables
- [x] Criteres technology-agnostic

### Pret pour planification
- [x] Toutes les exigences fonctionnelles ont des criteres clairs
- [x] User stories couvrent les flux principaux
- [x] La feature apporte une valeur mesurable

---

**Version**: 1.1 | **Cree**: 2026-02-01 | **Derniere modification**: 2026-02-01
