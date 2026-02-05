#!/bin/bash
# =============================================================================
# Script de verification de l'integrite des sauvegardes
# =============================================================================
# Usage: ./verify-backups.sh [options]
#
# Verifie l'integrite des sauvegardes vzdump et des states Terraform dans Minio.
#
# Options:
#   --node NODE            Noeud Proxmox cible (defaut: depuis terraform.tfvars)
#   --storage STORAGE      Storage Proxmox (defaut: local)
#   --vmid VMID            Filtrer par VMID (optionnel, tous si absent)
#   --full                 Verification complete (vzdump + Minio + connectivite)
#   --dry-run              Afficher les commandes sans les executer
#   -h, --help             Afficher cette aide
#
# Exemples:
#   ./verify-backups.sh --node pve-homelab
#   ./verify-backups.sh --node pve-homelab --vmid 100
#   ./verify-backups.sh --full
#   ./verify-backups.sh --dry-run
#
# Codes de sortie:
#   0 - Tout OK
#   1 - Avertissements (backup ancien, taille faible)
#   2 - Erreurs critiques (backup absent, JSON invalide)
# =============================================================================

set -euo pipefail

# =============================================================================
# Detection du repertoire du script et chargement des fonctions communes
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"

# Source common.sh
# shellcheck source=../lib/common.sh
source "${LIB_DIR}/common.sh"

# =============================================================================
# Variables globales
# =============================================================================

NODE=""
PVE_IP=""
STORAGE="local"
VMID_FILTER=""
FULL_MODE=false

# Compteurs pour le rapport
TOTAL_VERIFIED=0
COUNT_OK=0
COUNT_WARNING=0
COUNT_ERROR=0

# Tableau pour stocker les lignes du rapport
declare -a REPORT_LINES

# Codes de sortie
EXIT_CODE=0

# =============================================================================
# Fonctions de parsing et aide
# =============================================================================

show_help() {
    cat << 'HELPEOF'
Usage: verify-backups.sh [options]

Verifie l'integrite des sauvegardes vzdump et des states Terraform dans Minio.

Options:
  --node NODE            Noeud Proxmox cible (defaut: depuis terraform.tfvars)
  --storage STORAGE      Storage Proxmox (defaut: local)
  --vmid VMID            Filtrer par VMID (optionnel, tous si absent)
  --full                 Verification complete (vzdump + Minio + connectivite + jobs)
  --dry-run              Afficher les commandes sans les executer
  -h, --help             Afficher cette aide

Exemples:
  ./verify-backups.sh --node pve-homelab
  ./verify-backups.sh --node pve-homelab --vmid 100
  ./verify-backups.sh --full
  ./verify-backups.sh --dry-run

Codes de sortie:
  0 - Tout OK
  1 - Avertissements (backup ancien > 48h, taille faible)
  2 - Erreurs critiques (backup absent, JSON invalide, fichier corrompu)

HELPEOF
}

parse_args() {
    # Verifier --help/-h avant tout
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
            show_help
            exit 0
        fi
    done

    # Parser les options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --node)
                NODE="${2:?--node necessite une valeur}"
                shift 2
                ;;
            --storage)
                STORAGE="${2:?--storage necessite une valeur}"
                shift 2
                ;;
            --vmid)
                VMID_FILTER="${2:?--vmid necessite une valeur}"
                if ! [[ "$VMID_FILTER" =~ ^[0-9]+$ ]]; then
                    log_error "VMID invalide: doit etre un nombre"
                    exit 1
                fi
                shift 2
                ;;
            --full)
                FULL_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Detection du noeud
# =============================================================================

detect_node() {
    # Detecter depuis terraform.tfvars (essayer prod, puis lab, puis monitoring)
    local tfvars_dirs=(
        "${SCRIPT_DIR}/../../infrastructure/proxmox/environments/prod"
        "${SCRIPT_DIR}/../../infrastructure/proxmox/environments/lab"
        "${SCRIPT_DIR}/../../infrastructure/proxmox/environments/monitoring"
    )

    local detected_tfvars=""
    for dir in "${tfvars_dirs[@]}"; do
        local tfvars_file="${dir}/terraform.tfvars"
        if [[ -f "$tfvars_file" ]]; then
            detected_tfvars="$tfvars_file"
            # Detecter le nom du noeud si non specifie
            if [[ -z "$NODE" ]]; then
                NODE=$(get_pve_node "$tfvars_file" 2>/dev/null || echo "")
            fi
            # Detecter l'IP depuis proxmox_endpoint
            if [[ -z "$PVE_IP" ]]; then
                PVE_IP=$(grep -oP 'proxmox_endpoint\s*=\s*"https?://\K[0-9.]+' "$tfvars_file" 2>/dev/null | head -1 || echo "")
            fi
            if [[ -n "$NODE" ]] && [[ -n "$PVE_IP" ]]; then
                break
            fi
        fi
    done

    if [[ -n "$NODE" ]] && [[ -n "$PVE_IP" ]]; then
        log_info "Noeud Proxmox: ${NODE} (${PVE_IP})"
        return 0
    elif [[ -n "$NODE" ]]; then
        # Fallback: utiliser NODE comme hostname SSH
        PVE_IP="$NODE"
        log_info "Noeud Proxmox: ${NODE} (IP non detectee, utilise hostname)"
        return 0
    else
        log_warn "Noeud Proxmox non detecte (pas de tfvars ou --node non specifie)"
        log_info "Utilisez --node NODE pour activer la verification vzdump"
        return 1
    fi
}

# =============================================================================
# T021 - Verification vzdump
# =============================================================================

verify_vzdump_backups() {
    log_info "=== Verification des sauvegardes vzdump ==="
    log_info "Storage: ${STORAGE}"
    if [[ -n "$VMID_FILTER" ]]; then
        log_info "Filtrage par VMID: ${VMID_FILTER}"
    fi

    # Commande pvesh pour lister les backups
    local pvesh_cmd="pvesh get /nodes/${NODE}/storage/${STORAGE}/content --content backup --output-format json"

    local backups_json
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] SSH vers ${NODE}: ${pvesh_cmd}"
        # Mock output pour dry-run avec un backup recent (maintenant - 1h)
        local mock_ctime
        mock_ctime=$(($(date +%s) - 3600))
        backups_json='[{"volid":"local:backup/vzdump-qemu-100-2026_02_01-12_00_00.vma.zst","format":"vma.zst","size":1000000,"ctime":'$mock_ctime',"vmid":100}]'
    else
        backups_json=$(ssh_exec "${PVE_IP}" "${pvesh_cmd}" 2>/dev/null || echo "[]")
    fi

    # Parser le JSON avec jq
    local backup_count
    backup_count=$(echo "$backups_json" | jq '. | length' 2>/dev/null || echo "0")

    if [[ "$backup_count" -eq 0 ]]; then
        log_error "Aucune sauvegarde disponible sur ${NODE}:${STORAGE}"
        REPORT_LINES+=("vzdump | ${STORAGE} | ERROR | Aucun backup | Aucune sauvegarde trouvee")
        COUNT_ERROR=$((COUNT_ERROR + 1))
        TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
        EXIT_CODE=2
        return
    fi

    log_success "${backup_count} sauvegarde(s) trouvee(s)"

    # Filtrer par VMID si necessaire
    if [[ -n "$VMID_FILTER" ]]; then
        backups_json=$(echo "$backups_json" | jq --arg vmid "$VMID_FILTER" '[.[] | select(.vmid == ($vmid | tonumber))]')
        backup_count=$(echo "$backups_json" | jq '. | length' 2>/dev/null || echo "0")

        if [[ "$backup_count" -eq 0 ]]; then
            log_warn "Aucune sauvegarde pour VMID ${VMID_FILTER}"
            REPORT_LINES+=("vzdump | VMID ${VMID_FILTER} | ERROR | Aucun backup | VMID filtre sans backup")
            COUNT_ERROR=$((COUNT_ERROR + 1))
            TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
            EXIT_CODE=2
            return
        fi
    fi

    # Analyser chaque backup
    local vmid volid size ctime filename
    while IFS='|' read -r vmid volid size ctime; do
        # Extraire le nom du fichier depuis volid (format: storage:backup/filename)
        filename=$(echo "$volid" | sed 's/.*backup\///')

        # Verifier taille non-nulle
        if [[ "$size" -eq 0 ]]; then
            log_warn "VMID ${vmid}: sauvegarde vide (${filename})"
            REPORT_LINES+=("vzdump | VMID ${vmid} | WARNING | ${filename} | Taille nulle")
            COUNT_WARNING=$((COUNT_WARNING + 1))
            TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
            if [[ "$EXIT_CODE" -eq 0 ]]; then
                EXIT_CODE=1
            fi
            continue
        fi

        # Verifier que le fichier existe sur le filesystem
        local ls_cmd="ls -lh /var/lib/vz/dump/${filename}"
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] SSH vers ${NODE}: ${ls_cmd}"
        else
            if ! ssh_exec "${PVE_IP}" "${ls_cmd}" &>/dev/null; then
                log_error "VMID ${vmid}: fichier absent (${filename})"
                REPORT_LINES+=("vzdump | VMID ${vmid} | ERROR | ${filename} | Fichier absent")
                COUNT_ERROR=$((COUNT_ERROR + 1))
                TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
                EXIT_CODE=2
                continue
            fi
        fi

        # Verifier l'age du backup (WARNING si > 48h)
        local now_ts
        now_ts=$(date +%s)
        local age_hours=$(( (now_ts - ctime) / 3600 ))

        if [[ "$age_hours" -gt 48 ]]; then
            log_warn "VMID ${vmid}: dernier backup ancien (${age_hours}h)"
            REPORT_LINES+=("vzdump | VMID ${vmid} | WARNING | ${filename} | Backup ancien (${age_hours}h)")
            COUNT_WARNING=$((COUNT_WARNING + 1))
            TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
            if [[ "$EXIT_CODE" -eq 0 ]]; then
                EXIT_CODE=1
            fi
        else
            # Convertir taille en MB
            local size_mb=$((size / 1024 / 1024))
            log_success "VMID ${vmid}: OK (${size_mb}MB, ${age_hours}h)"
            REPORT_LINES+=("vzdump | VMID ${vmid} | OK | ${filename} | ${size_mb}MB, ${age_hours}h")
            COUNT_OK=$((COUNT_OK + 1))
            TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
        fi
    done < <(echo "$backups_json" | jq -r '.[] | "\(.vmid)|\(.volid)|\(.size)|\(.ctime)"')
}

# =============================================================================
# T022 - Verification state Minio
# =============================================================================

configure_mc() {
    local tfvars_file="${SCRIPT_DIR}/../../infrastructure/proxmox/environments/prod/terraform.tfvars"

    # Essayer monitoring si prod n'existe pas
    if [[ ! -f "$tfvars_file" ]]; then
        tfvars_file="${SCRIPT_DIR}/../../infrastructure/proxmox/environments/monitoring/terraform.tfvars"
    fi

    if [[ ! -f "$tfvars_file" ]]; then
        log_warn "Fichier terraform.tfvars introuvable, skip verification Minio"
        return 1
    fi

    log_info "Configuration du client Minio (mc)..."

    # Parser les valeurs Minio depuis le tfvars
    local minio_ip minio_user minio_password minio_port

    minio_ip=$(grep -A15 '^minio' "$tfvars_file" | grep -E '^\s*ip\s*=' | sed -E 's/.*ip\s*=\s*"([^"]+)".*/\1/' | xargs || echo "")
    minio_user=$(grep -A15 '^minio' "$tfvars_file" | grep -E '^\s*root_user\s*=' | sed -E 's/.*root_user\s*=\s*"([^"]+)".*/\1/' | xargs || echo "")
    minio_password=$(grep -A15 '^minio' "$tfvars_file" | grep -E '^\s*root_password\s*=' | sed -E 's/.*root_password\s*=\s*"([^"]+)".*/\1/' | xargs || echo "")
    minio_port=$(grep -A15 '^minio' "$tfvars_file" | grep -E '^\s*port\s*=' | sed -E 's/.*port\s*=\s*([0-9]+).*/\1/' | xargs || echo "")

    if [[ -z "$minio_ip" || -z "$minio_user" || -z "$minio_password" || -z "$minio_port" ]]; then
        log_warn "Configuration Minio incomplete dans terraform.tfvars"
        return 1
    fi

    local minio_endpoint="http://${minio_ip}:${minio_port}"
    local mc_alias="homelab"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] mc alias set ${mc_alias} ${minio_endpoint} ${minio_user} ****"
        return 0
    fi

    if ! mc alias set "${mc_alias}" "${minio_endpoint}" "${minio_user}" "${minio_password}" &>/dev/null; then
        log_warn "Impossible de configurer mc (Minio inaccessible?)"
        return 1
    fi

    log_success "Client mc configure"
    return 0
}

verify_minio_states() {
    log_info "=== Verification des states Terraform dans Minio ==="

    # En mode dry-run, on simule meme si la config echoue
    if [[ "$DRY_RUN" != true ]]; then
        if ! configure_mc; then
            log_warn "Skip verification Minio"
            return
        fi
    else
        # Simuler la configuration en dry-run
        log_info "[DRY-RUN] Configuration mc..."
    fi

    local mc_alias="homelab"
    local buckets=("tfstate-prod" "tfstate-lab" "tfstate-monitoring")

    for bucket in "${buckets[@]}"; do
        log_info "Verification du bucket: ${bucket}"

        # Verifier que le bucket existe
        local ls_cmd="mc ls ${mc_alias}/${bucket}"
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] ${ls_cmd}"
        else
            if ! mc ls "${mc_alias}/${bucket}" &>/dev/null; then
                log_error "Bucket ${bucket} absent ou inaccessible"
                REPORT_LINES+=("minio | ${bucket} | ERROR | Bucket absent | Bucket inaccessible")
                COUNT_ERROR=$((COUNT_ERROR + 1))
                TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
                EXIT_CODE=2
                continue
            fi
        fi

        # Lister les versions
        local versions_cmd="mc ls --versions ${mc_alias}/${bucket}/terraform.tfstate"
        local versions_count
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] ${versions_cmd}"
            versions_count=3
        else
            versions_count=$(mc ls --versions "${mc_alias}/${bucket}/terraform.tfstate" 2>/dev/null | wc -l || echo "0")
        fi

        if [[ "$versions_count" -eq 0 ]]; then
            log_error "Bucket ${bucket}: aucune version disponible"
            REPORT_LINES+=("minio | ${bucket} | ERROR | Aucune version | State absent")
            COUNT_ERROR=$((COUNT_ERROR + 1))
            TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
            EXIT_CODE=2
            continue
        fi

        # Telecharger version courante dans un fichier temporaire
        local tmpfile
        tmpfile=$(mktemp)
        local cp_cmd="mc cp ${mc_alias}/${bucket}/terraform.tfstate ${tmpfile}"

        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] ${cp_cmd}"
            # Mock un fichier JSON valide
            echo '{"version":4,"terraform_version":"1.5.0"}' > "$tmpfile"
        else
            if ! mc cp "${mc_alias}/${bucket}/terraform.tfstate" "${tmpfile}" &>/dev/null; then
                log_error "Bucket ${bucket}: impossible de telecharger le state"
                REPORT_LINES+=("minio | ${bucket} | ERROR | Download failed | Impossible de telecharger")
                COUNT_ERROR=$((COUNT_ERROR + 1))
                TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
                EXIT_CODE=2
                rm -f "$tmpfile"
                continue
            fi
        fi

        # Verifier JSON valide
        if ! jq . < "$tmpfile" > /dev/null 2>&1; then
            log_error "Bucket ${bucket}: JSON invalide"
            REPORT_LINES+=("minio | ${bucket} | ERROR | JSON invalide | State corrompu")
            COUNT_ERROR=$((COUNT_ERROR + 1))
            TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
            EXIT_CODE=2
            rm -f "$tmpfile"
            continue
        fi

        # Verifier taille non-nulle
        local size
        size=$(stat -f%z "$tmpfile" 2>/dev/null || stat -c%s "$tmpfile" 2>/dev/null || echo "0")

        if [[ "$size" -eq 0 ]]; then
            log_error "Bucket ${bucket}: fichier vide"
            REPORT_LINES+=("minio | ${bucket} | ERROR | Fichier vide | State vide")
            COUNT_ERROR=$((COUNT_ERROR + 1))
            TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
            EXIT_CODE=2
        else
            local size_kb=$((size / 1024))
            log_success "Bucket ${bucket}: OK (${versions_count} versions, ${size_kb}KB)"
            REPORT_LINES+=("minio | ${bucket} | OK | ${versions_count} versions | ${size_kb}KB, JSON valide")
            COUNT_OK=$((COUNT_OK + 1))
            TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))
        fi

        rm -f "$tmpfile"
    done
}

# =============================================================================
# T023 - Rapport global
# =============================================================================

generate_report() {
    echo ""
    log_info "============================================="
    log_info " RAPPORT DE VERIFICATION DES SAUVEGARDES"
    log_info "============================================="
    echo ""

    # Afficher le tableau
    printf "%-15s | %-20s | %-10s | %-30s | %-40s\n" "Type" "Composant" "Statut" "Dernier backup" "Details"
    printf "%s\n" "$(printf '%.0s-' {1..130})"

    for line in "${REPORT_LINES[@]}"; do
        IFS='|' read -r type component status last_backup details <<< "$line"
        printf "%-15s | %-20s | %-10s | %-30s | %-40s\n" "$type" "$component" "$status" "$last_backup" "$details"
    done

    echo ""
    log_info "============================================="
    log_info " RESUME"
    log_info "============================================="
    echo ""
    echo "  Total verifie:    ${TOTAL_VERIFIED}"
    echo "  OK:               ${COUNT_OK}"
    echo "  Warnings:         ${COUNT_WARNING}"
    echo "  Erreurs:          ${COUNT_ERROR}"
    echo ""

    if [[ "$COUNT_ERROR" -gt 0 ]]; then
        log_error "${COUNT_ERROR} erreur(s) critique(s) detectee(s)"
    elif [[ "$COUNT_WARNING" -gt 0 ]]; then
        log_warn "${COUNT_WARNING} avertissement(s)"
    else
        log_success "Toutes les sauvegardes sont OK"
    fi
    echo ""
}

verify_backup_jobs() {
    log_info "=== Verification des jobs de sauvegarde actifs ==="

    local jobs_cmd="pvesh get /cluster/backup --output-format json"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] SSH vers ${NODE}: ${jobs_cmd}"
        log_success "Jobs de sauvegarde actifs (dry-run)"
        return 0
    fi

    local jobs_json
    jobs_json=$(ssh_exec "${PVE_IP}" "${jobs_cmd}" 2>/dev/null || echo "[]")

    local jobs_count
    jobs_count=$(echo "$jobs_json" | jq '. | length' 2>/dev/null || echo "0")

    if [[ "$jobs_count" -eq 0 ]]; then
        log_warn "Aucun job de sauvegarde configure"
    else
        log_success "${jobs_count} job(s) de sauvegarde configure(s)"
    fi
}

# =============================================================================
# T025 - Verification connectivite VMs/LXC (mode --full)
# =============================================================================

verify_vm_connectivity() {
    log_info "=== Verification de la connectivite vers les VMs/LXC ==="

    # Lister toutes les VMs/LXC depuis Proxmox
    local vms_cmd="pvesh get /cluster/resources --type vm --output-format json"

    local vms_json
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] SSH vers ${NODE}: ${vms_cmd}"
        # Mock avec 2 VMs pour dry-run
        vms_json='[{"vmid":100,"type":"qemu","status":"running","name":"vm-prod","ip":"192.168.1.110"},{"vmid":101,"type":"lxc","status":"running","name":"lxc-db","ip":"192.168.1.111"}]'
    else
        vms_json=$(ssh_exec "${PVE_IP}" "${vms_cmd}" 2>/dev/null || echo "[]")
    fi

    local vm_count
    vm_count=$(echo "$vms_json" | jq '. | length' 2>/dev/null || echo "0")

    if [[ "$vm_count" -eq 0 ]]; then
        log_warn "Aucune VM/LXC trouvee"
        return 0
    fi

    log_info "${vm_count} VM(s)/LXC trouvee(s)"

    # Tester la connectivite pour chaque VM/LXC running
    local vmid name status type
    while IFS='|' read -r vmid name status type; do
        # Skip si status != running
        if [[ "$status" != "running" ]]; then
            log_info "VMID ${vmid} (${name}): skip (status: ${status})"
            continue
        fi

        # Recuperer l'IP de la VM depuis la config (qm ou pct)
        local ip_cmd
        if [[ "$type" == "qemu" ]]; then
            ip_cmd="qm config ${vmid} | grep -i ip= | head -1 | sed -E 's/.*ip=([0-9.]+).*/\1/'"
        else
            ip_cmd="pct config ${vmid} | grep -i ip= | head -1 | sed -E 's/.*ip=([0-9.]+).*/\1/'"
        fi

        local vm_ip
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] SSH vers ${NODE}: ${ip_cmd}"
            # Mock IP pour dry-run
            vm_ip="192.168.1.$((100 + vmid % 50))"
        else
            vm_ip=$(ssh_exec "${PVE_IP}" "${ip_cmd}" 2>/dev/null | xargs || echo "")
        fi

        if [[ -z "$vm_ip" ]]; then
            log_warn "VMID ${vmid} (${name}): IP non trouvee, skip"
            continue
        fi

        # Test ping
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] ping -c 1 -W 2 ${vm_ip}"
            log_success "VMID ${vmid} (${name}): ping OK (${vm_ip})"
        else
            if ping -c 1 -W 2 "${vm_ip}" &>/dev/null; then
                log_success "VMID ${vmid} (${name}): ping OK (${vm_ip})"
            else
                log_warn "VMID ${vmid} (${name}): ping FAILED (${vm_ip})"
            fi
        fi
    done < <(echo "$vms_json" | jq -r '.[] | "\(.vmid)|\(.name // "unnamed")|\(.status)|\(.type)"')
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Parsing arguments (doit etre fait AVANT d'afficher le header pour --help)
    parse_args "$@"

    log_info "============================================="
    log_info " Verification de l'integrite des sauvegardes"
    log_info "============================================="
    echo ""

    # Afficher mode dry-run si active
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Mode DRY-RUN active: aucune action ne sera executee"
    fi

    # Afficher mode full si active
    if [[ "$FULL_MODE" == true ]]; then
        log_info "Mode FULL active: verification complete (vzdump + Minio + connectivite + jobs)"
    fi

    # Verification des prerequis (SSH et jq obligatoires)
    local missing=()
    for cmd in "ssh" "jq"; do
        if ! check_command "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Outils manquants: ${missing[*]}"
        log_error "Installez les prerequis avant de continuer"
        exit 2
    fi

    # mc est optionnel - on skip la verification Minio si absent
    local MC_AVAILABLE=true
    if [[ "$DRY_RUN" != true ]] && ! check_command "mc"; then
        log_warn "mc (Minio Client) non installe - verification Minio desactivee"
        log_info "Pour installer: https://min.io/docs/minio/linux/reference/minio-mc.html"
        MC_AVAILABLE=false
    fi

    # Detection du noeud (optionnel - on skip vzdump si non detecte)
    local NODE_AVAILABLE=true
    if ! detect_node; then
        NODE_AVAILABLE=false
    fi

    # Verification vzdump (seulement si noeud disponible)
    if [[ "$NODE_AVAILABLE" == true ]]; then
        verify_vzdump_backups
    else
        log_info "=== Verification vzdump skippee (noeud non disponible) ==="
    fi

    # Verification Minio (seulement si mc est disponible)
    if [[ "$MC_AVAILABLE" == true ]]; then
        verify_minio_states
    else
        log_info "=== Verification Minio skippee (mc non disponible) ==="
    fi

    # Mode full: verifications supplementaires (seulement si noeud disponible)
    if [[ "$FULL_MODE" == true ]]; then
        if [[ "$NODE_AVAILABLE" == true ]]; then
            verify_backup_jobs
            verify_vm_connectivity
        else
            log_info "=== Verifications full skippees (noeud non disponible) ==="
        fi
        log_info "Verification complete terminee"
    fi

    # Generer le rapport
    generate_report

    # Retourner le code de sortie approprie
    exit "$EXIT_CODE"
}

main "$@"
