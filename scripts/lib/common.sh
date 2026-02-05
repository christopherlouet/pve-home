#!/bin/bash
# =============================================================================
# Bibliotheque commune pour les scripts de restauration
# =============================================================================
# Usage: source scripts/lib/common.sh
#
# Fournit des fonctions partagees pour :
# - Logging avec couleurs (log_info, log_success, log_warn, log_error)
# - Confirmation interactive (confirm)
# - Parsing arguments communs (parse_common_args)
# - Execution SSH sur le noeud PVE (ssh_exec)
# - Verification des prerequis (check_command, check_prereqs, check_ssh_access)
# - Parsing des fichiers terraform.tfvars (parse_tfvars, get_pve_node, get_pve_ip)
# - Mode dry-run (dry_run)
# - Creation de points de sauvegarde (create_backup_point)
# =============================================================================

set -euo pipefail

# =============================================================================
# Detection du repertoire du script
# =============================================================================

# Variable exportee pour utilisation par les scripts qui sourcent cette lib
# shellcheck disable=SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Couleurs
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# Variables globales
# =============================================================================

DRY_RUN=false
FORCE_MODE=false

# Fichier known_hosts dedie pour le homelab (securite SSH)
# Utiliser un fichier separe evite de polluer ~/.ssh/known_hosts
HOMELAB_KNOWN_HOSTS="${HOMELAB_KNOWN_HOSTS:-${HOME}/.ssh/homelab_known_hosts}"

# Mode d'initialisation SSH (permet accept-new uniquement lors de l'init)
SSH_INIT_MODE="${SSH_INIT_MODE:-false}"

# =============================================================================
# Fonctions SSH known_hosts (securite)
# =============================================================================

# Initialise le fichier known_hosts avec les cles SSH des hotes
# Usage: init_known_hosts "192.168.1.10" "192.168.1.11"
# Cette fonction doit etre appelee une fois lors du setup initial
init_known_hosts() {
    local hosts=("$@")

    if [[ ${#hosts[@]} -eq 0 ]]; then
        echo -e "${RED}[ERROR]${NC} init_known_hosts: au moins un hote requis"
        return 1
    fi

    # Creer le repertoire si necessaire
    mkdir -p "$(dirname "$HOMELAB_KNOWN_HOSTS")"

    echo -e "${BLUE}[INFO]${NC} Initialisation du fichier known_hosts: ${HOMELAB_KNOWN_HOSTS}"

    for host in "${hosts[@]}"; do
        echo -e "${BLUE}[INFO]${NC} Scan des cles SSH pour ${host}..."

        # Scanner les cles SSH de l'hote
        if ssh-keyscan -H "$host" >> "$HOMELAB_KNOWN_HOSTS" 2>/dev/null; then
            echo -e "${GREEN}[OK]${NC} Cles ajoutees pour ${host}"
        else
            echo -e "${YELLOW}[WARN]${NC} Impossible de scanner ${host} (hote inaccessible?)"
        fi
    done

    # Supprimer les doublons
    if [[ -f "$HOMELAB_KNOWN_HOSTS" ]]; then
        sort -u "$HOMELAB_KNOWN_HOSTS" -o "$HOMELAB_KNOWN_HOSTS"
        echo -e "${GREEN}[OK]${NC} Fichier known_hosts initialise avec $(wc -l < "$HOMELAB_KNOWN_HOSTS") entrees"
    fi

    return 0
}

# Verifie si un hote est dans le fichier known_hosts
# Usage: is_host_known "192.168.1.10"
is_host_known() {
    local host="$1"

    if [[ ! -f "$HOMELAB_KNOWN_HOSTS" ]]; then
        return 1
    fi

    # Verifier si l'hote est present (hash ou IP directe)
    if ssh-keygen -F "$host" -f "$HOMELAB_KNOWN_HOSTS" &>/dev/null; then
        return 0
    fi

    return 1
}

# Retourne les options SSH securisees
# Usage: ssh $(get_ssh_opts) root@host "command"
get_ssh_opts() {
    local opts="-o LogLevel=ERROR"
    opts+=" -o UserKnownHostsFile=${HOMELAB_KNOWN_HOSTS}"

    if [[ "$SSH_INIT_MODE" == "true" ]]; then
        # Mode init: accepter les nouvelles cles (premiere connexion)
        opts+=" -o StrictHostKeyChecking=accept-new"
    else
        # Mode normal: verifier strictement les cles
        opts+=" -o StrictHostKeyChecking=yes"
    fi

    echo "$opts"
}

# =============================================================================
# Fonctions de logging (T002)
# =============================================================================

# =============================================================================
# Fonction de masquage des secrets (P1 - Securite)
# =============================================================================

# Masque les secrets dans un message avant de le logger
# Usage: log_secret "Message avec secret abc123xyz"
# Les patterns suivants sont masques:
#   - Tokens API (32+ chars alphanumeriques)
#   - UUIDs
#   - Mots de passe (apres password=, passwd=, pwd=)
#   - Base64 (16+ chars)
log_secret() {
    local msg="$1"
    # Masquer les UUIDs
    msg=$(echo "$msg" | sed -E 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/***UUID***/gi')
    # Masquer les tokens API (longues chaines alphanumeriques)
    msg=$(echo "$msg" | sed -E 's/[A-Za-z0-9_-]{32,}/***TOKEN***/g')
    # Masquer les mots de passe apres password=, passwd=, pwd=
    msg=$(echo "$msg" | sed -E 's/(password|passwd|pwd|secret|token)=["'\''"]?[^"'\'' ]+["'\''"]?/\1=***/gi')
    # Masquer les chaines base64 longues
    msg=$(echo "$msg" | sed -E 's/[A-Za-z0-9+/]{24,}={0,2}/***BASE64***/g')
    log_info "$msg"
}

# Version securisee de log pour les operations sensibles
log_info_secure() {
    log_secret "$1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
    local message="$1"
    if [[ "$FORCE_MODE" == true ]]; then
        log_info "$message"
        return 0
    fi
    echo -en "${BLUE}[?]${NC} $message [O/n] "
    read -r response
    case "$response" in
        [nN]|[nN][oO]) return 1 ;;
        *) return 0 ;;
    esac
}

parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

show_help() {
    cat << 'HELPEOF'
Usage: script [options]

Options communes:
  --dry-run    Afficher les commandes sans les executer
  --force      Mode non-interactif (pas de confirmation)
  -h, --help   Afficher cette aide
HELPEOF
}

# =============================================================================
# Fonctions SSH et verification prerequis (T003)
# =============================================================================

ssh_exec() {
    local node="$1"
    local command="$2"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] SSH vers ${node}: ${command}"
        return 0
    fi

    # Options SSH securisees avec known_hosts dedie
    # shellcheck disable=SC2046
    ssh $(get_ssh_opts) "root@${node}" "${command}"
}

check_ssh_access() {
    local node="$1"

    log_info "Verification de l'acces SSH vers ${node}..."

    # Verifier si l'hote est connu, sinon suggerer l'initialisation
    if [[ ! -f "$HOMELAB_KNOWN_HOSTS" ]] || ! is_host_known "$node"; then
        log_warn "Hote ${node} non trouve dans ${HOMELAB_KNOWN_HOSTS}"
        log_warn "Executez: init_known_hosts '${node}' pour ajouter la cle SSH"
        log_warn "Ou exportez SSH_INIT_MODE=true pour accepter la cle automatiquement"
    fi

    # shellcheck disable=SC2046
    if ! retry_with_backoff 3 ssh -o ConnectTimeout=5 $(get_ssh_opts) \
         "root@${node}" "exit" &>/dev/null; then
        log_error "Impossible de se connecter en SSH a ${node} apres 3 tentatives"
        log_error "Verifiez que la cle SSH est configuree et que le noeud est accessible"
        log_error "Si c'est une nouvelle machine, initialisez known_hosts: init_known_hosts '${node}'"
        return 1
    fi

    log_success "Acces SSH vers ${node} OK"
    return 0
}

# =============================================================================
# Fonctions de retry avec backoff exponentiel
# =============================================================================

retry_with_backoff() {
    local max_attempts="$1"
    shift
    local attempt=1
    local delay=1

    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Echec apres ${max_attempts} tentatives: $*"
            return 1
        fi

        log_warn "Tentative ${attempt}/${max_attempts} echouee, retry dans ${delay}s..."
        sleep "$delay"
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

ssh_exec_retry() {
    local node="$1"
    local command="$2"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] SSH vers ${node}: ${command}"
        return 0
    fi

    # shellcheck disable=SC2046
    retry_with_backoff 3 ssh $(get_ssh_opts) "root@${node}" "${command}"
}

# =============================================================================
# Fonctions de verification prerequis
# =============================================================================

check_command() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null
}

check_prereqs() {
    local missing=()
    local required_commands=("ssh" "terraform" "mc" "jq")

    for cmd in "${required_commands[@]}"; do
        if ! check_command "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Outils manquants: ${missing[*]}"
        log_error "Installez les prerequis avant de continuer"
        return 1
    fi

    log_success "Tous les prerequis sont presents"
    return 0
}

check_disk_space() {
    local node="$1"
    local storage="$2"
    local required_mb="${3:-1000}"

    log_info "Verification de l'espace disque sur ${node}:${storage}..."

    # Recuperer le statut du storage via pvesh
    local status_json
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Verification espace disque sur ${storage}"
        return 0
    fi

    status_json=$(ssh_exec "${node}" "pvesh get /storage/${storage}/status --output-format json" 2>/dev/null || echo "")

    if [[ -z "$status_json" ]]; then
        log_warn "Impossible de verifier l'espace disque sur ${storage}"
        return 1
    fi

    local avail_mb
    avail_mb=$(echo "$status_json" | jq -r '.avail // 0' | awk '{print int($1/1024/1024)}')

    if [[ "$avail_mb" -lt "$required_mb" ]]; then
        log_error "Espace disque insuffisant: ${avail_mb}MB disponible, ${required_mb}MB requis"
        return 1
    fi

    log_success "Espace disque suffisant: ${avail_mb}MB disponible"
    return 0
}

# =============================================================================
# Fonction parse_hcl_block (P2 - Reduction duplication)
# =============================================================================

# Parse un bloc HCL et extrait une valeur
# Usage: parse_hcl_block "fichier.tfvars" "nom_bloc" "cle"
# Exemple: parse_hcl_block "$tfvars" "vms" "ip"
#          parse_hcl_block "$tfvars" "monitoring" "ip"
# Retourne toutes les valeurs correspondantes (une par ligne)
parse_hcl_block() {
    local file="$1"
    local block="$2"
    local key="$3"

    if [[ ! -f "$file" ]]; then
        log_error "Fichier introuvable: ${file}"
        return 1
    fi

    # Parser le bloc HCL et extraire la valeur de la cle
    # Support les formats: key = "value" et key = value
    awk "/^${block}\\s*=\\s*\\{/,/^\\}/" "$file" | \
        grep -oP "${key}\\s*=\\s*\"\\K[^\"]*" 2>/dev/null || \
        echo ""
}

# Variante qui retourne uniquement la premiere valeur
parse_hcl_block_first() {
    local file="$1"
    local block="$2"
    local key="$3"
    parse_hcl_block "$file" "$block" "$key" | head -1
}

# Variante qui retourne les valeurs uniques triees
parse_hcl_block_unique() {
    local file="$1"
    local block="$2"
    local key="$3"
    parse_hcl_block "$file" "$block" "$key" | sort -u
}

# Fonction de validation de choix parmi une liste
# Usage: validate_choice "valeur" "opt1" "opt2" "opt3"
# Retourne 0 si valide, 1 sinon
validate_choice() {
    local value="$1"
    shift
    local options=("$@")

    for opt in "${options[@]}"; do
        if [[ "$opt" == "$value" ]]; then
            return 0
        fi
    done

    return 1
}

# =============================================================================
# Fonctions parse_tfvars et dry_run (T004)
# =============================================================================

parse_tfvars() {
    local tfvars_file="$1"
    local key="$2"

    if [[ ! -f "$tfvars_file" ]]; then
        log_error "Fichier terraform.tfvars introuvable: ${tfvars_file}"
        return 1
    fi

    # Parser avec grep/sed
    # Format attendu: key = "value" ou key = value
    # Regex: ^key\s*= capture tout apres le '=' et supprime les quotes optionnelles
    local value
    value=$(grep "^${key}\\s*=" "$tfvars_file" | \
            sed -E 's/^[^=]*=\s*"?([^"]*)"?.*/\1/' | \
            tr -d '"' | \
            xargs)

    if [[ -z "$value" ]]; then
        log_error "Cle '${key}' introuvable dans ${tfvars_file}"
        return 1
    fi

    echo "$value"
}

get_pve_node() {
    local tfvars_file="${1:-terraform.tfvars}"
    # Essayer default_node d'abord, puis pve_node pour compatibilite
    local node
    node=$(parse_tfvars "$tfvars_file" "default_node" 2>/dev/null) || true
    if [[ -z "$node" ]]; then
        node=$(parse_tfvars "$tfvars_file" "pve_node" 2>/dev/null) || true
    fi
    echo "$node"
}

get_pve_ip() {
    local tfvars_file="${1:-terraform.tfvars}"
    parse_tfvars "$tfvars_file" "pve_ip"
}

dry_run() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] $*"
        return 0
    fi

    # Executer la commande directement (sans eval pour eviter l'injection)
    "$@"
}

create_backup_point() {
    local component="$1"
    local backup_dir="${2:-/tmp/restore-backups}"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)

    mkdir -p "$backup_dir"

    local backup_file="${backup_dir}/${component}-${timestamp}.backup"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Creation point de sauvegarde: ${backup_file}"
        return 0
    fi

    log_info "Creation point de sauvegarde pour ${component}..."

    # Creer un fichier de metadata sur la sauvegarde
    cat > "$backup_file" << EOF
# Point de sauvegarde
Component: ${component}
Timestamp: ${timestamp}
Date: $(date)
EOF

    log_success "Point de sauvegarde cree: ${backup_file}"
    echo "$backup_file"
    return 0
}
