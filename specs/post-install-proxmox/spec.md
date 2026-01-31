# Specification : Script de post-installation Proxmox

**Branche**: `feature/post-install-script`
**Date**: 2026-01-31
**Statut**: Draft

## Resume

Apres l'installation physique de Proxmox VE, l'administrateur doit executer une serie d'etapes de configuration (depots, utilisateurs, templates, securisation). Ce processus, actuellement manuel et documente etape par etape, est source d'erreurs et de perte de temps. Le script de post-installation automatise ces etapes en une seule commande, tout en permettant de personnaliser le comportement. La documentation est mise a jour pour integrer ce script et ajouter des recommandations de securisation.

## User Stories (prioritisees)

### US1 - Automatiser la configuration post-installation (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** executer un seul script apres l'installation de Proxmox
**Afin de** configurer automatiquement le systeme (depots, utilisateurs, templates) sans risque d'oubli ou d'erreur de frappe

**Pourquoi P1**: C'est la raison d'etre du projet. Sans ce script, les etapes manuelles restent la seule option, ce qui est lent et error-prone.

**Test independant**: Executer le script sur une installation Proxmox VE fraiche et verifier que toutes les etapes sont completees.

**Criteres d'acceptation**:

1. **Etant donne** une installation Proxmox VE 9.x fraiche, **Quand** l'administrateur execute le script en root, **Alors** les depots no-subscription sont configures, le systeme est mis a jour, les outils utiles sont installes, l'utilisateur Terraform est cree avec son token, les snippets cloud-init sont actives, et les templates sont telecharges.
2. **Etant donne** un script deja execute, **Quand** l'administrateur le relance, **Alors** chaque etape detecte l'etat existant et ne refait pas ce qui est deja fait (idempotence).
3. **Etant donne** une execution reussie, **Quand** le script se termine, **Alors** un resume affiche toutes les informations a noter (tokens API, URL, identifiants de templates).

---

### US2 - Personnaliser l'execution du script (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** pouvoir controler quelles etapes sont executees et avec quels parametres
**Afin d'** adapter le script a ma configuration specifique (timezone, templates, monitoring optionnel)

**Pourquoi P1**: Chaque homelab a des besoins differents. Sans personnalisation, le script serait trop rigide pour etre utilisable.

**Test independant**: Lancer le script avec differentes options et verifier que le comportement s'adapte.

**Criteres d'acceptation**:

1. **Etant donne** le script lance avec `--no-prometheus`, **Quand** l'execution atteint l'etape utilisateur Prometheus, **Alors** cette etape est ignoree.
2. **Etant donne** le script lance avec `--timezone America/New_York`, **Quand** l'etape timezone s'execute, **Alors** le fuseau horaire est configure sur America/New_York au lieu de Europe/Paris.
3. **Etant donne** le script lance avec `--yes`, **Quand** une etape demande normalement confirmation, **Alors** la confirmation est automatiquement acceptee.
4. **Etant donne** le script lance avec `--help`, **Quand** le script demarre, **Alors** il affiche l'aide et se termine sans executer aucune etape.
5. **Etant donne** le script lance avec `--vm-template-id 9001`, **Quand** l'etape de creation du template VM s'execute, **Alors** le template est cree avec l'ID 9001 au lieu de 9000.
6. **Etant donne** le script lance avec `--no-template-vm`, **Quand** l'execution atteint l'etape template VM, **Alors** cette etape est ignoree.
7. **Etant donne** le script lance avec `--skip-reboot`, **Quand** la mise a jour systeme est terminee, **Alors** le script continue sans redemarrer.

---

### US3 - Documenter l'acces SSH et la securisation (Priorite: P1) MVP

**En tant qu'** administrateur homelab
**Je veux** un guide pour configurer l'acces SSH par cle publique et securiser mon instance Proxmox
**Afin de** pouvoir executer le script a distance et proteger mon installation des acces non autorises

**Pourquoi P1**: L'acces SSH est un prerequis pour executer le script a distance, et la securisation est essentielle meme sur un reseau local.

**Test independant**: Suivre la documentation et verifier que la connexion SSH par cle fonctionne et que les mesures de securisation sont en place.

**Criteres d'acceptation**:

1. **Etant donne** la documentation mise a jour, **Quand** l'administrateur suit l'etape SSH, **Alors** il peut se connecter au node Proxmox sans mot de passe via sa cle publique.
2. **Etant donne** la documentation mise a jour, **Quand** l'administrateur lit la section securisation, **Alors** il trouve des instructions pour : desactiver l'authentification SSH par mot de passe, configurer fail2ban, et configurer le pare-feu Proxmox.
3. **Etant donne** un reseau local sans acces Internet, **Quand** l'administrateur lit les recommandations certificat et 2FA, **Alors** il comprend que le certificat auto-signe suffit et que le 2FA est optionnel.

---

### US4 - Integrer le script dans la documentation existante (Priorite: P2)

**En tant qu'** administrateur homelab
**Je veux** que la documentation d'installation reference le script comme methode recommandee
**Afin de** savoir immediatement quelle approche utiliser sans chercher dans plusieurs fichiers

**Pourquoi P2**: La documentation existante fonctionne deja. L'integration est importante pour la coherence mais n'apporte pas de nouvelle capacite.

**Test independant**: Lire la documentation et verifier que le parcours est clair : installation manuelle -> SSH -> script -> verification.

**Criteres d'acceptation**:

1. **Etant donne** la documentation mise a jour, **Quand** l'administrateur arrive a l'etape 5, **Alors** il trouve une instruction claire pour telecharger et executer le script.
2. **Etant donne** la documentation mise a jour, **Quand** l'administrateur souhaite comprendre les commandes executees, **Alors** il peut deplier des blocs de details pour voir les commandes manuelles equivalentes.
3. **Etant donne** la documentation mise a jour, **Quand** l'administrateur arrive a la section "Informations a noter", **Alors** elle reference les informations affichees par le resume du script.

---

### US5 - Supporter les anciennes versions de Proxmox (Priorite: P3)

**En tant qu'** administrateur homelab avec PVE 8.x
**Je veux** que le script fonctionne aussi sur mon installation existante
**Afin de** ne pas etre oblige de reinstaller en PVE 9.x pour beneficier de l'automatisation

**Pourquoi P3**: PVE 9.x est la version courante. Le support 8.x est un bonus pour les installations existantes, pas un prerequis.

**Test independant**: Executer le script sur un Proxmox VE 8.x et verifier que les depots sont configures au format .list au lieu de .sources.

**Criteres d'acceptation**:

1. **Etant donne** un node Proxmox VE 8.x, **Quand** le script detecte la version, **Alors** il utilise le format `.list` pour les depots APT et le codename `bookworm`.
2. **Etant donne** un node Proxmox VE 9.x, **Quand** le script detecte la version, **Alors** il utilise le format `.sources` (DEB822) et le codename `trixie`.
3. **Etant donne** un systeme non-Proxmox, **Quand** le script est execute, **Alors** il affiche un message d'erreur et se termine sans rien modifier.

## Exigences Fonctionnelles

- **EF-001**: Le script DOIT etre execute en tant que root sur le node Proxmox
- **EF-002**: Le script DOIT etre idempotent (une re-execution ne casse rien et ne duplique rien)
- **EF-003**: Le script DOIT sauvegarder les fichiers systeme avant modification (backup `.bak`)
- **EF-004**: Le script DOIT detecter automatiquement la version de Proxmox VE et adapter son comportement
- **EF-005**: Le script DOIT afficher un resume final avec toutes les informations generees (tokens, IDs)
- **EF-006**: Le script DOIT proposer une confirmation avant chaque etape en mode interactif
- **EF-007**: Le script DOIT supporter un mode non-interactif (`--yes`) pour les executions automatisees
- **EF-008**: Le script DOIT afficher des messages de progression clairs et colores
- **EF-009**: La documentation DOIT inclure une etape de configuration SSH par cle publique avant le script
- **EF-010**: La documentation DOIT inclure une section de securisation adaptee a un usage reseau local
- **EF-011**: La documentation DOIT conserver les commandes manuelles accessibles dans des blocs repliables
- **EF-012**: Le script DOIT verifier qu'il s'execute bien sur un systeme Proxmox avant toute action

## Cas Limites (Edge Cases)

- Que se passe-t-il si le script est interrompu en pleine execution (Ctrl+C, perte SSH) ? -> Idempotence : relancer le script reprend la ou il en etait
- Que se passe-t-il si l'utilisateur Terraform existe deja mais avec un role different ? -> Avertir l'utilisateur, ne pas ecraser la configuration existante
- Que se passe-t-il si le telechargement de l'image cloud Ubuntu echoue (reseau instable) ? -> Afficher un message d'erreur clair avec l'URL et suggerer un re-essai
- Que se passe-t-il si le template VM avec l'ID demande existe deja ? -> Avertir et proposer de passer l'etape
- Que se passe-t-il si le storage local-lvm n'existe pas ? -> Detecter et signaler l'erreur avant de tenter la creation du template
- Que se passe-t-il si un fichier `.sources` enterprise n'existe pas (deja desactive manuellement) ? -> Ignorer silencieusement, continuer
- Que se passe-t-il si l'espace disque est insuffisant pour telecharger l'image cloud (~700 MB) ? -> Verifier l'espace disponible avant le telechargement

## Criteres de Succes (mesurables)

- **CS-001**: Le script complete toutes les etapes sur une installation PVE 9.x fraiche sans erreur
- **CS-002**: Le script est re-executable sans effet de bord (idempotence verifiee)
- **CS-003**: L'option `--help` affiche l'aide et retourne le code 0
- **CS-004**: Le script passe `shellcheck` sans erreur
- **CS-005**: Apres execution, `terraform plan` fonctionne avec les credentials generees
- **CS-006**: La documentation permet a un nouvel utilisateur de completer l'installation de bout en bout

## Hors Scope (explicitement exclus)

- Installation physique de Proxmox VE (etapes 1-4 du guide existant) - reste manuelle par nature
- Configuration reseau avancee (VLAN, bonding, SDN) - trop specifique a chaque setup
- Configuration de Ceph / stockage distribue - non pertinent pour un setup single-node homelab
- Gestion des mises a jour continues (unattended-upgrades) - sera traitee dans une future iteration
- Configuration de sauvegardes automatisees (PBS) - hors perimetre de la post-installation
- Monitoring et alerting (couvert par le module monitoring-stack existant)

## Hypotheses et Dependances

### Hypotheses
- L'administrateur a un acces physique ou console au node Proxmox pour l'installation initiale
- Le node a un acces Internet fonctionnel (pour telecharger les packages et templates)
- L'installation Proxmox VE est standard (pas de configuration exotique du stockage)
- L'administrateur utilise un poste de travail Linux ou macOS pour la connexion SSH

### Dependances
- Installation Proxmox VE fonctionnelle (etapes 1-4 completees)
- Acces reseau entre le poste de travail et le node Proxmox
- Conventions de logging du projet (alignees sur `install-node-exporter.sh`)
- Documentation existante `docs/INSTALLATION-PROXMOX.md` comme base a modifier

## Points de Clarification

> Aucun point de clarification en suspens. Les choix suivants ont ete valides :
> - Certificat Let's Encrypt ACME : exclu (inutile en reseau local)
> - 2FA : mentionne comme optionnel dans la documentation
> - Branche : `feature/post-install-script` depuis `feature/monitoring-stack`
