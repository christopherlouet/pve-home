# Health checks automatises

Verification periodique de la sante de l'infrastructure PVE : VMs, LXC, stack monitoring, et backend Minio.

## Fonctionnement

Le script `scripts/health/check-health.sh` effectue des verifications sur :

- **VMs/LXC** : ping, SSH, statut QEMU Guest Agent
- **Monitoring** : Prometheus (`/-/ready`), Grafana (`/api/health`), Alertmanager (`/-/ready`)
- **Minio** : endpoint sante (`/minio/health/live`)

## Installation

### 1. Deployer le script

```bash
cd /opt/pve-home
./scripts/health/check-health.sh --help
```

### 2. Activer le timer systemd

```bash
cp /opt/pve-home/scripts/systemd/pve-health-check.service /etc/systemd/system/
cp /opt/pve-home/scripts/systemd/pve-health-check.timer /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now pve-health-check.timer
```

## Utilisation

```bash
# Verifier un environnement
./scripts/health/check-health.sh --env prod

# Verifier tout
./scripts/health/check-health.sh --all --force

# Specifier l'utilisateur SSH (defaut: ubuntu pour les VMs cloud-init)
./scripts/health/check-health.sh --env prod --ssh-user root

# Filtrer par composant
./scripts/health/check-health.sh --env monitoring --component monitoring

# Exclure des composants
./scripts/health/check-health.sh --all --exclude "dev-server,test-vm"

# Timeout personnalise (secondes)
./scripts/health/check-health.sh --all --timeout 30

# Mode dry-run
./scripts/health/check-health.sh --all --dry-run
```

### Extraction des IPs

Les IPs des VMs sont extraites uniquement du bloc `vms = { ... }` dans les fichiers `terraform.tfvars`. Les autres adresses IP (DNS, gateway, Proxmox) sont ignorees pour eviter les faux positifs.

### Authentification SSH

Le health check se connecte en SSH aux VMs pour verifier leur disponibilite. L'utilisateur par defaut est `ubuntu` (standard cloud-init). La VM monitoring utilise une **keypair SSH dediee** generee automatiquement par Terraform (`tls_private_key` dans le module monitoring-stack) :

- **Cle privee** : provisionnee sur la VM monitoring dans `/root/.ssh/id_ed25519` via cloud-init
- **Cle publique** : exposee via l'output `health_check_ssh_public_key`, a ajouter dans `monitoring_ssh_public_key` de l'env prod

### Alertmanager

La verification de l'Alertmanager est ignoree automatiquement lorsque les notifications Telegram sont desactivees (`telegram.enabled = false`).

## Metriques Prometheus

| Metrique | Description |
|----------|-------------|
| `pve_health_status{env,component,type}` | 0=ok, 1=failed |
| `pve_health_last_check_timestamp{env}` | Timestamp du dernier check |
| `pve_health_components_total{env}` | Nombre total de composants |
| `pve_health_components_healthy{env}` | Nombre de composants sains |

## Alertes

| Alerte | Severite | Condition |
|--------|----------|-----------|
| `InfraHealthCheckFailed` | warning | Composant en echec pendant 5m |
| `HealthCheckStale` | warning | Pas de check depuis 8h |

## Exclusions

Pour exclure des composants de la verification :

```bash
# Via flag
./scripts/health/check-health.sh --all --exclude "dev-server,test-vm"
```

## Installation

### Deploiement automatise

Utiliser `deploy.sh` pour deployer le script et les timers sur la VM monitoring :

```bash
./scripts/deploy.sh
```

### Deploiement manuel

```bash
cp /opt/pve-home/scripts/systemd/pve-health-check.service /etc/systemd/system/
cp /opt/pve-home/scripts/systemd/pve-health-check.timer /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now pve-health-check.timer
```

## Troubleshooting

### SSH unreachable sur les VMs prod

1. **Verifier la keypair monitoring** : `ls -la /root/.ssh/id_ed25519` sur la VM monitoring
2. **Verifier les authorized_keys** : `grep "health_check" ~/.ssh/authorized_keys` sur les VMs cibles
3. **Tester manuellement** : `SSH_INIT_MODE=true sudo -E ssh -v ubuntu@<ip> exit` (ou initialiser d'abord avec `init_known_hosts <ip>`)
4. **Si la keypair manque** : cloud-init ne se re-execute pas sur les VMs existantes. Copier manuellement la cle publique (output `health_check_ssh_public_key`) dans `~ubuntu/.ssh/authorized_keys` sur les VMs cibles

### Faux positifs sur SSH
- Verifier que l'utilisateur SSH est correct (defaut: `ubuntu`, surcharger avec `--ssh-user`)
- Augmenter le timeout avec `--timeout 30`

### Metriques manquantes
- Verifier le repertoire `/var/lib/prometheus/node-exporter`
- Verifier les permissions d'ecriture
