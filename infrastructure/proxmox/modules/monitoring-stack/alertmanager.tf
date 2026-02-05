# =============================================================================
# Alertmanager Configuration
# =============================================================================
# Alertmanager config and tooling alerts
# =============================================================================

locals {
  # Configuration Alertmanager
  alertmanager_config = templatefile("${path.module}/files/alertmanager.yml.tpl", {
    telegram_enabled   = var.telegram_enabled
    telegram_bot_token = var.telegram_bot_token
    telegram_chat_id   = var.telegram_chat_id
  })

  # Tooling Alerts
  tooling_alerts = var.tooling_enabled ? file("${path.module}/files/prometheus/alerts/tooling.yml") : ""
}
