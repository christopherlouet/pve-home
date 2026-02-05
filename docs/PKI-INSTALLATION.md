# Installation de la PKI Homelab (Step-ca)

Guide d'installation et de configuration de l'autorité de certification interne Step-ca.

## Table des matières

- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation du certificat racine](#installation-du-certificat-racine)
- [Utilisation avec ACME](#utilisation-avec-acme)
- [Intégration avec les services](#intégration-avec-les-services)
- [Dépannage](#dépannage)

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │         Step-ca (PKI)               │
                    │   https://pki.home.arpa:8443        │
                    │                                     │
                    │  ┌───────────┐  ┌───────────────┐  │
                    │  │  Root CA  │  │ ACME Provider │  │
                    │  │ (10 ans)  │  │   (auto TLS)  │  │
                    │  └───────────┘  └───────────────┘  │
                    └─────────────────────────────────────┘
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
          ▼                          ▼                          ▼
    ┌───────────┐            ┌───────────┐            ┌───────────┐
    │  Traefik  │            │  Harbor   │            │ Authentik │
    │   (TLS)   │            │   (TLS)   │            │   (TLS)   │
    └───────────┘            └───────────┘            └───────────┘
```

## Prérequis

- Accès réseau à `pki.home.arpa` (192.168.1.60)
- DNS configuré pour `*.home.arpa`
- Step CLI (optionnel, recommandé)

### Installation de Step CLI

```bash
# Linux (Debian/Ubuntu)
wget https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.deb
sudo dpkg -i step-cli_amd64.deb

# macOS
brew install step

# Windows (chocolatey)
choco install step-cli
```

## Installation du certificat racine

### Méthode 1 : Script automatique (recommandé)

```bash
# Télécharger et exécuter le script d'export
./scripts/tooling/export-ca.sh --all ./ca-certs

# Suivre les instructions affichées
```

### Méthode 2 : Step CLI

```bash
# Bootstrap avec Step-ca
step ca bootstrap --ca-url https://pki.home.arpa:8443 --fingerprint $(step certificate fingerprint root_ca.crt)

# Le certificat est automatiquement installé dans ~/.step/certs/root_ca.crt
```

### Méthode 3 : Manuelle

#### Linux (Debian/Ubuntu)

```bash
# Télécharger le certificat racine
curl -k https://pki.home.arpa:8443/roots.pem -o homelab-ca.pem

# Installer dans le store système
sudo cp homelab-ca.pem /usr/local/share/ca-certificates/homelab-ca.crt
sudo update-ca-certificates

# Vérifier
curl https://registry.home.arpa  # Pas de warning TLS
```

#### Linux (RHEL/CentOS/Fedora)

```bash
curl -k https://pki.home.arpa:8443/roots.pem -o homelab-ca.pem
sudo cp homelab-ca.pem /etc/pki/ca-trust/source/anchors/homelab-ca.pem
sudo update-ca-trust
```

#### macOS

```bash
curl -k https://pki.home.arpa:8443/roots.pem -o homelab-ca.pem
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain homelab-ca.pem
```

#### Windows (PowerShell Admin)

```powershell
# Télécharger
Invoke-WebRequest -Uri https://pki.home.arpa:8443/roots.pem -OutFile homelab-ca.crt

# Installer
Import-Certificate -FilePath homelab-ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```

### Docker

Pour que Docker fasse confiance au registre Harbor :

```bash
# Créer le répertoire de certificats
sudo mkdir -p /etc/docker/certs.d/registry.home.arpa

# Copier le certificat CA
sudo cp homelab-ca.pem /etc/docker/certs.d/registry.home.arpa/ca.crt

# Redémarrer Docker
sudo systemctl restart docker
```

### Navigateurs

| Navigateur | Installation |
|------------|--------------|
| Firefox | Settings > Privacy & Security > Certificates > Import |
| Chrome/Edge | Utilise le store système (installer comme ci-dessus) |
| Safari | Utilise le store système macOS |

## Utilisation avec ACME

Step-ca fournit un endpoint ACME compatible Let's Encrypt.

### Configuration Traefik

```yaml
certificatesResolvers:
  step-ca:
    acme:
      email: admin@home.arpa
      storage: /certs/acme.json
      caServer: https://pki.home.arpa:8443/acme/acme/directory
      tlsChallenge: {}
```

### Configuration Caddy

```caddyfile
{
    acme_ca https://pki.home.arpa:8443/acme/acme/directory
    acme_ca_root /path/to/homelab-ca.pem
}

registry.home.arpa {
    reverse_proxy harbor-core:8080
}
```

### Génération manuelle de certificat

```bash
# Avec Step CLI
step ca certificate myservice.home.arpa myservice.crt myservice.key \
  --ca-url https://pki.home.arpa:8443

# Avec certbot (ACME)
certbot certonly --standalone \
  --server https://pki.home.arpa:8443/acme/acme/directory \
  -d myservice.home.arpa
```

## Intégration avec les services

### Harbor

Harbor est configuré automatiquement pour utiliser les certificats TLS via Traefik.

```bash
# Test de connexion
docker login registry.home.arpa -u admin

# Push d'une image
docker tag myimage:latest registry.home.arpa/library/myimage:latest
docker push registry.home.arpa/library/myimage:latest
```

### Grafana

Grafana accède aux métriques via HTTPS avec le certificat CA.

```ini
# Dans grafana.ini ou variables d'environnement
[server]
root_url = https://grafana.home.arpa
```

### Prometheus

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'step-ca'
    scheme: https
    tls_config:
      ca_file: /etc/prometheus/homelab-ca.pem
    static_configs:
      - targets: ['pki.home.arpa:9290']
```

## Dépannage

### Erreur "certificate signed by unknown authority"

Le certificat racine n'est pas installé sur le client.

```bash
# Vérifier l'installation
openssl s_client -connect pki.home.arpa:8443 -CAfile /path/to/homelab-ca.pem

# Doit afficher "Verify return code: 0 (ok)"
```

### Erreur "x509: certificate is valid for X, not Y"

Le nom demandé ne correspond pas au certificat.

```bash
# Vérifier les noms dans le certificat
openssl s_client -connect registry.home.arpa:443 </dev/null 2>/dev/null | \
  openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
```

### Certificat expiré

Les certificats ACME ont une durée de 90 jours par défaut (configurable).

```bash
# Vérifier l'expiration
echo | openssl s_client -connect registry.home.arpa:443 2>/dev/null | \
  openssl x509 -noout -dates
```

### Step-ca ne démarre pas

```bash
# Vérifier les logs
docker logs step-ca

# Vérifier la santé
curl -k https://pki.home.arpa:8443/health
```

### Renouvellement automatique

Traefik renouvelle automatiquement les certificats via ACME. Pour les certificats manuels :

```bash
# Avec step CLI
step ca renew myservice.crt myservice.key --force

# Configurer le renouvellement automatique
step ca renew myservice.crt myservice.key --daemon
```

## Références

- [Step-ca Documentation](https://smallstep.com/docs/step-ca)
- [ACME Protocol (RFC 8555)](https://tools.ietf.org/html/rfc8555)
- [home.arpa (RFC 8375)](https://tools.ietf.org/html/rfc8375)
