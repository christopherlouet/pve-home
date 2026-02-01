# Specification : Detection de drift infrastructure

**Branche**: `feature/drift-detection`
**Date**: 2026-02-01
**Statut**: Draft
**Input**: Detecter automatiquement les ecarts entre l'etat Terraform et l'infrastructure reelle Proxmox

---

## Resume

L'infrastructure Proxmox est geree via Terraform, mais aucun mecanisme ne detecte les modifications manuelles effectuees directement dans l'interface Proxmox (ajout de RAM, modification de firewall, creation de VM hors IaC). Ces modifications silencieuses creent un ecart ("drift") entre l'etat declare et l'etat reel, provoquant des comportements imprevisibles lors des prochains `terraform apply`. Cette feature met en place une detection automatique et periodique du drift, avec notification et reporting.

---

## User Stories (prioritisees)

### US1 - Detecter le drift automatiquement via CI (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** qu'un job CI execute periodiquement `terraform plan` sur chaque environnement et me notifie si des changements sont detectes
**Afin de** savoir immediatement si l'infrastructure reelle a diverge de ma configuration declaree

**Pourquoi P1**: Sans detection, le drift s'accumule silencieusement et provoque des surprises lors du prochain apply. Le fix des tags tries (v0.7.2) illustre ce probleme : un drift non detecte a cause des plans perpetuels.

**Test independant**: Modifier manuellement une ressource dans Proxmox (ex: ajouter 1 Go de RAM a une VM), attendre le prochain cycle de detection, verifier qu'une notification est recue.

**Criteres d'acceptation**:

1. **Etant donne** un environnement Proxmox gere par Terraform, **Quand** le job de detection s'execute selon le planning defini, **Alors** un `terraform plan` est execute et le resultat est analyse.
2. **Etant donne** un plan Terraform sans changement, **Quand** le job se termine, **Alors** aucune notification n'est envoyee et le statut est "conforme".
3. **Etant donne** un plan Terraform avec des changements detectes (drift), **Quand** le job se termine, **Alors** une notification est envoyee a l'administrateur avec le resume des ecarts.
4. **Etant donne** une erreur d'execution du plan (credentials expires, node inaccessible), **Quand** le job echoue, **Alors** une notification d'erreur distincte est envoyee.

---

### US2 - Consulter l'historique de conformite (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** voir l'historique des resultats de detection de drift dans un tableau de bord
**Afin de** suivre la stabilite de mon infrastructure dans le temps et identifier les environnements problematiques

**Pourquoi P2**: Le tableau de bord apporte de la visibilite long-terme mais n'est pas bloquant pour la detection elle-meme.

**Test independant**: Apres plusieurs cycles de detection, consulter le tableau de bord et verifier que chaque execution est visible avec son statut.

**Criteres d'acceptation**:

1. **Etant donne** plusieurs executions du job de detection, **Quand** l'administrateur consulte le tableau de bord, **Alors** il voit l'historique des executions avec date, environnement, et statut (conforme/drift/erreur).
2. **Etant donne** un drift detecte, **Quand** l'administrateur consulte le detail, **Alors** il voit la liste des ressources impactees et le type de changement (ajout, modification, suppression).

---

### US3 - Reconcilier le drift detecte (Priorite: P3)

**En tant qu'** administrateur homelab
**Je veux** pouvoir choisir entre appliquer les changements Terraform (ecraser les modifications manuelles) ou importer les modifications manuelles dans le code
**Afin de** resoudre le drift de maniere controlee plutot que de le laisser s'accumuler

**Pourquoi P3**: La reconciliation est une action manuelle qui peut etre faite sans outillage specifique (`terraform apply` ou `terraform import`). L'outillage facilite mais n'est pas indispensable.

**Test independant**: A partir d'un drift detecte, suivre la procedure documentee pour reconcilier, verifier que le prochain cycle de detection ne detecte plus de drift.

**Criteres d'acceptation**:

1. **Etant donne** un drift detecte et documente, **Quand** l'administrateur suit la procedure de reconciliation, **Alors** le drift est resolu et le prochain cycle confirme la conformite.

---

## Cas Limites (Edge Cases)

- Que se passe-t-il si le node Proxmox est inaccessible au moment du scan ? -> Le job signale une erreur de connectivite, distinct d'un drift, et retente au prochain cycle.
- Que se passe-t-il si les credentials Terraform expirent ? -> Le job echoue avec une erreur d'authentification. L'alerte doit distinguer ce cas d'un drift.
- Que se passe-t-il si le state Minio est inaccessible ? -> Le plan ne peut pas s'executer. L'erreur est notifiee comme probleme d'infrastructure, pas comme drift.
- Que se passe-t-il si un `terraform apply` est en cours pendant le scan ? -> Le locking S3 empeche les executions concurrentes. Le job attend ou echoue avec un message explicite.
- Que se passe-t-il si le drift est cause par Terraform lui-meme (bug provider) ? -> Le rapport de drift documente les ressources impactees. L'administrateur decide si c'est un faux positif a ignorer.
- Que se passe-t-il si le planning de detection tombe pendant une maintenance Proxmox ? -> Le job echoue, une alerte d'erreur est envoyee, le prochain cycle reprend normalement.

---

## Exigences Fonctionnelles

- **EF-001**: Le systeme DOIT executer `terraform plan` automatiquement sur chaque environnement (prod, lab, monitoring) selon un planning configurable
- **EF-002**: Le systeme DOIT distinguer trois etats : conforme (aucun changement), drift detecte (changements non prevus), erreur (execution echouee)
- **EF-003**: Le systeme DOIT notifier l'administrateur uniquement en cas de drift ou d'erreur (pas de notification si conforme)
- **EF-004**: Le systeme DOIT fournir le detail des changements detectes (ressource, attribut, valeur actuelle vs attendue)
- **EF-005**: Le systeme DOIT fonctionner sans intervention manuelle apres la configuration initiale
- **EF-006**: Le systeme DOIT stocker les resultats de chaque execution pour consultation ulterieure
- **EF-007**: Le systeme DOIT supporter la configuration de la frequence de detection par environnement
- **EF-008**: Le systeme NE DOIT PAS executer de `terraform apply` automatiquement (detection uniquement, pas de correction)

---

## Entites Cles

| Entite | Ce qu'elle represente | Attributs cles | Relations |
|--------|----------------------|----------------|-----------|
| Scan de drift | Une execution de detection sur un environnement | date, environnement, statut, resume des changements | Cible un environnement |
| Changement detecte | Un ecart entre l'etat declare et l'etat reel | ressource, attribut, valeur attendue, valeur reelle, type (ajout/modification/suppression) | Appartient a un scan |
| Planning | La definition de quand scanner chaque environnement | frequence, heure, environnement | Configure un ou plusieurs scans |

---

## Criteres de Succes (mesurables)

- **CS-001**: La detection de drift s'execute au moins une fois par jour sur chaque environnement
- **CS-002**: Un drift introduit manuellement est detecte et notifie dans les 24 heures
- **CS-003**: Les faux positifs (drift cause par le provider, pas par une modification manuelle) representent moins de 10% des alertes apres stabilisation
- **CS-004**: L'historique de conformite est consultable sur les 30 derniers jours minimum
- **CS-005**: Le temps d'execution du scan ne depasse pas 5 minutes par environnement

---

## Hors Scope (explicitement exclus)

- Correction automatique du drift (`terraform apply` automatise) - trop risque pour un homelab sans review
- Detection en temps reel (webhook Proxmox) - complexite disproportionnee, le scan periodique suffit
- Comparaison avec des branches Git differentes - hors perimetre, le drift concerne l'ecart etat reel vs etat declare
- Gestion multi-utilisateurs et approbation de reconciliation - non pertinent pour un administrateur unique
- Integration avec des outils tiers de drift management (Spacelift, env0) - surdimensionne pour un homelab

---

## Hypotheses et Dependances

### Hypotheses
- Les credentials Terraform (tokens API Proxmox) sont disponibles sur le node monitoring dans des fichiers `.tfvars` proteges
- Le backend Minio S3 est accessible depuis le node monitoring (reseau local)
- L'execution de `terraform plan` en lecture seule ne modifie pas l'infrastructure
- La frequence quotidienne est suffisante pour un homelab (pas de besoin temps reel)
- Le node monitoring a un acces SSH aux autres nodes si necessaire

### Dependances
- Backend Minio S3 operationnel (feature backup-strategy, deja implementee)
- Node monitoring avec Terraform installe et les `.tfvars` configures
- Systeme de notification Alertmanager + Telegram operationnel
- Cron ou systemd timer sur le node monitoring

---

## Points de Clarification

- ~~[RESOLU]~~ La CI GitHub Actions n'a pas d'acces reseau aux nodes Proxmox ni a Minio. La detection de drift sera implementee comme un script local execute via cron/systemd timer sur le node monitoring (pas de runner self-hosted, pas de tunnel VPN).
- ~~[RESOLU]~~ Les notifications passent par Telegram via Alertmanager existant. Coherent avec le systeme de notification deja en place pour le monitoring.

### Session 2026-02-01
- Q: Acces CI vers le homelab ? -> R: Pas d'acces. Scripts locaux executes via cron/systemd timer sur le node monitoring.
- Q: Canal de notification ? -> R: Telegram via Alertmanager (systeme existant).

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

**Version**: 1.0 | **Cree**: 2026-02-01 | **Derniere modification**: 2026-02-01
