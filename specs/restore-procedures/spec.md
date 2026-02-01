# Specification : Procedures de Restauration Automatisees

**Branche**: `feature/restore-procedures`
**Date**: 2026-02-01
**Statut**: Draft

## Resume

Fournir des scripts de restauration fiables et testes pour chaque composant de l'infrastructure homelab (VMs, conteneurs, state Terraform, Minio, monitoring stack). L'operateur peut restaurer n'importe quel composant en une seule commande, avec verification automatique du succes, sans avoir a se souvenir des commandes manuelles.

## User Stories (prioritisees)

### US1 - Restaurer une VM ou un conteneur (Priorite: P1) MVP

**En tant qu'** operateur de l'infrastructure
**Je veux** restaurer une VM ou un conteneur depuis sa derniere sauvegarde en une commande
**Afin de** reprendre le service rapidement apres un incident sans risque d'erreur manuelle

**Pourquoi P1**: C'est le scenario de restauration le plus frequent. Une VM corrompue ou un conteneur casse doit pouvoir etre restaure en quelques minutes, sans consulter la documentation a chaque fois.

**Test independant**: Lancer le script sur un VMID de test, verifier que la VM est restauree et accessible en SSH.

**Criteres d'acceptation**:

1. **Etant donne** une VM arretee ou corrompue et au moins une sauvegarde vzdump disponible, **Quand** l'operateur lance le script de restauration avec le VMID, **Alors** la derniere sauvegarde est restauree, la VM est demarree et un test de connectivite (ping + SSH) confirme le succes.
2. **Etant donne** plusieurs sauvegardes disponibles pour un VMID, **Quand** l'operateur lance le script sans specifier de date, **Alors** la sauvegarde la plus recente est utilisee.
3. **Etant donne** plusieurs sauvegardes disponibles, **Quand** l'operateur specifie une date, **Alors** la sauvegarde correspondante est utilisee.
4. **Etant donne** aucune sauvegarde disponible pour le VMID demande, **Quand** l'operateur lance le script, **Alors** un message d'erreur clair est affiche et le script s'arrete sans modification.
5. **Etant donne** une restauration en cours, **Quand** la VM existante porte le meme VMID, **Alors** l'operateur est invite a confirmer l'ecrasement avant de proceder.
6. **Etant donne** un conteneur LXC, **Quand** l'operateur lance le script avec un CTID, **Alors** le comportement est identique (detection automatique du type VM/LXC).
7. **Etant donne** un VMID cible different specifie via `--target-id`, **Quand** l'operateur lance la restauration, **Alors** le backup est restaure sous le nouveau VMID sans toucher a la VM originale.

---

### US2 - Restaurer le state Terraform depuis Minio (Priorite: P1) MVP

**En tant qu'** operateur de l'infrastructure
**Je veux** restaurer un etat Terraform precedent depuis le backend Minio S3
**Afin de** revenir a un etat connu apres un terraform apply defaillant ou une corruption du state

**Pourquoi P1**: Un state Terraform corrompu bloque toute operation sur l'infrastructure. La restauration rapide est critique pour maintenir la capacite de gestion.

**Test independant**: Lister les versions du state, restaurer une version anterieure, verifier avec `terraform plan` qu'il n'y a pas de changement inattendu.

**Criteres d'acceptation**:

1. **Etant donne** un bucket Minio avec versioning actif et plusieurs versions du state, **Quand** l'operateur lance le script en mode liste, **Alors** les versions disponibles sont affichees avec leur date et taille.
2. **Etant donne** une version du state selectionnee, **Quand** l'operateur confirme la restauration, **Alors** la version est restauree comme version courante et un `terraform plan` est execute pour verification.
3. **Etant donne** que Minio est inaccessible, **Quand** l'operateur lance le script en mode fallback, **Alors** le backend Terraform bascule en local avec migration automatique de l'etat.
4. **Etant donne** un backend local actif et Minio redevenu accessible, **Quand** l'operateur lance le script en mode retour, **Alors** l'etat est remigre vers Minio S3.

---

### US3 - Reconstruire Minio depuis zero (Priorite: P2)

**En tant qu'** operateur de l'infrastructure
**Je veux** reconstruire le conteneur Minio et ses buckets depuis zero
**Afin de** restaurer le backend Terraform apres une perte totale du conteneur Minio

**Pourquoi P2**: La perte de Minio est moins frequente, mais bloque les operations Terraform sur tous les environnements. Le state local fait office de filet de securite temporaire.

**Test independant**: Detruire le conteneur Minio, executer le script de reconstruction, verifier que les buckets sont recrees et que `terraform init` fonctionne.

**Criteres d'acceptation**:

1. **Etant donne** un conteneur Minio absent ou casse, **Quand** l'operateur lance le script de reconstruction, **Alors** un nouveau conteneur est cree avec les memes parametres (IP, ports, buckets).
2. **Etant donne** un Minio reconstruit sans donnees, **Quand** l'operateur a un fichier state local, **Alors** le script permet de reenvoyer le state vers les buckets Minio.
3. **Etant donne** une reconstruction reussie, **Quand** l'operateur execute `terraform init` sur chaque environnement, **Alors** la connexion au backend S3 est retablie sans erreur.

---

### US4 - Reconstruire la stack monitoring (Priorite: P2)

**En tant qu'** operateur de l'infrastructure
**Je veux** reconstruire la VM monitoring et tous ses services (Prometheus, Grafana, alertes)
**Afin de** restaurer la visibilite sur l'infrastructure apres une perte de la VM monitoring

**Pourquoi P2**: La perte du monitoring n'arrete pas les services de production, mais supprime toute visibilite et alerte. La reconstruction doit etre rapide pour limiter la periode sans surveillance.

**Test independant**: Restaurer la VM monitoring depuis un backup, verifier que Grafana, Prometheus et les alertes sont operationnels.

**Criteres d'acceptation**:

1. **Etant donne** une VM monitoring arretee ou corrompue, **Quand** l'operateur lance le script de reconstruction, **Alors** la VM est restauree depuis le dernier backup vzdump et les services Docker sont verifies.
2. **Etant donne** une VM monitoring restauree, **Quand** les services demarrent, **Alors** Prometheus scrape les targets, Grafana affiche les dashboards, et Alertmanager est connecte.
3. **Etant donne** aucun backup vzdump disponible, **Quand** l'operateur lance la reconstruction complete, **Alors** le script indique de relancer `terraform apply` sur l'environnement monitoring pour recreer la VM depuis zero (configuration complete, historique metriques perdu).

---

### US5 - Verifier l'integrite des sauvegardes (Priorite: P2)

**En tant qu'** operateur de l'infrastructure
**Je veux** verifier periodiquement que les sauvegardes sont valides et restaurables
**Afin de** m'assurer que je pourrai restaurer en cas de besoin reel

**Pourquoi P2**: Une sauvegarde non testee n'est pas une sauvegarde. La verification reguliere evite les mauvaises surprises lors d'un incident reel.

**Test independant**: Lancer la verification sur toutes les sauvegardes, confirmer que le rapport indique le statut de chaque backup.

**Criteres d'acceptation**:

1. **Etant donne** des sauvegardes vzdump sur un noeud, **Quand** l'operateur lance la verification, **Alors** chaque fichier de sauvegarde est verifie (integrite, taille non-nulle, checksum si disponible) et un rapport est affiche.
2. **Etant donne** un bucket Minio avec des versions du state, **Quand** la verification est lancee, **Alors** chaque version est testee (fichier JSON valide, non vide) et le resultat est affiche.
3. **Etant donne** une sauvegarde corrompue ou manquante, **Quand** la verification detecte le probleme, **Alors** un avertissement clair est emis avec le VMID concerne.

---

### US6 - Procedure de disaster recovery complete (Priorite: P3)

**En tant qu'** operateur de l'infrastructure
**Je veux** une procedure guidee pas-a-pas pour reconstruire l'integralite de l'infrastructure depuis zero
**Afin de** pouvoir repartir de rien en cas de defaillance majeure (perte d'un noeud complet, corruption generalisee)

**Pourquoi P3**: Le scenario de perte totale est rare dans un homelab, mais la procedure documentee apporte une tranquillite d'esprit et sert de documentation de reference pour l'architecture.

**Test independant**: Suivre la procedure sur un noeud de test, verifier que tous les services sont restaures dans l'ordre correct.

**Criteres d'acceptation**:

1. **Etant donne** un noeud Proxmox fraichement installe, **Quand** l'operateur suit la procedure de disaster recovery, **Alors** l'ordre de restauration est clairement indique (1. Minio, 2. State Terraform, 3. Monitoring, 4. VMs de production).
2. **Etant donne** une procedure de disaster recovery, **Quand** l'operateur l'execute, **Alors** chaque etape indique les pre-requis, la commande a lancer, et la verification attendue.
3. **Etant donne** un noeud completement restaure, **Quand** toutes les etapes sont terminees, **Alors** un script de verification finale confirme que tous les services sont operationnels (connectivite, monitoring, sauvegardes actives).

## Exigences Fonctionnelles

- **EF-001**: Chaque script de restauration DOIT verifier les pre-requis avant d'agir (acces SSH, espace disque, existence des sauvegardes).
- **EF-002**: Chaque script DOIT afficher un resume de l'action avant execution et demander confirmation (sauf mode --force).
- **EF-003**: Chaque restauration DOIT produire un rapport de succes ou d'echec avec les details (fichier restaure, duree, verifications effectuees).
- **EF-004**: Les scripts DOIVENT etre executables depuis la machine de l'operateur (pas besoin d'etre sur le noeud Proxmox).
- **EF-005**: Les scripts DOIVENT fonctionner avec la configuration existante (lecture des terraform.tfvars pour les IPs, credentials, etc.).
- **EF-006**: Chaque operation destructive (ecrasement d'une VM, remplacement d'un state) DOIT creer un point de sauvegarde avant de proceder.
- **EF-007**: Les scripts DOIVENT supporter un mode dry-run (--dry-run) qui affiche les actions sans les executer.

## Cas Limites (Edge Cases)

- Que se passe-t-il quand le noeud Proxmox est injoignable en SSH ? → Message d'erreur clair, suggestion de verifier la connectivite reseau.
- Que se passe-t-il quand l'espace disque est insuffisant pour la restauration ? → Verification prealable et avertissement avant de lancer la restauration.
- Que se passe-t-il quand le VMID cible est deja en cours d'execution ? → Demander confirmation pour arreter puis restaurer, ou proposer un VMID alternatif.
- Que se passe-t-il quand le fichier de sauvegarde est corrompu ? → Detection via verification d'integrite, message d'erreur, suggestion d'utiliser un backup plus ancien.
- Que se passe-t-il quand Minio et le state local sont tous les deux absents ? → Le script indique clairement que le state est perdu et guide l'operateur pour reimporter les ressources existantes (`terraform import`).

## Entites Cles

| Entite | Description | Attributs cles |
|--------|-------------|----------------|
| Sauvegarde vzdump | Fichier de sauvegarde d'une VM ou d'un conteneur | vmid, date, type (qemu/lxc), taille, emplacement |
| State Terraform | Etat de l'infrastructure geree par Terraform | environnement (prod/lab/monitoring), version, date |
| Noeud Proxmox | Serveur physique hebergeant les VMs/conteneurs | nom, ip, storage disponible |
| Conteneur Minio | Service de stockage objet pour les states | ip, port, buckets, etat de sante |
| Stack monitoring | VM avec Prometheus, Grafana, Alertmanager | ip, services Docker, etat de sante |

## Criteres de Succes (mesurables)

- **CS-001**: Restauration d'une VM/LXC en moins de 5 minutes (hors temps de transfert du fichier backup).
- **CS-002**: Restauration du state Terraform en moins de 2 minutes.
- **CS-003**: Reconstruction de Minio en moins de 10 minutes.
- **CS-004**: Reconstruction de la stack monitoring en moins de 15 minutes.
- **CS-005**: Verification d'integrite de toutes les sauvegardes d'un noeud en moins de 5 minutes.
- **CS-006**: 100% des scripts retournent un code de sortie 0 en cas de succes et non-zero en cas d'echec.
- **CS-007**: Disaster recovery complet (depuis un noeud Proxmox vierge) realisable en moins de 1 heure.

## Hors Scope (explicitement exclus)

- **Sauvegardes offsite** (replication vers un site distant) - sera traite dans une future iteration.
- **Sauvegardes incrementales** (PBS, Proxmox Backup Server) - pas necessaire pour un homelab avec stockage local suffisant.
- **Restauration cross-node** (restaurer une VM d'un noeud sur un autre) - complexite reseau/storage non justifiee en homelab.
- **Interface web** pour la gestion des restaurations - les scripts CLI sont suffisants pour un operateur unique.
- **Automatisation complete** (restauration sans intervention humaine) - une confirmation manuelle est preferable pour les operations destructives.

## Hypotheses et Dependances

### Hypotheses
- L'operateur a un acces SSH par cle aux noeuds Proxmox depuis sa machine.
- Les sauvegardes vzdump sont stockees sur le storage local de chaque noeud.
- Les buckets Minio ont le versioning active.
- L'operateur a `terraform`, `mc` (Minio Client), `ssh` et `jq` installes localement.
- Les fichiers `terraform.tfvars` contiennent les IPs et identifiants necessaires.

### Dependances
- Module `backup/` existant (sauvegardes vzdump configurees et fonctionnelles).
- Module `minio/` existant (backend S3 operationnel avec versioning).
- Module `monitoring-stack/` existant (Prometheus, Grafana deployes).
- Documentation `docs/BACKUP-RESTORE.md` existante (sert de base pour les scripts).

## Points de Clarification

*Tous les points de clarification ont ete resolus (voir section Clarifications).*

## Clarifications

### Session 2026-02-01
- Q: Faut-il supporter la restauration vers un VMID different ? → R: Restauration en place par defaut, avec option `--target-id` pour restaurer vers un VMID/CTID different si besoin.
- Q: Faut-il restaurer les donnees Prometheus (historique metriques) ? → R: Configuration uniquement. Le backup vzdump inclut les donnees si disponible. La reconstruction depuis zero (terraform apply) recree la configuration complete mais l'historique metriques est perdu.
