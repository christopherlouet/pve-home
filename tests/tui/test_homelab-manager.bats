#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/homelab (T007)
# =============================================================================
# Tests du point d'entree TUI : arguments, help, version, prerequis

setup() {
    # Repertoire du projet
    PROJECT_ROOT="/home/chris/source/sideprojects/pve-home"
    TUI_DIR="${PROJECT_ROOT}/scripts"
    SCRIPT="${TUI_DIR}/homelab"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_tui"
    mkdir -p "${TEST_DIR}"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests existence et structure
# =============================================================================

@test "homelab-manager.sh existe" {
    [ -f "$SCRIPT" ]
}

@test "homelab-manager.sh est executable" {
    [ -x "$SCRIPT" ]
}

@test "homelab-manager.sh commence par shebang bash" {
    head -1 "$SCRIPT" | grep -q "#!/usr/bin/env bash\|#!/bin/bash"
}

# =============================================================================
# Tests arguments --help et --version
# =============================================================================

@test "--help affiche l'aide sans erreur" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "-h est un alias pour --help" {
    run "$SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "--help affiche les options disponibles" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--help"* ]]
    [[ "$output" == *"--version"* ]]
}

@test "--version affiche la version" {
    run "$SCRIPT" --version
    [ "$status" -eq 0 ]
    # Format attendu: x.y.z ou vx.y.z
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]] || [[ "$output" == *"version"* ]]
}

@test "-V est un alias pour --version" {
    run "$SCRIPT" -V
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests verification des prerequis
# =============================================================================

@test "verifie que gum est requis" {
    # Le script doit mentionner gum dans l'aide ou la verification
    run "$SCRIPT" --help
    [[ "$output" == *"gum"* ]] || {
        # Ou bien le script doit echouer proprement si gum n'est pas installe
        # En creant un environnement sans gum
        PATH="/usr/bin:/bin" run "$SCRIPT" --check-prereqs 2>&1
        [[ "$output" == *"gum"* ]] || [[ "$status" -ne 0 ]]
    }
}

@test "--check-prereqs verifie les outils requis" {
    run "$SCRIPT" --check-prereqs
    # Doit retourner 0 si tous les outils sont presents, 1 sinon
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    # Doit lister les outils verifies (Prerequis avec accent ou sans)
    [[ "$output" == *"gum"* ]] || [[ "$output" == *"Prerequis"* ]] || [[ "$output" == *"prerequis"* ]] || [[ "$output" == *"verifi"* ]]
}

# =============================================================================
# Tests detection du contexte (local vs distant)
# =============================================================================

@test "detecte le contexte d'execution" {
    # Le script doit pouvoir fonctionner en local ou sur VM monitoring
    run "$SCRIPT" --show-context
    [ "$status" -eq 0 ]
    # Doit indiquer local ou remote/monitoring
    [[ "$output" == *"local"* ]] || [[ "$output" == *"remote"* ]] || [[ "$output" == *"monitoring"* ]]
}

# =============================================================================
# Tests arguments invalides
# =============================================================================

@test "argument invalide retourne une erreur" {
    run "$SCRIPT" --option-invalide-xyz
    [ "$status" -ne 0 ]
}

@test "argument invalide affiche un message d'erreur" {
    run "$SCRIPT" --option-invalide-xyz
    [[ "$output" == *"invalide"* ]] || [[ "$output" == *"invalid"* ]] || [[ "$output" == *"unknown"* ]] || [[ "$output" == *"inconnu"* ]]
}

# =============================================================================
# Tests mode non-interactif
# =============================================================================

@test "--non-interactive empeche les prompts" {
    # En mode non-interactif, le script ne doit pas bloquer sur input
    # On peut verifier que l'option est acceptee
    run timeout 2 "$SCRIPT" --non-interactive --help
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests integration avec les libs
# =============================================================================

@test "source common.sh sans erreur" {
    # Le script doit pouvoir sourcer la lib commune
    run bash -c "source ${TUI_DIR}/lib/tui/common.sh && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "source config.sh sans erreur" {
    run bash -c "source ${TUI_DIR}/lib/tui/config.sh && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "source colors.sh sans erreur" {
    run bash -c "source ${TUI_DIR}/lib/tui/colors.sh && echo OK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# =============================================================================
# Tests structure du script
# =============================================================================

@test "definit une fonction main ou point d'entree" {
    # Le script doit avoir une structure claire
    grep -qE "^main\(\)|^function main|# Point d'entree|# Main" "$SCRIPT"
}

@test "utilise set -euo pipefail pour robustesse" {
    grep -q "set -euo pipefail\|set -e" "$SCRIPT"
}
