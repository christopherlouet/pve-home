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
./scripts/health/check-health.sh --all

# Filtrer par composant
./scripts/health/check-health.sh --env monitoring --component monitoring

# Exclure des composants
./scripts/health/check-health.sh --all --exclude "dev-server,test-vm"

# Timeout personnalise (secondes)
./scripts/health/check-health.sh --all --timeout 30

# Mode dry-run
./scripts/health/check-health.sh --all --dry-run
```

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

## Troubleshooting

### Faux positifs sur SSH
- Verifier que la cle SSH de l'operateur est deployee sur les VMs
- Augmenter le timeout avec `--timeout 30`

### Metriques manquantes
- Verifier le repertoire `/var/lib/prometheus/node-exporter`
- Verifier les permissions d'ecriture
