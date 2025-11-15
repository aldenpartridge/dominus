#!/bin/bash

# Common functions and variables for DOMINUS
# Source this file in all scripts: source "$SCRIPT_DIR/lib/common.sh"

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Disable colors if configured
if [ "$ENABLE_COLORS" = "false" ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    PURPLE=''
    NC=''
fi

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# Get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log to file if enabled
log_to_file() {
    local message="$1"
    if [ "$ENABLE_DETAILED_LOGGING" = "true" ] && [ -n "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        echo "[$(get_timestamp)] $message" >> "$LOG_DIR/dominus.log"
    fi
}

# Info message [*]
log_info() {
    local message="$1"
    echo -e "${BLUE}[*]${NC} $message"
    log_to_file "INFO: $message"
}

# Success message [✓]
log_success() {
    local message="$1"
    echo -e "${GREEN}[✓]${NC} $message"
    log_to_file "SUCCESS: $message"
}

# Warning message [!]
log_warning() {
    local message="$1"
    echo -e "${YELLOW}[!]${NC} $message"
    log_to_file "WARNING: $message"
}

# Error message [✗]
log_error() {
    local message="$1"
    echo -e "${RED}[✗]${NC} $message"
    log_to_file "ERROR: $message"
}

# Critical error [!!]
log_critical() {
    local message="$1"
    echo -e "${PURPLE}[!!]${NC} $message"
    log_to_file "CRITICAL: $message"
}

# Phase announcement [>>]
log_phase() {
    local message="$1"
    echo ""
    echo -e "${MAGENTA}[>>]${NC} ${CYAN}$message${NC}"
    echo ""
    log_to_file "PHASE: $message"
}

# Debug message (only if verbosity >= 3)
log_debug() {
    local message="$1"
    if [ "${VERBOSITY:-1}" -ge 3 ]; then
        echo -e "${CYAN}[DEBUG]${NC} $message"
    fi
    log_to_file "DEBUG: $message"
}

# ============================================================================
# PROGRESS INDICATORS
# ============================================================================

# Show progress bar
show_progress() {
    local phase="$1"
    local current="$2"
    local total="$3"

    if [ "$total" -eq 0 ]; then
        return
    fi

    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    printf "\r${CYAN}[*]${NC} %-30s [" "$phase"
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %3d%%" "$percent"
}

# Clear progress line
clear_progress() {
    printf "\r%80s\r" " "
}

# Spinner for long-running operations
show_spinner() {
    local pid=$1
    local message="$2"
    local spin='-\|/'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${CYAN}[${spin:$i:1}]${NC} $message"
        sleep 0.1
    done
    printf "\r%80s\r" " "
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if file is not empty
file_not_empty() {
    [ -s "$1" ]
}

# Count lines in file
count_lines() {
    local file="$1"
    if [ -f "$file" ]; then
        wc -l < "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Deduplicate and sort file
dedupe_file() {
    local file="$1"
    if [ -f "$file" ]; then
        sort -u "$file" -o "$file"
    fi
}

# Safely append to file (deduplicates)
safe_append() {
    local source="$1"
    local target="$2"

    if [ -f "$source" ] && [ -s "$source" ]; then
        if command_exists anew; then
            cat "$source" | anew "$target" >/dev/null 2>&1
        else
            cat "$source" >> "$target"
            dedupe_file "$target"
        fi
    fi
}

# Create directory safely
safe_mkdir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || {
            log_error "Failed to create directory: $dir"
            return 1
        }
    fi
}

# ============================================================================
# DRY RUN SUPPORT
# ============================================================================

# Execute command or show what would be executed
execute_or_dry_run() {
    local description="$1"
    shift
    local command="$@"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: $description"
        log_debug "Would execute: $command"
        return 0
    else
        log_debug "Executing: $command"
        eval "$command"
    fi
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Retry a command with exponential backoff
retry_command() {
    local max_retries="${MAX_RETRIES:-3}"
    local delay="${RETRY_DELAY:-5}"
    local attempt=1
    local exitcode=0

    while [ $attempt -le $max_retries ]; do
        if "$@"; then
            return 0
        else
            exitcode=$?
            if [ $attempt -lt $max_retries ]; then
                log_warning "Command failed (attempt $attempt/$max_retries). Retrying in ${delay}s..."
                sleep $delay
                delay=$((delay * 2))
            fi
            attempt=$((attempt + 1))
        fi
    done

    log_error "Command failed after $max_retries attempts"
    return $exitcode
}

# ============================================================================
# TIME TRACKING
# ============================================================================

# Get current timestamp in seconds
get_epoch() {
    date +%s
}

# Calculate duration
calc_duration() {
    local start_time=$1
    local end_time=$2
    local duration=$((end_time - start_time))

    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))

    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# ============================================================================
# METADATA MANAGEMENT
# ============================================================================

# Add metadata entry
add_metadata() {
    local key="$1"
    local value="$2"
    local metadata_file="${3:-$WORK_DIR/metadata.txt}"

    if [ -n "$metadata_file" ]; then
        echo "$key: $value" >> "$metadata_file"
    fi
}

# ============================================================================
# CACHE MANAGEMENT
# ============================================================================

# Get cached data
get_cached() {
    local key="$1"
    local cache_file="$CACHE_DIR/$key"

    if [ "$ENABLE_CACHE" != "true" ]; then
        return 1
    fi

    if [ -f "$cache_file" ]; then
        local age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo "0")))
        local ttl="${CACHE_TTL:-86400}"

        if [ $age -lt $ttl ]; then
            cat "$cache_file"
            return 0
        else
            log_debug "Cache expired for: $key"
            rm -f "$cache_file"
        fi
    fi

    return 1
}

# Save to cache
set_cached() {
    local key="$1"
    local data="$2"
    local cache_file="$CACHE_DIR/$key"

    if [ "$ENABLE_CACHE" = "true" ]; then
        safe_mkdir "$CACHE_DIR"
        echo "$data" > "$cache_file"
    fi
}

# Clear cache
clear_cache() {
    if [ -d "$CACHE_DIR" ]; then
        log_info "Clearing cache..."
        rm -rf "$CACHE_DIR"/*
        log_success "Cache cleared"
    fi
}

# ============================================================================
# BANNER AND UI
# ============================================================================

# Print separator line
print_separator() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
}

print_separator_end() {
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Print section header
print_header() {
    local title="$1"
    echo ""
    print_separator
    echo -e "${CYAN}║${NC}  ${YELLOW}$title${NC}"
    print_separator_end
    echo ""
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Load configuration defaults
load_defaults() {
    # Set defaults if not already set
    : "${BASE_DIR:=$HOME/recon}"
    : "${WORDLISTS_DIR:=$BASE_DIR/wordlists}"
    : "${DEFAULT_THREADS:=25}"
    : "${HTTPX_THREADS:=50}"
    : "${CONCURRENCY:=25}"
    : "${RATE_LIMIT:=150}"
    : "${VERBOSITY:=1}"
    : "${ENABLE_COLORS:=true}"
    : "${ENABLE_CACHE:=true}"
    : "${CACHE_DIR:=$BASE_DIR/.cache}"
    : "${CACHE_TTL:=86400}"
    : "${ENABLE_DETAILED_LOGGING:=true}"
    : "${LOG_DIR:=$BASE_DIR/logs}"
    : "${MAX_RETRIES:=3}"
    : "${RETRY_DELAY:=5}"
    : "${ENABLE_RESUME:=true}"
    : "${AUTO_STAGE3:=true}"
    : "${DRY_RUN:=false}"
    : "${ENABLE_JSON:=true}"
    : "${ENABLE_NOTIFICATIONS:=false}"
}

# Initialize common variables
init_common() {
    load_defaults

    # Create base directories
    safe_mkdir "$BASE_DIR"
    safe_mkdir "$LOG_DIR"

    if [ "$ENABLE_CACHE" = "true" ]; then
        safe_mkdir "$CACHE_DIR"
    fi

    log_debug "Common library initialized"
}

# Auto-initialize if sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    init_common
fi
