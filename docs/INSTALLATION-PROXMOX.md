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

## Étape 5 : Configuration post-installation

### 5.1 Supprimer le message de souscription

Exécuter sur le node Proxmox (via SSH ou la console web) :

```bash
# Supprimer le popup de souscription (optionnel, légal pour usage personnel)
sed -Ezi.bak "s/(Ext\.Msg\.show\(\{.+?title: 'No valid subscription)/void({ \/\/ \1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service
```

### 5.2 Configurer les dépôts (gratuits)

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

### 5.3 Mettre à jour le système

```bash
apt update && apt full-upgrade -y
reboot
```

### 5.4 Configurer le fuseau horaire

```bash
timedatectl set-timezone Europe/Paris
```

### 5.5 Installer les outils utiles

```bash
apt install -y vim htop iotop curl wget net-tools
```

## Étape 6 : Créer un utilisateur Terraform

Pour que Terraform puisse gérer Proxmox, il faut créer un utilisateur dédié avec un token API.

```bash
# Créer l'utilisateur terraform
pveum user add terraform@pve --comment "Terraform automation"

# Créer un rôle avec les permissions nécessaires (PVE 9.x)
# Inclut VM.GuestAgent.Audit pour la récupération d'infos via QEMU Guest Agent
pveum role add TerraformRole -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.GuestAgent.Audit VM.Migrate VM.PowerMgmt User.Modify"

# Assigner le rôle à l'utilisateur sur tout le datacenter
pveum aclmod / -user terraform@pve -role TerraformRole

# Créer le token API (NOTEZ BIEN LE TOKEN AFFICHÉ)
pveum user token add terraform@pve terraform-token --privsep=0
```

> **Important** : Copiez et sauvegardez le token affiché. Il ne sera plus visible ensuite.

Le format du token sera :
```
terraform@pve!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

## Étape 7 : Créer un utilisateur Prometheus (optionnel)

Si vous prévoyez d'utiliser le module `monitoring-stack` pour surveiller vos nodes Proxmox, créez un utilisateur dédié avec des permissions en lecture seule :

```bash
# Créer l'utilisateur prometheus (lecture seule)
pveum user add prometheus@pve --comment "Prometheus monitoring"

# Assigner le rôle PVEAuditor (lecture seule intégrée)
pveum aclmod / -user prometheus@pve -role PVEAuditor

# Créer le token API (NOTEZ BIEN LE TOKEN AFFICHÉ)
pveum user token add prometheus@pve prometheus --privsep=0
```

Le format du token sera :
```
prometheus@pve!prometheus=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

> **Note** : Ce token est utilisé par `pve-exporter` pour collecter les métriques Proxmox (VMs, LXC, stockage, etc.).

## Étape 8 : Activer les snippets pour cloud-init

Pour que Terraform puisse uploader des fichiers cloud-init personnalisés (installation Docker, etc.), il faut activer le content type "snippets" sur le storage local :

```bash
# Créer le répertoire snippets
mkdir -p /var/lib/vz/snippets

# Activer les snippets sur le storage local
pvesm set local --content backup,iso,vztmpl,snippets
```

> **Note** : Sans cette configuration, Terraform ne pourra pas créer de VMs avec Docker pré-installé.

## Étape 9 : Télécharger des templates

### Templates LXC (conteneurs)

Depuis l'interface web ou en ligne de commande :

```bash
# Mettre à jour la liste des templates
pveam update

# Lister les templates disponibles
pveam available --section system

# Télécharger Ubuntu 24.04 (recommandé)
pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst

# Télécharger Debian 13 (Trixie - base de PVE 9.x)
pveam download local debian-13-standard_13.1-2_amd64.tar.zst

# Ou Debian 12 (Bookworm)
pveam download local debian-12-standard_12.12-1_amd64.tar.zst
```

### Template VM cloud-init (pour Terraform)

```bash
# Télécharger l'image cloud Ubuntu
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Créer une VM template (ID 9000)
qm create 9000 --name "ubuntu-cloud-template" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Importer le disque
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm

# Configurer le disque
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Configurer cloud-init
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0

# Activer QEMU Guest Agent
qm set 9000 --agent enabled=1

# Convertir en template
qm template 9000
```

## Étape 10 : Vérification

### Vérifier que tout fonctionne

```bash
# Vérifier les services Proxmox
systemctl status pvedaemon pveproxy

# Vérifier les informations du node
pvesh get /nodes/$(hostname)/status

# Vérifier le stockage
pvesm status

# Lister les templates téléchargés
pveam list local

# Tester l'API avec le token (utiliser des guillemets simples pour éviter l'interprétation du !)
curl -k -H 'Authorization: PVEAPIToken=terraform@pve!terraform-token=VOTRE_TOKEN' \
  'https://127.0.0.1:8006/api2/json/nodes'
```

> **Note** : La commande `pvecm status` est uniquement pour les clusters multi-nodes. Sur une installation single-node, elle retourne une erreur (c'est normal).

## Informations à noter

Gardez ces informations pour la configuration Terraform :

| Information | Valeur |
|-------------|--------|
| URL Proxmox | `https://192.168.1.X:8006` |
| Node name | `pve` (nom par défaut) |
| Token API Terraform | `terraform@pve!terraform-token=xxx` |
| Token API Prometheus | `prometheus@pve!prometheus=xxx` (optionnel, pour monitoring) |
| Template VM ID | `9000` |
| Template LXC | `local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst` |
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
- Normal sans souscription, suivre l'étape 5.1 pour supprimer le popup

### Token API ne fonctionne pas
- Vérifier que `--privsep=0` a été utilisé
- Vérifier les permissions du rôle

### VMs ne démarrent pas
- Vérifier que VT-x est activé dans le BIOS
- Vérifier l'espace disque : `df -h`
