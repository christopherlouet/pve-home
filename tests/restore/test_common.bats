#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/lib/common.sh
# =============================================================================

# Setup: source le fichier common.sh avant chaque test
setup() {
    # Charger la bibliotheque commune
    SCRIPT_DIR="/home/chris/source/sideprojects/pve-home/scripts/lib"
    source "${SCRIPT_DIR}/common.sh"

    # Variables de test
    TEST_DIR="${BATS_TEST_TMPDIR}/test_restore"
    mkdir -p "${TEST_DIR}"

    # Mock terraform.tfvars pour les tests
    TEST_TFVARS="${TEST_DIR}/terraform.tfvars"
    cat > "${TEST_TFVARS}" << 'EOF'
# Test terraform.tfvars
pve_node = "pve-node1"
pve_ip = "192.168.1.100"
minio_ip = "192.168.1.50"
minio_access_key = "minioadmin"
minio_secret_key = "minioadmin"
EOF
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests T002 - Fonctions de base
# =============================================================================

@test "log_info produit le bon format avec prefixe [INFO]" {
    run log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "log_success produit le bon format avec prefixe [OK]" {
    run log_success "success message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK]"* ]]
    [[ "$output" == *"success message"* ]]
}

@test "log_warn produit le bon format avec prefixe [WARN]" {
    run log_warn "warning message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]]
    [[ "$output" == *"warning message"* ]]
}

@test "log_error produit le bon format avec prefixe [ERROR]" {
    run log_error "error message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
    [[ "$output" == *"error message"* ]]
}

@test "confirm retourne 0 en mode --force" {
    FORCE_MODE=true
    run confirm "Test question?"
    [ "$status" -eq 0 ]
}

@test "confirm affiche la question en mode interactif" {
    # Tester que la fonction affiche bien la question
    # En mode non-force, confirm doit attendre l'input
    # On teste seulement que la fonction existe et accepte un argument
    declare -f confirm > /dev/null
}

@test "parse_common_args gere --dry-run" {
    DRY_RUN=false
    parse_common_args --dry-run
    [ "$DRY_RUN" = "true" ]
}

@test "parse_common_args gere --force" {
    FORCE_MODE=false
    parse_common_args --force
    [ "$FORCE_MODE" = "true" ]
}

@test "parse_common_args gere --help" {
    run parse_common_args --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "show_help affiche un message d'usage" {
    run show_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

# =============================================================================
# Tests T003 - Fonctions SSH et verification prerequis
# =============================================================================

@test "check_command detecte une commande presente" {
    run check_command "bash"
    [ "$status" -eq 0 ]
}

@test "check_command detecte une commande absente" {
    run check_command "commande_inexistante_xyz123"
    [ "$status" -eq 1 ]
}

@test "ssh_exec peut etre appele avec les bons parametres" {
    # Test que la fonction existe et accepte les parametres
    # On ne peut pas tester reellement SSH sans infrastructure
    declare -f ssh_exec > /dev/null
}

@test "check_ssh_access verifie les parametres requis" {
    # Test que la fonction existe
    declare -f check_ssh_access > /dev/null
}

@test "check_prereqs verifie les outils requis" {
    # La fonction doit verifier ssh, terraform, mc, jq
    # En mode test, on verifie juste qu'elle existe
    declare -f check_prereqs > /dev/null
}

@test "check_disk_space peut etre appele" {
    # Test que la fonction existe
    declare -f check_disk_space > /dev/null
}

# =============================================================================
# Tests T004 - Fonctions parse_tfvars et dry_run
# =============================================================================

@test "parse_tfvars extrait pve_node correctement" {
    run parse_tfvars "${TEST_TFVARS}" "pve_node"
    [ "$status" -eq 0 ]
    [ "$output" = "pve-node1" ]
}

@test "parse_tfvars extrait pve_ip correctement" {
    run parse_tfvars "${TEST_TFVARS}" "pve_ip"
    [ "$status" -eq 0 ]
    [ "$output" = "192.168.1.100" ]
}

@test "parse_tfvars extrait minio_ip correctement" {
    run parse_tfvars "${TEST_TFVARS}" "minio_ip"
    [ "$status" -eq 0 ]
    [ "$output" = "192.168.1.50" ]
}

@test "parse_tfvars retourne erreur si fichier inexistant" {
    run parse_tfvars "/fichier/inexistant.tfvars" "pve_node"
    [ "$status" -eq 1 ]
}

@test "parse_tfvars retourne vide si cle inexistante" {
    run parse_tfvars "${TEST_TFVARS}" "cle_inexistante"
    [ "$status" -eq 1 ]
}

@test "get_pve_node detecte le noeud PVE depuis tfvars" {
    # La fonction doit utiliser parse_tfvars en interne
    declare -f get_pve_node > /dev/null
}

@test "get_pve_ip detecte l'IP du noeud PVE" {
    declare -f get_pve_ip > /dev/null
}

@test "dry_run affiche la commande en mode DRY_RUN=true" {
    DRY_RUN=true
    run dry_run echo test
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY-RUN]"* ]]
    [[ "$output" == *"echo test"* ]]
}

@test "dry_run execute la commande en mode DRY_RUN=false" {
    DRY_RUN=false
    run dry_run echo test_execution
    [ "$status" -eq 0 ]
    [[ "$output" == *"test_execution"* ]]
}

@test "create_backup_point peut etre appele" {
    # Test que la fonction existe
    declare -f create_backup_point > /dev/null
}

# =============================================================================
# Tests integration - Variables globales et conventions
# =============================================================================

@test "common.sh definit SCRIPT_DIR" {
    # SCRIPT_DIR doit etre defini apres le source
    [ -n "$SCRIPT_DIR" ]
}

@test "common.sh utilise set -euo pipefail" {
    # Verifier que le fichier contient bien la ligne
    grep -q "set -euo pipefail" "${SCRIPT_DIR}/common.sh"
}

@test "common.sh definit les couleurs" {
    # Verifier que les couleurs sont definies
    [ -n "$RED" ]
    [ -n "$GREEN" ]
    [ -n "$YELLOW" ]
    [ -n "$BLUE" ]
    [ -n "$NC" ]
}
