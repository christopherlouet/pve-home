# ADR-006: Actions CI pinnees par SHA

## Statut

Accepted

## Contexte

Les GitHub Actions sont des dependances tierces executees avec les permissions du repository. Un tag mutable (`@v4`) peut etre modifie par le mainteneur pour injecter du code malveillant (supply chain attack).

## Decision

Pinner **toutes** les GitHub Actions par commit SHA au lieu de tags :

```yaml
# Avant (vulnerable)
uses: actions/checkout@v6

# Apres (securise)
uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6
```

Le commentaire en fin de ligne garde la lisibilite du numero de version.

## Consequences

### Positif

- **Immunite aux supply chain attacks** : Le SHA est immutable
- **Reproductibilite** : Le meme commit est toujours execute
- **Audit trail** : Chaque mise a jour de SHA est visible dans le diff Git
- **Securite CI** : Aligne avec les recommandations OSSF Scorecard

### Negatif

- **Mises a jour manuelles** : Pas d'auto-update via Dependabot par defaut
- **Lisibilite reduite** : Les SHA sont longs (atenue par le commentaire version)
- **Effort initial** : Convertir toutes les references existantes

## Actions pinnees dans le projet

| Action | SHA | Version |
|--------|-----|---------|
| actions/checkout | de0fac2e... | v6 |
| hashicorp/setup-terraform | b9cd54a3... | v3 |
| actions/cache | 0057852b... | v4 |
| gitleaks/gitleaks-action | dcedce43... | v2 |
| aquasecurity/tfsec-action | 49ea7e3f... | v1 |
| bridgecrewio/checkov-action | 16e70a06... | v12 |
| aquasecurity/trivy-action | b6643a29... | 0.33.1 |
| terraform-docs/gh-actions | 6de6da0c... | v1 |
| DavidAnson/markdownlint-cli2-action | 07035fd0... | v22 |
