# ADR-001: Separation en 3 environnements Terraform

## Statut

Accepted

## Contexte

Le homelab Proxmox heberge des workloads de nature differente : production, experimentation, et monitoring/outillage. Il faut decider comment organiser les states Terraform.

## Decision

Separer l'infrastructure en **3 environnements independants** avec des states Terraform distincts :

- **prod** : Workloads de production (VMs, LXC)
- **lab** : Environnement d'experimentation avec expiration automatique
- **monitoring** : PVE dedie au monitoring (Prometheus, Grafana) et outillage (PKI, Registry, SSO)

Chaque environnement a son propre `terraform.tfvars`, backend S3, et state file.

## Consequences

### Positif

- **Isolation des blast radius** : Un `terraform destroy` en lab n'affecte pas la prod
- **Gestion de state simplifiee** : Pas de state monolithique avec des centaines de resources
- **Permissions granulaires** : Possibilite de restreindre l'acces par environnement
- **Deploiements independants** : Chaque environnement peut evoluer a son propre rythme

### Negatif

- **Duplication de variables** : Resolu par les symlinks (voir ADR-002)
- **Pas de references croisees** : Les environnements ne peuvent pas referencer les outputs des autres directement
- **Maintenance des 3 backends** : 3 configurations S3 a maintenir

## Alternatives considerees

1. **Monorepo avec un seul state** : Rejete (blast radius trop large)
2. **Workspaces Terraform** : Rejete (meme backend, separation insuffisante)
3. **Terragrunt** : Rejete (complexite supplementaire non justifiee pour un homelab)
