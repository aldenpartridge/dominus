#!/bin/bash

# DOMINUS - Bug Bounty Recon Suite v2.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
if [ -f "$SCRIPT_DIR/recon_config.sh" ]; then
    source "$SCRIPT_DIR/recon_config.sh"
fi

# Source libraries
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/notifications.sh"
source "$SCRIPT_DIR/lib/resume.sh"
source "$SCRIPT_DIR/lib/output.sh"

# ASCII Art Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
██████╗  ██████╗ ███╗   ███╗██╗███╗   ██╗██╗   ██╗███████╗
██╔══██╗██╔═══██╗████╗ ████║██║████╗  ██║██║   ██║██╔════╝
██║  ██║██║   ██║██╔████╔██║██║██╔██╗ ██║██║   ██║███████╗
██║  ██║██║   ██║██║╚██╔╝██║██║██║╚██╗██║██║   ██║╚════██║
██████╔╝╚██████╔╝██║ ╚═╝ ██║██║██║ ╚████║╚██████╔╝███████║
╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}          ${GREEN}Automated Bug Bounty Reconnaissance Suite${NC}            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}                     ${CYAN}Version 2.0${NC}                              ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}                    ${CYAN}Select Operation${NC}                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}1)${NC} Verify Tools & Environment                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}2)${NC} Execute Full Reconnaissance Pipeline                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}3)${NC} Test Notification Systems                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}4)${NC} Clear Cache                                             ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}5)${NC} View Configuration                                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}6)${NC} Download All Bug Bounty Scopes (Chaos)                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                     ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

run_stage1() {
    log_info "Initiating tool verification..."
    echo ""

    if [ -f "$SCRIPT_DIR/scripts/stage1.sh" ]; then
        bash "$SCRIPT_DIR/scripts/stage1.sh"
    else
        log_error "Stage 1 script not found"
        return 1
    fi
}

run_full_pipeline() {
    log_info "Initiating full reconnaissance pipeline..."
    echo ""

    print_separator
    echo -e "${YELLOW}║${NC}                    ${CYAN}Target Acquisition${NC}                       ${YELLOW}║${NC}"
    print_separator_end
    echo ""

    # Get domain input
    read -p "$(echo -e ${GREEN}[+]${NC} Enter target domain: )" domain

    # Validate domain
    if ! validate_domain "$domain"; then
        return 1
    fi

    # Get operation name
    read -p "$(echo -e ${GREEN}[+]${NC} Enter operation name: )" org_name

    # Sanitize organization name
    org_name=$(sanitize_org_name "$org_name")

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}Target:${NC} ${GREEN}$domain${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}Operation:${NC} ${GREEN}$org_name${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Legal warning and authorization
    if ! confirm_authorization "$domain"; then
        return 1
    fi

    # Export variables for child scripts
    export DOMAIN="$domain"
    export ORG_NAME="$org_name"

    # Execute stage 2
    if [ -f "$SCRIPT_DIR/scripts/stage2.sh" ]; then
        bash "$SCRIPT_DIR/scripts/stage2.sh" "$domain" "$org_name"
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log_success "Reconnaissance pipeline completed successfully"
        else
            log_error "Reconnaissance pipeline failed with exit code: $exit_code"
        fi

        return $exit_code
    else
        log_error "Stage 2 script not found"
        return 1
    fi
}

test_notifications() {
    log_info "Testing notification systems..."
    echo ""

    if [ "$ENABLE_NOTIFICATIONS" != "true" ]; then
        log_warning "Notifications are disabled in configuration"
        log_info "Set ENABLE_NOTIFICATIONS=true in recon_config.sh"
        return 1
    fi

    test_notifications
}

clear_cache_menu() {
    log_warning "This will clear all cached data"
    read -p "$(echo -e ${YELLOW}Are you sure? \(y/n\): ${NC})" confirm

    if [ "$confirm" = "y" ]; then
        clear_cache
    else
        log_info "Cache clear cancelled"
    fi
}

view_configuration() {
    print_header "Current Configuration"

    echo -e "${CYAN}Base Settings:${NC}"
    echo -e "  BASE_DIR: ${GREEN}${BASE_DIR}${NC}"
    echo -e "  WORDLISTS_DIR: ${GREEN}${WORDLISTS_DIR}${NC}"
    echo ""

    echo -e "${CYAN}Performance:${NC}"
    echo -e "  DEFAULT_THREADS: ${GREEN}${DEFAULT_THREADS}${NC}"
    echo -e "  HTTPX_THREADS: ${GREEN}${HTTPX_THREADS}${NC}"
    echo -e "  CONCURRENCY: ${GREEN}${CONCURRENCY}${NC}"
    echo -e "  RATE_LIMIT: ${GREEN}${RATE_LIMIT}${NC}"
    echo ""

    echo -e "${CYAN}Features:${NC}"
    echo -e "  ENABLE_RESUME: ${GREEN}${ENABLE_RESUME:-true}${NC}"
    echo -e "  ENABLE_NOTIFICATIONS: ${GREEN}${ENABLE_NOTIFICATIONS:-false}${NC}"
    echo -e "  ENABLE_JSON: ${GREEN}${ENABLE_JSON:-true}${NC}"
    echo -e "  ENABLE_CACHE: ${GREEN}${ENABLE_CACHE:-true}${NC}"
    echo -e "  DRY_RUN: ${GREEN}${DRY_RUN:-false}${NC}"
    echo -e "  DEBUG: ${GREEN}${DEBUG:-0}${NC} ${YELLOW}(set DEBUG=1 for verbose logging)${NC}"
    echo ""

    echo -e "${CYAN}Notifications:${NC}"
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        echo -e "  Telegram: ${GREEN}Configured${NC}"
    else
        echo -e "  Telegram: ${YELLOW}Not configured${NC}"
    fi

    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        echo -e "  Slack: ${GREEN}Configured${NC}"
    else
        echo -e "  Slack: ${YELLOW}Not configured${NC}"
    fi

    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
        echo -e "  Discord: ${GREEN}Configured${NC}"
    else
        echo -e "  Discord: ${YELLOW}Not configured${NC}"
    fi

    echo ""
    echo -e "${CYAN}Configuration file:${NC}"
    if [ -f "$SCRIPT_DIR/recon_config.sh" ]; then
        echo -e "  ${GREEN}$SCRIPT_DIR/recon_config.sh${NC}"
    else
        echo -e "  ${YELLOW}Not found (using defaults)${NC}"
        echo -e "  ${BLUE}Tip: Copy recon_config.sh.example to recon_config.sh${NC}"
    fi

    echo ""
}

# Helper function to download a single program (used by parallel execution)
download_single_program() {
    local program="$1"
    local output_dir="$2"
    local stats_dir="$3"

    local name=$(echo "$program" | jq -r '.name')
    local url=$(echo "$program" | jq -r '.URL')
    local count=$(echo "$program" | jq -r '.count')

    # Skip if no URL or 0 domains
    if [ "$url" = "null" ] || [ -z "$url" ] || [ "$count" = "0" ]; then
        echo "skipped" >> "$stats_dir/skipped.count"
        return 0
    fi

    # Sanitize program name for directory
    local dir_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
    local program_dir="$output_dir/$dir_name"
    local zip_file="$program_dir/$dir_name.zip"

    # Check if already downloaded
    if [ -d "$program_dir" ] && [ -n "$(ls -A $program_dir 2>/dev/null)" ]; then
        echo "skipped" >> "$stats_dir/skipped.count"
        return 0
    fi

    # Create program directory
    mkdir -p "$program_dir"

    # Download with retry logic
    local download_success=0
    for attempt in 1 2; do
        if command -v curl &>/dev/null; then
            curl -L -s --max-time 30 "$url" -o "$zip_file" 2>/dev/null && download_success=1 && break
        elif command -v wget &>/dev/null; then
            wget -q -T 30 "$url" -O "$zip_file" 2>/dev/null && download_success=1 && break
        fi
        sleep 1
    done

    # Verify download
    if [ $download_success -eq 0 ] || [ ! -f "$zip_file" ] || [ ! -s "$zip_file" ]; then
        echo "failed" >> "$stats_dir/failed.count"
        rm -rf "$program_dir"
        return 1
    fi

    echo "downloaded" >> "$stats_dir/downloaded.count"

    # Extract if unzip available
    if command -v unzip &>/dev/null; then
        if unzip -q -o "$zip_file" -d "$program_dir" 2>/dev/null; then
            rm -f "$zip_file"  # Remove zip after extraction
            echo "extracted" >> "$stats_dir/extracted.count"
        fi
    fi

    return 0
}

# Export function for parallel to use
export -f download_single_program

download_all_chaos_scopes() {
    log_phase "Bulk Download Bug Bounty Scopes from Chaos"

    # Check prerequisites
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for this feature"
        log_info "Install: sudo pacman -S jq  # or sudo apt install jq"
        return 1
    fi

    if ! command -v unzip &>/dev/null; then
        log_warning "unzip not found - scopes will be downloaded but not extracted"
        log_info "Install: sudo pacman -S unzip  # or sudo apt install unzip"
    fi

    # Define output directory
    local output_dir="$SCRIPT_DIR/subdomains"

    # Determine parallel execution method
    local parallel_method="sequential"
    local parallel_jobs=10  # Default: 10 concurrent downloads

    if command -v parallel &>/dev/null; then
        parallel_method="gnu_parallel"
        log_info "GNU Parallel detected - will use parallel downloads (10x faster!)"
    elif command -v xargs &>/dev/null; then
        # Test if xargs supports -P flag
        if echo "test" | xargs -P 2 echo &>/dev/null 2>&1; then
            parallel_method="xargs"
            log_info "xargs -P detected - will use parallel downloads (5x faster!)"
        fi
    fi

    echo ""
    log_info "This will download ALL bug bounty program scopes from Chaos"
    log_info "Output directory: $output_dir"
    log_info "Download method: $parallel_method"
    echo ""

    read -p "$(echo -e ${YELLOW}Filter by bounty programs only? \(y/n\): ${NC})" bounty_only
    echo ""

    # Ask about parallel jobs if using parallel method
    if [ "$parallel_method" != "sequential" ]; then
        read -p "$(echo -e ${YELLOW}Number of parallel downloads? \(default: 10\): ${NC})" user_jobs
        [ -n "$user_jobs" ] && parallel_jobs="$user_jobs"
        echo ""
    fi

    # Fetch program list
    local chaos_index="https://chaos-data.projectdiscovery.io/index.json"
    local temp_index="/tmp/chaos_index_$$.json"

    log_info "Fetching program list from Chaos..."

    if command -v curl &>/dev/null; then
        curl -s "$chaos_index" -o "$temp_index"
    elif command -v wget &>/dev/null; then
        wget -q "$chaos_index" -O "$temp_index"
    else
        log_error "Neither curl nor wget found"
        return 1
    fi

    if [ ! -s "$temp_index" ]; then
        log_error "Failed to fetch program list"
        rm -f "$temp_index"
        return 1
    fi

    # Filter programs - use -c for compact JSON (one object per line)
    local programs_json
    if [ "$bounty_only" = "y" ] || [ "$bounty_only" = "yes" ]; then
        programs_json=$(jq -c '.[] | select(.bounty == true)' "$temp_index")
        local total=$(echo "$programs_json" | wc -l)
        log_success "Found $total programs with bounties"
    else
        programs_json=$(jq -c '.[]' "$temp_index")
        local total=$(echo "$programs_json" | wc -l)
        log_success "Found $total total programs"
    fi

    # Confirm download
    local total_count=$(echo "$programs_json" | wc -l)
    echo ""
    log_warning "About to download $total_count programs"
    log_info "This may take some time and bandwidth"
    echo ""
    read -p "$(echo -e ${YELLOW}Continue? \(y/n\): ${NC})" confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "yes" ]; then
        log_info "Download cancelled"
        rm -f "$temp_index"
        return 0
    fi

    echo ""
    log_phase "Starting Bulk Download (${parallel_method}, ${parallel_jobs} parallel jobs)"

    # Create output directory and stats directory
    mkdir -p "$output_dir"
    local stats_dir="/tmp/chaos_stats_$$"
    mkdir -p "$stats_dir"

    # Initialize stat files
    : > "$stats_dir/downloaded.count"
    : > "$stats_dir/extracted.count"
    : > "$stats_dir/failed.count"
    : > "$stats_dir/skipped.count"

    local start_time=$(date +%s)

    # Execute downloads based on available method
    if [ "$parallel_method" = "gnu_parallel" ]; then
        # GNU Parallel - best performance
        echo "$programs_json" | parallel -j "$parallel_jobs" --bar download_single_program {} "$output_dir" "$stats_dir"
    elif [ "$parallel_method" = "xargs" ]; then
        # xargs -P - good fallback
        echo "$programs_json" | xargs -P "$parallel_jobs" -I {} bash -c "download_single_program '{}' '$output_dir' '$stats_dir'"
    else
        # Sequential fallback
        log_warning "No parallel tool found - using sequential download"
        local current=0
        echo "$programs_json" | while IFS= read -r program; do
            ((current++))
            echo -ne "\r[*] Progress: $current/$total_count"
            download_single_program "$program" "$output_dir" "$stats_dir"
        done
        echo ""
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Collect statistics
    local downloaded=$(wc -l < "$stats_dir/downloaded.count" 2>/dev/null || echo 0)
    local extracted=$(wc -l < "$stats_dir/extracted.count" 2>/dev/null || echo 0)
    local failed=$(wc -l < "$stats_dir/failed.count" 2>/dev/null || echo 0)
    local skipped=$(wc -l < "$stats_dir/skipped.count" 2>/dev/null || echo 0)

    # Cleanup
    rm -rf "$stats_dir"
    rm -f "$temp_index"

    echo ""
    log_phase "Download Complete"
    echo ""
    log_success "Downloaded: $downloaded programs"
    if command -v unzip &>/dev/null; then
        log_success "Extracted: $extracted programs"
    fi
    log_info "Skipped: $skipped programs (already exist or no data)"
    if [ $failed -gt 0 ]; then
        log_error "Failed: $failed programs"
    fi
    log_info "Time taken: ${duration}s"
    if [ $downloaded -gt 0 ] && [ $duration -gt 0 ]; then
        local rate=$((downloaded / duration))
        log_info "Download rate: ~${rate} programs/second"
    fi
    echo ""
    log_info "Output directory: $output_dir"
    echo ""

    # Show some stats about downloaded scopes
    if [ -d "$output_dir" ]; then
        local program_count=$(find "$output_dir" -maxdepth 1 -type d 2>/dev/null | wc -l)
        program_count=$((program_count - 1))  # Subtract the parent directory

        log_info "Total programs on disk: $program_count"

        # Count total domain files
        local total_files=$(find "$output_dir" -type f \( -name "*.txt" -o -name "*.list" \) 2>/dev/null | wc -l)
        log_info "Total scope files: $total_files"
        echo ""
    fi
}

main() {
    show_banner
    show_menu

    read -p "$(echo -e ${CYAN}[>]${NC} Select operation \(0-6\): )" choice
    echo ""

    case $choice in
        1)
            run_stage1
            ;;
        2)
            run_full_pipeline
            ;;
        3)
            test_notifications
            ;;
        4)
            clear_cache_menu
            ;;
        5)
            view_configuration
            ;;
        6)
            download_all_chaos_scopes
            ;;
        0)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid selection"
            exit 1
            ;;
    esac

    echo ""
    log_success "Operation complete"
    exit 0
}

main
