# Specification : Strategie de backup pour l'infrastructure Proxmox

**Branche**: `feature/backup-strategy`
**Date**: 2026-02-01
**Statut**: Draft

---

## Resume

L'infrastructure homelab Proxmox gere trois environnements (production, lab, monitoring) avec des machines virtuelles, des conteneurs et une stack de supervision. Actuellement, aucune sauvegarde n'est en place : une defaillance materielle, une erreur humaine ou une corruption de donnees entrainerait la perte totale des workloads et de leur historique. Cette feature met en place une strategie de sauvegarde automatisee, une politique de retention, et une procedure de restauration testee, afin de garantir la continuite de service et la recuperation des donnees.

---

## User Stories (prioritisees)

### US1 - Sauvegarder automatiquement les machines virtuelles et conteneurs (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** que mes machines virtuelles et conteneurs soient sauvegardes automatiquement selon une frequence definie
**Afin de** pouvoir recuperer un workload en cas de panne materielle, d'erreur humaine ou de corruption de donnees

**Pourquoi P1**: C'est la raison d'etre de la feature. Sans sauvegarde des workloads, toute defaillance est irrecuperable. Les VMs et conteneurs contiennent les services critiques (production, lab).

**Test independant**: Creer une VM de test, attendre qu'une sauvegarde automatique se declenche, supprimer la VM, puis la restaurer depuis la sauvegarde.

**Criteres d'acceptation**:

1. **Etant donne** un environnement Proxmox avec des VMs et conteneurs deployes, **Quand** la sauvegarde automatique est configuree via l'infrastructure as code, **Alors** chaque VM et conteneur est sauvegarde selon la frequence definie (quotidienne par defaut).
2. **Etant donne** une sauvegarde planifiee, **Quand** l'heure de sauvegarde est atteinte, **Alors** la sauvegarde demarre sans intervention manuelle et se termine avec un statut de succes.
3. **Etant donne** une sauvegarde reussie, **Quand** l'administrateur consulte l'espace de stockage dedie, **Alors** il voit la sauvegarde datee et identifiable par nom de machine et environnement.
4. **Etant donne** un workload supprime accidentellement, **Quand** l'administrateur lance une restauration depuis la derniere sauvegarde, **Alors** le workload est restaure dans un etat fonctionnel.

---

### US2 - Proteger l'etat de l'infrastructure as code (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** que l'etat de mon infrastructure (fichiers d'etat Terraform) soit stocke de maniere resiliente et versionnee
**Afin de** ne pas perdre la correspondance entre mon code et les ressources reellement deployees

**Pourquoi P1**: L'etat Terraform est actuellement stocke uniquement en local sur le poste de travail. Sa perte signifie une perte de controle sur toutes les ressources deployees : impossibilite de modifier ou detruire proprement l'infrastructure existante.

**Test independant**: Configurer le stockage distant, executer un `terraform plan` et verifier qu'il lit correctement l'etat. Supprimer l'etat local et verifier que l'etat distant prend le relais.

**Criteres d'acceptation**:

1. **Etant donne** un environnement Terraform configure, **Quand** l'administrateur execute une commande Terraform, **Alors** l'etat est lu et ecrit depuis un emplacement distant et resilient (pas uniquement le poste local).
2. **Etant donne** un etat stocke a distance, **Quand** l'administrateur travaille depuis un autre poste, **Alors** il accede au meme etat et peut gerer l'infrastructure normalement.
3. **Etant donne** un etat stocke a distance, **Quand** l'etat est modifie, **Alors** la version precedente est conservee et recuperable.

---

### US3 - Appliquer une politique de retention des sauvegardes (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** que les sauvegardes anciennes soient supprimees automatiquement selon une politique de retention
**Afin de** ne pas saturer l'espace de stockage tout en gardant un historique suffisant pour la recuperation

**Pourquoi P2**: Sans politique de retention, le stockage se remplit inevitablement. C'est important pour la perennite mais pas bloquant pour le MVP (les premieres sauvegardes ne rempliront pas le disque immediatement).

**Test independant**: Configurer une retention de 3 sauvegardes, executer 5 cycles de sauvegarde, verifier que seules les 3 plus recentes sont conservees.

**Criteres d'acceptation**:

1. **Etant donne** une politique de retention configuree (ex: garder les 7 dernieres sauvegardes quotidiennes), **Quand** une nouvelle sauvegarde est creee et depasse le nombre maximal, **Alors** la sauvegarde la plus ancienne est automatiquement supprimee.
2. **Etant donne** une politique de retention, **Quand** l'administrateur consulte les sauvegardes, **Alors** le nombre de sauvegardes conservees correspond a la politique definie.
3. **Etant donne** la politique de retention par defaut, **Quand** l'administrateur souhaite l'ajuster, **Alors** il peut modifier la retention par environnement (ex: plus de sauvegardes conservees en production qu'en lab).

---

### US4 - Superviser l'etat des sauvegardes (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** etre alerte si une sauvegarde echoue ou ne s'execute pas
**Afin de** detecter un probleme de sauvegarde avant d'en avoir besoin pour une restauration

**Pourquoi P2**: Une sauvegarde silencieusement defaillante donne un faux sentiment de securite. La supervision est essentielle mais depend d'abord de la mise en place des sauvegardes (US1).

**Test independant**: Provoquer un echec de sauvegarde (stockage plein, machine eteinte), verifier qu'une alerte est emise.

**Criteres d'acceptation**:

1. **Etant donne** une sauvegarde planifiee, **Quand** la sauvegarde echoue, **Alors** une alerte est envoyee a l'administrateur via le systeme de notification existant.
2. **Etant donne** une sauvegarde planifiee, **Quand** aucune sauvegarde ne s'est executee depuis plus de 48 heures, **Alors** une alerte "sauvegarde manquante" est emise.
3. **Etant donne** les metriques de sauvegarde, **Quand** l'administrateur consulte le tableau de bord de supervision, **Alors** il voit le statut de la derniere sauvegarde, sa date et la taille occupee par environnement.

---

### US5 - Documenter les procedures de restauration (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** disposer d'une procedure documentee et testee pour restaurer chaque type de ressource
**Afin de** pouvoir reagir rapidement en situation de crise sans improviser les etapes de restauration

**Pourquoi P2**: La documentation de restauration est indispensable pour que les sauvegardes soient reellement utiles. Une sauvegarde sans procedure de restauration n'a qu'une valeur limitee.

**Test independant**: Suivre la procedure documentee pour restaurer une VM et un conteneur. Verifier que chaque etape est claire et que la restauration aboutit.

**Criteres d'acceptation**:

1. **Etant donne** la documentation de restauration, **Quand** l'administrateur suit la procedure pour une VM, **Alors** il peut restaurer la VM en etat fonctionnel en suivant les etapes decrites.
2. **Etant donne** la documentation de restauration, **Quand** l'administrateur suit la procedure pour un conteneur, **Alors** il peut restaurer le conteneur en etat fonctionnel.
3. **Etant donne** la documentation de restauration, **Quand** l'administrateur suit la procedure pour l'etat Terraform, **Alors** il peut recuperer un etat anterieur et reprendre la gestion de l'infrastructure.

---

### US6 - Sauvegarder vers un emplacement distant (Priorite: P3)

**En tant qu'** administrateur homelab
**Je veux** que les sauvegardes soient copiees vers un emplacement physiquement separe du node Proxmox
**Afin de** survivre a une defaillance materielle totale du serveur (disque mort, vol, incendie)

**Pourquoi P3**: La sauvegarde locale (US1) couvre les cas les plus courants (erreur humaine, corruption). La sauvegarde distante ajoute une couche de protection contre les sinistres physiques, mais necessite un second emplacement de stockage.

**Test independant**: Verifier que les sauvegardes sont repliquees sur l'emplacement distant. Simuler la perte du node principal et restaurer depuis le stockage distant.

**Criteres d'acceptation**:

1. **Etant donne** une sauvegarde locale completee, **Quand** l'administrateur configure un stockage distant (ex: NAS via NFS), **Alors** les sauvegardes sont copiees vers cet emplacement automatiquement.
2. **Etant donne** l'emplacement distant, **Quand** le node Proxmox principal est indisponible, **Alors** les sauvegardes restent accessibles depuis l'emplacement distant.
3. **Etant donne** une perte totale du node, **Quand** l'administrateur reinstalle Proxmox sur un nouveau materiel, **Alors** il peut restaurer ses workloads depuis l'emplacement distant.
4. **Etant donne** un administrateur sans NAS, **Quand** le stockage distant n'est pas configure, **Alors** le systeme fonctionne normalement avec les sauvegardes locales uniquement (le distant est optionnel).

---

## Exigences Fonctionnelles

- **EF-001**: Le systeme DOIT sauvegarder automatiquement toutes les VMs et conteneurs deployes sans intervention manuelle
- **EF-002**: Le systeme DOIT permettre de definir la frequence de sauvegarde par environnement (quotidienne, hebdomadaire)
- **EF-003**: Le systeme DOIT stocker les sauvegardes dans un espace de stockage dedie et identifiable
- **EF-004**: Le systeme DOIT appliquer une politique de retention configurable (nombre de sauvegardes conservees)
- **EF-005**: Le systeme DOIT supporter la restauration individuelle d'une VM ou d'un conteneur specifique
- **EF-006**: Le systeme DOIT etre configurable integralement via l'infrastructure as code (pas d'etape manuelle dans l'interface)
- **EF-007**: L'etat Terraform DOIT etre stocke dans un emplacement resilient avec historique des versions
- **EF-008**: Le systeme DOIT emettre des alertes en cas d'echec de sauvegarde via le systeme de notification existant
- **EF-009**: Le systeme DOIT exposer des metriques de sauvegarde consultables depuis le tableau de bord existant
- **EF-010**: La retention DOIT etre configurable independamment par environnement (production vs lab)
- **EF-011**: La documentation DOIT inclure des procedures de restauration pas-a-pas pour chaque type de ressource
- **EF-012**: Le systeme DOIT permettre de definir une fenetre horaire pour les sauvegardes (eviter les heures de forte utilisation)

---

## Cas Limites (Edge Cases)

- Que se passe-t-il si une VM est en cours de modification pendant la sauvegarde ? -> La sauvegarde doit capturer un etat coherent (snapshot pre-sauvegarde)
- Que se passe-t-il si l'espace de stockage de sauvegarde est plein ? -> La sauvegarde echoue proprement avec une alerte, les sauvegardes existantes ne sont pas corrompues
- Que se passe-t-il si le node Proxmox est eteint au moment de la sauvegarde planifiee ? -> La sauvegarde manquee est detectee et signalee, elle n'est pas rattrapee automatiquement
- Que se passe-t-il si une sauvegarde est corrompue ? -> La restauration detecte la corruption et signale l'erreur au lieu de restaurer des donnees invalides
- Que se passe-t-il si l'administrateur restaure une VM sur un node different de celui d'origine ? -> La restauration doit fonctionner sur tout node ayant acces au stockage de sauvegarde
- Que se passe-t-il si deux sauvegardes de la meme machine se chevauchent ? -> Le systeme doit empecher les executions concurrentes sur une meme ressource
- Que se passe-t-il si la politique de retention est modifiee (reduire de 7 a 3) ? -> Les sauvegardes excedentaires sont purgees au prochain cycle

---

## Entites Cles

| Entite | Ce qu'elle represente | Attributs cles | Relations |
|--------|----------------------|----------------|-----------|
| Sauvegarde | Une capture a un instant T d'une VM ou d'un conteneur | date, machine source, environnement, taille, statut | Appartient a un environnement, cible une machine |
| Politique de retention | Les regles de conservation des sauvegardes | nombre quotidiennes, nombre hebdomadaires, par environnement | S'applique a un environnement |
| Planification | La definition de quand et quoi sauvegarder | frequence, heure, jours, machines incluses | Lie un environnement a ses sauvegardes |
| Etat Terraform | Le fichier d'etat representant les ressources deployees | version, date, environnement | Un par environnement |

---

## Criteres de Succes (mesurables)

- **CS-001**: 100% des VMs et conteneurs deployes sont couverts par une sauvegarde automatique
- **CS-002**: La restauration d'une VM depuis une sauvegarde aboutit en moins de 15 minutes
- **CS-003**: Les echecs de sauvegarde declenchent une alerte dans les 10 minutes suivant l'echec
- **CS-004**: L'espace de stockage de sauvegarde ne depasse jamais 80% de sa capacite grace a la retention
- **CS-005**: La procedure de restauration documentee est executable par l'administrateur sans aide exterieure
- **CS-006**: L'etat Terraform est recuperable meme en cas de perte du poste de travail local

---

## Hors Scope (explicitement exclus)

- Sauvegarde des donnees applicatives internes aux VMs (bases de donnees applicatives, fichiers utilisateur) - necessite des agents dans les VMs, sera traite dans une future iteration
- Chiffrement des sauvegardes - sera evalue dans une iteration ulterieure si les sauvegardes quittent le reseau local
- Proxmox Backup Server (PBS) - complexite disproportionnee pour le MVP, a reevaluer si le volume de donnees augmente
- Replication multi-site geographique - non pertinent pour un homelab single-site
- Restauration automatisee sans intervention (self-healing) - complexite disproportionnee pour un homelab
- Migration live de VMs entre nodes - hors perimetre des sauvegardes
- Sauvegarde de la configuration Proxmox elle-meme (fichiers systeme /etc/pve) - le script post-install et l'IaC permettent de reconstruire la configuration

---

## Hypotheses et Dependances

### Hypotheses
- Les nodes Proxmox disposent d'un espace de stockage suffisant pour heberger les sauvegardes (volume estime 50-200 Go, prevoir 2 a 3x pour la retention soit 400-600 Go)
- Le reseau local entre les nodes Proxmox est fiable et suffisamment rapide pour les transferts de sauvegardes
- L'infrastructure de supervision existante (Prometheus, Grafana, Alertmanager) est operationnelle pour recevoir les metriques et alertes de sauvegarde
- L'administrateur accepte une fenetre de sauvegarde pendant laquelle les performances des workloads peuvent etre legerement degradees

### Dependances
- Module monitoring-stack existant (pour les alertes et tableaux de bord)
- Infrastructure Proxmox deployee et fonctionnelle (environments prod, lab, monitoring)
- Provider Terraform bpg/proxmox (support des ressources de sauvegarde)
- Systeme de notification existant (Alertmanager + Telegram)

---

## Points de Clarification

- ~~[RESOLU]~~ Sauvegardes vzdump sur stockage local dedie par node. Support optionnel d'un stockage NFS/NAS distant configurable ulterieurement.
- ~~[RESOLU]~~ Volume estime : 50-200 Go cumules. Retention de 7 sauvegardes quotidiennes faisable sur stockage local. Prevoir une surveillance de l'espace occupe (CS-004).
- ~~[RESOLU]~~ Stockage auto-heberge (Minio compatible S3 sur un conteneur LXC). Coherent avec la philosophie homelab, versioning et locking natifs, pas de dependance cloud.

---

## Clarifications

### Session 2026-02-01
- Q: PBS dedie ou stockage local ? → R: Stockage local dedie (vzdump) par node. Support NFS/NAS optionnel en P3.
- Q: Volume de donnees a sauvegarder ? → R: 50-200 Go cumules. Retention 7 jours faisable, prevoir 400-600 Go de stockage.
- Q: Backend Terraform auto-heberge ou cloud ? → R: Auto-heberge (Minio S3 sur LXC). Coherent homelab, pas de dependance externe.

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
