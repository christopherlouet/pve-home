# Guide d'onboarding

Guide pour decouvrir et comprendre le projet PVE-Home en 30 minutes.

## Parcours de lecture

```
README.md                          # Vue d'ensemble (5 min)
  -> docs/ARCHITECTURE.md          # Architecture multi-environnements (5 min)
  -> infrastructure/proxmox/README.md  # Structure Terraform (5 min)
  -> environments/prod/main.tf     # Exemple concret d'utilisation (5 min)
  -> modules/vm/                   # Comprendre un module (10 min)
```

## Concepts cles

### 3 environnements isoles

| Environnement | PVE Node | Usage | Reseau |
|---------------|----------|-------|--------|
| **prod** | pve-prod | VMs applicatives (web, db, etc.) | 192.168.1.0/24 |
| **lab** | pve-lab | Tests et experimentation | 192.168.2.0/24 |
| **monitoring** | pve-monitoring | Prometheus, Grafana, Minio, Tooling | 192.168.1.0/24 |

Chaque environnement a son propre state Terraform (voir [ADR-001](adr/001-three-environment-separation.md)).

### 6 modules reutilisables

| Module | Role | Utilise par |
|--------|------|-------------|
| **vm** | Deployer une VM avec cloud-init | prod, lab |
| **lxc** | Deployer un conteneur LXC | prod, lab |
| **backup** | Configurer les jobs vzdump | prod, lab, monitoring |
| **minio** | Conteneur LXC Minio S3 | monitoring |
| **monitoring-stack** | Prometheus, Grafana, Alertmanager, Loki | monitoring |
| **tooling-stack** | Step-ca, Harbor, Authentik, Traefik | monitoring |

### Variables partagees via symlinks

Les variables communes (SSH keys, DNS, gateway) sont definies une seule fois dans `shared/` et symlinkes dans chaque environnement (voir [ADR-002](adr/002-shared-variables-symlinks.md)).

```
shared/common_variables.tf  -->  environments/prod/common_variables.tf (symlink)
shared/env_variables.tf     -->  environments/prod/env_variables.tf (symlink)
```

## Premier deploiement

### Prerequis

```bash
# Verifier Terraform >= 1.9
terraform version

# Verifier l'acces au node Proxmox
curl -k https://<PVE_IP>:8006/api2/json/version
```

### Etapes

```bash
# 1. Cloner le repo
git clone https://github.com/christopherlouet/pve-home.git
cd pve-home

# 2. Configurer l'environnement prod
cd infrastructure/proxmox/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Editer terraform.tfvars avec vos valeurs (IP, token, SSH keys)

# 3. Initialiser et deployer
terraform init
terraform plan    # Verifier les changements
terraform apply   # Appliquer
```

### Verification

```bash
# SSH dans une VM deployee
ssh ubuntu@<VM_IP>

# Health check (depuis la VM monitoring)
./scripts/check-health.sh --env prod --dry-run
```

## Taches courantes

### Ajouter une VM

Dans `environments/prod/main.tf` :

```hcl
module "vms" {
  source = "../../modules/vm"
  # ...
  vms = {
    "ma-nouvelle-vm" = {
      target_node = "pve-prod"
      ip_address  = "192.168.1.20/24"
      cpu_cores   = 2
      memory_mb   = 4096
      disk_size_gb = 30
    }
  }
}
```

### Ajouter un conteneur LXC

```hcl
module "lxc" {
  source = "../../modules/lxc"
  # ...
  containers = {
    "mon-conteneur" = {
      target_node   = "pve-prod"
      ip_address    = "192.168.1.21/24"
      template_name = "ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    }
  }
}
```

### Lancer les tests

```bash
# Tests Terraform (un module)
cd infrastructure/proxmox/modules/vm
terraform init -backend=false && terraform test

# Tests BATS (tous les scripts)
bats --recursive tests/

# Tests Terraform (tous les modules)
for m in vm lxc backup minio monitoring-stack tooling-stack; do
  (cd infrastructure/proxmox/modules/$m && terraform init -backend=false && terraform test)
done
```

## Architecture des tests

Le projet utilise deux frameworks de test (voir [ADR-003](adr/003-native-terraform-tests.md) et [ADR-004](adr/004-bats-static-analysis.md)) :

| Framework | Fichiers | Approche |
|-----------|----------|----------|
| `terraform test` | `*.tftest.hcl` | Mock provider, validation plan-level |
| BATS | `tests/**/*.bats` | Analyse statique grep-based (pas d'infra requise) |

### Types de tests Terraform par module

| Fichier | Role |
|---------|------|
| `valid_inputs.tftest.hcl` | Bornes des variables (CPU, RAM, disk, formats) |
| `plan_resources.tftest.hcl` | Ressources generees par `terraform plan` |
| `regression.tftest.hcl` | Non-regression de bugs corriges |
| `outputs.tftest.hcl` | Structure des outputs |

## Documentation de reference

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Architecture multi-environnements |
| [INSTALLATION-PROXMOX.md](INSTALLATION-PROXMOX.md) | Installation Proxmox de zero |
| [BACKUP-RESTORE.md](BACKUP-RESTORE.md) | Strategies de sauvegarde et restauration |
| [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) | Plan de reprise apres sinistre |
| [HEALTH-CHECKS.md](HEALTH-CHECKS.md) | Surveillance de la sante |
| [VM-LIFECYCLE.md](VM-LIFECYCLE.md) | Snapshots, expiration, rotation SSH |
| [ALERTING.md](ALERTING.md) | Configuration des alertes Telegram |
| [DRIFT-DETECTION.md](DRIFT-DETECTION.md) | Detection de derive Terraform |
| [TOOLING-STACK.md](TOOLING-STACK.md) | PKI, Harbor, Authentik |
| [adr/](adr/) | Architecture Decision Records (6 ADRs) |
