# Gestion du cycle de vie des VMs/LXC

Outils pour gerer le cycle de vie complet des VMs et conteneurs LXC : mises a jour de securite, snapshots, expiration, et rotation des cles SSH.

## Mises a jour de securite automatiques

Les VMs et LXC deployes avec Terraform sont configures par defaut avec `unattended-upgrades` pour appliquer automatiquement les correctifs de securite.

### Configuration

```hcl
# Actif par defaut - pour desactiver :
module "vm" {
  # ...
  auto_security_updates = false
}
```

Le module configure :
- `unattended-upgrades` : uniquement les paquets de securite
- Pas de reboot automatique (alerte Prometheus si reboot necessaire)

### Alerte

`VMRebootRequired` : declenche si un hote necessite un reboot depuis plus de 24h.

## Snapshots

### Utilisation

```bash
# Creer un snapshot
./scripts/lifecycle/snapshot-vm.sh create 100
./scripts/lifecycle/snapshot-vm.sh create 100 --name "pre-upgrade"

# Lister les snapshots
./scripts/lifecycle/snapshot-vm.sh list 100

# Restaurer un snapshot
./scripts/lifecycle/snapshot-vm.sh rollback 100 --name "pre-upgrade"

# Supprimer un snapshot
./scripts/lifecycle/snapshot-vm.sh delete 100 --name "pre-upgrade"
```

### Nettoyage automatique

Les snapshots prefixes par `auto-` sont automatiquement supprimes apres 7 jours.

```bash
# Execution manuelle
./scripts/lifecycle/cleanup-snapshots.sh

# Personnaliser l'age max
./scripts/lifecycle/cleanup-snapshots.sh --max-age 14
```

### Installation du timer

```bash
cp scripts/systemd/pve-cleanup-snapshots.* /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now pve-cleanup-snapshots.timer
```

## Expiration des VMs de lab

Les VMs/LXC de l'environnement lab peuvent avoir une date d'expiration. Les VMs expirees sont automatiquement arretees.

### Configuration Terraform

```hcl
module "vm" {
  # ...
  expiration_days = 14  # Expire dans 14 jours
}
```

Le module ajoute automatiquement un tag `expires:YYYY-MM-DD` a la VM.

### Verification manuelle

```bash
./scripts/lifecycle/expire-lab-vms.sh --dry-run
./scripts/lifecycle/expire-lab-vms.sh --force
```

### Installation du timer

```bash
cp scripts/systemd/pve-expire-lab.* /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now pve-expire-lab.timer
```

### Protection

Le script d'expiration ne s'applique **qu'aux VMs de l'environnement lab**. Les environnements prod et monitoring ne sont pas affectes.

## Rotation des cles SSH

### Ajouter une nouvelle cle

```bash
# Sur un environnement specifique
./scripts/lifecycle/rotate-ssh-keys.sh --add-key ~/.ssh/new_key.pub --env prod

# Sur tous les environnements
./scripts/lifecycle/rotate-ssh-keys.sh --add-key ~/.ssh/new_key.pub --all
```

### Revoquer une cle

```bash
# Identifier le fingerprint
ssh-keygen -lf ~/.ssh/old_key.pub

# Revoquer
./scripts/lifecycle/rotate-ssh-keys.sh --remove-key "SHA256:abc123..." --env prod
```

### Protection anti-lockout

Le script refuse de supprimer la derniere cle SSH d'un hote pour eviter de perdre l'acces.

## Alertes Prometheus

| Alerte | Severite | Description |
|--------|----------|-------------|
| `VMRebootRequired` | warning | Reboot necessaire depuis > 24h |
| `LabVMExpired` | warning | VMs lab expirees et arretees |
| `SnapshotOlderThanWeek` | info | Snapshots anciens nettoyes |

## Timers systemd

| Timer | Schedule | Script |
|-------|----------|--------|
| `pve-cleanup-snapshots` | 05:00 quotidien | `cleanup-snapshots.sh` |
| `pve-expire-lab` | 07:00 quotidien | `expire-lab-vms.sh` |

## Troubleshooting

### unattended-upgrades ne fonctionne pas
- Verifier : `ssh ubuntu@<ip> systemctl status unattended-upgrades`
- Verifier les logs : `ssh ubuntu@<ip> cat /var/log/unattended-upgrades/unattended-upgrades.log`

### Snapshot echoue
- Verifier l'espace disque sur le datastore
- Verifier que la VM n'est pas verrouillee

### Expiration ne s'applique pas
- Verifier que le tag `expires:YYYY-MM-DD` est present : `pvesh get /cluster/resources --type vm --output-format json | jq`
- Verifier que le timer est actif : `systemctl status pve-expire-lab.timer`
