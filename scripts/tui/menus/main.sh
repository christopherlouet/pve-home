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

menu_deploy() {
    tui_banner "Deploiement"
    tui_log_info "Cette fonctionnalite sera implementee dans la Phase 5 (US4)"
    echo ""
    tui_log_info "Appuyez sur Entree pour revenir au menu principal..."
    read -r
}

menu_maintenance() {
    tui_banner "Maintenance"
    tui_log_info "Cette fonctionnalite sera implementee dans la Phase 6 (US5)"
    echo ""
    tui_log_info "Appuyez sur Entree pour revenir au menu principal..."
    read -r
}

menu_disaster() {
    tui_banner "Disaster Recovery"
    tui_log_info "Cette fonctionnalite sera implementee dans la Phase 7 (US6)"
    echo ""
    tui_log_info "Appuyez sur Entree pour revenir au menu principal..."
    read -r
}

menu_services() {
    tui_banner "Services"
    tui_log_info "Cette fonctionnalite sera implementee dans la Phase 8 (US7)"
    echo ""
    tui_log_info "Appuyez sur Entree pour revenir au menu principal..."
    read -r
}

# =============================================================================
# Export des fonctions
# =============================================================================

export -f menu_main
export -f menu_deploy
export -f menu_maintenance menu_disaster menu_services
