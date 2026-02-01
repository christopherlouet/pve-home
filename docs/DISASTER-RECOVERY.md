# Disaster Recovery - Reconstruction Complete

Guide de reconstruction complete de l'infrastructure depuis zero apres une defaillance majeure.

## Introduction

### Quand utiliser ce runbook

Ce runbook est concu pour les scenarios suivants :
- **Perte totale d'un noeud Proxmox** (defaillance materielle, corruption generalisee)
- **Corruption majeure du state Terraform** rendant l'infrastructure non-gerable
- **Perte simultanee de plusieurs composants critiques** (Minio, monitoring, VMs de production)

Pour une perte partielle (VM seule, Minio seul, etc.), consultez plutot `docs/BACKUP-RESTORE.md` pour des procedures ciblees.

### Prerequis

Avant de commencer, verifiez que vous avez :

- [x] **Proxmox VE installe** sur le noeud cible (version 8.x ou superieure)
- [x] **Acces SSH par cle** depuis votre machine vers le noeud Proxmox (`root@<ip-pve>`)
- [x] **Outils installes localement** :
  - `terraform` (>= 1.5.0)
  - `mc` (Minio Client) : `wget https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x mc && sudo mv mc /usr/local/bin/`
  - `jq` : `sudo apt install jq` ou `brew install jq`
  - `ssh` (deja present sur Linux/macOS)
- [x] **Fichiers de configuration disponibles** :
  - `terraform.tfvars` pour chaque environnement (prod, lab, monitoring)
  - Acces au repository Git avec les scripts de restauration
- [x] **Sauvegardes vzdump accessibles** sur le noeud Proxmox (storage `local` ou NFS)

### Temps estime

**Reconstruction complete : ~60 minutes** (hors temps de transfert des sauvegardes)

Decomposition :
- Etape 1 (Minio) : ~10 min
- Etape 2 (State Terraform) : ~5 min
- Etape 3 (Monitoring) : ~15 min
- Etape 4 (VMs production) : ~20 min (variable selon le nombre de VMs)
- Etape 5 (Verification) : ~10 min

---

## Ordre de restauration

```
┌──────────────────────────────────────────────────────────────┐
│                   DISASTER RECOVERY                          │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│  Etape 1 : Reconstruire Minio (backend S3)                  │
│  Script : ./scripts/restore/rebuild-minio.sh                │
│  Duree  : ~10 min                                            │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│  Etape 2 : Restaurer State Terraform                        │
│  Script : ./scripts/restore/restore-tfstate.sh              │
│  Duree  : ~5 min                                             │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│  Etape 3 : Reconstruire Monitoring Stack                    │
│  Script : ./scripts/restore/rebuild-monitoring.sh           │
│  Duree  : ~15 min                                            │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│  Etape 4 : Restaurer VMs de production                      │
│  Script : ./scripts/restore/restore-vm.sh (pour chaque VMID)│
│  Duree  : ~20 min (variable)                                 │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│  Etape 5 : Verification finale                              │
│  Script : ./scripts/restore/verify-backups.sh --full        │
│  Duree  : ~10 min                                            │
└──────────────────────────────────────────────────────────────┘
```

**Important** : Respecter cet ordre. Chaque etape depend de la precedente.

---

## Etape 1 : Reconstruire Minio

### Objectif

Reconstruire le conteneur Minio pour restaurer le backend S3 de Terraform. Sans Minio, impossible de gerer l'infrastructure avec Terraform.

### Prerequis

- [x] Proxmox VE accessible en SSH
- [x] Environnement `monitoring` configure dans `infrastructure/proxmox/environments/monitoring/terraform.tfvars`
- [x] Terraform installe localement

### Commande

```bash
cd /path/to/pve-home
./scripts/restore/rebuild-minio.sh --force
```

**Options** :
- `--force` : mode non-interactif (pas de confirmation, recommande pour DR)
- `--dry-run` : afficher les actions sans les executer (pour tester)

### Verification attendue

Le script affiche les etapes suivantes :

1. **Terraform apply sur module.minio**
   ```
   ✓ Terraform apply complete
   ✓ Conteneur Minio cree avec IP <minio-ip>
   ```

2. **Healthcheck Minio**
   ```
   ✓ Minio healthcheck OK (http://<minio-ip>:9000/minio/health/live)
   ```

3. **Buckets crees et versioning actif**
   ```
   ✓ Bucket tfstate-prod cree, versioning: Enabled
   ✓ Bucket tfstate-lab cree, versioning: Enabled
   ✓ Bucket tfstate-monitoring cree, versioning: Enabled
   ```

4. **Verification des backends Terraform**
   ```
   ✓ Backend prod: terraform init OK
   ✓ Backend lab: terraform init OK
   ✓ Backend monitoring: terraform init OK
   ```

### Troubleshooting

#### Probleme : Terraform apply echoue

**Symptome** : `Error: ... unable to connect to Proxmox API`

**Solutions** :
1. Verifier la connectivite SSH vers le noeud Proxmox : `ssh root@<ip-pve> "pvesh get /version"`
2. Verifier que le token API dans `terraform.tfvars` est valide
3. Verifier l'espace disque disponible sur le noeud : `ssh root@<ip-pve> "df -h"`

#### Probleme : Healthcheck Minio echoue

**Symptome** : `Minio healthcheck failed after X retries`

**Solutions** :
1. Verifier que le conteneur est demarre : `ssh root@<ip-pve> "pct list | grep <minio-ctid>"`
2. Verifier les logs du conteneur : `ssh root@<ip-pve> "pct exec <minio-ctid> -- journalctl -u minio -n 50"`
3. Verifier la configuration reseau du conteneur (IP, passerelle)

#### Probleme : Pas de state local disponible

**Symptome** : `No local state file found, buckets will be empty`

**Impact** : Les buckets Minio sont vides. Il faudra utiliser `--fallback` a l'etape 2.

**Solution** : Continuer avec l'etape 2 en mode fallback. Le state Terraform sera migre depuis le backend local si disponible.

### Si echec : Fallback

Si la reconstruction de Minio echoue completement, utilisez le mode fallback pour basculer temporairement sur le backend local :

```bash
./scripts/restore/restore-tfstate.sh --env monitoring --fallback
```

Cela permet de continuer a gerer l'infrastructure avec Terraform pendant la resolution du probleme Minio.

---

## Etape 2 : Restaurer State Terraform

### Objectif

Restaurer les etats Terraform depuis les buckets Minio (ou migrer depuis le backend local si Minio vient d'etre reconstruit).

### Prerequis

- [x] Minio operationnel (etape 1 terminee avec succes) **OU** mode fallback actif
- [x] Client `mc` (Minio Client) installe localement

### Commande

#### Cas 1 : Minio operationnel avec buckets vides (apres reconstruction)

Si Minio vient d'etre reconstruit et que vous avez un state local disponible :

```bash
# L'etape 1 a deja upload le state local vers Minio
# Verifier que les states sont presents :
./scripts/restore/restore-tfstate.sh --env prod --list
./scripts/restore/restore-tfstate.sh --env lab --list
./scripts/restore/restore-tfstate.sh --env monitoring --list
```

#### Cas 2 : Minio operationnel avec historique de versions

Si Minio contient deja des versions du state, lister et restaurer une version specifique :

```bash
# Lister les versions disponibles
./scripts/restore/restore-tfstate.sh --env prod --list

# Restaurer une version specifique (copier le version-id depuis la liste)
./scripts/restore/restore-tfstate.sh --env prod --restore <version-id>
```

#### Cas 3 : Minio indisponible (fallback)

Si Minio est inaccessible, basculer temporairement sur le backend local :

```bash
./scripts/restore/restore-tfstate.sh --env prod --fallback
./scripts/restore/restore-tfstate.sh --env lab --fallback
./scripts/restore/restore-tfstate.sh --env monitoring --fallback
```

### Verification attendue

Pour chaque environnement (prod, lab, monitoring) :

1. **Configuration mc reussie**
   ```
   ✓ Client mc configure (alias homelab)
   ```

2. **State restaure ou migre**
   ```
   ✓ State restaure depuis version <version-id>
   ✓ Terraform init complete
   ```

3. **Aucun changement inattendu**
   ```bash
   cd infrastructure/proxmox/environments/prod
   terraform plan
   # Resultat attendu : "No changes. Your infrastructure matches the configuration."
   ```

   **Important** : Si `terraform plan` montre des changements inattendus (creation ou destruction de ressources), **NE PAS APPLIQUER**. Cela indique que le state ne correspond pas a l'infrastructure reelle.

### Troubleshooting

#### Probleme : `terraform plan` montre des changements inattendus

**Symptome** : `Plan: 5 to add, 0 to change, 3 to destroy`

**Causes possibles** :
1. Le state restaure ne correspond pas a l'etat reel de l'infrastructure
2. Une ancienne version du state a ete restauree

**Solutions** :
1. Lister les versions disponibles et restaurer une version plus recente
2. Si aucune version ne correspond, utiliser `terraform import` pour reimporter les ressources existantes

#### Probleme : Minio inaccessible

**Symptome** : `Error: failed to configure mc alias`

**Solution** : Utiliser le mode fallback (voir Cas 3 ci-dessus)

### Si echec : Utiliser le backend local

Si toutes les tentatives echouent, basculer definitivement sur le backend local :

```bash
./scripts/restore/restore-tfstate.sh --env prod --fallback
```

Vous pourrez migrer vers Minio plus tard avec `--return` une fois le probleme resolu.

---

## Etape 3 : Reconstruire Monitoring Stack

### Objectif

Restaurer la VM monitoring avec Prometheus, Grafana et Alertmanager. Sans monitoring, aucune visibilite sur l'infrastructure.

### Prerequis

- [x] State Terraform restaure (etape 2 terminee)
- [x] Sauvegarde vzdump de la VM monitoring disponible **OU** configuration Terraform complete

### Commande

#### Cas 1 : Sauvegarde vzdump disponible (recommande)

Restaurer la VM monitoring depuis le dernier backup :

```bash
./scripts/restore/rebuild-monitoring.sh --mode restore
```

#### Cas 2 : Pas de backup disponible (reconstruction complete)

Reconstruire la VM monitoring depuis zero avec Terraform :

```bash
./scripts/restore/rebuild-monitoring.sh --mode rebuild
```

**Attention** : La reconstruction complete perd l'historique des metriques Prometheus. Seule la configuration est recreee.

### Verification attendue

1. **VM monitoring restauree ou recreee**
   ```
   ✓ VM monitoring (VMID <vmid>) restored
   ✓ VM started
   ```

2. **Services Docker operationnels**
   ```
   ✓ Docker service active
   ✓ Prometheus up
   ✓ Grafana up
   ✓ Alertmanager up
   ```

3. **Healthcheck des services**
   ```
   ✓ Prometheus API: http://<monitoring-ip>:9090/-/api/v1/targets
   ✓ Grafana API: http://<monitoring-ip>:3000/api/health
   ✓ Alertmanager API: http://<monitoring-ip>:9093/-/healthy
   ```

4. **Verification manuelle**
   - Ouvrir Grafana : `http://<monitoring-ip>:3000`
   - Login : `admin` / (mot de passe depuis terraform.tfvars)
   - Verifier que les dashboards sont visibles
   - Verifier que Prometheus scrape les targets (Configuration > Data Sources > Prometheus > Test)

### Troubleshooting

#### Probleme : Services Docker ne demarrent pas

**Symptome** : `Docker service inactive or failed`

**Solutions** :
1. Verifier les logs Docker : `ssh ubuntu@<monitoring-ip> "sudo journalctl -u docker -n 50"`
2. Verifier l'espace disque : `ssh ubuntu@<monitoring-ip> "df -h"`
3. Redemarrer les conteneurs manuellement :
   ```bash
   ssh ubuntu@<monitoring-ip>
   cd /opt/monitoring
   sudo docker-compose restart
   ```

#### Probleme : Prometheus ne scrape pas les targets

**Symptome** : `Prometheus targets down`

**Solutions** :
1. Verifier la configuration Prometheus : `ssh ubuntu@<monitoring-ip> "cat /opt/monitoring/prometheus/prometheus.yml"`
2. Verifier la connectivite reseau vers les targets (PVE nodes) : `ping <target-ip>`
3. Verifier les credentials de scraping dans `prometheus.yml`

#### Probleme : Grafana inaccessible

**Symptome** : `Connection refused` sur le port 3000

**Solutions** :
1. Verifier que le conteneur Grafana est demarre : `ssh ubuntu@<monitoring-ip> "sudo docker ps | grep grafana"`
2. Verifier les logs Grafana : `ssh ubuntu@<monitoring-ip> "sudo docker logs grafana"`

### Post-rebuild : Deployer les scripts et keypair SSH

Apres la reconstruction du monitoring, deployer les scripts de health check et drift detection :

```bash
# Deployer scripts, tfvars et timers systemd
./scripts/deploy.sh

# Recuperer la cle SSH publique du monitoring
cd infrastructure/proxmox/environments/monitoring
terraform output health_check_ssh_public_key

# Ajouter dans prod/terraform.tfvars > monitoring_ssh_public_key
# Puis appliquer sur prod pour injecter la cle dans les VMs
cd ../prod && terraform apply
```

**Note** : La keypair SSH est regeneree a chaque reconstruction (`tls_private_key`). La cle publique doit etre redistribuee sur les VMs des autres environnements. Pour les VMs existantes (cloud-init ne se re-execute pas), ajouter manuellement la cle publique dans `~ubuntu/.ssh/authorized_keys`.

### Note : Historique metriques

- **Mode restore** : L'historique Prometheus est conserve si inclus dans le backup vzdump
- **Mode rebuild** : L'historique est perdu. Seule la configuration est recreee. Les nouvelles metriques commencent a etre collectees immediatement.

---

## Etape 4 : Restaurer VMs de production

### Objectif

Restaurer toutes les VMs et conteneurs de production depuis leurs sauvegardes vzdump.

### Prerequis

- [x] State Terraform restaure (etape 2 terminee)
- [x] Monitoring operationnel (etape 3 terminee) - optionnel mais recommande
- [x] Sauvegardes vzdump disponibles pour chaque VM/LXC

### Liste des VMs/LXC a restaurer

Consulter les fichiers `terraform.tfvars` de chaque environnement pour identifier les VMIDs :

**Exemple** (a adapter a votre infrastructure) :

| Environnement | VMID | Type | Description |
|--------------|------|------|-------------|
| prod | 100 | VM | Serveur applicatif principal |
| prod | 101 | LXC | Base de donnees PostgreSQL |
| lab | 200 | VM | Serveur de test |
| monitoring | 150 | LXC | Minio (deja restaure a l'etape 1) |

**Note** : Le conteneur Minio a deja ete restaure a l'etape 1, ne pas le restaurer a nouveau.

### Commande

Pour chaque VMID a restaurer :

```bash
./scripts/restore/restore-vm.sh <vmid> --node <node-name>
```

**Exemples** :

```bash
# Restaurer la VM 100 (prod)
./scripts/restore/restore-vm.sh 100 --node pve-prod

# Restaurer le conteneur LXC 101 (prod)
./scripts/restore/restore-vm.sh 101 --node pve-prod

# Restaurer la VM 200 (lab)
./scripts/restore/restore-vm.sh 200 --node pve-lab
```

**Options utiles** :
- `--date YYYY-MM-DD` : restaurer depuis une sauvegarde specifique (au lieu de la plus recente)
- `--target-id <new-id>` : restaurer vers un nouveau VMID (si l'original doit etre preserve)
- `--dry-run` : simuler la restauration

### Verification attendue

Pour chaque VM/LXC :

1. **Sauvegarde trouvee et restauree**
   ```
   ✓ Backup found: vzdump-qemu-100-2026_02_01-01_00_00.vma.zst
   ✓ Restored to VMID 100
   ```

2. **VM demarree**
   ```
   ✓ VM started
   ✓ Waiting for boot...
   ```

3. **Connectivite verifiee**
   ```
   ✓ Ping OK (192.168.1.110)
   ✓ SSH OK (ubuntu@192.168.1.110)
   ```

### Verification manuelle

Apres restauration de chaque VM :

```bash
# Tester la connectivite
ping <ip-vm>

# Tester SSH
ssh <user>@<ip-vm>

# Verifier les services critiques (exemple pour une VM applicative)
ssh <user>@<ip-vm> "sudo systemctl status nginx"
ssh <user>@<ip-vm> "sudo systemctl status postgresql"
```

### Troubleshooting

#### Probleme : Aucune sauvegarde disponible

**Symptome** : `No backup found for VMID <vmid>`

**Solutions** :
1. Verifier manuellement les sauvegardes : `ssh root@<pve-node> "ls -lh /var/lib/vz/dump/ | grep <vmid>"`
2. Si vraiment aucune sauvegarde, recreer la VM avec Terraform : `terraform apply -target=module.<vm-name>`

#### Probleme : Echec SSH apres restauration

**Symptome** : `SSH connection failed`

**Causes possibles** :
1. La VM n'a pas termine de booter (attendre 1-2 min)
2. Probleme de configuration reseau (IP, passerelle)
3. Service SSH non demarre

**Solutions** :
1. Attendre et reessayer
2. Verifier la console de la VM dans l'interface Proxmox
3. Demarrer SSH manuellement via la console : `sudo systemctl start ssh`

#### Probleme : Conflit VMID

**Symptome** : `VMID <vmid> already exists`

**Solutions** :
1. Restaurer vers un nouveau VMID : `./scripts/restore/restore-vm.sh <vmid> --target-id <new-vmid>`
2. Detruire la VM existante puis restaurer (si vous etes sur) : `ssh root@<pve-node> "qm destroy <vmid>" && ./scripts/restore/restore-vm.sh <vmid>`

---

## Etape 5 : Verification finale

### Objectif

Verifier que tous les composants sont operationnels et que les sauvegardes automatiques sont reconfigures.

### Commande

```bash
./scripts/restore/verify-backups.sh --full
```

### Verification attendue

Le script verifie :

1. **Sauvegardes vzdump**
   ```
   ✓ Vzdump backups verified for all VMIDs
   ✓ No missing or corrupted backups
   ```

2. **Buckets Minio**
   ```
   ✓ Bucket tfstate-prod: 5 versions, JSON valid
   ✓ Bucket tfstate-lab: 3 versions, JSON valid
   ✓ Bucket tfstate-monitoring: 4 versions, JSON valid
   ```

3. **Connectivite VMs/LXC**
   ```
   ✓ All VMs/LXC reachable (ping test)
   ```

4. **Jobs de sauvegarde actifs**
   ```
   ✓ 3 backup job(s) configured and active
   ```

### Checklist manuelle finale

Cocher chaque element apres verification :

#### Infrastructure de base
- [ ] **Proxmox VE accessible** : interface web sur `https://<pve-ip>:8006`
- [ ] **Toutes les VMs/LXC sont up** : verifier dans Proxmox > Datacenter > Summary
- [ ] **Connectivite SSH vers toutes les VMs** : `ssh <user>@<ip-vm>` pour chaque VM

#### Backend Terraform
- [ ] **Minio operationnel** : `curl http://<minio-ip>:9000/minio/health/live` retourne `200 OK`
- [ ] **Buckets Minio accessibles** : `mc ls homelab/tfstate-prod` liste les versions
- [ ] **Backend Terraform S3 operationnel** : `terraform init` sur chaque environnement sans erreur
- [ ] **Aucun changement inattendu** : `terraform plan` sur chaque environnement retourne "No changes"

#### Monitoring
- [ ] **Grafana accessible** : `http://<monitoring-ip>:3000` affiche l'interface de login
- [ ] **Prometheus operationnel** : `http://<monitoring-ip>:9090` affiche l'interface Prometheus
- [ ] **Targets Prometheus up** : Configuration > Status > Targets, toutes les targets sont vertes
- [ ] **Alertmanager operationnel** : `http://<monitoring-ip>:9093` affiche l'interface Alertmanager
- [ ] **Dashboards Grafana fonctionnels** : ouvrir "Backup Overview" et "PVE Overview", les metriques s'affichent

#### Sauvegardes automatiques
- [ ] **Jobs vzdump configures** : `ssh root@<pve-node> "pvesh get /cluster/backup"` liste les jobs
- [ ] **Prochaine sauvegarde planifiee** : verifier dans Proxmox > Datacenter > Backup
- [ ] **Retention policy correcte** : verifier que les anciens backups sont purges automatiquement

#### Services applicatifs (exemple a adapter)
- [ ] **Nginx/Apache operationnel** : `curl http://<vm-app-ip>` retourne une page web
- [ ] **Base de donnees accessible** : `psql -h <vm-db-ip> -U <user> -c "SELECT 1;"` fonctionne
- [ ] **Applications critiques fonctionnelles** : tester chaque service metier

### Troubleshooting

#### Probleme : Jobs de sauvegarde absents

**Symptome** : `0 backup job(s) configured`

**Solutions** :
1. Recreer les jobs manuellement dans Proxmox > Datacenter > Backup
2. Ou via Terraform si configures dans le code : `terraform apply -target=module.backup`

#### Probleme : Targets Prometheus down

**Symptome** : Certaines targets sont rouges dans Prometheus

**Solutions** :
1. Verifier la connectivite reseau vers les targets : `ping <target-ip>`
2. Verifier que le node exporter est demarre sur chaque target : `ssh <target-ip> "sudo systemctl status prometheus-node-exporter"`
3. Verifier la configuration Prometheus : `ssh ubuntu@<monitoring-ip> "cat /opt/monitoring/prometheus/prometheus.yml"`

---

## Scenarios de perte partielle

Pour les scenarios de perte partielle (non-disaster recovery complet), utilisez ces procedures ciblees :

### Perte d'une VM seule

```bash
# Restaurer uniquement la VM affectee
./scripts/restore/restore-vm.sh <vmid> --node <node-name>
```

Voir `docs/BACKUP-RESTORE.md` section 1 pour plus de details.

### Perte de Minio

```bash
# Reconstruire Minio
./scripts/restore/rebuild-minio.sh --force

# Verifier les backends Terraform
./scripts/restore/restore-tfstate.sh --env prod --list
./scripts/restore/restore-tfstate.sh --env lab --list
./scripts/restore/restore-tfstate.sh --env monitoring --list
```

Voir Etape 1 de ce runbook.

### Perte de monitoring

```bash
# Restaurer depuis backup
./scripts/restore/rebuild-monitoring.sh --mode restore

# Ou reconstruire depuis zero
./scripts/restore/rebuild-monitoring.sh --mode rebuild
```

Voir Etape 3 de ce runbook.

### State Terraform corrompu

```bash
# Lister les versions disponibles
./scripts/restore/restore-tfstate.sh --env prod --list

# Restaurer une version anterieure
./scripts/restore/restore-tfstate.sh --env prod --restore <version-id>

# Verifier
cd infrastructure/proxmox/environments/prod
terraform plan
```

Voir Etape 2 de ce runbook.

### Perte totale

Suivre le runbook complet dans l'ordre : Etape 1 → Etape 2 → Etape 3 → Etape 4 → Etape 5.

---

## Annexes

### A. Commandes utiles

#### Lister toutes les VMs/LXC

```bash
ssh root@<pve-node> "pvesh get /cluster/resources --type vm"
```

#### Verifier l'espace disque

```bash
# Sur le noeud Proxmox
ssh root@<pve-node> "df -h"

# Sur une VM
ssh <user>@<vm-ip> "df -h"
```

#### Verifier les logs Proxmox

```bash
# Logs vzdump
ssh root@<pve-node> "cat /var/log/vzdump/*.log"

# Logs systeme
ssh root@<pve-node> "journalctl -u pve-cluster -n 50"
```

#### Verifier la connectivite Minio

```bash
# Healthcheck
curl http://<minio-ip>:9000/minio/health/live

# Lister les buckets
mc ls homelab/
```

### B. Contacts et escalade

En cas de probleme non resolu :

1. Verifier les logs de chaque composant
2. Consulter la documentation officielle :
   - Proxmox VE : https://pve.proxmox.com/wiki/Main_Page
   - Terraform : https://www.terraform.io/docs
   - Minio : https://min.io/docs/minio/linux/index.html
3. Ouvrir une issue sur le repository Git du projet

### C. Changelog des procedures

| Date | Version | Changements |
|------|---------|-------------|
| 2026-02-01 | 1.1 | Ajout etape deploy.sh et keypair SSH post-rebuild monitoring |
| 2026-02-01 | 1.0 | Creation initiale du runbook DR |

---

**Version** : 1.0 | **Date** : 2026-02-01 | **Auteur** : Infrastructure Team
