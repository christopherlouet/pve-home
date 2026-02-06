#!/usr/bin/env bats
# =============================================================================
# Tests BATS - Docker Compose Tooling Stack Template
# =============================================================================
# Validation statique du template docker-compose.yml.tpl du module tooling.
# Verifie la structure, les services, la securite et la coherence.
# =============================================================================

TEMPLATE_FILE="${BATS_TEST_DIRNAME}/../../infrastructure/proxmox/modules/tooling-stack/files/docker-compose.yml.tpl"

# -----------------------------------------------------------------------------
# Existence et structure
# -----------------------------------------------------------------------------

@test "tooling docker-compose.yml.tpl existe" {
    [ -f "$TEMPLATE_FILE" ]
}

@test "tooling docker-compose: pas de version deprecated" {
    ! grep -q '^version:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: definit le reseau tooling" {
    grep -q 'tooling:' "$TEMPLATE_FILE"
    grep -q 'driver: bridge' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: definit le subnet 172.20.0.0/24" {
    grep -q '172.20.0.0/24' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Services conditionnels Step-ca
# -----------------------------------------------------------------------------

@test "tooling docker-compose: step-ca conditionnel sur step_ca_enabled" {
    grep -q '%{ if step_ca_enabled' "$TEMPLATE_FILE"
    grep -q 'step-ca:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: step-ca utilise smallstep/step-ca" {
    grep -q 'smallstep/step-ca:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: step-ca expose le port 8443" {
    grep -q '8443:8443' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: step-ca expose les metriques 9290" {
    grep -q '9290:9290' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Services conditionnels Traefik
# -----------------------------------------------------------------------------

@test "tooling docker-compose: traefik conditionnel sur traefik_enabled" {
    grep -q '%{ if traefik_enabled' "$TEMPLATE_FILE"
    grep -q 'traefik:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: traefik expose les ports 80 et 443" {
    grep -q '"80:80"' "$TEMPLATE_FILE"
    grep -q '"443:443"' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Services conditionnels Harbor
# -----------------------------------------------------------------------------

@test "tooling docker-compose: harbor conditionnel sur harbor_enabled" {
    grep -q '%{ if harbor_enabled' "$TEMPLATE_FILE"
    grep -q 'harbor-core:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: harbor-db utilise goharbor/harbor-db" {
    grep -q 'goharbor/harbor-db:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: harbor-registry utilise goharbor/registry-photon" {
    grep -q 'goharbor/registry-photon:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: harbor-core utilise goharbor/harbor-core" {
    grep -q 'goharbor/harbor-core:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: harbor-portal present" {
    grep -q 'harbor-portal:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: harbor-jobservice present" {
    grep -q 'harbor-jobservice:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: harbor-trivy conditionnel" {
    grep -q '%{ if harbor_trivy_enabled' "$TEMPLATE_FILE"
    grep -q 'harbor-trivy:' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Services conditionnels Authentik
# -----------------------------------------------------------------------------

@test "tooling docker-compose: authentik conditionnel sur authentik_enabled" {
    grep -q '%{ if authentik_enabled' "$TEMPLATE_FILE"
    grep -q 'authentik-server:' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: authentik-db utilise postgres:15-alpine" {
    grep -q 'postgres:15-alpine' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: authentik-redis utilise redis:7-alpine" {
    grep -q 'redis:7-alpine' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: authentik-worker present" {
    grep -q 'authentik-worker:' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Securite Docker (hardening)
# -----------------------------------------------------------------------------

@test "tooling docker-compose: tous les services ont no-new-privileges" {
    local service_count
    local security_count
    service_count=$(grep -c 'image:' "$TEMPLATE_FILE")
    security_count=$(grep -c 'no-new-privileges:true' "$TEMPLATE_FILE")
    [ "$security_count" -ge "$service_count" ]
}

@test "tooling docker-compose: tous les services ont cap_drop ALL" {
    local service_count
    local capdrop_count
    service_count=$(grep -c 'image:' "$TEMPLATE_FILE")
    capdrop_count=$(grep -c 'cap_drop:' "$TEMPLATE_FILE")
    [ "$capdrop_count" -ge "$service_count" ]
}

@test "tooling docker-compose: step-ca a read_only true" {
    sed -n '/step-ca:/,/^  [a-z%]/p' "$TEMPLATE_FILE" | grep -q 'read_only: true'
}

@test "tooling docker-compose: harbor-registry a read_only true" {
    sed -n '/harbor-registry:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'read_only: true'
}

@test "tooling docker-compose: harbor-portal a read_only true" {
    sed -n '/harbor-portal:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'read_only: true'
}

@test "tooling docker-compose: authentik-redis a read_only true" {
    sed -n '/authentik-redis:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'read_only: true'
}

@test "tooling docker-compose: harbor-db a les cap_add necessaires" {
    # PostgreSQL a besoin de CHOWN, SETUID, SETGID pour fonctionner
    sed -n '/harbor-db:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'CHOWN'
    sed -n '/harbor-db:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'SETUID'
    sed -n '/harbor-db:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'SETGID'
}

@test "tooling docker-compose: authentik-db a les cap_add necessaires" {
    sed -n '/authentik-db:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'CHOWN'
    sed -n '/authentik-db:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'SETUID'
}

# -----------------------------------------------------------------------------
# Healthchecks
# -----------------------------------------------------------------------------

@test "tooling docker-compose: step-ca a un healthcheck" {
    sed -n '/step-ca:/,/^  [a-z%]/p' "$TEMPLATE_FILE" | grep -q 'healthcheck:'
}

@test "tooling docker-compose: harbor-db a un healthcheck pg_isready" {
    sed -n '/harbor-db:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'pg_isready'
}

@test "tooling docker-compose: harbor-core a un healthcheck" {
    sed -n '/harbor-core:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'healthcheck:'
}

@test "tooling docker-compose: authentik-db a un healthcheck pg_isready" {
    sed -n '/authentik-db:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'pg_isready'
}

@test "tooling docker-compose: authentik-redis a un healthcheck redis-cli ping" {
    sed -n '/authentik-redis:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'redis-cli'
}

@test "tooling docker-compose: authentik-server a un healthcheck" {
    sed -n '/authentik-server:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'healthcheck:'
}

# -----------------------------------------------------------------------------
# Depends_on avec conditions
# -----------------------------------------------------------------------------

@test "tooling docker-compose: harbor-core depends_on harbor-db healthy" {
    sed -n '/harbor-core:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'service_healthy'
}

@test "tooling docker-compose: authentik-server depends_on db et redis" {
    sed -n '/authentik-server:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'authentik-db:'
    sed -n '/authentik-server:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'authentik-redis:'
}

# -----------------------------------------------------------------------------
# Variables de template Terraform
# -----------------------------------------------------------------------------

@test "tooling docker-compose: utilise domain_suffix" {
    grep -q '${domain_suffix}' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: utilise step_ca_password" {
    grep -q '${step_ca_password}' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: utilise harbor_admin_password" {
    grep -q '${harbor_admin_password}' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: utilise authentik_secret_key" {
    grep -q '${authentik_secret_key}' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Restart policies et images
# -----------------------------------------------------------------------------

@test "tooling docker-compose: tous les services ont restart unless-stopped" {
    local service_count
    local restart_count
    service_count=$(grep -c 'image:' "$TEMPLATE_FILE")
    restart_count=$(grep -c 'restart: unless-stopped' "$TEMPLATE_FILE")
    [ "$restart_count" -ge "$service_count" ]
}

@test "tooling docker-compose: aucune image :latest" {
    ! grep -E 'image:.*:latest' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Adresses IP statiques
# -----------------------------------------------------------------------------

@test "tooling docker-compose: step-ca a une IP statique 172.20.0.10" {
    grep -q '172.20.0.10' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: traefik a une IP statique 172.20.0.2" {
    grep -q '172.20.0.2' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: harbor-core a une IP statique 172.20.0.20" {
    grep -q '172.20.0.20' "$TEMPLATE_FILE"
}

@test "tooling docker-compose: authentik-server a une IP statique 172.20.0.30" {
    grep -q '172.20.0.30' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Traefik labels
# -----------------------------------------------------------------------------

@test "tooling docker-compose: step-ca a des labels traefik" {
    sed -n '/step-ca:/,/^%/p' "$TEMPLATE_FILE" | grep -q 'traefik.enable=true'
}

@test "tooling docker-compose: harbor-core a des labels traefik" {
    sed -n '/harbor-core:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'traefik.enable=true'
}

@test "tooling docker-compose: authentik-server a des labels traefik" {
    sed -n '/authentik-server:/,/^  [a-z]/p' "$TEMPLATE_FILE" | grep -q 'traefik.enable=true'
}
