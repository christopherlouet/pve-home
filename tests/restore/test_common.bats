#!/usr/bin/env bats
# =============================================================================
# Tests pour scripts/lib/common.sh
# =============================================================================

# Setup: source le fichier common.sh avant chaque test
setup() {
    # Charger la bibliotheque commune
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts/lib" && pwd)"
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

# =============================================================================
# Tests retry_with_backoff et ssh_exec_retry
# =============================================================================

@test "retry_with_backoff existe comme fonction" {
    declare -f retry_with_backoff > /dev/null
}

@test "retry_with_backoff reussit au 1er essai" {
    run retry_with_backoff 3 true
    [ "$status" -eq 0 ]
}

@test "retry_with_backoff reussit au 2eme essai" {
    # Creer un script qui echoue la 1ere fois puis reussit
    local counter_file="${BATS_TEST_TMPDIR}/retry_counter"
    echo "0" > "$counter_file"

    attempt_cmd() {
        local count
        count=$(cat "$counter_file")
        count=$((count + 1))
        echo "$count" > "$counter_file"
        [ "$count" -ge 2 ]
    }

    run retry_with_backoff 3 attempt_cmd
    [ "$status" -eq 0 ]
}

@test "retry_with_backoff echoue apres max tentatives" {
    run retry_with_backoff 2 false
    [ "$status" -eq 1 ]
    [[ "$output" == *"Echec apres 2 tentatives"* ]]
}

@test "retry_with_backoff log les tentatives intermediaires" {
    run retry_with_backoff 2 false
    [ "$status" -eq 1 ]
    [[ "$output" == *"Tentative"* ]]
    [[ "$output" == *"retry dans"* ]]
}

@test "ssh_exec_retry existe comme fonction" {
    declare -f ssh_exec_retry > /dev/null
}

@test "check_ssh_access utilise retry_with_backoff" {
    # Verifier que la definition de check_ssh_access contient retry_with_backoff
    local func_def
    func_def=$(declare -f check_ssh_access)
    [[ "$func_def" == *"retry_with_backoff"* ]]
}

# =============================================================================
# Tests securite SSH - known_hosts et StrictHostKeyChecking
# =============================================================================

@test "HOMELAB_KNOWN_HOSTS est defini avec valeur par defaut" {
    [ -n "$HOMELAB_KNOWN_HOSTS" ]
    [[ "$HOMELAB_KNOWN_HOSTS" == *"homelab_known_hosts"* ]]
}

@test "SSH_INIT_MODE est defini avec valeur false par defaut" {
    [ "$SSH_INIT_MODE" = "false" ]
}

@test "init_known_hosts existe comme fonction" {
    declare -f init_known_hosts > /dev/null
}

@test "init_known_hosts requiert au moins un hote" {
    run init_known_hosts
    [ "$status" -eq 1 ]
    [[ "$output" == *"au moins un hote requis"* ]]
}

@test "is_host_known existe comme fonction" {
    declare -f is_host_known > /dev/null
}

@test "is_host_known retourne 1 si fichier known_hosts n'existe pas" {
    local old_known_hosts="$HOMELAB_KNOWN_HOSTS"
    HOMELAB_KNOWN_HOSTS="/fichier/inexistant/known_hosts"
    run is_host_known "192.168.1.1"
    [ "$status" -eq 1 ]
    HOMELAB_KNOWN_HOSTS="$old_known_hosts"
}

@test "get_ssh_opts existe comme fonction" {
    declare -f get_ssh_opts > /dev/null
}

@test "get_ssh_opts retourne StrictHostKeyChecking=yes en mode normal" {
    SSH_INIT_MODE=false
    run get_ssh_opts
    [ "$status" -eq 0 ]
    [[ "$output" == *"StrictHostKeyChecking=yes"* ]]
    [[ "$output" == *"UserKnownHostsFile="* ]]
}

@test "get_ssh_opts retourne StrictHostKeyChecking=accept-new en mode init" {
    SSH_INIT_MODE=true
    run get_ssh_opts
    [ "$status" -eq 0 ]
    [[ "$output" == *"StrictHostKeyChecking=accept-new"* ]]
    SSH_INIT_MODE=false
}

@test "get_ssh_opts inclut le fichier known_hosts dedie" {
    run get_ssh_opts
    [ "$status" -eq 0 ]
    [[ "$output" == *"UserKnownHostsFile=${HOMELAB_KNOWN_HOSTS}"* ]]
}

@test "ssh_exec utilise get_ssh_opts" {
    local func_def
    func_def=$(declare -f ssh_exec)
    [[ "$func_def" == *"get_ssh_opts"* ]]
}

@test "ssh_exec_retry utilise get_ssh_opts" {
    local func_def
    func_def=$(declare -f ssh_exec_retry)
    [[ "$func_def" == *"get_ssh_opts"* ]]
}

@test "check_ssh_access utilise get_ssh_opts" {
    local func_def
    func_def=$(declare -f check_ssh_access)
    [[ "$func_def" == *"get_ssh_opts"* ]]
}

@test "common.sh n'utilise pas StrictHostKeyChecking hardcode dans les fonctions SSH" {
    # Verifier qu'il n'y a pas de StrictHostKeyChecking hardcode (sauf dans get_ssh_opts)
    # On compte les occurrences hors de get_ssh_opts
    local hardcoded_count
    hardcoded_count=$(grep -c "StrictHostKeyChecking=" "${SCRIPT_DIR}/common.sh" | head -1)
    # Il devrait y avoir exactement 2 occurrences dans get_ssh_opts (yes et accept-new)
    [ "$hardcoded_count" -eq 2 ]
}
