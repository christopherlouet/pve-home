# Specification : Health checks automatises post-deploiement

**Branche**: `feature/health-checks`
**Date**: 2026-02-01
**Statut**: Draft
**Input**: Verifier automatiquement la sante de l'infrastructure apres chaque deploiement et en continu

---

## Resume

Apres un `terraform apply`, aucune verification automatique ne confirme que les ressources deployees sont reellement operationnelles : une VM peut etre creee mais ne pas demarrer, un service Docker peut echouer au lancement, un conteneur LXC peut manquer de connectivite reseau. De meme, les scripts de restauration (`restore-vm.sh`, `rebuild-monitoring.sh`) ne sont pas automatiquement valides apres execution. Cette feature ajoute des verifications de sante automatisees, declenchees apres deploiement et executees periodiquement, pour garantir que l'infrastructure deployee est reellement fonctionnelle.

---

## User Stories (prioritisees)

### US1 - Verifier la sante apres un terraform apply (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** qu'apres chaque deploiement Terraform, un ensemble de verifications confirme que les ressources deployees sont operationnelles
**Afin de** detecter immediatement les problemes de deploiement au lieu de les decouvrir plus tard lors de l'utilisation

**Pourquoi P1**: Un `terraform apply` reussi ne garantit pas que l'infrastructure fonctionne. Le apply peut reussir (ressource creee dans Proxmox) mais la VM peut ne pas demarrer, le reseau peut ne pas etre configure, ou Docker peut ne pas s'installer.

**Test independant**: Deployer une VM via Terraform, executer le health check, verifier qu'il confirme la connectivite SSH, la reponse du QEMU Guest Agent, et la presence du reseau.

**Criteres d'acceptation**:

1. **Etant donne** un deploiement Terraform termine avec succes, **Quand** le script de health check est execute, **Alors** il verifie la connectivite reseau (ping), l'acces SSH, et le statut de la VM/LXC dans Proxmox.
2. **Etant donne** une VM deployee avec Docker active, **Quand** le health check s'execute, **Alors** il verifie que le service Docker est demarre et fonctionnel.
3. **Etant donne** une verification echouee (VM inaccessible, service down), **Quand** le health check se termine, **Alors** il affiche un rapport clair indiquant la ressource, la verification echouee, et une suggestion de resolution.
4. **Etant donne** toutes les verifications reussies, **Quand** le health check se termine, **Alors** il affiche un rapport de succes avec le resume de chaque verification.

---

### US2 - Verifier la sante de la stack de monitoring (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** verifier automatiquement que Prometheus, Grafana et Alertmanager sont operationnels apres deploiement ou redemarrage
**Afin de** m'assurer que mon systeme de supervision fonctionne avant de compter sur lui pour detecter d'autres problemes

**Pourquoi P1**: Si le monitoring est en panne sans qu'on le sache, toutes les autres alertes (backup, disk, CPU) sont silencieusement perdues. C'est le "who watches the watchmen" problem.

**Test independant**: Deployer la stack monitoring, executer le health check, verifier qu'il confirme que Prometheus scrape les targets, Grafana est accessible, et Alertmanager recoit des alertes.

**Criteres d'acceptation**:

1. **Etant donne** la stack monitoring deployee, **Quand** le health check s'execute, **Alors** il verifie que Prometheus est accessible et scrape au moins un target avec succes.
2. **Etant donne** la stack monitoring deployee, **Quand** le health check s'execute, **Alors** il verifie que Grafana est accessible et repond sur son port configure.
3. **Etant donne** la stack monitoring deployee, **Quand** le health check s'execute, **Alors** il verifie que Alertmanager est accessible et que la configuration Telegram est valide (si activee).
4. **Etant donne** un composant de monitoring en panne, **Quand** le health check s'execute, **Alors** il identifie le composant defaillant et suggere les commandes de diagnostic.

---

### US3 - Verifier la sante du backend Minio S3 (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** verifier automatiquement que Minio est operationnel, que les buckets existent et que le state Terraform est accessible
**Afin de** m'assurer que je peux continuer a gerer mon infrastructure sans perte d'etat

**Pourquoi P1**: Minio stocke l'etat de toute l'infrastructure. Son indisponibilite bloque toute operation Terraform. La detection rapide est critique.

**Test independant**: Executer le health check Minio, verifier qu'il confirme l'acces au endpoint, l'existence des buckets, et la presence des fichiers d'etat.

**Criteres d'acceptation**:

1. **Etant donne** Minio deploye, **Quand** le health check s'execute, **Alors** il verifie que le endpoint S3 repond et que l'authentification fonctionne.
2. **Etant donne** Minio deploye, **Quand** le health check s'execute, **Alors** il verifie que les buckets tfstate (prod, lab, monitoring) existent et contiennent des fichiers d'etat valides.
3. **Etant donne** Minio inaccessible, **Quand** le health check s'execute, **Alors** il signale l'indisponibilite avec les commandes de diagnostic.

---

### US4 - Executer les health checks periodiquement (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** que les health checks s'executent automatiquement a intervalles reguliers (pas seulement apres deploiement)
**Afin de** detecter les pannes ou degradations qui surviennent en dehors des deploiements (redemarrage de node, panne materielle, expiration de certificat)

**Pourquoi P2**: Les health checks post-deploiement (US1-US3) couvrent le cas le plus frequent. L'execution periodique ajoute une couche de surveillance continue mais depend de l'infrastructure de scheduling (cron, systemd timer, ou CI schedule).

**Test independant**: Configurer l'execution periodique, attendre un cycle, verifier que le rapport est genere et que les echecs declenchent une notification.

**Criteres d'acceptation**:

1. **Etant donne** un planning de health check configure, **Quand** l'heure d'execution est atteinte, **Alors** le health check s'execute sans intervention manuelle.
2. **Etant donne** un health check periodique echoue, **Quand** le rapport est genere, **Alors** une notification est envoyee a l'administrateur via le systeme de notification existant.
3. **Etant donne** un health check periodique reussi, **Quand** le rapport est genere, **Alors** aucune notification n'est envoyee (mode silencieux si tout va bien).

---

### US5 - Integrer les resultats dans le dashboard Grafana (Priorite: P3)

**En tant qu'** administrateur homelab
**Je veux** voir les resultats des health checks dans un tableau de bord centralise
**Afin de** avoir une vue d'ensemble de la sante de toute l'infrastructure en un seul endroit

**Pourquoi P3**: Le reporting console (US1-US3) et les notifications (US4) couvrent les besoins operationnels. Le dashboard apporte de la commodite mais necessite l'exposition de metriques supplementaires.

**Test independant**: Apres plusieurs executions, consulter le dashboard et verifier que chaque composant affiche son statut de sante.

**Criteres d'acceptation**:

1. **Etant donne** des resultats de health check disponibles, **Quand** l'administrateur consulte le dashboard, **Alors** il voit le statut de sante de chaque composant (VM, monitoring, Minio) avec la date du dernier check.

---

## Cas Limites (Edge Cases)

- Que se passe-t-il si une VM est en cours de demarrage pendant le health check ? -> Le check retente avec un delai configurable (timeout) avant de declarer un echec.
- Que se passe-t-il si le health check lui-meme ne peut pas s'executer (node de management inaccessible) ? -> L'erreur est rapportee comme un probleme d'execution, distinct d'un echec de sante.
- Que se passe-t-il si une VM est intentionnellement arretee (maintenance) ? -> Un mecanisme d'exclusion permet d'ignorer temporairement certaines ressources.
- Que se passe-t-il si Prometheus est en panne mais que le health check periodique depend de Prometheus pour les notifications ? -> Le health check ecrit aussi un rapport local (fichier) comme fallback.
- Que se passe-t-il si les credentials SSH ont expire ou change ? -> Le check signale l'echec d'authentification comme un probleme specifique de credentials.
- Que se passe-t-il si le reseau est partiellement defaillant (ping OK mais SSH timeout) ? -> Chaque verification est independante et rapportee separement.

---

## Exigences Fonctionnelles

- **EF-001**: Le systeme DOIT verifier la connectivite reseau (ping) de chaque VM et LXC deploye
- **EF-002**: Le systeme DOIT verifier l'acces SSH a chaque VM et LXC deploye
- **EF-003**: Le systeme DOIT verifier le statut de la VM/LXC dans l'API Proxmox (running, stopped, error)
- **EF-004**: Le systeme DOIT verifier le service Docker sur les VMs ou il est installe
- **EF-005**: Le systeme DOIT verifier l'accessibilite de Prometheus, Grafana et Alertmanager sur leurs ports respectifs
- **EF-006**: Le systeme DOIT verifier l'accessibilite de Minio et la validite des buckets tfstate
- **EF-007**: Le systeme DOIT produire un rapport structuree (succes/echec par composant) avec code de retour exploitable
- **EF-008**: Le systeme DOIT supporter un mode `--dry-run` pour tester sans connexion reelle
- **EF-009**: Le systeme DOIT supporter l'exclusion temporaire de ressources (maintenance)
- **EF-010**: Le systeme DOIT s'integrer avec la librairie shell commune existante (`scripts/lib/common.sh`)
- **EF-011**: Le systeme DOIT avoir un timeout configurable par verification pour eviter les blocages

---

## Entites Cles

| Entite | Ce qu'elle represente | Attributs cles | Relations |
|--------|----------------------|----------------|-----------|
| Health Check | Une execution de verification de sante | date, environnement, statut global, duree | Contient des verifications |
| Verification | Un test unitaire de sante sur un composant | composant, type (ping/ssh/port/api), statut, message | Appartient a un health check |
| Composant | Une ressource d'infrastructure verifiable | nom, type (VM/LXC/service), adresse IP, port | Cible d'une verification |
| Exclusion | Une ressource temporairement exclue des checks | composant, raison, date debut, date fin | Reference un composant |

---

## Criteres de Succes (mesurables)

- **CS-001**: Le health check post-deploiement detecte 100% des VMs inaccessibles (pas de faux negatif)
- **CS-002**: Le health check complet (tous environnements) s'execute en moins de 2 minutes
- **CS-003**: Le rapport de sante est comprehensible sans connaissance technique approfondie (tableau avec statuts couleur)
- **CS-004**: Les faux positifs (resource temporairement lente mais fonctionnelle) representent moins de 5% des alertes
- **CS-005**: Le script de health check est testable via BATS avec le meme framework que les scripts existants

---

## Hors Scope (explicitement exclus)

- Verification de la sante applicative a l'interieur des VMs (bases de donnees, serveurs web applicatifs) - necessite des agents specifiques par application
- Auto-remediation (redemarrage automatique des services en echec) - trop risque sans supervision humaine
- Verification des performances (latence, debit) - couvert par le monitoring Prometheus existant
- Verification des certificats TLS - pas de TLS dans l'infrastructure actuelle
- Health checks des services tiers (DNS externe, NTP) - hors perimetre infrastructure locale
- Smoke tests applicatifs (requetes HTTP sur les services deployes) - phase ulterieure

---

## Hypotheses et Dependances

### Hypotheses
- Les VMs et LXC deployes sont accessibles via SSH depuis le poste d'administration ou le node monitoring
- Le QEMU Guest Agent est actif sur les VMs (variable `agent_enabled = true` par defaut)
- Les ports des services de monitoring (Prometheus 9090, Grafana 3000, Alertmanager 9093) sont accessibles depuis le reseau local
- Le script `verify-backups.sh` existant peut etre etendu ou compose avec le nouveau health check

### Dependances
- Librairie shell commune `scripts/lib/common.sh` (logging, SSH, validation)
- Framework de test BATS existant dans `tests/restore/`
- Infrastructure deployee (VMs, LXC, monitoring stack, Minio)
- Terraform outputs disponibles (IPs, noms, ports)

---

## Points de Clarification

- ~~[RESOLU]~~ Le health check est un script local execute depuis le poste de l'administrateur (post-deploiement) ou depuis le node monitoring (execution periodique via cron/systemd timer). Le node monitoring est le point central d'execution pour les checks periodiques, coherent avec l'approche choisie pour la drift detection.

### Session 2026-02-01
- Q: Execution depuis quel endroit ? -> R: Poste admin (post-deploiement) + node monitoring (periodique via cron/systemd timer). Notifications via Telegram/Alertmanager.

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
