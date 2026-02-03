# Intel e1000e - Hardware Unit Hang

## Problème

Le serveur Proxmox devient inaccessible de manière intermittente :
- Perte de connexion SSH
- Interface web Proxmox inaccessible
- Les VMs/LXC continuent de tourner mais sont isolées du réseau

## Symptômes

### Logs caractéristiques

```
e1000e 0000:00:1f.6 nic0: Detected Hardware Unit Hang:
  TDH                  <bc>
  TDT                  <c8>
  next_to_use          <c8>
  next_to_clean        <bc>
```

Ces messages apparaissent toutes les 2 secondes dans `dmesg` ou `journalctl -k`.

### Vérification

```bash
# Vérifier les événements passés
journalctl -k | grep -i "hardware unit hang"

# Surveiller en temps réel
journalctl -f -k | grep -i "hardware unit hang"

# Compter les occurrences
journalctl --no-pager | grep -c "Hardware Unit Hang"
```

## Cause

Bug connu du driver `e1000e` avec les cartes réseau **Intel I219-V** et **I219-LM** (Ethernet Connection 10/11/12) sur les chipsets récents.

Le driver détecte un blocage du transmit descriptor ring (TDH/TDT mismatch) et ne parvient pas à récupérer, causant un gel complet de l'interface réseau.

### Matériel affecté

```bash
# Identifier la carte réseau
lspci | grep -i ethernet
# Exemple: Intel Corporation Ethernet Connection (10) I219-V

# Détails complets
lspci -vvs $(lspci | grep -i ethernet | cut -d' ' -f1)
```

## Solutions

### Solution 1 : Désactiver Smart Power Down (recommandé)

Désactive les optimisations d'énergie du PHY qui peuvent causer des instabilités.

```bash
# Créer la configuration
cat > /etc/modprobe.d/e1000e.conf << 'EOF'
# Fix Intel I219-V Hardware Unit Hang issue
options e1000e SmartPowerDownEnable=0
EOF

# Mettre à jour l'initramfs
update-initramfs -u

# Redémarrer pour appliquer
reboot
```

**Vérification après reboot :**

```bash
dmesg | grep -i "smart power"
# Doit afficher: PHY Smart Power Down Disabled
```

### Solution 2 : Augmenter les ring buffers (recommandé)

Augmente la taille des buffers de transmission/réception de 256 à 4096.

```bash
# Appliquer immédiatement
ethtool -G nic0 rx 4096 tx 4096

# Rendre persistant dans /etc/network/interfaces
# Ajouter dans la section "iface nic0 inet manual" :
#   post-up ethtool -G nic0 rx 4096 tx 4096
```

**Configuration complète `/etc/network/interfaces` :**

```
auto lo
iface lo inet loopback

iface nic0 inet manual
    post-up ethtool -G nic0 rx 4096 tx 4096

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.50/24
    gateway 192.168.1.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0
```

**Vérification :**

```bash
ethtool -g nic0 | grep -A5 "Current hardware"
# RX et TX doivent être à 4096
```

### Solution 3 : Désactiver TSO/GSO/GRO

Si les solutions 1 et 2 ne suffisent pas, désactiver les optimisations d'offload.

```bash
# Appliquer immédiatement
ethtool -K nic0 tso off gso off gro off

# Rendre persistant dans /etc/network/interfaces
# Ajouter :
#   post-up ethtool -K nic0 tso off gso off gro off
```

### Solution 4 : Forcer 100 Mbps (dernier recours)

Le problème semble plus fréquent à 1 Gbps. Forcer 100 Mbps peut stabiliser la connexion.

```bash
# Appliquer immédiatement
ethtool -s nic0 speed 100 duplex full autoneg off

# Rendre persistant dans /etc/network/interfaces
# Ajouter :
#   post-up ethtool -s nic0 speed 100 duplex full autoneg off
```

## Configuration recommandée

Appliquer les **solutions 1 et 2** ensemble :

**`/etc/modprobe.d/e1000e.conf` :**

```
# Fix Intel I219-V Hardware Unit Hang issue
options e1000e SmartPowerDownEnable=0
```

**`/etc/network/interfaces` :**

```
iface nic0 inet manual
    post-up ethtool -G nic0 rx 4096 tx 4096
```

## Diagnostic complet

```bash
# Informations sur la carte
ethtool -i nic0

# Paramètres actuels
ethtool nic0

# Ring buffers
ethtool -g nic0

# Offload settings
ethtool -k nic0

# Statistiques (chercher les erreurs)
ethtool -S nic0 | grep -i error

# Paramètres du module
modinfo e1000e | grep parm
```

## Historique des incidents

| Date | Serveur | Action | Résultat |
|------|---------|--------|----------|
| 2026-02-03 | pve-mon (192.168.1.50) | Solutions 1+2 appliquées | En observation |

## Références

- [Intel I219 e1000e driver issues - Proxmox Forum](https://forum.proxmox.com/threads/intel-i219-e1000e-driver-issues.42292/)
- [e1000e Hardware Unit Hang - Kernel Bug](https://bugzilla.kernel.org/show_bug.cgi?id=205119)
- [Red Hat Knowledgebase - e1000e troubleshooting](https://access.redhat.com/solutions/1165513)
