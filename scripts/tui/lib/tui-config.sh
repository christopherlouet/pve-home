#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Configuration et detection contexte (T003)
# =============================================================================
# Usage: source scripts/tui/lib/tui-config.sh
#
# Detecte si le TUI s'execute en local ou sur la VM monitoring,
# et configure les chemins dynamiquement.
# =============================================================================

# =============================================================================
# Detection du contexte d'execution
# =============================================================================

# Detecte si on est en local (workstation) ou remote (VM monitoring)
# Retourne: "local" ou "remote"
detect_context() {
    # Indicateurs que nous sommes sur la VM monitoring :
    # 1. Le repertoire /opt/pve-home existe (deploiement standard)
    # 2. Le hostname contient "monitoring"
    # 3. Une variable d'environnement est definie

    if [[ -n "${TUI_FORCE_CONTEXT:-}" ]]; then
        echo "$TUI_FORCE_CONTEXT"
        return 0
    fi

    if [[ -d "/opt/pve-home" ]]; then
        echo "remote"
        return 0
    fi

    if [[ "$(hostname)" == *"monitoring"* ]]; then
        echo "remote"
        return 0
    fi

    if [[ -n "${PVE_MONITORING_VM:-}" ]]; then
        echo "remote"
        return 0
    fi

    echo "local"
}

# =============================================================================
# Configuration des chemins selon le contexte
# =============================================================================

# Contexte actuel (local ou remote)
TUI_CONTEXT=$(detect_context)

# Chemins de base selon le contexte
if [[ "$TUI_CONTEXT" == "remote" ]]; then
    # Sur la VM monitoring - chemins de deploiement
    TUI_PROJECT_ROOT="/opt/pve-home"
    TUI_SCRIPTS_DIR="${TUI_PROJECT_ROOT}/scripts"
    TUI_TFVARS_DIR="${TUI_PROJECT_ROOT}/tfvars"
    TUI_LOG_DIR="/var/log/pve-tui"
else
    # En local - chemins du repo git
    # Detecter la racine du projet
    if [[ -n "${TUI_PROJECT_ROOT_OVERRIDE:-}" ]]; then
        TUI_PROJECT_ROOT="$TUI_PROJECT_ROOT_OVERRIDE"
    else
        # Remonter depuis le script pour trouver la racine
        TUI_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
    fi
    TUI_SCRIPTS_DIR="${TUI_PROJECT_ROOT}/scripts"
    TUI_TFVARS_DIR="${TUI_PROJECT_ROOT}/infrastructure/proxmox/environments"
    TUI_LOG_DIR="${TUI_PROJECT_ROOT}/logs"
fi

# Sous-repertoires communs
TUI_LIB_DIR="${TUI_SCRIPTS_DIR}/lib"
TUI_TUI_DIR="${TUI_SCRIPTS_DIR}/tui"
TUI_TUI_LIB_DIR="${TUI_TUI_DIR}/lib"
TUI_TUI_MENUS_DIR="${TUI_TUI_DIR}/menus"

# =============================================================================
# Configuration des environnements Terraform
# =============================================================================

# Liste des environnements disponibles
TUI_ENVIRONMENTS=("prod" "lab" "monitoring")

# Retourne le chemin du tfvars pour un environnement
# Usage: get_tfvars_path "prod"
get_tfvars_path() {
    local env="$1"

    if [[ "$TUI_CONTEXT" == "remote" ]]; then
        echo "${TUI_TFVARS_DIR}/${env}.tfvars"
    else
        echo "${TUI_TFVARS_DIR}/${env}/terraform.tfvars"
    fi
}

# Verifie si un environnement existe
# Usage: env_exists "prod"
env_exists() {
    local env="$1"
    local tfvars_path
    tfvars_path=$(get_tfvars_path "$env")
    [[ -f "$tfvars_path" ]]
}

# =============================================================================
# Configuration globale du TUI
# =============================================================================

# Version du TUI
TUI_VERSION="1.0.0"

# Mode force (skip confirmations)
TUI_FORCE_MODE="${TUI_FORCE_MODE:-false}"

# Mode non-interactif
TUI_NON_INTERACTIVE="${TUI_NON_INTERACTIVE:-false}"

# Mode dry-run
TUI_DRY_RUN="${TUI_DRY_RUN:-false}"

# =============================================================================
# Export des variables
# =============================================================================

export TUI_CONTEXT TUI_VERSION
export TUI_PROJECT_ROOT TUI_SCRIPTS_DIR TUI_TFVARS_DIR TUI_LOG_DIR
export TUI_LIB_DIR TUI_TUI_DIR TUI_TUI_LIB_DIR TUI_TUI_MENUS_DIR
export TUI_ENVIRONMENTS
export TUI_FORCE_MODE TUI_NON_INTERACTIVE TUI_DRY_RUN
