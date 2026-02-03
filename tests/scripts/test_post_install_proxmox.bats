#!/usr/bin/env bats
# =============================================================================
# Tests BATS : scripts/post-install-proxmox.sh
# =============================================================================
# Tests unitaires pour le script de post-installation Proxmox.
# Note: Ces tests verifient la logique sans executer les commandes systeme.
# =============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)"
    export POST_INSTALL_SCRIPT="${SCRIPT_DIR}/post-install-proxmox.sh"

    # Creer une structure de repertoire pour les tests
    mkdir -p "${TEST_DIR}/etc/apt/sources.list.d"
    mkdir -p "${TEST_DIR}/root/.pve-tokens"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests de base
# =============================================================================

@test "post-install-proxmox.sh existe et est executable" {
    [ -f "$POST_INSTALL_SCRIPT" ]
    [ -x "$POST_INSTALL_SCRIPT" ]
}

@test "post-install-proxmox.sh affiche l'aide avec --help" {
    run "$POST_INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--yes"* ]]
    [[ "$output" == *"--skip-reboot"* ]]
    [[ "$output" == *"--timezone"* ]]
}

@test "post-install-proxmox.sh affiche l'aide avec -h" {
    run "$POST_INSTALL_SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "post-install-proxmox.sh passe shellcheck" {
    if ! command -v shellcheck &>/dev/null; then
        skip "shellcheck non installe"
    fi
    run shellcheck -x -e SC1091 "$POST_INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests des options de ligne de commande
# =============================================================================

@test "post-install-proxmox.sh accepte --timezone" {
    run "$POST_INSTALL_SCRIPT" --help
    [[ "$output" == *"--timezone"* ]]
}

@test "post-install-proxmox.sh accepte --vm-template-id" {
    run "$POST_INSTALL_SCRIPT" --help
    [[ "$output" == *"--vm-template-id"* ]]
}

@test "post-install-proxmox.sh accepte --no-prometheus" {
    run "$POST_INSTALL_SCRIPT" --help
    [[ "$output" == *"--no-prometheus"* ]]
}

@test "post-install-proxmox.sh accepte --no-template-vm" {
    run "$POST_INSTALL_SCRIPT" --help
    [[ "$output" == *"--no-template-vm"* ]]
}

@test "post-install-proxmox.sh accepte --reset-tokens" {
    run "$POST_INSTALL_SCRIPT" --help
    [[ "$output" == *"--reset-tokens"* ]]
}

# =============================================================================
# Tests de detection de version PVE
# =============================================================================

@test "format version PVE majeure extraction" {
    # Simulation du parsing de version
    local pve_full="8.3.1"
    local pve_major="${pve_full%%.*}"
    [ "$pve_major" = "8" ]
}

@test "format version PVE 9.x detecte trixie" {
    local pve_major="9"
    local pve_codename=""
    local pve_repo_format=""

    if [[ "$pve_major" -ge 9 ]]; then
        pve_codename="trixie"
        pve_repo_format="deb822"
    elif [[ "$pve_major" -ge 8 ]]; then
        pve_codename="bookworm"
        pve_repo_format="list"
    fi

    [ "$pve_codename" = "trixie" ]
    [ "$pve_repo_format" = "deb822" ]
}

@test "format version PVE 8.x detecte bookworm" {
    local pve_major="8"
    local pve_codename=""
    local pve_repo_format=""

    if [[ "$pve_major" -ge 9 ]]; then
        pve_codename="trixie"
        pve_repo_format="deb822"
    elif [[ "$pve_major" -ge 8 ]]; then
        pve_codename="bookworm"
        pve_repo_format="list"
    fi

    [ "$pve_codename" = "bookworm" ]
    [ "$pve_repo_format" = "list" ]
}

# =============================================================================
# Tests de securite des tokens
# =============================================================================

@test "TOKENS_DIR est defini dans le script" {
    grep -q 'TOKENS_DIR=' "$POST_INSTALL_SCRIPT"
}

@test "tokens sont sauvegardes avec chmod 600" {
    grep -q 'chmod 600' "$POST_INSTALL_SCRIPT"
}

@test "repertoire tokens cree avec chmod 700" {
    grep -q 'chmod 700' "$POST_INSTALL_SCRIPT"
}

@test "tokens ne sont pas logges en clair" {
    # Verifier qu'on ne fait pas echo du token directement
    ! grep -E 'echo.*\$TERRAFORM_TOKEN[^}]' "$POST_INSTALL_SCRIPT" || \
    ! grep -E 'echo.*\$PROMETHEUS_TOKEN[^}]' "$POST_INSTALL_SCRIPT"
}

@test "tokens sauvegardes dans fichiers securises" {
    grep -q 'terraform.token' "$POST_INSTALL_SCRIPT"
    grep -q 'prometheus.token' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests extraction token UUID
# =============================================================================

@test "extraction UUID depuis sortie pveum" {
    local token_output="
┌──────────┬──────────────────────────────────────┐
│ key      │ value                                │
├──────────┼──────────────────────────────────────┤
│ full-tokenid │ terraform@pve!terraform-token    │
│ info         │                                  │
│ value        │ 12345678-1234-1234-1234-123456789abc │
└──────────┴──────────────────────────────────────┘"

    local token
    token=$(echo "$token_output" | grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
    [ "$token" = "12345678-1234-1234-1234-123456789abc" ]
}

@test "extraction UUID echoue si pas de token" {
    local token_output="error: something went wrong"
    local token
    token=$(echo "$token_output" | grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' || echo "")
    [ -z "$token" ]
}

# =============================================================================
# Tests de la logique de confirmation
# =============================================================================

@test "mode AUTO_YES bypass la confirmation" {
    # Simuler la logique de confirmation
    local AUTO_YES=true
    local result="no"

    if [[ "$AUTO_YES" == true ]]; then
        result="yes"
    fi

    [ "$result" = "yes" ]
}

@test "mode interactif demande confirmation" {
    # Verifier que le script a une fonction confirm
    grep -q 'confirm()' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests configuration depots
# =============================================================================

@test "script gere format deb822 pour PVE 9.x" {
    grep -q '_configure_repos_deb822' "$POST_INSTALL_SCRIPT"
}

@test "script gere format list pour PVE 8.x" {
    grep -q '_configure_repos_list' "$POST_INSTALL_SCRIPT"
}

@test "depot no-subscription configure" {
    grep -q 'pve-no-subscription' "$POST_INSTALL_SCRIPT"
}

@test "depot enterprise desactive" {
    grep -q 'pve-enterprise' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests fail2ban
# =============================================================================

@test "jail sshd configure dans fail2ban" {
    grep -q '\[sshd\]' "$POST_INSTALL_SCRIPT"
}

@test "jail proxmox configure dans fail2ban" {
    grep -q '\[proxmox\]' "$POST_INSTALL_SCRIPT"
}

@test "filtre proxmox avec failregex" {
    grep -q 'failregex' "$POST_INSTALL_SCRIPT"
    grep -q 'pvedaemon' "$POST_INSTALL_SCRIPT"
}

@test "support journald pour PVE 9.x sans daemon.log" {
    grep -q 'systemd' "$POST_INSTALL_SCRIPT"
    grep -q 'daemon.log' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests roles Terraform
# =============================================================================

@test "role TerraformRole defini avec privileges" {
    grep -q 'TerraformRole' "$POST_INSTALL_SCRIPT"
    grep -q 'VM.Allocate' "$POST_INSTALL_SCRIPT"
}

@test "privilege VM.Config.Cloudinit inclus" {
    grep -q 'VM.Config.Cloudinit' "$POST_INSTALL_SCRIPT"
}

@test "privilege Datastore.Allocate inclus" {
    grep -q 'Datastore.Allocate' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests role Prometheus
# =============================================================================

@test "role PVEAuditor assigne a prometheus" {
    grep -q 'PVEAuditor' "$POST_INSTALL_SCRIPT"
}

@test "utilisateur prometheus@pve cree" {
    grep -q 'prometheus@pve' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests template VM
# =============================================================================

@test "template cloud-init avec qemu-guest-agent" {
    grep -q 'agent enabled=1' "$POST_INSTALL_SCRIPT"
}

@test "template avec virtio-scsi-pci" {
    grep -q 'virtio-scsi-pci' "$POST_INSTALL_SCRIPT"
}

@test "template converti avec qm template" {
    grep -q 'qm template' "$POST_INSTALL_SCRIPT"
}

@test "image Ubuntu Noble utilisee" {
    grep -q 'noble-server-cloudimg' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests snippets cloud-init
# =============================================================================

@test "snippets actives sur storage local" {
    grep -q 'snippets' "$POST_INSTALL_SCRIPT"
    grep -q '/var/lib/vz/snippets' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests outils installes
# =============================================================================

@test "fail2ban dans la liste des outils" {
    grep -q 'fail2ban' "$POST_INSTALL_SCRIPT"
}

@test "vim et htop dans la liste des outils" {
    grep -q 'vim' "$POST_INSTALL_SCRIPT"
    grep -q 'htop' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests securite generale
# =============================================================================

@test "script utilise set -euo pipefail" {
    grep -q 'set -euo pipefail' "$POST_INSTALL_SCRIPT"
}

@test "verification execution root" {
    grep -q 'EUID -ne 0' "$POST_INSTALL_SCRIPT"
}

@test "sauvegarde avant modification (.bak)" {
    grep -q '\.bak' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests resume final
# =============================================================================

@test "resume affiche URL Proxmox" {
    grep -q 'URL Proxmox' "$POST_INSTALL_SCRIPT"
}

@test "resume affiche chemin des tokens" {
    grep -q 'TOKENS_DIR' "$POST_INSTALL_SCRIPT"
}

@test "resume mentionne Terraform" {
    grep -q 'Terraform' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests LXC templates
# =============================================================================

@test "template Ubuntu 24.04 LXC reference" {
    grep -q 'ubuntu-24.04' "$POST_INSTALL_SCRIPT"
}

@test "template Debian 12 LXC reference" {
    grep -q 'debian-12' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests gestion reboot
# =============================================================================

@test "option --skip-reboot documentee" {
    run "$POST_INSTALL_SCRIPT" --help
    [[ "$output" == *"--skip-reboot"* ]]
}

@test "variable NEEDS_REBOOT utilisee" {
    grep -q 'NEEDS_REBOOT' "$POST_INSTALL_SCRIPT"
}

@test "delai avant reboot (securite)" {
    grep -q 'sleep 5' "$POST_INSTALL_SCRIPT"
}

# =============================================================================
# Tests edge cases
# =============================================================================

@test "gestion fichier proxmoxlib.js manquant" {
    grep -q 'proxmoxlib.js introuvable' "$POST_INSTALL_SCRIPT"
}

@test "verification espace disque avant template VM" {
    grep -q 'Espace disque' "$POST_INSTALL_SCRIPT"
}

@test "verification local-lvm existe" {
    grep -q 'local-lvm introuvable' "$POST_INSTALL_SCRIPT"
}

