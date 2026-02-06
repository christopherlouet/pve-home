# =============================================================================
# Alertmanager Configuration
# =============================================================================
# Alertmanager config and tooling alerts.
#
# Alertmanager recoit les alertes de Prometheus et les route vers Telegram.
# Si telegram_enabled=false, Alertmanager demarre mais n'envoie rien.
# Les regles d'alerte sont dans files/prometheus/alerts/ (default.yml + tooling.yml).
# =============================================================================

locals {
  # Genere alertmanager.yml : route vers Telegram si active, sinon receiver null
  alertmanager_config = templatefile("${path.module}/files/alertmanager.yml.tpl", {
    telegram_enabled   = var.telegram_enabled
    telegram_bot_token = var.telegram_bot_token
    telegram_chat_id   = var.telegram_chat_id
  })

  # Regles d'alerte specifiques a la tooling-stack (Step-ca cert expiry, Harbor health, etc.)
  tooling_alerts = var.tooling_enabled ? file("${path.module}/files/prometheus/alerts/tooling.yml") : ""
}
