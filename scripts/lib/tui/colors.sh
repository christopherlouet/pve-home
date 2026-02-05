#!/bin/bash
# =============================================================================
# TUI Homelab Manager - Definitions des couleurs
# =============================================================================
# Usage: source scripts/lib/tui/colors.sh
#
# Definit les couleurs et le theme pour gum et l'affichage terminal.
# =============================================================================

# =============================================================================
# Couleurs ANSI pour le terminal
# =============================================================================

# Couleurs de base
TUI_COLOR_RED='\033[0;31m'
TUI_COLOR_GREEN='\033[0;32m'
TUI_COLOR_YELLOW='\033[1;33m'
TUI_COLOR_BLUE='\033[0;34m'
TUI_COLOR_MAGENTA='\033[0;35m'
TUI_COLOR_CYAN='\033[0;36m'
TUI_COLOR_WHITE='\033[1;37m'
TUI_COLOR_GRAY='\033[0;90m'
TUI_COLOR_NC='\033[0m'  # No Color / Reset

# =============================================================================
# Theme semantique pour le TUI
# =============================================================================

# Couleurs principales
TUI_COLOR_PRIMARY="${TUI_COLOR_CYAN}"
TUI_COLOR_SECONDARY="${TUI_COLOR_MAGENTA}"
TUI_COLOR_ACCENT="${TUI_COLOR_BLUE}"

# Couleurs de statut
TUI_COLOR_SUCCESS="${TUI_COLOR_GREEN}"
TUI_COLOR_WARNING="${TUI_COLOR_YELLOW}"
TUI_COLOR_ERROR="${TUI_COLOR_RED}"
TUI_COLOR_INFO="${TUI_COLOR_BLUE}"

# Couleurs pour les elements UI
TUI_COLOR_TITLE="${TUI_COLOR_CYAN}"
TUI_COLOR_SUBTITLE="${TUI_COLOR_GRAY}"
TUI_COLOR_BORDER="${TUI_COLOR_GRAY}"
TUI_COLOR_HIGHLIGHT="${TUI_COLOR_WHITE}"
TUI_COLOR_MUTED="${TUI_COLOR_GRAY}"

# =============================================================================
# Codes couleur hex pour gum (sans #)
# =============================================================================

# Theme gum (utilisé par les wrappers)
GUM_COLOR_PRIMARY="87CEEB"      # Sky blue
GUM_COLOR_SECONDARY="DA70D6"    # Orchid
GUM_COLOR_SUCCESS="32CD32"      # Lime green
GUM_COLOR_WARNING="FFD700"      # Gold
GUM_COLOR_ERROR="FF6347"        # Tomato
GUM_COLOR_INFO="6495ED"         # Cornflower blue
GUM_COLOR_BORDER="808080"       # Gray
GUM_COLOR_CURSOR="87CEEB"       # Sky blue
GUM_COLOR_SELECTED="FFFFFF"     # White

# =============================================================================
# Symboles et icones
# =============================================================================

TUI_ICON_SUCCESS="✓"
TUI_ICON_ERROR="✗"
TUI_ICON_WARNING="⚠"
TUI_ICON_INFO="ℹ"
TUI_ICON_ARROW="→"
TUI_ICON_BULLET="•"
TUI_ICON_CHECK="☑"
TUI_ICON_UNCHECK="☐"
TUI_ICON_SPINNER="◐"

# Fallback ASCII si le terminal ne supporte pas UTF-8
if [[ "${LANG:-}" != *UTF-8* ]] && [[ "${LC_ALL:-}" != *UTF-8* ]]; then
    TUI_ICON_SUCCESS="[OK]"
    TUI_ICON_ERROR="[X]"
    TUI_ICON_WARNING="[!]"
    TUI_ICON_INFO="[i]"
    TUI_ICON_ARROW="->"
    TUI_ICON_BULLET="*"
    TUI_ICON_CHECK="[x]"
    TUI_ICON_UNCHECK="[ ]"
    TUI_ICON_SPINNER="..."
fi

# =============================================================================
# Export des variables
# =============================================================================

export TUI_COLOR_RED TUI_COLOR_GREEN TUI_COLOR_YELLOW TUI_COLOR_BLUE
export TUI_COLOR_MAGENTA TUI_COLOR_CYAN TUI_COLOR_WHITE TUI_COLOR_GRAY TUI_COLOR_NC
export TUI_COLOR_PRIMARY TUI_COLOR_SECONDARY TUI_COLOR_ACCENT
export TUI_COLOR_SUCCESS TUI_COLOR_WARNING TUI_COLOR_ERROR TUI_COLOR_INFO
export TUI_COLOR_TITLE TUI_COLOR_SUBTITLE TUI_COLOR_BORDER TUI_COLOR_HIGHLIGHT TUI_COLOR_MUTED
export GUM_COLOR_PRIMARY GUM_COLOR_SECONDARY GUM_COLOR_SUCCESS GUM_COLOR_WARNING
export GUM_COLOR_ERROR GUM_COLOR_INFO GUM_COLOR_BORDER GUM_COLOR_CURSOR GUM_COLOR_SELECTED
export TUI_ICON_SUCCESS TUI_ICON_ERROR TUI_ICON_WARNING TUI_ICON_INFO
export TUI_ICON_ARROW TUI_ICON_BULLET TUI_ICON_CHECK TUI_ICON_UNCHECK TUI_ICON_SPINNER
