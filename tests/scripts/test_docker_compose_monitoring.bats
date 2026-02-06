#!/usr/bin/env bats
# =============================================================================
# Tests BATS - Docker Compose Monitoring Stack Template
# =============================================================================
# Validation statique du template docker-compose.yml.tpl du module monitoring.
# Verifie la structure, les services, la securite et la coherence.
# =============================================================================

TEMPLATE_FILE="${BATS_TEST_DIRNAME}/../../infrastructure/proxmox/modules/monitoring-stack/files/docker-compose.yml.tpl"

# -----------------------------------------------------------------------------
# Existence et structure
# -----------------------------------------------------------------------------

@test "monitoring docker-compose.yml.tpl existe" {
    [ -f "$TEMPLATE_FILE" ]
}

@test "monitoring docker-compose: definit la version" {
    grep -q 'version:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: definit le reseau monitoring" {
    grep -q 'monitoring:' "$TEMPLATE_FILE"
    grep -q 'driver: bridge' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Services obligatoires (toujours presents)
# -----------------------------------------------------------------------------

@test "monitoring docker-compose: service prometheus present" {
    grep -q 'prometheus:' "$TEMPLATE_FILE"
    grep -q 'prom/prometheus:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: service grafana present" {
    grep -q 'grafana:' "$TEMPLATE_FILE"
    grep -q 'grafana/grafana:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: service pve-exporter present" {
    grep -q 'pve-exporter:' "$TEMPLATE_FILE"
    grep -q 'prompve/prometheus-pve-exporter:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: service node-exporter present" {
    grep -q 'node-exporter:' "$TEMPLATE_FILE"
    grep -q 'prom/node-exporter:' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Services conditionnels
# -----------------------------------------------------------------------------

@test "monitoring docker-compose: traefik conditionnel sur traefik_enabled" {
    grep -q '%{ if traefik_enabled' "$TEMPLATE_FILE"
    grep -q 'traefik:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: alertmanager conditionnel sur telegram_enabled" {
    grep -q '%{ if telegram_enabled' "$TEMPLATE_FILE"
    grep -q 'alertmanager:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: loki conditionnel sur loki_enabled" {
    grep -q '%{ if loki_enabled' "$TEMPLATE_FILE"
    grep -q 'loki:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: promtail conditionnel sur loki_enabled" {
    grep -q 'promtail:' "$TEMPLATE_FILE"
    grep -q 'grafana/promtail:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: uptime-kuma conditionnel sur uptime_kuma_enabled" {
    grep -q '%{ if uptime_kuma_enabled' "$TEMPLATE_FILE"
    grep -q 'uptime-kuma:' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Securite Docker (hardening)
# -----------------------------------------------------------------------------

@test "monitoring docker-compose: prometheus a no-new-privileges" {
    # Verifie que la section prometheus contient la directive securite
    sed -n '/^  prometheus:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'no-new-privileges:true'
}

@test "monitoring docker-compose: prometheus a cap_drop ALL" {
    sed -n '/^  prometheus:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'ALL'
}

@test "monitoring docker-compose: grafana a no-new-privileges" {
    sed -n '/^  grafana:/,/^  [a-z%]/p' "$TEMPLATE_FILE" | grep -q 'no-new-privileges:true'
}

@test "monitoring docker-compose: grafana a cap_drop ALL" {
    sed -n '/^  grafana:/,/^  [a-z%]/p' "$TEMPLATE_FILE" | grep -q 'ALL'
}

@test "monitoring docker-compose: pve-exporter a no-new-privileges" {
    sed -n '/^  pve-exporter:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'no-new-privileges:true'
}

@test "monitoring docker-compose: node-exporter a no-new-privileges" {
    sed -n '/^  node-exporter:/,/^[a-z]/p' "$TEMPLATE_FILE" | grep -q 'no-new-privileges:true'
}

@test "monitoring docker-compose: tous les services ont security_opt" {
    # Compte le nombre de services (image:) vs security_opt
    local service_count
    local security_count
    service_count=$(grep -c 'image:' "$TEMPLATE_FILE")
    security_count=$(grep -c 'no-new-privileges:true' "$TEMPLATE_FILE")
    [ "$security_count" -ge "$service_count" ]
}

@test "monitoring docker-compose: tous les services ont cap_drop ALL" {
    local service_count
    local capdrop_count
    service_count=$(grep -c 'image:' "$TEMPLATE_FILE")
    capdrop_count=$(grep -c 'cap_drop:' "$TEMPLATE_FILE")
    [ "$capdrop_count" -ge "$service_count" ]
}

# -----------------------------------------------------------------------------
# Configuration des services
# -----------------------------------------------------------------------------

@test "monitoring docker-compose: prometheus expose le port 9090" {
    grep -q '9090:9090' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: grafana expose le port 3000" {
    grep -q '3000:3000' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: alertmanager expose le port 9093" {
    grep -q '9093:9093' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: pve-exporter expose le port 9221" {
    grep -q '9221:9221' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: node-exporter expose le port 9100" {
    grep -q '9100:9100' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: loki expose le port 3100" {
    grep -q '3100:3100' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Volumes persistants
# -----------------------------------------------------------------------------

@test "monitoring docker-compose: volume prometheus_data defini" {
    grep -q 'prometheus_data:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: volume grafana_data defini" {
    grep -q 'grafana_data:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: volume alertmanager_data conditionnel" {
    grep -q 'alertmanager_data:' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: volume loki_data conditionnel" {
    grep -q 'loki_data:' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Variables de template Terraform
# -----------------------------------------------------------------------------

@test "monitoring docker-compose: utilise retention_days" {
    grep -q '${retention_days}' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: utilise retention_size" {
    grep -q '${retention_size}' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: utilise grafana_admin_password" {
    grep -q '${grafana_admin_password}' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: utilise domain_suffix" {
    grep -q '${domain_suffix}' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: utilise monitoring_ip" {
    grep -q '${monitoring_ip}' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Restart policies
# -----------------------------------------------------------------------------

@test "monitoring docker-compose: tous les services ont restart unless-stopped" {
    local service_count
    local restart_count
    service_count=$(grep -c 'image:' "$TEMPLATE_FILE")
    restart_count=$(grep -c 'restart: unless-stopped' "$TEMPLATE_FILE")
    [ "$restart_count" -ge "$service_count" ]
}

# -----------------------------------------------------------------------------
# Prometheus specifique
# -----------------------------------------------------------------------------

@test "monitoring docker-compose: prometheus utilise user nobody (65534)" {
    grep -q 'user:.*65534' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: prometheus active wal-compression" {
    grep -q 'wal-compression' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: prometheus active web-enable-lifecycle" {
    grep -q 'web.enable-lifecycle' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Images versionnees (pas de :latest)
# -----------------------------------------------------------------------------

@test "monitoring docker-compose: aucune image :latest" {
    ! grep -E 'image:.*:latest' "$TEMPLATE_FILE"
}

@test "monitoring docker-compose: toutes les images ont un tag de version" {
    # Chaque ligne image: doit avoir un :vX.Y.Z ou :X.Y.Z
    local images_without_version
    images_without_version=$(grep 'image:' "$TEMPLATE_FILE" | grep -v ':v\?[0-9]' | grep -v ':[0-9]' || true)
    [ -z "$images_without_version" ]
}
