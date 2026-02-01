# Specification : Tests d'infrastructure Terraform natifs

**Branche**: `feature/terraform-testing`
**Date**: 2026-02-01
**Statut**: Draft
**Input**: Ajouter des tests d'infrastructure avec le framework terraform test natif pour valider les modules

---

## Resume

Les modules Terraform (vm, lxc, backup, minio, monitoring-stack) sont valides uniquement via `terraform validate` (syntaxe) et des fixtures minimales dans `tests/`. Aucun test ne verifie la logique metier des modules : les valeurs par defaut, les validations d'entrees, les outputs generes, les interactions entre variables, ou les cas d'erreur. Cette feature ajoute des tests natifs Terraform (`terraform test`, disponible depuis Terraform 1.6) pour chaque module, permettant de valider le comportement attendu sans deployer de ressources reelles, et de detecter les regressions avant merge.

---

## User Stories (prioritisees)

### US1 - Tester les validations d'entrees des modules (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** que les regles de validation des variables de chaque module soient testees automatiquement
**Afin de** m'assurer qu'une configuration invalide (IP malformee, disque trop petit, template inexistant) est rejetee avec un message clair plutot que de provoquer un echec cryptique au moment du apply

**Pourquoi P1**: Les validations sont la premiere ligne de defense contre les erreurs de configuration. Les tester garantit qu'elles fonctionnent comme prevu, surtout apres un refactoring.

**Test independant**: Executer `terraform test` sur le module VM avec des valeurs invalides (template_id = 0, disk_size = -1, ip_address = "invalid"), verifier que chaque cas est rejete avec le bon message d'erreur.

**Criteres d'acceptation**:

1. **Etant donne** un module Terraform avec des regles de validation, **Quand** une variable invalide est fournie, **Alors** le test confirme que l'erreur de validation est declenchee avec le message attendu.
2. **Etant donne** un module Terraform avec des valeurs par defaut, **Quand** aucune variable n'est surchargee, **Alors** le test confirme que les valeurs par defaut sont appliquees correctement.
3. **Etant donne** les 5 modules existants (vm, lxc, backup, minio, monitoring-stack), **Quand** les tests s'executent, **Alors** chaque module a au moins un fichier de test couvrant ses validations.

---

### US2 - Tester le plan genere par les modules (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** que le plan Terraform genere par chaque module soit verifie automatiquement (nombre de ressources, types, attributs cles)
**Afin de** detecter les regressions qui changeraient le comportement d'un module (ex: un refactoring qui supprime accidentellement une ressource)

**Pourquoi P1**: Un changement involontaire dans un module peut detruire des ressources en production. Les tests de plan sont le filet de securite contre les regressions.

**Test independant**: Executer `terraform test` sur le module VM avec une configuration standard, verifier que le plan cree exactement les ressources attendues (VM, cloud-init file, firewall rules).

**Criteres d'acceptation**:

1. **Etant donne** un module VM configure avec des parametres standard, **Quand** le test s'execute, **Alors** le plan contient exactement les ressources attendues (VM, fichier cloud-init, regles firewall).
2. **Etant donne** un module VM avec `install_docker = true`, **Quand** le test s'execute, **Alors** le plan inclut les ressources supplementaires liees a Docker.
3. **Etant donne** un module backup configure, **Quand** le test s'execute, **Alors** le plan contient le job de sauvegarde avec le schedule et la retention configures.

---

### US3 - Executer les tests dans la CI (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** que les tests Terraform s'executent automatiquement a chaque pull request
**Afin de** bloquer le merge de code qui casserait le comportement des modules

**Pourquoi P2**: L'execution locale (US1-US2) apporte deja de la valeur. L'integration CI automatise la verification mais necessite une configuration supplementaire du workflow.

**Test independant**: Creer une PR avec une modification d'un module, verifier que le job de test s'execute et que son resultat apparait dans la PR.

**Criteres d'acceptation**:

1. **Etant donne** une pull request modifiant un module Terraform, **Quand** la CI s'execute, **Alors** les tests Terraform du module modifie sont executes.
2. **Etant donne** un test en echec, **Quand** la CI se termine, **Alors** la PR est marquee comme echouee avec le detail du test en erreur.
3. **Etant donne** tous les tests reussis, **Quand** la CI se termine, **Alors** la PR est marquee comme valide pour le merge.

---

### US4 - Tester les scenarios de non-regression (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** des tests specifiques qui documentent et verifient les corrections de bugs anterieures (ex: tri des tags v0.7.2, taille mount_point Minio v0.7.2)
**Afin de** garantir que les bugs corriges ne reapparaissent pas lors de futures modifications

**Pourquoi P2**: Les tests de non-regression sont une bonne pratique mais necessitent d'abord que le framework de test soit en place (US1-US2).

**Test independant**: Creer un test qui reproduit le bug des tags non tries, verifier qu'il passe avec le code actuel.

**Criteres d'acceptation**:

1. **Etant donne** un bug corrige (ex: tags non tries causant du drift), **Quand** le test s'execute, **Alors** il verifie que le comportement corrige est maintenu.
2. **Etant donne** un test de non-regression, **Quand** un developpeur reintroduit accidentellement le bug, **Alors** le test echoue et bloque le merge.

---

### US5 - Documenter la strategie de test (Priorite: P3)

**En tant qu'** administrateur homelab
**Je veux** disposer d'une documentation expliquant comment ecrire, executer et maintenir les tests Terraform
**Afin de** pouvoir ajouter des tests pour les futurs modules sans retrouver les conventions a chaque fois

**Pourquoi P3**: La documentation facilite la maintenance long-terme mais le code de test est lui-meme une documentation (convention over documentation).

**Test independant**: Un contributeur novice peut ajouter un test pour un nouveau module en suivant la documentation.

**Criteres d'acceptation**:

1. **Etant donne** la documentation de test, **Quand** un contributeur la suit, **Alors** il peut creer et executer un nouveau test en suivant les exemples fournis.

---

## Cas Limites (Edge Cases)

- Que se passe-t-il si un module depend d'un provider qui n'est pas mockable ? -> Les tests utilisent `plan` mode (pas `apply`), ce qui ne necessite pas de connexion reelle au provider.
- Que se passe-t-il si les tests passent localement mais echouent en CI ? -> La version de Terraform et des providers doit etre identique en local et en CI (contrainte de versions dans `versions.tf`).
- Que se passe-t-il si un test est lent (timeout) ? -> Les tests en mode `plan` sont rapides (<10s). Un timeout est configure pour detecter les blocages.
- Que se passe-t-il si une validation depend d'une valeur dynamique (ex: template_id qui existe dans Proxmox) ? -> Les tests valident la syntaxe et les regles statiques. Les validations dependant de l'infrastructure reelle sont hors scope.
- Que se passe-t-il si Terraform change le format de sortie de `terraform test` entre versions ? -> La version de Terraform est fixee dans `versions.tf` (>= 1.5). Mettre a jour si necessaire.

---

## Exigences Fonctionnelles

- **EF-001**: Le systeme DOIT fournir des fichiers de test `.tftest.hcl` pour chaque module existant (vm, lxc, backup, minio, monitoring-stack)
- **EF-002**: Les tests DOIVENT valider les regles de validation des variables (cas valides et invalides)
- **EF-003**: Les tests DOIVENT valider le plan genere (nombre et types de ressources)
- **EF-004**: Les tests DOIVENT s'executer en mode `plan` uniquement (sans deploiement reel)
- **EF-005**: Les tests DOIVENT s'executer en moins de 30 secondes par module
- **EF-006**: Les tests DOIVENT etre executables localement avec `terraform test`
- **EF-007**: Les tests DOIVENT etre integres dans le workflow CI existant
- **EF-008**: Les tests DOIVENT couvrir les bugs corriges (non-regression)
- **EF-009**: La version minimum de Terraform requise DOIT etre mise a jour a >= 1.9.0 pour supporter `terraform test` avec mock providers

---

## Entites Cles

| Entite | Ce qu'elle represente | Attributs cles | Relations |
|--------|----------------------|----------------|-----------|
| Suite de test | L'ensemble des tests d'un module | module cible, nombre de tests, statut global | Contient des cas de test |
| Cas de test | Une verification specifique | nom, type (validation/plan/regression), assertion, statut | Appartient a une suite |
| Fixture | Une configuration minimale pour executer un test | variables, providers mock | Utilisee par les cas de test |

---

## Criteres de Succes (mesurables)

- **CS-001**: 100% des modules existants (5) ont au moins un fichier de test
- **CS-002**: 100% des regles de validation existantes sont couvertes par un test
- **CS-003**: Les tests s'executent en moins de 2 minutes au total (tous modules)
- **CS-004**: Les tests passent a 100% sur la branche main a tout moment
- **CS-005**: Le nombre de bugs de non-regression est zero apres implementation

---

## Hors Scope (explicitement exclus)

- Tests d'integration avec Proxmox reel (necessite un environnement de test dedie) - phase ulterieure
- Tests de performance Terraform (temps d'apply, taille du state) - non pertinent
- Tests end-to-end deploiement + health check - couvert par la feature health-checks
- Terratest (framework Go) - le framework natif `terraform test` est suffisant et ne necessite pas de dependance supplementaire
- Tests des environments (prod, lab, monitoring) - seuls les modules reutilisables sont testes

---

## Hypotheses et Dependances

### Hypotheses
- Terraform >= 1.9.0 est disponible en local et en CI
- Les tests en mode `plan` ne necessitent pas de credentials Proxmox (mock providers disponibles depuis TF 1.9)
- Le provider `bpg/proxmox` supporte l'initialisation sans endpoint reel via mock provider

### Dependances
- Terraform >= 1.9.0 (support natif de `terraform test` avec mock providers)
- Provider bpg/proxmox (deja dans `versions.tf`)
- CI GitHub Actions (workflow `ci.yml` existant a etendre)
- Modules existants avec regles de validation (vm, lxc, backup, minio, monitoring-stack)

---

## Points de Clarification

- ~~[RESOLU]~~ La contrainte de version Terraform sera passee a `>= 1.9.0` pour beneficier des dernieres ameliorations de `terraform test` (mock providers, etc.). Terraform 1.9+ est deja installe sur les postes de travail et la CI.

### Session 2026-02-01
- Q: Bump de version Terraform >= 1.5 -> >= 1.6 ? -> R: Passer directement a >= 1.9 pour les mock providers et les dernieres fonctionnalites de terraform test.

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
