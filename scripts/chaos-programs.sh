#!/bin/bash

# TROXXER - Chaos Bug Bounty Programs Helper
# Fetches and displays available bug bounty programs from ProjectDiscovery's public Chaos data
# No API key required!

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to source common library for better logging
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
    source "$SCRIPT_DIR/../lib/common.sh"
else
    # Fallback logging functions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'

    log_info() { echo -e "${BLUE}[*]${NC} $1"; }
    log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
    log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
    log_error() { echo -e "${RED}[✗]${NC} $1"; }
fi

# Chaos API endpoints
CHAOS_INDEX="https://chaos-data.projectdiscovery.io/index.json"
CACHE_DIR="${BASE_DIR:-.}/.chaos-cache"
CACHE_FILE="$CACHE_DIR/programs.json"
CACHE_TTL=86400  # 24 hours

# Create cache directory
mkdir -p "$CACHE_DIR"

# Fetch programs from Chaos API
fetch_programs() {
    log_info "Fetching bug bounty programs from ProjectDiscovery Chaos..."

    if command -v curl &>/dev/null; then
        curl -s "$CHAOS_INDEX" -o "$CACHE_FILE"
    elif command -v wget &>/dev/null; then
        wget -q "$CHAOS_INDEX" -O "$CACHE_FILE"
    else
        log_error "Neither curl nor wget found. Please install one of them."
        return 1
    fi

    if [ $? -eq 0 ] && [ -s "$CACHE_FILE" ]; then
        log_success "Fetched $(count_programs) programs"
        return 0
    else
        log_error "Failed to fetch programs from Chaos API"
        return 1
    fi
}

# Check if cache is valid
is_cache_valid() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi

    local file_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo "0")))
    if [ $file_age -lt $CACHE_TTL ]; then
        return 0
    else
        return 1
    fi
}

# Count programs
count_programs() {
    if [ -f "$CACHE_FILE" ] && command -v jq &>/dev/null; then
        jq 'length' "$CACHE_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# List all programs
list_programs() {
    local filter="${1:-all}"  # all, bounty, platform

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for this feature. Install it first."
        echo "  Install: sudo pacman -S jq  # or sudo apt install jq"
        return 1
    fi

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${YELLOW}ProjectDiscovery Chaos Bug Bounty Programs${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    case "$filter" in
        bounty)
            log_info "Showing only programs with bounties..."
            jq -r '.[] | select(.bounty == true) | "\(.name) - \(.platform) - \(.count) domains"' "$CACHE_FILE" | nl
            ;;
        platform)
            local platform="$2"
            log_info "Showing programs on $platform..."
            jq -r ".[] | select(.platform == \"$platform\") | \"\(.name) - \(.count) domains\"" "$CACHE_FILE" | nl
            ;;
        *)
            log_info "Showing all programs..."
            jq -r '.[] | "\(.name) - \(.platform) - \(.count) domains - Bounty: \(.bounty)"' "$CACHE_FILE" | nl
            ;;
    esac

    echo ""
}

# Search programs
search_programs() {
    local query="$1"

    if [ -z "$query" ]; then
        log_error "Please provide a search query"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for this feature"
        return 1
    fi

    log_info "Searching for: $query"
    echo ""

    jq -r ".[] | select(.name | ascii_downcase | contains(\"${query,,}\")) | \"\(.name) - \(.platform) - \(.count) domains - \(.program_url)\"" "$CACHE_FILE"
    echo ""
}

# Get program details
get_program_details() {
    local program_name="$1"

    if [ -z "$program_name" ]; then
        log_error "Please provide a program name"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for this feature"
        return 1
    fi

    local details=$(jq -r ".[] | select(.name | ascii_downcase == \"${program_name,,}\")" "$CACHE_FILE")

    if [ -z "$details" ]; then
        log_error "Program not found: $program_name"
        return 1
    fi

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}Program Details${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo "$details" | jq -r '
        "Name: \(.name)",
        "Platform: \(.platform)",
        "Bounty: \(.bounty)",
        "Domain Count: \(.count)",
        "Program URL: \(.program_url)",
        "Download URL: \(.URL)",
        "Last Updated: \(.last_updated)",
        "Is New: \(.is_new)"
    '

    echo ""
}

# Download program scope
download_scope() {
    local program_name="$1"
    local output_dir="${2:-.}"

    if [ -z "$program_name" ]; then
        log_error "Please provide a program name"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for this feature"
        return 1
    fi

    local download_url=$(jq -r ".[] | select(.name | ascii_downcase == \"${program_name,,}\") | .URL" "$CACHE_FILE")

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        log_error "Program not found: $program_name"
        return 1
    fi

    log_info "Downloading scope for: $program_name"
    log_info "URL: $download_url"

    local filename="${program_name,,}.zip"
    local filepath="$output_dir/$filename"

    if command -v curl &>/dev/null; then
        curl -L "$download_url" -o "$filepath"
    elif command -v wget &>/dev/null; then
        wget "$download_url" -O "$filepath"
    else
        log_error "Neither curl nor wget found"
        return 1
    fi

    if [ $? -eq 0 ] && [ -s "$filepath" ]; then
        log_success "Downloaded to: $filepath"

        # Optionally extract
        if command -v unzip &>/dev/null; then
            read -p "$(echo -e ${YELLOW}Extract now? \(y/n\): ${NC})" extract
            if [ "$extract" = "y" ]; then
                unzip -o "$filepath" -d "$output_dir/${program_name,,}"
                log_success "Extracted to: $output_dir/${program_name,,}/"
            fi
        fi

        return 0
    else
        log_error "Download failed"
        return 1
    fi
}

# Show statistics
show_stats() {
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for this feature"
        return 1
    fi

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  ${YELLOW}Chaos Data Statistics${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total=$(jq 'length' "$CACHE_FILE")
    local with_bounty=$(jq '[.[] | select(.bounty == true)] | length' "$CACHE_FILE")
    local hackerone=$(jq '[.[] | select(.platform == "hackerone")] | length' "$CACHE_FILE")
    local bugcrowd=$(jq '[.[] | select(.platform == "bugcrowd")] | length' "$CACHE_FILE")
    local intigriti=$(jq '[.[] | select(.platform == "intigriti")] | length' "$CACHE_FILE")
    local yeswehack=$(jq '[.[] | select(.platform == "yeswehack")] | length' "$CACHE_FILE")
    local hackenproof=$(jq '[.[] | select(.platform == "hackenproof")] | length' "$CACHE_FILE")
    local total_domains=$(jq '[.[] | .count] | add' "$CACHE_FILE")

    echo -e "${GREEN}Total Programs:${NC} $total"
    echo -e "${GREEN}With Bounties:${NC} $with_bounty"
    echo -e "${GREEN}Total Domains:${NC} $total_domains"
    echo ""
    echo -e "${YELLOW}By Platform:${NC}"
    echo -e "  HackerOne: $hackerone"
    echo -e "  Bugcrowd: $bugcrowd"
    echo -e "  Intigriti: $intigriti"
    echo -e "  YesWeHack: $yeswehack"
    echo -e "  HackenProof: $hackenproof"
    echo ""
}

# Show help
show_help() {
    cat << EOF
TROXXER Chaos Programs Helper

Usage: $0 [command] [options]

Commands:
  list [filter]              List all programs
                            Filters: all (default), bounty, platform <name>

  search <query>            Search for programs by name

  details <program>         Show detailed information about a program

  download <program> [dir]  Download program scope (zip file)
                            Optionally specify output directory

  stats                     Show statistics about available programs

  update                    Force update the program cache

  help                      Show this help message

Examples:
  $0 list                   # List all programs
  $0 list bounty            # List only programs with bounties
  $0 search google          # Search for programs containing "google"
  $0 details hackerone      # Show details for HackerOne program
  $0 download uber          # Download Uber program scope
  $0 stats                  # Show statistics

Note: No API key required! All data is publicly available from:
https://chaos-data.projectdiscovery.io/

Requirements: jq (for parsing JSON)
Install: sudo pacman -S jq  # or sudo apt install jq

EOF
}

# Main function
main() {
    local command="${1:-list}"

    # Update cache if needed
    if ! is_cache_valid; then
        fetch_programs || exit 1
    else
        log_info "Using cached data (updated within 24h)"
    fi

    case "$command" in
        list)
            list_programs "$2" "$3"
            ;;
        search)
            search_programs "$2"
            ;;
        details)
            get_program_details "$2"
            ;;
        download)
            download_scope "$2" "$3"
            ;;
        stats)
            show_stats
            ;;
        update)
            fetch_programs
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
