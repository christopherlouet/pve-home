# ADR-003: Tests natifs Terraform avec mock_provider

## Statut

Accepted

## Contexte

Les modules Terraform doivent etre testes sans infrastructure Proxmox reelle. Plusieurs frameworks existent : Terratest (Go), kitchen-terraform (Ruby), terraform test (natif >= 1.6).

## Decision

Utiliser le framework de test **natif Terraform** (`terraform test` >= 1.6) avec `mock_provider` pour tester les modules au niveau `plan` sans connexion reelle.

Structure de tests par module :
- `valid_inputs.tftest.hcl` : Validation des variables (bornes, formats, regex)
- `plan_resources.tftest.hcl` : Verification des ressources generees
- `regression.tftest.hcl` : Non-regression des bugs corriges
- `outputs.tftest.hcl` : Coherence des outputs

## Consequences

### Positif

- **Zero dependance externe** : Pas de Go, Ruby, ou binaire supplementaire
- **Rapide** : Tests `plan` en quelques secondes (pas d'apply)
- **CI simple** : `terraform init && terraform test` suffit
- **mock_provider** : Simule le provider sans API reelle
- **524 tests** couvrent les 6 modules et 3 environnements

### Negatif

- **Pas de test d'apply** : Les erreurs runtime (API Proxmox) ne sont pas detectees
- **Valeurs provider-computed** : Certains outputs ne sont pas evaluables en plan
- **Maturite** : Framework relativement recent (GA en Terraform 1.6, 2023)

## Alternatives considerees

1. **Terratest** : Rejete (necessite Go, tests lents avec apply/destroy)
2. **kitchen-terraform** : Rejete (Ruby, moins maintenu)
3. **Pas de tests** : Rejete (regression inevitables)
4. **Tests manuels `terraform plan`** : Rejete (non reproductible, pas CI)
