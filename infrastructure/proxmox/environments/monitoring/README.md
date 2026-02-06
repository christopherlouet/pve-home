# Environnement Monitoring

PVE dedie au monitoring centralise de tous les environnements (prod, lab).

## Objectif

Deployer et operer la stack d'observabilite : Prometheus, Grafana, Alertmanager, Loki, Uptime Kuma. Optionnellement, la stack tooling : Step-ca (PKI), Harbor (Registry), Authentik (SSO).

## Ressources deployees

| Type | Module | Description |
|------|--------|-------------|
| Monitoring VM | `modules/monitoring-stack` | Prometheus, Grafana, Alertmanager, Loki |
| Tooling VM | `modules/tooling-stack` | Step-ca, Harbor, Authentik, Traefik (optionnel) |
| Minio LXC | `modules/minio` | Backend S3 pour Terraform state |
| Backup | `modules/backup` | Sauvegardes vzdump quotidiennes |
| Firewall | inline | Regles par VM/service |

## Reseau

| Parametre | Valeur par defaut |
|-----------|-------------------|
| Bridge | `vmbr0` |
| Gateway | `192.168.1.1` |
| CIDR | `/24` |
| DNS | `1.1.1.1`, `8.8.8.8` |

### Ports exposes (monitoring)

| Port | Service |
|------|---------|
| 3000 | Grafana |
| 9090 | Prometheus |
| 9093 | Alertmanager |
| 3100 | Loki API |
| 3001 | Uptime Kuma |
| 8080 | Traefik Dashboard |

### Ports exposes (tooling, si active)

| Port | Service |
|------|---------|
| 80/443 | Traefik (HTTP/HTTPS) |
| 8443 | Step-ca ACME |
| 9000 | Authentik |

## Variables

| Fichier | Source | Contenu |
|---------|--------|---------|
| `common_variables.tf` | symlink `shared/` | Proxmox endpoint, SSH, reseau |
| `firewall_locals.tf` | symlink `shared/` | Regles firewall partagees |
| `variables.tf` | local | monitoring, tooling, minio, backup, remote_targets |
| `monitoring.tf` | local | Module monitoring-stack + firewall |
| `tooling.tf` | local | Module tooling-stack + firewall (conditionnel) |
| `minio.tf` | local | Module minio (S3 backend) |

## Deploiement

```bash
# 1. Configurer les variables
cp terraform.tfvars.example terraform.tfvars
# Editer terraform.tfvars avec vos valeurs
# - proxmox_nodes : tous les PVE a monitorer avec tokens API
# - grafana_admin_password
# - minio root_password

# 2. Initialiser
terraform init

# 3. Planifier
terraform plan

# 4. Appliquer
terraform apply

# 5. Recuperer la cle SSH pour health checks (a ajouter dans env prod)
terraform output health_check_ssh_public_key
```

## Operations courantes

```bash
# URLs des services
terraform output monitoring

# Ajouter des cibles de monitoring distantes
# Editer terraform.tfvars > remote_targets = [{ name = "...", ip = "..." }]
terraform plan && terraform apply

# Activer la stack tooling
# Editer terraform.tfvars > tooling.enabled = true
terraform plan && terraform apply

# Custom Prometheus scrape configs
# Editer terraform.tfvars > custom_scrape_configs = <<-YAML ... YAML
terraform plan && terraform apply
```

## Sauvegardes

| Parametre | Valeur |
|-----------|--------|
| Frequence | Quotidienne a 02:00 |
| Mode | snapshot |
| Compression | zstd |
| Retention | 7 daily |

## Fichiers

```
monitoring/
├── main.tf                  # Locals, outputs globaux
├── monitoring.tf            # Module monitoring-stack + firewall
├── tooling.tf               # Module tooling-stack + firewall (conditionnel)
├── minio.tf                 # Module minio (S3 backend)
├── backup.tf                # Jobs vzdump
├── variables.tf             # Toutes les variables (monitoring, tooling, minio, backup)
├── common_variables.tf      # -> shared/common_variables.tf
├── firewall_locals.tf       # -> shared/firewall_locals.tf
├── provider.tf              # Configuration provider Proxmox
├── backend.tf               # Backend S3 (Minio)
├── versions.tf              # Contraintes de version
├── terraform.tfvars.example # Exemple de configuration complet
└── tests/                   # Tests d'integration
```
