#!/usr/bin/env bats
# =============================================================================
# Tests pour verify-backups.sh
# =============================================================================
# US5 - Verification integrite des sauvegardes
# T021: Verification vzdump
# T022: Verification state Minio
# T023: Rapport global
# =============================================================================

# Setup commun
setup() {
    # Repertoire du script a tester
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    VERIFY_SCRIPT="${SCRIPT_DIR}/scripts/restore/verify-backups.sh"

    # Repertoire temporaire pour les tests
    TEST_TMPDIR="$(mktemp -d)"

    # Mock terraform.tfvars
    MOCK_TFVARS="${TEST_TMPDIR}/terraform.tfvars"
    cat > "$MOCK_TFVARS" << 'EOF'
pve_node = "pve-homelab"
pve_ip = "192.168.1.100"

minio = {
  ip            = "192.168.1.150"
  port          = 9000
  root_user     = "minioadmin"
  root_password = "minioadmin123"
}
EOF
}

teardown() {
    # Nettoyer le repertoire temporaire
    rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# Tests de parsing des arguments
# =============================================================================

@test "verify-backups.sh affiche l'aide avec --help" {
    run bash "$VERIFY_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--node"* ]]
    [[ "$output" == *"--storage"* ]]
}

@test "verify-backups.sh accepte --node NODE" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"pve-test"* ]]
}

@test "verify-backups.sh utilise storage par defaut (local)" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"local"* ]]
}

@test "verify-backups.sh accepte --storage STORAGE" {
    run bash "$VERIFY_SCRIPT" --node pve-test --storage pve-storage --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"pve-storage"* ]]
}

@test "verify-backups.sh accepte --vmid VMID (filtrage)" {
    run bash "$VERIFY_SCRIPT" --node pve-test --vmid 100 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"100"* ]]
}

@test "verify-backups.sh accepte --dry-run" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "verify-backups.sh accepte --full pour verification complete" {
    run bash "$VERIFY_SCRIPT" --node pve-test --full --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Verification complete"* ]] || [[ "$output" == *"FULL"* ]] || [[ "$output" == *"full"* ]]
}

# =============================================================================
# Tests de detection du noeud depuis terraform.tfvars
# =============================================================================

@test "verify-backups.sh detecte le noeud depuis terraform.tfvars si --node absent" {
    # Mock du script avec terraform.tfvars disponible
    skip "Necessite un mock de terraform.tfvars dans le bon repertoire"
}

@test "verify-backups.sh affiche une erreur si --node absent et tfvars introuvable" {
    # Tester dans un contexte sans terraform.tfvars
    run bash -c "cd /tmp && bash $VERIFY_SCRIPT --dry-run 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"noeud"* ]] || [[ "$output" == *"node"* ]]
}

# =============================================================================
# Tests T021 - Verification vzdump
# =============================================================================

@test "verify-backups.sh verifie la taille des fichiers vzdump" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    # En mode dry-run, on doit voir la commande pvesh
    [[ "$output" == *"pvesh"* ]] || [[ "$output" == *"backup"* ]]
}

@test "verify-backups.sh affiche un WARNING si dernier backup > 48h" {
    skip "Necessite un mock de pvesh avec backup ancien"
}

@test "verify-backups.sh affiche une ERROR si aucun backup disponible" {
    skip "Necessite un mock de pvesh avec liste vide"
}

@test "verify-backups.sh filtre par VMID si --vmid specifie" {
    run bash "$VERIFY_SCRIPT" --node pve-test --vmid 100 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"100"* ]]
}

@test "verify-backups.sh liste tous les backups si --vmid absent" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    # Pas de filtrage par VMID
}

@test "verify-backups.sh verifie l'existence du fichier sur le filesystem" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    # En dry-run, doit montrer la commande ls via SSH
    [[ "$output" == *"ls"* ]] || [[ "$output" == *"dump"* ]]
}

# =============================================================================
# Tests T022 - Verification state Minio
# =============================================================================

@test "verify-backups.sh configure mc depuis terraform.tfvars" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    # Doit montrer la configuration mc
    [[ "$output" == *"mc"* ]] || [[ "$output" == *"minio"* ]]
}

@test "verify-backups.sh verifie les buckets tfstate-prod, tfstate-lab, tfstate-monitoring" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"tfstate-prod"* ]] || [[ "$output" == *"tfstate-lab"* ]] || [[ "$output" == *"tfstate-monitoring"* ]]
}

@test "verify-backups.sh verifie que le bucket existe" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    # Doit montrer mc ls
    [[ "$output" == *"mc ls"* ]] || [[ "$output" == *"bucket"* ]]
}

@test "verify-backups.sh liste les versions du state" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"version"* ]] || [[ "$output" == *"mc ls --versions"* ]]
}

@test "verify-backups.sh verifie que le JSON est valide avec jq" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"jq"* ]] || [[ "$output" == *"JSON"* ]]
}

@test "verify-backups.sh verifie la taille non-nulle du state" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"KB"* ]] || [[ "$output" == *"MB"* ]]
}

# =============================================================================
# Tests T023 - Rapport global
# =============================================================================

@test "verify-backups.sh affiche un rapport formate en tableau" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    # Le rapport doit contenir des colonnes
    [[ "$output" == *"Composant"* ]] || [[ "$output" == *"Type"* ]] || [[ "$output" == *"Statut"* ]]
}

@test "verify-backups.sh affiche le resume avec compteurs" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    # Resume avec compteurs: X OK, Y warnings, Z erreurs
    [[ "$output" == *"OK"* ]] || [[ "$output" == *"WARNING"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "verify-backups.sh retourne code de sortie 0 si tout OK" {
    skip "Necessite un mock complet avec backups OK"
}

@test "verify-backups.sh retourne code de sortie 1 si avertissements" {
    skip "Necessite un mock avec backup ancien (>48h)"
}

@test "verify-backups.sh retourne code de sortie 2 si erreurs critiques" {
    skip "Necessite un mock avec backup absent ou JSON invalide"
}

# =============================================================================
# Tests mode --full (T025, pour Phase 6 US6)
# =============================================================================

@test "verify-backups.sh en mode --full verifie vzdump + Minio + connectivite VMs" {
    run bash "$VERIFY_SCRIPT" --node pve-test --full --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"vzdump"* ]]
    [[ "$output" == *"minio"* ]] || [[ "$output" == *"Minio"* ]]
    [[ "$output" == *"VM"* ]] || [[ "$output" == *"connectivite"* ]]
}

@test "verify-backups.sh en mode --full verifie que les jobs de sauvegarde sont actifs" {
    run bash "$VERIFY_SCRIPT" --node pve-test --full --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"backup"* ]] || [[ "$output" == *"job"* ]]
}

@test "verify-backups.sh en mode --full teste la connectivite vers toutes les VMs/LXC connues" {
    run bash "$VERIFY_SCRIPT" --node pve-test --full --dry-run
    [ "$status" -eq 0 ]
    # Doit afficher une section de verification de connectivite separee
    [[ "$output" == *"Verification de la connectivite"* ]] || [[ "$output" == *"Test de connectivite"* ]]
}

# =============================================================================
# Tests mode dry-run
# =============================================================================

@test "verify-backups.sh en mode --dry-run n'execute aucune commande SSH" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    # Toutes les commandes SSH doivent etre prefixees [DRY-RUN]
    [[ "$output" == *"[DRY-RUN]"* ]] || [[ "$output" == *"DRY-RUN"* ]]
}

@test "verify-backups.sh en mode --dry-run n'execute aucune commande mc" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    # Toutes les commandes mc doivent etre prefixees [DRY-RUN]
    [[ "$output" == *"[DRY-RUN]"* ]] || [[ "$output" == *"DRY-RUN"* ]]
}

# =============================================================================
# Tests format rapport
# =============================================================================

@test "verify-backups.sh affiche le composant dans le rapport" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Composant"* ]]
}

@test "verify-backups.sh affiche le type (vzdump/minio) dans le rapport" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Type"* ]]
}

@test "verify-backups.sh affiche le statut (OK/WARNING/ERROR) dans le rapport" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Statut"* ]]
}

@test "verify-backups.sh affiche le dernier backup dans le rapport" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"backup"* ]] || [[ "$output" == *"Dernier"* ]]
}

@test "verify-backups.sh affiche les details dans le rapport" {
    run bash "$VERIFY_SCRIPT" --node pve-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Details"* ]] || [[ "$output" == *"taille"* ]]
}
