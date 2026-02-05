# Stack Tooling Homelab

Stack d'outillage interne pour homelab : PKI, Registry Docker, SSO.

## Vue d'ensemble

| Service | Description | Port | URL |
|---------|-------------|------|-----|
| **Step-ca** | Autorité de certification interne | 8443 | `https://pki.home.arpa` |
| **Harbor** | Registre Docker privé | 443 | `https://registry.home.arpa` |
| **Authentik** | SSO (Single Sign-On) | 9000 | `https://auth.home.arpa` |
| **Traefik** | Reverse proxy | 80/443 | `https://traefik.home.arpa` |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     VM Tooling (192.168.1.60)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Step-ca    │    │    Harbor    │    │   Authentik  │      │
│  │   (PKI)      │    │  (Registry)  │    │    (SSO)     │      │
│  │   :8443      │    │    :443      │    │    :9000     │      │
│  │   :9290 ←────│────│──────────────│────│────→ :9300   │      │
│  │   (metrics)  │    │    :9090     │    │   (metrics)  │      │
│  └──────┬───────┘    │   (metrics)  │    └──────┬───────┘      │
│         │            └──────┬───────┘           │              │
│         │                   │                   │              │
│         │    ┌──────────────┴───────────────┐   │              │
│         └────│          Traefik             │───┘              │
│              │    (Reverse Proxy + TLS)     │                  │
│              │        :80 / :443            │                  │
│              └──────────────┬───────────────┘                  │
│                             │                                  │
│                    ┌────────┴────────┐                         │
│                    │   Node Exporter │                         │
│                    │      :9100      │                         │
│                    └─────────────────┘                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Prometheus    │
                    │ (monitoring VM) │
                    └─────────────────┘
```

## Prérequis

### Matériel

| Ressource | Minimum | Recommandé |
|-----------|---------|------------|
| CPU | 2 cores | 4 cores |
| RAM | 4 GB | 8 GB |
| Disque système | 30 GB | 50 GB |
| Disque données | 100 GB | 200 GB |

### Réseau

Configurer les enregistrements DNS suivants (OPNsense/Pi-hole) :

```
pki.home.arpa      → 192.168.1.60
registry.home.arpa → 192.168.1.60
auth.home.arpa     → 192.168.1.60
traefik.home.arpa  → 192.168.1.60
```

## Déploiement

### 1. Configuration

Éditer `infrastructure/proxmox/environments/monitoring/terraform.tfvars` :

```hcl
tooling = {
  enabled = true
  vm = {
    ip        = "192.168.1.60"
    cores     = 4
    memory    = 8192
    disk      = 50
    data_disk = 200
  }
  domain_suffix   = "home.arpa"
  traefik_enabled = true

  step_ca = {
    enabled  = true
    password = "votre-mot-de-passe-ca"
  }

  harbor = {
    enabled        = true
    admin_password = "votre-mot-de-passe-harbor"
  }

  authentik = {
    enabled            = true
    secret_key         = "votre-cle-secrete-50-caracteres-minimum"
    bootstrap_password = "votre-mot-de-passe-admin"
  }
}
```

### 2. Déploiement

```bash
cd infrastructure/proxmox/environments/monitoring
terraform init
terraform plan
terraform apply
```

Ou utiliser le script de reconstruction :

```bash
./scripts/restore/rebuild-tooling.sh
```

### 3. Vérification

```bash
# Status des services
terraform output tooling

# Santé Traefik
curl -s http://192.168.1.60:8082/ping

# Santé Step-ca (HTTPS, certificat auto-signé)
curl -sk https://192.168.1.60:8443/health

# Interface Harbor
open https://registry.home.arpa

# Interface Authentik
open https://auth.home.arpa
```

## Step-ca (PKI)

### Installation du certificat racine

#### Linux (Debian/Ubuntu)

```bash
# Télécharger le certificat
curl -sk https://pki.home.arpa/roots.pem -o /tmp/homelab-ca.crt

# Installer
sudo cp /tmp/homelab-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

#### macOS

```bash
curl -sk https://pki.home.arpa/roots.pem -o ~/homelab-ca.crt
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain ~/homelab-ca.crt
```

#### Windows (PowerShell Admin)

```powershell
Invoke-WebRequest -Uri https://pki.home.arpa/roots.pem -OutFile homelab-ca.crt
Import-Certificate -FilePath homelab-ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```

### Génération de certificats

```bash
# Installer step CLI
curl -sLO https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb
sudo dpkg -i step-cli_amd64.deb

# Bootstrap (une seule fois)
step ca bootstrap --ca-url https://pki.home.arpa --fingerprint <FINGERPRINT>

# Générer un certificat
step ca certificate myapp.home.arpa myapp.crt myapp.key
```

### Configuration ACME (Traefik)

Traefik est préconfiguré pour utiliser Step-ca via ACME. Les certificats sont générés automatiquement.

## Harbor (Registry)

### Connexion Docker

```bash
# Login
docker login registry.home.arpa -u admin

# Push une image
docker tag myapp:latest registry.home.arpa/library/myapp:v1
docker push registry.home.arpa/library/myapp:v1

# Pull une image
docker pull registry.home.arpa/library/myapp:v1
```

### Garbage Collection

Le garbage collection est planifié automatiquement. Pour un GC manuel :

```bash
./scripts/tooling/harbor-gc.sh
```

### Scan de vulnérabilités

Trivy est activé par défaut. Les images sont scannées automatiquement après push.

```bash
# Voir les vulnérabilités dans l'UI
open https://registry.home.arpa/harbor/projects/1/repositories/myapp

# Ou via API
curl -s -u admin:PASSWORD \
    "https://registry.home.arpa/api/v2.0/projects/library/repositories/myapp/artifacts/v1/vulnerabilities"
```

## Authentik (SSO)

### Accès admin

- URL : `https://auth.home.arpa/if/admin/`
- User : `akadmin`
- Password : défini dans `authentik.bootstrap_password`

### Configuration SSO Grafana

Un blueprint Authentik préconfigré crée automatiquement le provider OAuth2 pour Grafana.

Dans Grafana (`grafana.ini` ou variables d'environnement) :

```ini
[auth.generic_oauth]
enabled = true
name = Authentik
client_id = grafana
client_secret = <GENERATED_SECRET>
auth_url = https://auth.home.arpa/application/o/authorize/
token_url = https://auth.home.arpa/application/o/token/
api_url = https://auth.home.arpa/application/o/userinfo/
scopes = openid profile email
```

### Configuration SSO Harbor

Harbor est préconfiguré pour utiliser Authentik comme provider OIDC.

1. Dans Harbor Admin > Configuration > Authentication
2. Sélectionner "OIDC"
3. Les paramètres sont préremplis par le blueprint

## Monitoring

### Dashboards Grafana

Trois dashboards sont automatiquement provisionnés dans le dossier "Tooling" :

| Dashboard | Métriques |
|-----------|-----------|
| **Step-ca - PKI Monitoring** | CA Health, Certificates Issued, ACME Requests, Root CA Expiry |
| **Harbor - Registry Monitoring** | Storage, Projects, Vulnerabilities, Push/Pull Rate |
| **Authentik - SSO Monitoring** | System Health, Logins, Users, OAuth tokens |

### Alertes

| Service | Alerte | Sévérité |
|---------|--------|----------|
| Step-ca | StepCaDown | Critical |
| Step-ca | StepCaRootCAExpiringSoon | Warning |
| Step-ca | StepCaRootCAExpiryCritical | Critical |
| Harbor | HarborDown | Critical |
| Harbor | HarborStorageCritical | Critical |
| Harbor | HarborCriticalVulnerabilities | Warning |
| Authentik | AuthentikDown | Critical |
| Authentik | AuthentikHighLoginFailureRate | Warning |
| Authentik | AuthentikLoginFailureSpike | Warning |
| Traefik | TraefikToolingDown | Critical |
| Traefik | TraefikCertificateExpiryCritical | Critical |

## Backup et Restauration

### Données à sauvegarder

| Service | Données | Chemin |
|---------|---------|--------|
| Step-ca | Clés CA, config | `/opt/tooling/step-ca/` |
| Harbor | Base de données, config | `/opt/tooling/harbor/database/` |
| Harbor | Images Docker | `/opt/tooling/harbor/registry/` |
| Authentik | Base de données | `/opt/tooling/authentik/database/` |

### Backup vzdump

La VM est automatiquement sauvegardée par vzdump (configuré dans `backup.tf`).

### Restauration

1. Restaurer la VM depuis une sauvegarde vzdump :
   ```bash
   qmrestore /var/lib/vz/dump/vzdump-qemu-XXX.vma.zst XXX
   ```

2. Ou reconstruire depuis Terraform :
   ```bash
   ./scripts/restore/rebuild-tooling.sh
   ```

## Dépannage

### Services ne démarrent pas

```bash
# Vérifier les logs Docker
ssh ubuntu@192.168.1.60
cd /opt/tooling
docker compose logs -f

# Vérifier un service spécifique
docker compose logs step-ca
docker compose logs harbor-core
docker compose logs authentik-server
```

### Certificats ACME échouent

```bash
# Vérifier les logs Traefik
docker compose logs traefik

# Vérifier la résolution DNS
nslookup pki.home.arpa
nslookup registry.home.arpa

# Tester Step-ca manuellement
curl -sk https://192.168.1.60:8443/health
```

### Harbor ne démarre pas

```bash
# Vérifier les prérequis Harbor
docker compose logs harbor-db
docker compose logs harbor-redis

# Réinitialiser Harbor (ATTENTION: perte de données)
docker compose down -v
docker compose up -d
```

### Authentik erreur de connexion

```bash
# Vérifier les logs
docker compose logs authentik-server
docker compose logs authentik-worker

# Vérifier Redis et PostgreSQL
docker compose logs redis
docker compose logs postgresql
```

## Références

- [Step-ca Documentation](https://smallstep.com/docs/step-ca/)
- [Harbor Documentation](https://goharbor.io/docs/)
- [Authentik Documentation](https://docs.goauthentik.io/)
- [RFC 8375 - home.arpa](https://www.rfc-editor.org/rfc/rfc8375.html)
