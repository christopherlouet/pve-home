#!/usr/bin/env bats
# =============================================================================
# Tests BATS - Script install-minio.sh.tpl
# =============================================================================
# Validation statique du template d'installation Minio.
# Verifie les bonnes pratiques: checksums SHA256, securite, structure.
# =============================================================================

TEMPLATE_FILE="${BATS_TEST_DIRNAME}/../../infrastructure/proxmox/modules/minio/files/install-minio.sh.tpl"

# -----------------------------------------------------------------------------
# Existence et structure
# -----------------------------------------------------------------------------

@test "install-minio: template existe" {
    [ -f "$TEMPLATE_FILE" ]
}

@test "install-minio: commence par shebang bash" {
    head -1 "$TEMPLATE_FILE" | grep -q '#!/bin/bash'
}

@test "install-minio: utilise set -euo pipefail" {
    grep -q 'set -euo pipefail' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Verification d'integrite SHA256 - Binaire Minio
# -----------------------------------------------------------------------------

@test "install-minio: telecharge le binaire minio" {
    grep -q 'curl.*minio.*-o.*/usr/local/bin/minio' "$TEMPLATE_FILE"
}

@test "install-minio: telecharge le fichier sha256sum pour minio" {
    grep -q 'curl.*minio.sha256sum' "$TEMPLATE_FILE"
}

@test "install-minio: verifie le checksum minio avec sha256sum -c" {
    grep -q 'sha256sum -c.*/tmp/minio.sha256sum' "$TEMPLATE_FILE"
}

@test "install-minio: nettoie le fichier sha256sum minio apres verification" {
    grep -q 'rm -f /tmp/minio.sha256sum' "$TEMPLATE_FILE"
}

@test "install-minio: curl utilise -fsSL pour minio (fail silently)" {
    grep 'minio.*-o.*/usr/local/bin/minio' "$TEMPLATE_FILE" | grep -q '\-fsSL'
}

# -----------------------------------------------------------------------------
# Verification d'integrite SHA256 - Client mc
# -----------------------------------------------------------------------------

@test "install-minio: telecharge le client mc" {
    grep -q 'curl.*mc.*-o.*/usr/local/bin/mc' "$TEMPLATE_FILE"
}

@test "install-minio: telecharge le fichier sha256sum pour mc" {
    grep -q 'curl.*mc.sha256sum' "$TEMPLATE_FILE"
}

@test "install-minio: verifie le checksum mc avec sha256sum -c" {
    grep -q 'sha256sum -c.*/tmp/mc.sha256sum' "$TEMPLATE_FILE"
}

@test "install-minio: nettoie le fichier sha256sum mc apres verification" {
    grep -q 'rm -f /tmp/mc.sha256sum' "$TEMPLATE_FILE"
}

@test "install-minio: curl utilise -fsSL pour mc (fail silently)" {
    grep 'mc.*-o.*/usr/local/bin/mc' "$TEMPLATE_FILE" | grep -q '\-fsSL'
}

# -----------------------------------------------------------------------------
# Securite des binaires
# -----------------------------------------------------------------------------

@test "install-minio: chmod +x sur le binaire minio" {
    grep -q 'chmod +x /usr/local/bin/minio' "$TEMPLATE_FILE"
}

@test "install-minio: chmod +x sur le client mc" {
    grep -q 'chmod +x /usr/local/bin/mc' "$TEMPLATE_FILE"
}

@test "install-minio: cree un utilisateur systeme dedie" {
    grep -q 'useradd.*minio' "$TEMPLATE_FILE"
}

@test "install-minio: utilisateur sans shell de login" {
    grep -q '/sbin/nologin' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Credentials securises
# -----------------------------------------------------------------------------

@test "install-minio: utilise MC_HOST_local pour les credentials" {
    grep -q 'MC_HOST_local' "$TEMPLATE_FILE"
}

@test "install-minio: ne passe pas de credentials en arguments mc" {
    # mc alias set est la methode non securisee
    ! grep -q 'mc alias set' "$TEMPLATE_FILE"
    ! grep -q 'mc config host' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Service systemd
# -----------------------------------------------------------------------------

@test "install-minio: cree un service systemd" {
    grep -q 'minio.service' "$TEMPLATE_FILE"
}

@test "install-minio: service a Restart=always" {
    grep -q 'Restart=always' "$TEMPLATE_FILE"
}

@test "install-minio: service a LimitNOFILE" {
    grep -q 'LimitNOFILE' "$TEMPLATE_FILE"
}

@test "install-minio: active le service au demarrage" {
    grep -q 'systemctl enable' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Variables de template Terraform
# -----------------------------------------------------------------------------

@test "install-minio: utilise variable minio_root_user" {
    grep -q '${minio_root_user}' "$TEMPLATE_FILE"
}

@test "install-minio: utilise variable minio_root_password" {
    grep -q '${minio_root_password}' "$TEMPLATE_FILE"
}

@test "install-minio: utilise variable minio_port" {
    grep -q '${minio_port}' "$TEMPLATE_FILE"
}

@test "install-minio: utilise variable minio_console_port" {
    grep -q '${minio_console_port}' "$TEMPLATE_FILE"
}

@test "install-minio: utilise boucle for pour les buckets" {
    grep -q '%{for bucket in buckets' "$TEMPLATE_FILE"
}

# -----------------------------------------------------------------------------
# Pattern de telechargement securise
# -----------------------------------------------------------------------------

@test "install-minio: SHA256 verification avant chmod (minio)" {
    # Le sha256sum -c doit apparaitre avant le chmod +x pour minio
    local checksum_line
    local chmod_line
    checksum_line=$(grep -n 'sha256sum -c.*/tmp/minio.sha256sum' "$TEMPLATE_FILE" | head -1 | cut -d: -f1)
    chmod_line=$(grep -n 'chmod +x /usr/local/bin/minio' "$TEMPLATE_FILE" | head -1 | cut -d: -f1)
    [ "$checksum_line" -lt "$chmod_line" ]
}

@test "install-minio: SHA256 verification avant chmod (mc)" {
    # Le sha256sum -c doit apparaitre avant le chmod +x pour mc
    local checksum_line
    local chmod_line
    checksum_line=$(grep -n 'sha256sum -c.*/tmp/mc.sha256sum' "$TEMPLATE_FILE" | head -1 | cut -d: -f1)
    chmod_line=$(grep -n 'chmod +x /usr/local/bin/mc' "$TEMPLATE_FILE" | head -1 | cut -d: -f1)
    [ "$checksum_line" -lt "$chmod_line" ]
}

@test "install-minio: service a NoNewPrivileges" {
    grep -q 'NoNewPrivileges=yes' "$TEMPLATE_FILE"
}

@test "install-minio: service a PrivateTmp" {
    grep -q 'PrivateTmp=yes' "$TEMPLATE_FILE"
}

@test "install-minio: service a ProtectKernelModules" {
    grep -q 'ProtectKernelModules=yes' "$TEMPLATE_FILE"
}

@test "install-minio: service a ProtectKernelTunables" {
    grep -q 'ProtectKernelTunables=yes' "$TEMPLATE_FILE"
}

@test "install-minio: service a RestrictRealtime" {
    grep -q 'RestrictRealtime=yes' "$TEMPLATE_FILE"
}

@test "install-minio: telecharge depuis dl.min.io officiel" {
    grep -q 'https://dl.min.io/server/minio/release/' "$TEMPLATE_FILE"
    grep -q 'https://dl.min.io/client/mc/release/' "$TEMPLATE_FILE"
}
