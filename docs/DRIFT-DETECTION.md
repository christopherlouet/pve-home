# Detection de drift infrastructure

Detection automatique des changements non planifies entre l'etat Terraform et l'infrastructure Proxmox reelle.

## Fonctionnement

Le script `scripts/drift/check-drift.sh` execute `terraform plan -detailed-exitcode` sur chaque environnement :

- **Code 0** : Conforme, aucun drift
- **Code 1** : Erreur Terraform (credentials, lock, reseau)
- **Code 2** : Drift detecte (ressources modifiees/ajoutees/supprimees)

Les resultats sont exposes en metriques Prometheus via le textfile collector de node_exporter.

## Installation

### 1. Deployer le script

```bash
# Cloner le depot sur le noeud monitoring
cd /opt
git clone <repo-url> pve-home

# Verifier les prerequis
/opt/pve-home/scripts/drift/check-drift.sh --help
```

### 2. Activer le timer systemd

```bash
cp /opt/pve-home/scripts/systemd/pve-drift-check.service /etc/systemd/system/
cp /opt/pve-home/scripts/systemd/pve-drift-check.timer /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now pve-drift-check.timer

# Verifier le statut
systemctl status pve-drift-check.timer
systemctl list-timers pve-drift-check.timer
```

### 3. Configurer le textfile collector

S'assurer que node_exporter est lance avec le flag `--collector.textfile.directory=/var/lib/prometheus/node-exporter`.

```bash
mkdir -p /var/lib/prometheus/node-exporter
```

## Utilisation

```bash
# Verifier un environnement specifique
./scripts/drift/check-drift.sh --env prod

# Verifier tous les environnements
./scripts/drift/check-drift.sh --all

# Mode dry-run (pas d'execution Terraform)
./scripts/drift/check-drift.sh --all --dry-run
```

## Metriques Prometheus

| Metrique | Description |
|----------|-------------|
| `pve_drift_status{env}` | 0=conforme, 1=drift, 2=erreur |
| `pve_drift_resources_changed{env}` | Nombre de ressources en drift |
| `pve_drift_last_check_timestamp{env}` | Timestamp du dernier check |

## Alertes

| Alerte | Severite | Condition |
|--------|----------|-----------|
| `DriftDetected` | warning | `pve_drift_status == 1` pendant 5m |
| `DriftCheckFailed` | critical | `pve_drift_status == 2` pendant 5m |
| `DriftCheckStale` | warning | Pas de check depuis 48h |

## Reconciliation du drift

Quand un drift est detecte :

1. **Identifier** : Consulter le rapport dans `/var/log/pve-drift/` ou le dashboard Grafana
2. **Analyser** : Determiner si le changement etait intentionnel (maintenance manuelle) ou non
3. **Decider** :
   - Si le changement Proxmox est correct : `terraform import` ou modifier le `.tf`
   - Si l'etat Terraform est correct : `terraform apply` pour restaurer
4. **Verifier** : Relancer `./check-drift.sh --env <env>` pour confirmer la resolution

## Logs

Les rapports sont stockes dans `/var/log/pve-drift/drift-YYYY-MM-DD-ENV.log` avec une rotation automatique de 30 jours.

## Troubleshooting

### Le check echoue avec "Init failed"
- Verifier que les providers sont accessibles (reseau)
- Verifier que `terraform init` fonctionne manuellement dans l'environnement

### Le check echoue avec "Erreur Terraform"
- Verifier les credentials dans `terraform.tfvars`
- Verifier que le fichier state n'est pas verrouille
- Verifier l'accessibilite du noeud Proxmox

### Pas de metriques dans Prometheus
- Verifier que le repertoire `/var/lib/prometheus/node-exporter` existe
- Verifier que node_exporter est configure avec `--collector.textfile.directory`
- Verifier les permissions du fichier `.prom`
