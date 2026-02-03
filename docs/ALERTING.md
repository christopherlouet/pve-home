# Configuration des alertes Telegram

Guide de configuration des notifications Telegram pour recevoir les alertes de l'infrastructure Proxmox.

## Architecture

```
Prometheus          Alertmanager         Telegram
   |                    |                   |
   | (evalue regles)    |                   |
   +---> firing ------->+ (route par        |
                        |  severite)        |
                        +------------------>+ Bot envoie message
                                            | au chat/groupe
```

## Prerequis

- Stack monitoring deployee (`environments/monitoring/`)
- Compte Telegram
- Acces a Internet depuis la VM monitoring (port 443 sortant)

## Configuration

### 1. Creer un bot Telegram

1. Ouvrir Telegram et chercher **@BotFather**
2. Envoyer `/newbot`
3. Donner un nom au bot (ex: "PVE Home Alerts")
4. Donner un username unique (ex: `pve_home_alerts_bot`)
5. **Copier le token** affiche (format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

> **Important** : Conservez ce token en securite, il donne un acces complet au bot.

### 2. Obtenir le Chat ID

#### Option A : Chat prive (recommande pour debuter)

1. Envoyer un message quelconque a votre bot (ex: "Hello")
2. Ouvrir dans un navigateur :
   ```
   https://api.telegram.org/bot<VOTRE_TOKEN>/getUpdates
   ```
3. Chercher `"chat":{"id":123456789}` dans la reponse JSON
4. Le nombre `123456789` est votre **chat_id**

#### Option B : Groupe Telegram

1. Creer un groupe et y ajouter votre bot
2. Envoyer un message dans le groupe
3. Utiliser la meme URL `getUpdates`
4. Le chat_id d'un groupe est **negatif** (ex: `-123456789`)

> **Astuce** : Pour un groupe, vous pouvez aussi ajouter `@RawDataBot` temporairement, il affichera le chat_id dans le groupe.

### 3. Configurer Terraform

Editer le fichier `terraform.tfvars` dans `infrastructure/proxmox/environments/monitoring/` :

```hcl
monitoring = {
  # ... configuration existante ...

  telegram = {
    enabled   = true
    bot_token = "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
    chat_id   = "987654321"
  }
}
```

### 4. Appliquer les changements

```bash
cd infrastructure/proxmox/environments/monitoring
terraform plan   # Verifier les changements
terraform apply  # Appliquer
```

La VM monitoring sera reconfiguree avec Alertmanager active.

## Tester la configuration

### Test manuel du bot

Verifier que le bot peut envoyer des messages :

```bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -d "chat_id=<CHAT_ID>" \
  -d "text=Test alerte PVE Home"
```

### Declencher une alerte de test

Sur la VM monitoring, creer une alerte manuelle :

```bash
# Se connecter a la VM monitoring
ssh ubuntu@<IP_MONITORING>

# Envoyer une alerte de test a Alertmanager
curl -X POST http://localhost:9093/api/v2/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "instance": "test"
    },
    "annotations": {
      "summary": "Test alert from CLI",
      "description": "This is a test alert to verify Telegram notifications"
    }
  }]'
```

Vous devriez recevoir un message Telegram dans les 30 secondes.

## Alertes configurees

28 alertes reparties en 7 groupes avec routage par severite :

| Severite | Icone | Repetition | Exemples |
|----------|-------|------------|----------|
| **critical** | `[U+1F6A8]` | Toutes les 1h | HostDown, ProxmoxNodeDown, DiskAlmostFull |
| **warning** | `[U+26A0][U+FE0F]` | Toutes les 4h | HighCpuUsage, HighMemoryUsage, BackupStorageAlmostFull |
| **info** | `[U+1F535]` | Toutes les 4h | SnapshotOlderThanWeek |

### Groupes d'alertes

| Groupe | Alertes | Description |
|--------|---------|-------------|
| **Node** | 9 | CPU, RAM, disque, reseau, services systemd |
| **Proxmox** | 5 | Nodes PVE, VMs, stockage |
| **Prometheus** | 3 | Targets, config, regles |
| **Backup** | 3 | Sauvegardes, espace stockage |
| **Drift** | 3 | Derives Terraform |
| **Health** | 2 | Sante infrastructure |
| **Lifecycle** | 3 | Expiration VMs, snapshots, reboot |

Liste complete dans le [README principal](../README.md#alertes-prometheus).

## Format des messages

Les messages Telegram sont formates selon la severite :

**Alerte critique** :
```
[U+1F6A8] CRITICAL ALERT [U+1F6A8]

Alert: HostDown
Instance: pve-prod:9100
Description: Host pve-prod has been unreachable for more than 2 minutes
Started: 2024-01-15 14:32:00
```

**Alerte warning** :
```
[U+26A0][U+FE0F] WARNING

Alert: HighCpuUsage
Instance: docker-server:9100
Description: CPU usage is above 85% for more than 5 minutes
```

**Resolution** :
```
[U+1F7E2] RESOLVED

Alert: HighCpuUsage
Instance: docker-server:9100
```

## Personnalisation

### Modifier les templates de message

Les templates sont dans `infrastructure/proxmox/modules/monitoring-stack/files/alertmanager.yml.tpl`.

### Ajouter des alertes

Les regles sont dans `infrastructure/proxmox/modules/monitoring-stack/files/prometheus/alerts/default.yml`.

Exemple d'ajout :

```yaml
- alert: CustomAlert
  expr: my_metric > 100
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Custom alert triggered"
    description: "my_metric is {{ $value }} on {{ $labels.instance }}"
```

### Modifier les intervalles de repetition

Dans `alertmanager.yml.tpl`, ajuster `repeat_interval` par route :

```yaml
routes:
  - receiver: 'critical'
    match:
      severity: critical
    repeat_interval: 30m  # Reduire a 30 minutes pour les alertes critiques
```

## Troubleshooting

### Pas de message recu

1. **Verifier que le bot est demarre** : Envoyer `/start` au bot dans Telegram
2. **Verifier le token** : Tester avec curl (voir section "Test manuel")
3. **Verifier le chat_id** : Un chat_id de groupe doit etre negatif
4. **Verifier les logs Alertmanager** :
   ```bash
   ssh ubuntu@<IP_MONITORING>
   docker logs monitoring-alertmanager-1
   ```

### Erreur "chat not found"

- Le bot n'a jamais recu de message dans ce chat
- Solution : Envoyer un message au bot ou dans le groupe, puis reessayer

### Erreur "Forbidden: bot was blocked by the user"

- L'utilisateur a bloque le bot
- Solution : Debloquer le bot dans Telegram (parametres du chat)

### Alertmanager non deploye

Si `telegram.enabled = false` dans tfvars, Alertmanager n'est pas deploye.

Verifier :
```bash
ssh ubuntu@<IP_MONITORING>
docker ps | grep alertmanager
```

### Messages en double

- Verifier qu'il n'y a pas plusieurs instances d'Alertmanager
- Verifier les `group_by` dans la configuration pour regrouper les alertes similaires

## Desactiver les notifications

Pour desactiver temporairement sans supprimer la configuration :

```hcl
telegram = {
  enabled   = false  # Desactive Alertmanager
  bot_token = "..."
  chat_id   = "..."
}
```

Puis `terraform apply`.

## Securite

- **Ne jamais commiter** le `bot_token` dans le code source
- Le fichier `terraform.tfvars` est dans `.gitignore`
- En production, utiliser des variables d'environnement ou un gestionnaire de secrets
- Le bot_token est marque `sensitive` dans Terraform (masque dans les logs)

## Voir aussi

- [README principal - Alertes Prometheus](../README.md#alertes-prometheus)
- [Health Checks](HEALTH-CHECKS.md)
- [Drift Detection](DRIFT-DETECTION.md)
- [terraform.tfvars.example](../infrastructure/proxmox/environments/monitoring/terraform.tfvars.example)
