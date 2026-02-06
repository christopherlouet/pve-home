# ADR-002: Variables partagees via symlinks

## Statut

Accepted

## Contexte

Avec 3 environnements et 6 modules, certaines variables sont identiques (provider config, network settings, common tags). La duplication entraine des inconsistances lors des mises a jour.

## Decision

Utiliser des **symlinks filesystem** pour partager les fichiers de variables et de locals entre environnements/modules :

```
infrastructure/proxmox/shared/
├── common_variables.tf        -> environments/*/
├── env_variables.tf           -> environments/prod/, environments/lab/
├── expiration_variables.tf    -> modules/vm/, modules/lxc/
├── expiration_locals.tf       -> modules/vm/, modules/lxc/
├── firewall_locals.tf         -> environments/*/
└── docker-install-runcmd.json.tpl -> modules/vm/, modules/monitoring-stack/
```

La CI valide l'integrite des symlinks via le job `terraform-consistency`.

## Consequences

### Positif

- **DRY** : Une seule source de verite pour les variables partagees
- **Atomique** : Modifier un fichier met a jour tous les consommateurs
- **Valide en CI** : Les symlinks casses sont detectes automatiquement
- **Natif Terraform** : Terraform suit les symlinks nativement, aucun outil supplementaire

### Negatif

- **Visibilite reduite** : `ls` ne montre pas que le fichier est un symlink sans `-l`
- **Portabilite Windows** : Les symlinks necessitent des privileges ou Git config specifique
- **IDE support** : Certains IDE ne suivent pas les symlinks pour l'autocompletion

## Alternatives considerees

1. **Copier-coller** : Rejete (drift inevitable)
2. **Terraform modules pour variables** : Rejete (over-engineering, pas supporte nativement)
3. **Terragrunt generate blocks** : Rejete (ajout de dependance)
4. **Git submodules** : Rejete (complexite de gestion)
