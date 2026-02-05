#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Menu principal (T006)
# =============================================================================
# Usage: source scripts/tui/menus/main.sh && menu_main
#
# Menu principal avec les 7 categories de gestion du homelab.
# =============================================================================

# =============================================================================
# Menu principal
# =============================================================================

menu_main() {
    local running=true

    while $running; do
        # Afficher la banniere
        tui_banner "Homelab Manager v${TUI_VERSION}"

        # Afficher le contexte
        echo -e "${TUI_COLOR_MUTED}Contexte: ${TUI_CONTEXT} | Projet: ${TUI_PROJECT_ROOT}${TUI_COLOR_NC}"
        echo ""

        # Options du menu
        local options=(
            "1. 📊 Status & Health - Voir l'etat de l'infrastructure"
            "2. 📸 Lifecycle - Snapshots et cycle de vie VMs"
            "3. 🏗️  Terraform - Plan, Apply, Output"
            "4. 🚀 Deploiement - Deployer scripts sur monitoring"
            "5. 🔍 Maintenance - Drift detection, verifications"
            "6. 💾 Disaster Recovery - Restauration, backups"
            "7. ⚙️  Services - Activer/desactiver Harbor, etc."
            "8. 🔧 Configuration - Preferences du TUI"
            "$(tui_quit_option)"
        )

        # Afficher le menu
        local choice
        choice=$(tui_menu "Que voulez-vous faire?" "${options[@]}")

        # Traiter le choix
        case "$choice" in
            "1."*|*"Status"*|*"Health"*)
                menu_status
                ;;
            "2."*|*"Lifecycle"*|*"Snapshots"*)
                menu_lifecycle
                ;;
            "3."*|*"Terraform"*)
                menu_terraform
                ;;
            "4."*|*"Deploiement"*|*"Deploy"*)
                menu_deploy
                ;;
            "5."*|*"Maintenance"*|*"Drift"*)
                menu_maintenance
                ;;
            "6."*|*"Disaster"*|*"Recovery"*)
                menu_disaster
                ;;
            "7."*|*"Services"*)
                menu_services
                ;;
            "8."*|*"Configuration"*|*"Preferences"*)
                menu_config
                ;;
            *"Quitter"*|*"quit"*|*"exit"*|"")
                running=false
                tui_log_info "Au revoir!"
                ;;
            *)
                tui_log_warn "Option non reconnue: $choice"
                ;;
        esac
    done
}

# =============================================================================
# Sous-menus (stubs pour Phase 1 - a implementer dans les phases suivantes)
# =============================================================================

# Charger les modules depuis les fichiers dedies
MAIN_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${MAIN_MENU_DIR}/status.sh" ]]; then
    source "${MAIN_MENU_DIR}/status.sh"
fi
if [[ -f "${MAIN_MENU_DIR}/lifecycle.sh" ]]; then
    source "${MAIN_MENU_DIR}/lifecycle.sh"
fi
if [[ -f "${MAIN_MENU_DIR}/terraform.sh" ]]; then
    source "${MAIN_MENU_DIR}/terraform.sh"
fi
if [[ -f "${MAIN_MENU_DIR}/deploy.sh" ]]; then
    source "${MAIN_MENU_DIR}/deploy.sh"
fi
if [[ -f "${MAIN_MENU_DIR}/maintenance.sh" ]]; then
    source "${MAIN_MENU_DIR}/maintenance.sh"
fi
if [[ -f "${MAIN_MENU_DIR}/disaster.sh" ]]; then
    source "${MAIN_MENU_DIR}/disaster.sh"
fi
if [[ -f "${MAIN_MENU_DIR}/services.sh" ]]; then
    source "${MAIN_MENU_DIR}/services.sh"
fi
if [[ -f "${MAIN_MENU_DIR}/config.sh" ]]; then
    source "${MAIN_MENU_DIR}/config.sh"
fi

# =============================================================================
# Export des fonctions
# =============================================================================

export -f menu_main
