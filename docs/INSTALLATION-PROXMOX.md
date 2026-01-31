# Installation de Proxmox VE sur Intel NUC

Guide d'installation de Proxmox VE 9.x sur un Intel NUC pour un homelab.

> **Note** : Ce guide a été mis à jour pour Proxmox VE 9.x (basé sur Debian Trixie). Pour les versions antérieures (8.x basé sur Bookworm), adaptez les noms de release dans les commandes APT.

## Prérequis

### Matériel
- Intel NUC (ou équivalent)
- 16 GB RAM minimum (32 GB recommandé pour plusieurs VMs)
- SSD NVMe pour l'OS et les VMs
- Clé USB 8 GB minimum (pour l'installation)

### Réseau
- Connexion Ethernet (câble RJ45)
- Adresse IP fixe réservée sur votre routeur/box

### Logiciels requis
- [Balena Etcher](https://etcher.balena.io/) ou Rufus (pour créer la clé USB)
- Image ISO Proxmox VE : https://www.proxmox.com/en/downloads

## Étape 1 : Préparation de la clé USB bootable

1. Télécharger l'ISO Proxmox VE 9.x depuis le site officiel
2. Insérer une clé USB de 8 GB minimum
3. Lancer Balena Etcher :
   - Sélectionner l'ISO Proxmox
   - Sélectionner la clé USB
   - Cliquer sur "Flash"

## Étape 2 : Configuration du BIOS du NUC

1. Démarrer le NUC et appuyer sur F2 pour entrer dans le BIOS
2. Configurer les options suivantes :

### Boot
- **Boot Priority** : USB en premier
- **Secure Boot** : Désactivé

### Advanced > Virtualization
- **Intel Virtualization Technology (VT-x)** : Enabled
- **Intel VT-d** : Enabled (pour le passthrough)

### Power
- **After Power Failure** : Power On (optionnel, pour redémarrage auto)

3. Sauvegarder et quitter (F10)

## Étape 3 : Installation de Proxmox VE

1. Démarrer sur la clé USB
2. Sélectionner "Install Proxmox VE (Graphical)"
3. Accepter la licence

### Configuration du disque
- **Target Harddisk** : Sélectionner le SSD NVMe
- **Options** :
  - Filesystem : ext4 (simple) ou ZFS (recommandé si 2+ disques)
  - Pour ZFS single disk : zfs (RAID0)

### Configuration réseau

C'est ici que vous configurez l'IP fixe :

```
Management Interface: Votre interface réseau (enX0 ou eno1)
Hostname (FQDN):      pve.home.local
IP Address (CIDR):    192.168.1.X/24     # Remplacer X par votre IP
Gateway:              192.168.1.1         # Votre routeur/box
DNS Server:           192.168.1.1         # Ou 1.1.1.1, 8.8.8.8
```

> **Important** : Notez bien l'adresse IP, vous en aurez besoin pour accéder à l'interface web.

### Configuration admin
- **Password** : Mot de passe root (gardez-le précieusement)
- **Email** : Votre email pour les alertes

4. Lancer l'installation et attendre ~5-10 minutes
5. Retirer la clé USB et redémarrer

## Étape 4 : Accès à l'interface web

1. Depuis un autre ordinateur sur le même réseau
2. Ouvrir un navigateur et aller sur : `https://192.168.1.X:8006`
   - Remplacer X par l'IP configurée
3. Accepter l'avertissement du certificat auto-signé
4. Se connecter :
   - User: `root`
   - Password: Le mot de passe défini à l'installation
   - Realm: `Linux PAM standard authentication`

## Étape 5 : Configurer l'accès SSH avec clé publique

Avant de lancer le script de post-installation, configurez l'accès SSH par clé publique depuis votre poste de travail. Cela permet d'exécuter le script à distance et est requis par Terraform.

### 5.1 Générer une paire de clés SSH (si nécessaire)

Si vous n'avez pas encore de clé SSH, générez-en une sur votre poste de travail :

```bash
ssh-keygen -t ed25519 -C "votre-email@example.com"
```

> **Note** : Appuyez sur Entrée pour accepter l'emplacement par défaut (`~/.ssh/id_ed25519`). Vous pouvez définir une passphrase pour plus de sécurité.

### 5.2 Copier la clé publique sur le node Proxmox

```bash
ssh-copy-id root@192.168.1.X
```

Ou manuellement, si `ssh-copy-id` n'est pas disponible :

```bash
# Afficher votre clé publique
cat ~/.ssh/id_ed25519.pub

# Sur le node Proxmox (via la console web), ajouter la clé :
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "VOTRE_CLE_PUBLIQUE_ICI" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 5.3 Vérifier la connexion

```bash
ssh root@192.168.1.X "hostname && pveversion"
```

Vous devez obtenir le nom du node et la version de Proxmox sans saisir de mot de passe.

## Étape 6 : Configuration post-installation (script automatisé)

Le script `post-install-proxmox.sh` automatise toutes les étapes de configuration :
- Suppression du popup de souscription
- Configuration des dépôts APT (no-subscription)
- Mise à jour système
- Configuration du fuseau horaire
- Installation des outils utiles (vim, htop, iotop, curl, wget, net-tools, sudo, fail2ban)
- Configuration de fail2ban (protection SSH + interface web Proxmox)
- Création de l'utilisateur Terraform avec token API
- Création de l'utilisateur Prometheus (optionnel)
- Activation des snippets cloud-init
- Téléchargement des templates LXC et VM cloud-init

### Exécution du script

Copiez le script sur le node Proxmox et exécutez-le :

```bash
# Depuis votre poste de travail
scp scripts/post-install-proxmox.sh root@192.168.1.X:/root/

# Sur le node Proxmox (via SSH)
ssh root@192.168.1.X
chmod +x /root/post-install-proxmox.sh
./post-install-proxmox.sh
```

Le script est interactif : il demande confirmation avant chaque étape. Utilisez `--yes` pour tout accepter automatiquement :

```bash
./post-install-proxmox.sh --yes
```

### Options disponibles

| Option | Description |
|--------|-------------|
| `-y`, `--yes` | Mode non-interactif (tout accepter) |
| `--skip-reboot` | Ne pas redémarrer après la mise à jour |
| `--timezone ZONE` | Fuseau horaire (défaut: `Europe/Paris`) |
| `--vm-template-id ID` | ID du template VM cloud-init (défaut: `9000`) |
| `--no-prometheus` | Ne pas créer l'utilisateur Prometheus |
| `--no-template-vm` | Ne pas créer le template VM cloud-init |
| `-h`, `--help` | Afficher l'aide |

> **Important** : Le script affiche un résumé final avec les tokens API générés. Notez-les immédiatement, ils ne seront plus affichables ensuite.

<details>
<summary>Commandes manuelles détaillées (référence)</summary>

### Supprimer le message de souscription

```bash
# Supprimer le popup de souscription (optionnel, légal pour usage personnel)
sed -Ezi.bak "s/(Ext\.Msg\.show\(\{.+?title: 'No valid subscription)/void({ \/\/ \1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service
```

### Configurer les dépôts (gratuits)

> **Proxmox VE 9.x** utilise le nouveau format de fichiers APT DEB822 (`.sources`) au lieu de l'ancien format `.list`.

```bash
# Désactiver le dépôt enterprise PVE (nouveau format .sources pour PVE 9.x)
mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.disabled

# Désactiver le dépôt enterprise Ceph (présent par défaut dans PVE 9.x)
mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph.sources.disabled

# Ajouter le dépôt no-subscription PVE (format DEB822 pour PVE 9.x)
cat > /etc/apt/sources.list.d/pve-no-subscription.sources << 'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

# Mettre à jour
apt update && apt full-upgrade -y
```

> **Note** : Si vous utilisez Ceph pour le stockage distribué, vous pouvez créer un dépôt Ceph no-subscription :
> ```bash
> cat > /etc/apt/sources.list.d/ceph-no-subscription.sources << 'EOF'
> Types: deb
> URIs: http://download.proxmox.com/debian/ceph-squid
> Suites: trixie
> Components: no-subscription
> Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
> EOF
> ```

<details>
<summary>Anciennes versions (PVE 8.x et antérieures) - Format .list</summary>

```bash
# Désactiver le dépôt enterprise (ancien format .list pour PVE 8.x)
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Ajouter le dépôt no-subscription
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Mettre à jour
apt update && apt full-upgrade -y
```

</details>

### Mettre à jour le système

```bash
apt update && apt full-upgrade -y
reboot
```

### Configurer le fuseau horaire

```bash
timedatectl set-timezone Europe/Paris
```

### Installer les outils utiles

```bash
apt install -y vim htop iotop curl wget net-tools sudo fail2ban
```

### Créer un utilisateur Terraform

```bash
# Créer l'utilisateur terraform
pveum user add terraform@pve --comment "Terraform automation"

# Créer un rôle avec les permissions nécessaires (PVE 9.x)
pveum role add TerraformRole -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.GuestAgent.Audit VM.Migrate VM.PowerMgmt User.Modify"

# Assigner le rôle à l'utilisateur sur tout le datacenter
pveum aclmod / -user terraform@pve -role TerraformRole

# Créer le token API (NOTEZ BIEN LE TOKEN AFFICHÉ)
pveum user token add terraform@pve terraform-token --privsep=0
```

### Créer un utilisateur Prometheus (optionnel)

```bash
pveum user add prometheus@pve --comment "Prometheus monitoring"
pveum aclmod / -user prometheus@pve -role PVEAuditor
pveum user token add prometheus@pve prometheus --privsep=0
```

### Activer les snippets pour cloud-init

```bash
mkdir -p /var/lib/vz/snippets
pvesm set local --content backup,iso,vztmpl,snippets
```

### Télécharger des templates

```bash
# Templates LXC
pveam update
pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
pveam download local debian-12-standard_12.12-1_amd64.tar.zst

# Template VM cloud-init (ID 9000)
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
qm create 9000 --name "ubuntu-cloud-template" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
qm template 9000
```

### Vérification

```bash
systemctl status pvedaemon pveproxy
pvesh get /nodes/$(hostname)/status
pvesm status
pveam list local
curl -k -H 'Authorization: PVEAPIToken=terraform@pve!terraform-token=VOTRE_TOKEN' \
  'https://127.0.0.1:8006/api2/json/nodes'
```

</details>

## Étape 7 : Sécurisation de l'instance Proxmox

Même sur un réseau local, quelques mesures de sécurité de base sont recommandées.

### 7.1 Désactiver l'authentification SSH par mot de passe

Une fois la clé SSH configurée (étape 5), désactivez l'authentification par mot de passe :

```bash
# Sur le node Proxmox
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
```

> **Important** : Vérifiez que votre connexion par clé SSH fonctionne **avant** de désactiver le mot de passe. En cas de problème, vous pouvez toujours accéder au node via la console physique ou l'interface web (Shell).

### 7.2 Configurer fail2ban

Le script de post-installation (étape 6) installe et configure automatiquement `fail2ban` avec deux jails :
- **sshd** : protège SSH (5 tentatives max, ban 1h)
- **proxmox** : protège l'interface web (3 tentatives max, ban 1h)

Vous pouvez vérifier que fail2ban est actif :

```bash
fail2ban-client status
fail2ban-client status sshd
fail2ban-client status proxmox
```

<details>
<summary>Configuration manuelle (si le script n'a pas été utilisé)</summary>

```bash
# PVE 9.x (Debian Trixie) utilise journald, pas /var/log/daemon.log
# Adapter "backend" selon votre version :
#   - PVE 9.x : backend = systemd (pas de logpath)
#   - PVE 8.x : backend = auto, logpath = /var/log/daemon.log
cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = ssh
maxretry = 5
bantime = 3600

[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
backend = systemd
maxretry = 3
bantime = 3600
EOF

cat > /etc/fail2ban/filter.d/proxmox.conf << 'EOF'
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
journalmatch = _SYSTEMD_UNIT=pvedaemon.service
EOF

systemctl enable fail2ban
systemctl restart fail2ban
```

</details>

### 7.3 Configurer le pare-feu Proxmox

Le pare-feu intégré de Proxmox peut être activé via l'interface web ou en ligne de commande. Ports à ouvrir :

| Port | Service | Requis |
|------|---------|--------|
| 22 | SSH | Oui |
| 8006 | Interface web Proxmox | Oui |
| 9100 | Node Exporter (Prometheus) | Optionnel (monitoring) |

Le pare-feu Proxmox fonctionne a deux niveaux : **datacenter** (regles partagees par tous les nodes) et **node** (activation par node). Les deux niveaux doivent etre configures.

```bash
# 1. Configurer les regles au niveau du datacenter
cat > /etc/pve/firewall/cluster.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -p tcp -dport 22 -log nolog
IN ACCEPT -p tcp -dport 8006 -log nolog
IN ACCEPT -p tcp -dport 9100 -log nolog -comment "Node Exporter"
IN ACCEPT -p icmp -log nolog -comment "Ping"
EOF

# 2. Activer le pare-feu au niveau du node
#    $(hostname) detecte automatiquement le nom du node (ex: pve, pve-lab, nuc-01...)
#    Verifier avec : echo $(hostname)
cat > /etc/pve/nodes/$(hostname)/host.fw << 'EOF'
[OPTIONS]
enable: 1
EOF

# 3. Activer et demarrer le service pve-firewall
systemctl enable pve-firewall
systemctl start pve-firewall
```

Apres configuration, les regles sont visibles dans l'interface web :
- **Datacenter > Firewall** : regles globales (cluster.fw)
- **Node > Firewall > Options** : activation du pare-feu au niveau du node (host.fw)

> **Note** : Le service `pve-firewall` surveille automatiquement les fichiers dans `/etc/pve/firewall/` et applique les changements a chaud. Les modifications ulterieures seront prises en compte sans redemarrage du service.

> **Attention** : Activez le pare-feu uniquement si vous etes sur que vos regles sont correctes. Une mauvaise configuration peut bloquer l'acces au node. En cas de probleme, accedez au node via la console physique et desactivez le pare-feu : `pve-firewall stop`.

### 7.4 Certificat HTTPS

Le certificat auto-signé de Proxmox est suffisant pour un usage sur réseau local. L'avertissement du navigateur est normal et n'affecte pas la sécurité du chiffrement.

Si l'avertissement vous gêne, vous pouvez utiliser [mkcert](https://github.com/FiloSottile/mkcert) pour créer une autorité de certification locale et générer un certificat de confiance pour votre navigateur.

### 7.5 Authentification à deux facteurs (optionnel)

Sur un réseau local domestique, le 2FA n'est généralement pas nécessaire. Il peut être utile si :
- D'autres personnes ont accès à votre réseau (Wi-Fi partagé, appareils IoT)
- Vous exposez l'interface web via un VPN

La configuration se fait dans l'interface web Proxmox : **Datacenter > Permissions > Two Factor**.

## Informations à noter

Gardez ces informations pour la configuration Terraform (affichées dans le résumé du script) :

| Information | Valeur |
|-------------|--------|
| URL Proxmox | `https://192.168.1.X:8006` |
| Node name | Défini à l'installation (ex: `pve`, `pve-lab`). Vérifier avec `hostname` |
| Token API Terraform | `terraform@pve!terraform-token=xxx` |
| Token API Prometheus | `prometheus@pve!prometheus=xxx` (optionnel, pour monitoring) |
| Template VM ID | `9000` |
| Template LXC | `local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst` |
| Bridge réseau | `vmbr0` |
| Datastore | `local-lvm` |
| Gateway | `192.168.1.1` |

## Prochaines étapes

Une fois Proxmox installé et configuré :

1. Configurer Terraform (voir `infrastructure/proxmox/`)
2. Créer vos premières VMs et conteneurs
3. Configurer les sauvegardes

## Dépannage

### Impossible d'accéder à l'interface web
- Vérifier que vous êtes sur le même réseau
- Vérifier que l'IP est correcte : `ip a` sur le NUC
- Vérifier le firewall : `pve-firewall status`

### Erreur "No valid subscription"
- Normal sans souscription, le script de post-installation désactive automatiquement le popup

### Token API ne fonctionne pas
- Vérifier que `--privsep=0` a été utilisé
- Vérifier les permissions du rôle

### VMs ne démarrent pas
- Vérifier que VT-x est activé dans le BIOS
- Vérifier l'espace disque : `df -h`

### Connexion SSH refusée après sécurisation
- Accéder au node via la console physique ou le Shell de l'interface web
- Vérifier `/etc/ssh/sshd_config`
- Réactiver temporairement `PasswordAuthentication yes` si nécessaire

### Pare-feu bloque l'accès
- Accéder au node via la console physique
- Désactiver le pare-feu : `pve-firewall stop`
- Corriger les règles dans `/etc/pve/firewall/cluster.fw`
