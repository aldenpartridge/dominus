#!/bin/bash

# Input validation and sanitization for DOMINUS

# Source common library if not already loaded
if [ -z "$GREEN" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "$SCRIPT_DIR/lib/common.sh"
fi

# ============================================================================
# DOMAIN VALIDATION
# ============================================================================

# Validate domain format
validate_domain() {
    local domain="$1"

    # Check if empty
    if [ -z "$domain" ]; then
        log_error "Domain cannot be empty"
        return 1
    fi

    # Check length
    if [ ${#domain} -gt 253 ]; then
        log_error "Domain too long (max 253 characters)"
        return 1
    fi

    # Check format (basic DNS compliant)
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid domain format: $domain"
        log_info "Domain must contain only letters, numbers, dots, and hyphens"
        return 1
    fi

    # Check for obvious malicious patterns
    if [[ "$domain" =~ \.\. ]] || [[ "$domain" =~ ^- ]] || [[ "$domain" =~ -$ ]]; then
        log_error "Invalid domain format: $domain"
        return 1
    fi

    # Check for path traversal attempts
    if [[ "$domain" =~ \.\./|/\.\. ]]; then
        log_error "Invalid domain: path traversal detected"
        return 1
    fi

    log_debug "Domain validated: $domain"
    return 0
}

# Validate IP address
validate_ip() {
    local ip="$1"

    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Validate CIDR notation
validate_cidr() {
    local cidr="$1"

    if [[ "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        local ip="${cidr%/*}"
        local mask="${cidr#*/}"

        validate_ip "$ip" || return 1

        if [ "$mask" -ge 0 ] && [ "$mask" -le 32 ]; then
            return 0
        fi
    fi
    return 1
}

# ============================================================================
# ORGANIZATION NAME VALIDATION
# ============================================================================

# Sanitize organization name
sanitize_org_name() {
    local org_name="$1"

    # Remove special characters, keep only alphanumeric, dash, underscore
    local sanitized=$(echo "$org_name" | tr -cd '[:alnum:]_-')

    # Remove leading/trailing dashes
    sanitized=$(echo "$sanitized" | sed 's/^-*//' | sed 's/-*$//')

    # Convert to lowercase
    sanitized=$(echo "$sanitized" | tr '[:upper:]' '[:lower:]')

    # Limit length
    if [ ${#sanitized} -gt 50 ]; then
        sanitized="${sanitized:0:50}"
    fi

    # Check if empty after sanitization
    if [ -z "$sanitized" ]; then
        sanitized="unnamed-operation"
    fi

    echo "$sanitized"
}

# Validate organization name
validate_org_name() {
    local org_name="$1"

    if [ -z "$org_name" ]; then
        log_error "Organization name cannot be empty"
        return 1
    fi

    # Check for path traversal
    if [[ "$org_name" =~ \.\./|/\.\. ]]; then
        log_error "Invalid organization name: path traversal detected"
        return 1
    fi

    # Check for absolute paths
    if [[ "$org_name" =~ ^/ ]]; then
        log_error "Invalid organization name: absolute path detected"
        return 1
    fi

    log_debug "Organization name validated: $org_name"
    return 0
}

# ============================================================================
# SCOPE FILE VALIDATION
# ============================================================================

# Validate scope file
validate_scope_file() {
    local scope_file="$1"

    if [ -z "$scope_file" ]; then
        return 0  # Empty is OK (means interactive mode)
    fi

    if [ ! -f "$scope_file" ]; then
        log_error "Scope file not found: $scope_file"
        return 1
    fi

    if [ ! -r "$scope_file" ]; then
        log_error "Scope file not readable: $scope_file"
        return 1
    fi

    local line_count=$(grep -v '^#' "$scope_file" | grep -v '^$' | wc -l)
    if [ "$line_count" -eq 0 ]; then
        log_error "Scope file is empty: $scope_file"
        return 1
    fi

    log_debug "Scope file validated: $scope_file ($line_count domains)"
    return 0
}

# Parse scope file
parse_scope_file() {
    local scope_file="$1"

    if [ ! -f "$scope_file" ]; then
        return 1
    fi

    # Extract non-comment, non-empty lines
    grep -v '^#' "$scope_file" | grep -v '^$' | while read -r domain; do
        # Trim whitespace
        domain=$(echo "$domain" | xargs)

        # Validate each domain
        if validate_domain "$domain" 2>/dev/null; then
            echo "$domain"
        else
            log_warning "Skipping invalid domain in scope file: $domain"
        fi
    done
}

# Check if domain is in scope
is_in_scope() {
    local domain="$1"
    local scope_file="$2"

    if [ -z "$scope_file" ] || [ ! -f "$scope_file" ]; then
        return 0  # No scope file means everything is in scope
    fi

    # Check if domain or parent domain is in scope
    local current_domain="$domain"
    while [ -n "$current_domain" ]; do
        if grep -q "^${current_domain}$" "$scope_file" 2>/dev/null; then
            return 0
        fi

        # Check wildcard
        if grep -q "^\*\.${current_domain}$" "$scope_file" 2>/dev/null; then
            return 0
        fi

        # Move to parent domain
        if [[ "$current_domain" =~ \. ]]; then
            current_domain="${current_domain#*.}"
        else
            break
        fi
    done

    return 1
}

# Check if domain is out of scope
is_out_of_scope() {
    local domain="$1"
    local out_of_scope_file="${OUT_OF_SCOPE_FILE}"

    if [ -z "$out_of_scope_file" ] || [ ! -f "$out_of_scope_file" ]; then
        return 1  # No out-of-scope file means nothing is excluded
    fi

    if grep -q "^${domain}$" "$out_of_scope_file" 2>/dev/null; then
        return 0
    fi

    return 1
}

# ============================================================================
# URL VALIDATION
# ============================================================================

# Validate URL format
validate_url() {
    local url="$1"

    # Basic URL format check
    if [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+(/.*)?$ ]]; then
        return 0
    fi

    return 1
}

# Extract domain from URL
extract_domain_from_url() {
    local url="$1"

    # Remove protocol
    local domain="${url#http://}"
    domain="${domain#https://}"

    # Remove path
    domain="${domain%%/*}"

    # Remove port
    domain="${domain%%:*}"

    echo "$domain"
}

# ============================================================================
# FILE PATH VALIDATION
# ============================================================================

# Validate file path (prevent directory traversal)
validate_file_path() {
    local path="$1"
    local base_dir="$2"

    # Check for path traversal
    if [[ "$path" =~ \.\./|/\.\. ]]; then
        log_error "Invalid path: directory traversal detected"
        return 1
    fi

    # If base_dir specified, ensure path is within it
    if [ -n "$base_dir" ]; then
        local real_base=$(realpath "$base_dir" 2>/dev/null)
        local real_path=$(realpath "$path" 2>/dev/null)

        if [ -n "$real_base" ] && [ -n "$real_path" ]; then
            if [[ "$real_path" != "$real_base"* ]]; then
                log_error "Path outside base directory: $path"
                return 1
            fi
        fi
    fi

    return 0
}

# ============================================================================
# AUTHORIZATION VALIDATION
# ============================================================================

# Show legal warning and get authorization
confirm_authorization() {
    local domain="$1"

    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                      LEGAL WARNING                           ║${NC}"
    echo -e "${RED}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC}  This tool performs security reconnaissance that may:       ${RED}║${NC}"
    echo -e "${RED}║${NC}  • Generate significant network traffic                     ${RED}║${NC}"
    echo -e "${RED}║${NC}  • Be detected by security monitoring systems               ${RED}║${NC}"
    echo -e "${RED}║${NC}  • Violate computer fraud and abuse laws if unauthorized    ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                              ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${YELLOW}ONLY scan targets you have EXPLICIT permission to test${NC}   ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Target domain:${NC} ${CYAN}$domain${NC}"
    echo ""
    echo -e "${YELLOW}Authorization Checklist:${NC}"
    echo -e "  ${GREEN}✓${NC} Bug bounty program scope"
    echo -e "  ${GREEN}✓${NC} Written penetration testing agreement"
    echo -e "  ${GREEN}✓${NC} Your own infrastructure"
    echo -e "  ${GREEN}✓${NC} Authorized security research"
    echo ""

    read -p "$(echo -e ${YELLOW}I confirm I have explicit authorization to scan this target \(yes/no\): ${NC})" confirm

    if [ "$confirm" = "yes" ]; then
        log_success "Authorization confirmed"
        return 0
    else
        log_error "Authorization required. Exiting."
        return 1
    fi
}

# ============================================================================
# NUMERICAL VALIDATION
# ============================================================================

# Validate integer
validate_integer() {
    local value="$1"
    local min="${2:-0}"
    local max="${3:-999999}"

    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        return 1
    fi

    return 0
}

# Validate port number
validate_port() {
    local port="$1"

    validate_integer "$port" 1 65535
}

# Validate port range
validate_port_range() {
    local range="$1"

    if [[ "$range" =~ ^[0-9]+-[0-9]+$ ]]; then
        local start="${range%-*}"
        local end="${range#*-}"

        validate_port "$start" || return 1
        validate_port "$end" || return 1

        if [ "$start" -ge "$end" ]; then
            return 1
        fi

        return 0
    fi

    return 1
}
