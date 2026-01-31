#!/usr/bin/env bats
# =============================================================================
# Tests pour le script de post-installation Proxmox
# =============================================================================
# Usage: bats tests/test-post-install-proxmox.bats
# =============================================================================

SCRIPT="scripts/post-install-proxmox.sh"

# =============================================================================
# Tests de qualite du script
# =============================================================================

@test "shellcheck passe sans erreur" {
    shellcheck "$SCRIPT"
}

@test "le script est executable" {
    [ -x "$SCRIPT" ]
}

@test "le script utilise set -euo pipefail" {
    grep -q 'set -euo pipefail' "$SCRIPT"
}

# =============================================================================
# Tests de l'option --help
# =============================================================================

@test "--help affiche l'aide et retourne 0" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "-h affiche l'aide et retourne 0" {
    run bash "$SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "--help mentionne les options disponibles" {
    run bash "$SCRIPT" --help
    [[ "$output" == *"--yes"* ]]
    [[ "$output" == *"--skip-reboot"* ]]
    [[ "$output" == *"--timezone"* ]]
    [[ "$output" == *"--vm-template-id"* ]]
    [[ "$output" == *"--no-prometheus"* ]]
    [[ "$output" == *"--no-template-vm"* ]]
    [[ "$output" == *"--reset-tokens"* ]]
}

# =============================================================================
# Tests du parsing des options
# =============================================================================

@test "option --timezone accepte une valeur" {
    run bash "$SCRIPT" --help --timezone America/New_York
    [ "$status" -eq 0 ]
}

@test "option --vm-template-id accepte une valeur" {
    run bash "$SCRIPT" --help --vm-template-id 9001
    [ "$status" -eq 0 ]
}

@test "option inconnue affiche une erreur" {
    run bash "$SCRIPT" --option-inexistante
    [ "$status" -ne 0 ]
    [[ "$output" == *"inconnue"* ]] || [[ "$output" == *"unknown"* ]]
}

# =============================================================================
# Tests de detection d'environnement
# =============================================================================

@test "le script refuse de tourner sur un systeme non-Proxmox" {
    # On est sur une machine de dev, pas un node PVE
    # Le script doit detecter l'absence de pveversion et refuser
    run bash "$SCRIPT" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Proxmox"* ]]
}

@test "le script refuse de tourner sans root (si Proxmox detecte)" {
    # Ce test verifie que la verification root est presente dans le code
    grep -q 'EUID' "$SCRIPT"
}

# =============================================================================
# Tests de la structure du script
# =============================================================================

@test "le script definit les fonctions de log" {
    grep -q 'log_info()' "$SCRIPT"
    grep -q 'log_warn()' "$SCRIPT"
    grep -q 'log_error()' "$SCRIPT"
    grep -q 'log_success()' "$SCRIPT"
}

@test "le script definit toutes les fonctions metier" {
    grep -q 'remove_subscription_popup()' "$SCRIPT"
    grep -q 'configure_repositories()' "$SCRIPT"
    grep -q 'update_system()' "$SCRIPT"
    grep -q 'configure_timezone()' "$SCRIPT"
    grep -q 'install_tools()' "$SCRIPT"
    grep -q 'configure_fail2ban()' "$SCRIPT"
    grep -q 'create_terraform_user()' "$SCRIPT"
    grep -q 'create_prometheus_user()' "$SCRIPT"
    grep -q 'enable_snippets()' "$SCRIPT"
    grep -q 'download_templates()' "$SCRIPT"
    grep -q 'verify_installation()' "$SCRIPT"
}

@test "le script definit les valeurs par defaut" {
    grep -q 'Europe/Paris' "$SCRIPT"
    grep -q '9000' "$SCRIPT"
}

# =============================================================================
# Tests des fonctions utilitaires (sourcing partiel)
# =============================================================================

@test "le script contient une fonction de confirmation interactive" {
    grep -q 'confirm\|ask_confirmation' "$SCRIPT"
}

@test "le script contient une detection de version PVE" {
    grep -q 'pveversion\|PVE_MAJOR' "$SCRIPT"
}

@test "le script contient un resume final" {
    grep -q 'resume\|summary\|recapitulatif' "$SCRIPT" || \
    grep -qi 'informations a noter\|resume final' "$SCRIPT"
}
