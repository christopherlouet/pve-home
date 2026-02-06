#!/usr/bin/env bats
# =============================================================================
# Tests BATS - Script install-node-exporter.sh
# =============================================================================
# Validation statique du script d'installation de Node Exporter.
# Verifie les bonnes pratiques: checksums SHA256, securite, structure.
# =============================================================================

SCRIPT_FILE="${BATS_TEST_DIRNAME}/../../infrastructure/proxmox/modules/monitoring-stack/files/install-node-exporter.sh"

# -----------------------------------------------------------------------------
# Existence et structure
# -----------------------------------------------------------------------------

@test "install-node-exporter: script existe" {
    [ -f "$SCRIPT_FILE" ]
}

@test "install-node-exporter: commence par shebang bash" {
    head -1 "$SCRIPT_FILE" | grep -q '#!/bin/bash'
}

@test "install-node-exporter: utilise set -euo pipefail" {
    grep -q 'set -euo pipefail' "$SCRIPT_FILE"
}

@test "install-node-exporter: a une description d'usage" {
    grep -q '# Usage:' "$SCRIPT_FILE"
}

# -----------------------------------------------------------------------------
# Verification d'integrite SHA256
# -----------------------------------------------------------------------------

@test "install-node-exporter: definit l'URL de checksum" {
    grep -q 'CHECKSUM_URL=.*sha256sums.txt' "$SCRIPT_FILE"
}

@test "install-node-exporter: telecharge le fichier sha256sums.txt" {
    grep -q 'wget.*sha256sums.txt' "$SCRIPT_FILE"
}

@test "install-node-exporter: filtre le checksum pour le bon fichier" {
    grep -q 'grep.*node_exporter.*sha256sums.txt' "$SCRIPT_FILE"
}

@test "install-node-exporter: verifie le checksum avec sha256sum -c" {
    grep -q 'sha256sum -c' "$SCRIPT_FILE"
}

@test "install-node-exporter: gere l'absence de checksum (degradation gracieuse)" {
    grep -q 'Checksum non disponible' "$SCRIPT_FILE"
}

@test "install-node-exporter: URL checksum pointe vers GitHub releases officiel" {
    grep -q 'https://github.com/prometheus/node_exporter/releases' "$SCRIPT_FILE"
}

# -----------------------------------------------------------------------------
# Securite
# -----------------------------------------------------------------------------

@test "install-node-exporter: verifie les droits root" {
    grep -q 'EUID.*-ne 0' "$SCRIPT_FILE"
}

@test "install-node-exporter: cree un utilisateur systeme dedie" {
    grep -q 'useradd.*--system' "$SCRIPT_FILE"
}

@test "install-node-exporter: utilisateur sans home directory" {
    grep -q 'no-create-home' "$SCRIPT_FILE"
}

@test "install-node-exporter: utilisateur sans shell de login" {
    grep -q '/bin/false' "$SCRIPT_FILE"
}

@test "install-node-exporter: service avec NoNewPrivileges" {
    grep -q 'NoNewPrivileges=yes' "$SCRIPT_FILE"
}

@test "install-node-exporter: service avec ProtectSystem" {
    grep -q 'ProtectSystem=strict' "$SCRIPT_FILE"
}

@test "install-node-exporter: service avec ProtectHome" {
    grep -q 'ProtectHome=yes' "$SCRIPT_FILE"
}

@test "install-node-exporter: service avec PrivateTmp" {
    grep -q 'PrivateTmp=yes' "$SCRIPT_FILE"
}

@test "install-node-exporter: service avec PrivateDevices" {
    grep -q 'PrivateDevices=yes' "$SCRIPT_FILE"
}

# -----------------------------------------------------------------------------
# Gestion des erreurs
# -----------------------------------------------------------------------------

@test "install-node-exporter: gere l'echec de telechargement" {
    grep -q 'Echec du telechargement' "$SCRIPT_FILE"
}

@test "install-node-exporter: nettoie le repertoire temporaire en cas d'erreur" {
    grep -q 'rm -rf.*TEMP_DIR' "$SCRIPT_FILE"
}

@test "install-node-exporter: utilise mktemp pour le repertoire temporaire" {
    grep -q 'mktemp -d' "$SCRIPT_FILE"
}

@test "install-node-exporter: gere l'echec du demarrage du service" {
    grep -q 'Echec du demarrage' "$SCRIPT_FILE"
}

@test "install-node-exporter: affiche les logs en cas d'echec" {
    grep -q 'journalctl.*node_exporter' "$SCRIPT_FILE"
}

# -----------------------------------------------------------------------------
# Version et mise a jour
# -----------------------------------------------------------------------------

@test "install-node-exporter: accepte la version en argument" {
    grep -q 'NODE_EXPORTER_VERSION=.*{1:-' "$SCRIPT_FILE"
}

@test "install-node-exporter: accepte le port en argument" {
    grep -q 'NODE_EXPORTER_PORT=.*{2:-' "$SCRIPT_FILE"
}

@test "install-node-exporter: detecte une version deja installee" {
    grep -q 'systemctl is-active.*node_exporter' "$SCRIPT_FILE"
}

@test "install-node-exporter: arrete le service avant mise a jour" {
    grep -q 'systemctl stop node_exporter' "$SCRIPT_FILE"
}

# -----------------------------------------------------------------------------
# Service systemd
# -----------------------------------------------------------------------------

@test "install-node-exporter: cree un service systemd" {
    grep -q 'node_exporter.service' "$SCRIPT_FILE"
}

@test "install-node-exporter: service a Restart=always" {
    grep -q 'Restart=always' "$SCRIPT_FILE"
}

@test "install-node-exporter: service ecoute sur le port configure" {
    grep -q 'web.listen-address' "$SCRIPT_FILE"
}

@test "install-node-exporter: active le service au demarrage" {
    grep -q 'systemctl enable node_exporter' "$SCRIPT_FILE"
}

# -----------------------------------------------------------------------------
# Test de connectivite
# -----------------------------------------------------------------------------

@test "install-node-exporter: effectue un test de connectivite" {
    grep -q 'curl.*metrics' "$SCRIPT_FILE"
}

@test "install-node-exporter: verifie la reponse Prometheus (HELP)" {
    grep -q 'grep.*HELP' "$SCRIPT_FILE"
}

# -----------------------------------------------------------------------------
# Collectors configures
# -----------------------------------------------------------------------------

@test "install-node-exporter: exclut les filesystems virtuels" {
    grep -q 'mount-points-exclude.*sys.*proc.*dev' "$SCRIPT_FILE"
}

@test "install-node-exporter: exclut les interfaces docker/veth" {
    grep -q 'ignored-devices.*veth.*docker' "$SCRIPT_FILE"
}

@test "install-node-exporter: active le textfile collector" {
    grep -q 'textfile.directory' "$SCRIPT_FILE"
}

@test "install-node-exporter: cree le repertoire textfile collector" {
    grep -q 'mkdir.*textfile_collector' "$SCRIPT_FILE"
}
