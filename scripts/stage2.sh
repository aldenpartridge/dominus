#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../recon_config.sh" 2>/dev/null || {
    export BASE_DIR="$HOME/recon"
}

# Set default wordlists directory
export WORDLISTS_DIR="${WORDLISTS_DIR:-$BASE_DIR/wordlists}"

# Debug mode (set DEBUG=1 for verbose logging)
export DEBUG="${DEBUG:-0}"

# Colors
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
log_phase() { echo -e "${MAGENTA}[>>]${NC} ${CYAN}$1${NC}"; }
log_debug() { [ "$DEBUG" = "1" ] && echo -e "${CYAN}[DEBUG]${NC} $1" || true; }

check_tool() {
    command -v "$1" >/dev/null 2>&1
}

main() {
    if [ $# -lt 2 ]; then
        log_error "Usage: $0 <domain> <organization_name>"
        exit 1
    fi

    DOMAIN="$1"
    ORG_NAME="$2"
    
    # Sanitize
    DOMAIN=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]' | sed 's/https\?:\/\///' | sed 's/\/$//' | sed 's/[^a-z0-9.-]//g')
    
    if ! echo "$DOMAIN" | grep -qE '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'; then
        log_error "Invalid domain format: $DOMAIN"
        exit 1
    fi
    
    ORG_NAME=$(echo "$ORG_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    
    log_info "Target: ${CYAN}$DOMAIN${NC}"
    log_info "Operation: ${CYAN}$ORG_NAME${NC}"
    
    WORK_DIR="$BASE_DIR/$ORG_NAME"
    
    if [ -d "$WORK_DIR" ]; then
        log_warning "Operation directory exists - continuing..."
    fi
    
    mkdir -p "$WORK_DIR/logs"
    log_success "Base established: $WORK_DIR"
    
    echo "$DOMAIN" > "$WORK_DIR/rootdomain.txt"
    
    {
        echo "scan_date=$(date)"
        echo "domain=$DOMAIN"
        echo "organization=$ORG_NAME"
        echo "base_dir=$WORK_DIR"
    } > "$WORK_DIR/metadata.txt"
    
    START_TIME=$(date +%s)
    
    # ═══════════════════════════════════════════════════════════
    # PHASE 1: Subdomain Enumeration
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}               ${YELLOW}PHASE 1: Subdomain Enumeration${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Subfinder
    if check_tool subfinder; then
        log_phase "Launching subfinder reconnaissance..."
        # Note: Removed -recursive to prevent infinite loops on wildcard DNS
        # -all fetches from all sources, which is sufficient for comprehensive enumeration
        subfinder -d "$DOMAIN" -all -silent -o "$WORK_DIR/.subs_subfinder.txt" 2>/dev/null || true
        if [ -f "$WORK_DIR/.subs_subfinder.txt" ]; then
            COUNT=$(wc -l < "$WORK_DIR/.subs_subfinder.txt")
            log_success "Subfinder: ${GREEN}$COUNT${NC} subdomains identified"
        fi
    fi
    
    # Assetfinder
    if check_tool assetfinder; then
        log_phase "Deploying assetfinder scanner..."
        echo "$DOMAIN" | assetfinder --subs-only > "$WORK_DIR/.subs_assetfinder.txt" 2>/dev/null || true
        if [ -f "$WORK_DIR/.subs_assetfinder.txt" ]; then
            COUNT=$(wc -l < "$WORK_DIR/.subs_assetfinder.txt")
            log_success "Assetfinder: ${GREEN}$COUNT${NC} subdomains discovered"
        fi
    fi
    
    # Findomain
    if check_tool findomain; then
        log_phase "Executing findomain search..."
        findomain -t "$DOMAIN" -u "$WORK_DIR/.subs_findomain.txt" 2>/dev/null || true
        if [ -f "$WORK_DIR/.subs_findomain.txt" ]; then
            COUNT=$(wc -l < "$WORK_DIR/.subs_findomain.txt")
            log_success "Findomain: ${GREEN}$COUNT${NC} subdomains located"
        fi
    fi
    
    # Combine and deduplicate
    log_phase "Aggregating intelligence..."

    # Combine all subdomain files
    cat "$WORK_DIR"/.subs_*.txt 2>/dev/null | sort -u > "$WORK_DIR/all_subs.txt"

    # Ensure root domain is included
    if ! grep -qFx "$DOMAIN" "$WORK_DIR/all_subs.txt" 2>/dev/null; then
        echo "$DOMAIN" >> "$WORK_DIR/all_subs.txt"
        sort -u "$WORK_DIR/all_subs.txt" -o "$WORK_DIR/all_subs.txt"
    fi
    
    SUB_COUNT=$(wc -l < "$WORK_DIR/all_subs.txt" 2>/dev/null || echo "0")
    log_success "Total assets: ${CYAN}$SUB_COUNT${NC} unique subdomains"
    
    rm -f "$WORK_DIR"/.subs_*.txt
    
    # ═══════════════════════════════════════════════════════════
    # PHASE 2: DNS Resolution
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  ${YELLOW}PHASE 2: DNS Resolution${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if check_tool dnsx && [ -f "$WORK_DIR/all_subs.txt" ] && [ -s "$WORK_DIR/all_subs.txt" ]; then
        log_phase "Resolving DNS records..."

        # Try DNS resolution with dnsx
        # Note: -silent mode outputs only resolved domains (one per line)
        dnsx -l "$WORK_DIR/all_subs.txt" \
            -silent \
            -t ${DEFAULT_THREADS:-50} \
            -retry 2 \
            -o "$WORK_DIR/.resolved_raw.txt" 2>"$WORK_DIR/.dnsx_errors.txt" || true

        # With -silent, dnsx outputs just the domain names (no columns)
        # Clean and deduplicate the output
        if [ -f "$WORK_DIR/.resolved_raw.txt" ] && [ -s "$WORK_DIR/.resolved_raw.txt" ]; then
            # Extract first field (handles both single-column and multi-column output)
            awk '{print $1}' "$WORK_DIR/.resolved_raw.txt" | grep -v '^$' | sort -u > "$WORK_DIR/all_resolved.txt"
            rm -f "$WORK_DIR/.resolved_raw.txt"
        else
            touch "$WORK_DIR/all_resolved.txt"
        fi

        RESOLVED_COUNT=$(wc -l < "$WORK_DIR/all_resolved.txt" 2>/dev/null || echo "0")

        if [ $RESOLVED_COUNT -gt 0 ]; then
            log_success "Resolved: ${GREEN}$RESOLVED_COUNT${NC} active hosts"
        else
            # Check if there were errors
            if [ -f "$WORK_DIR/.dnsx_errors.txt" ] && [ -s "$WORK_DIR/.dnsx_errors.txt" ]; then
                log_warning "DNS resolution issues detected (see logs for details)"
                head -3 "$WORK_DIR/.dnsx_errors.txt" | while read line; do
                    log_info "  $line"
                done 2>/dev/null || true
            fi

            # Try with alternative resolvers
            RESOLVERS_FILE="$WORDLISTS_DIR/resolvers.txt"

            if [ -f "$RESOLVERS_FILE" ] && [ -s "$RESOLVERS_FILE" ]; then
                # Use the downloaded resolvers list
                RESOLVER_COUNT=$(wc -l < "$RESOLVERS_FILE")
                log_info "Retrying with resolver list ($RESOLVER_COUNT resolvers from $RESOLVERS_FILE)..."

                dnsx -l "$WORK_DIR/all_subs.txt" \
                    -r "$RESOLVERS_FILE" \
                    -silent \
                    -t ${DEFAULT_THREADS:-50} \
                    -retry 2 \
                    -o "$WORK_DIR/.resolved_retry.txt" 2>/dev/null || true
            else
                # Fall back to public DNS if resolvers.txt doesn't exist
                log_info "Retrying with public DNS resolvers (1.1.1.1, 8.8.8.8)..."
                echo -e "1.1.1.1\n8.8.8.8\n1.0.0.1\n8.8.4.4" > "$WORK_DIR/.fallback_resolvers.txt"

                dnsx -l "$WORK_DIR/all_subs.txt" \
                    -r "$WORK_DIR/.fallback_resolvers.txt" \
                    -silent \
                    -t ${DEFAULT_THREADS:-50} \
                    -retry 2 \
                    -o "$WORK_DIR/.resolved_retry.txt" 2>/dev/null || true

                rm -f "$WORK_DIR/.fallback_resolvers.txt"
            fi

            if [ -f "$WORK_DIR/.resolved_retry.txt" ] && [ -s "$WORK_DIR/.resolved_retry.txt" ]; then
                awk '{print $1}' "$WORK_DIR/.resolved_retry.txt" | sort -u > "$WORK_DIR/all_resolved.txt"
                RESOLVED_COUNT=$(wc -l < "$WORK_DIR/all_resolved.txt")
                log_success "Retry successful: ${GREEN}$RESOLVED_COUNT${NC} hosts resolved"
                rm -f "$WORK_DIR/.resolved_retry.txt"
            else
                log_warning "DNS resolution returned 0 hosts - using all subdomains as fallback"
                log_info "Possible causes: rate limiting, network issues, or invalid subdomains"
                cp "$WORK_DIR/all_subs.txt" "$WORK_DIR/all_resolved.txt"
                RESOLVED_COUNT=$(wc -l < "$WORK_DIR/all_resolved.txt")
                log_info "Fallback: ${CYAN}$RESOLVED_COUNT${NC} hosts to probe"
            fi
        fi

        rm -f "$WORK_DIR/.dnsx_errors.txt"
    else
        log_warning "DNS resolution skipped - using all subdomains"
        cp "$WORK_DIR/all_subs.txt" "$WORK_DIR/all_resolved.txt" 2>/dev/null || touch "$WORK_DIR/all_resolved.txt"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # PHASE 3: HTTP Probing
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                   ${YELLOW}PHASE 3: HTTP Probing${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if check_tool httpx && [ -f "$WORK_DIR/all_resolved.txt" ] && [ -s "$WORK_DIR/all_resolved.txt" ]; then
        log_phase "Probing for live HTTP services..."
        log_debug "Running httpx with tech detection and title extraction"

        # Save full httpx output with metadata for reference
        httpx -l "$WORK_DIR/all_resolved.txt" \
            -silent \
            -t ${HTTPX_THREADS:-50} \
            -timeout 10 \
            -status-code \
            -tech-detect \
            -title \
            -o "$WORK_DIR/all_alive_full.txt" 2>/dev/null || true

        if [ -f "$WORK_DIR/all_alive_full.txt" ] && [ -s "$WORK_DIR/all_alive_full.txt" ]; then
            log_debug "Httpx raw output saved to all_alive_full.txt"

            # Extract clean URLs using httpx json output is more reliable, but for backward compatibility:
            # Match URL at start of line, stop at first space (httpx metadata starts with space)
            # This preserves URLs with brackets: http://example.com/api?param=[value]
            awk '{print $1}' "$WORK_DIR/all_alive_full.txt" | sort -u > "$WORK_DIR/all_alive.txt"

            ALIVE_COUNT=$(wc -l < "$WORK_DIR/all_alive.txt" 2>/dev/null || echo "0")
            log_success "Live targets: ${GREEN}$ALIVE_COUNT${NC} hosts responding"
            log_debug "Clean URLs extracted to all_alive.txt for tool consumption"

            if [ "$DEBUG" = "1" ]; then
                log_debug "Sample URLs:"
                head -3 "$WORK_DIR/all_alive.txt" 2>/dev/null | while read url; do
                    log_debug "  $url"
                done
            fi
        else
            log_warning "Httpx returned no results"
            touch "$WORK_DIR/all_alive.txt"
            touch "$WORK_DIR/all_alive_full.txt"
        fi
    else
        log_warning "HTTP probing skipped"
        touch "$WORK_DIR/all_alive.txt"
        touch "$WORK_DIR/all_alive_full.txt"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # PHASE 4: Port Scanning
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  ${YELLOW}PHASE 4: Port Scanning${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if check_tool naabu && [ -f "$WORK_DIR/all_alive.txt" ] && [ -s "$WORK_DIR/all_alive.txt" ]; then
        log_phase "Scanning for open ports..."
        log_info "Note: httpx already identified ports 80/443; scanning for additional services"

        # Extract hostnames from httpx output (removes http://, https://, paths, and ports)
        # httpx outputs: "http://example.com" or "https://example.com:8443/path"
        # We need: "example.com" (naabu will scan all ports anyway)
        # Handle IPv6 addresses properly: http://[2001:db8::1]:8080/path
        sed -E 's|^https?://||; s|^(\[[^]]+\]).*|\1|; s|:[0-9]+(/.*)?$||; s|/.*||' "$WORK_DIR/all_alive.txt" | \
        sed -E 's|^\[([^]]+)\]$|\1|' | sort -u > "$WORK_DIR/.hosts_for_naabu.txt"

        if [ -s "$WORK_DIR/.hosts_for_naabu.txt" ]; then
            HOST_COUNT=$(wc -l < "$WORK_DIR/.hosts_for_naabu.txt")
            log_info "Scanning $HOST_COUNT unique hosts for open ports (this may take a while)..."

            naabu -l "$WORK_DIR/.hosts_for_naabu.txt" \
                -p - \
                -c ${CONCURRENCY:-25} \
                -rate ${RATE_LIMIT:-150} \
                -silent \
                -o "$WORK_DIR/open_ports.txt" 2>"$WORK_DIR/.naabu_errors.txt" || true

            rm -f "$WORK_DIR/.hosts_for_naabu.txt"

            # Check for capability errors
            if [ -f "$WORK_DIR/.naabu_errors.txt" ] && grep -qi "operation not permitted\|capability" "$WORK_DIR/.naabu_errors.txt" 2>/dev/null; then
                log_warning "naabu requires special capabilities to run"
                log_info "Fix: sudo setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip \$(which naabu)"
            fi
            rm -f "$WORK_DIR/.naabu_errors.txt"

            if [ -f "$WORK_DIR/open_ports.txt" ] && [ -s "$WORK_DIR/open_ports.txt" ]; then
                PORT_COUNT=$(wc -l < "$WORK_DIR/open_ports.txt")
                log_success "Additional ports found: ${GREEN}$PORT_COUNT${NC} non-HTTP services"
            else
                touch "$WORK_DIR/open_ports.txt"
                log_info "No additional ports beyond 80/443 (this is normal for web-only targets)"
            fi
        else
            log_warning "No hosts to scan"
            touch "$WORK_DIR/open_ports.txt"
        fi
    else
        log_warning "Port scanning skipped"
        touch "$WORK_DIR/open_ports.txt"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # PHASE 5: URL Discovery
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  ${YELLOW}PHASE 5: URL Discovery${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Waybackurls
    if check_tool waybackurls && [ -f "$WORK_DIR/all_subs.txt" ] && [ -s "$WORK_DIR/all_subs.txt" ]; then
        log_phase "Mining wayback archives..."
        log_debug "Input: $(wc -l < "$WORK_DIR/all_subs.txt") subdomains"
        cat "$WORK_DIR/all_subs.txt" | waybackurls > "$WORK_DIR/.urls_wayback.txt" 2>/dev/null || true
        [ -f "$WORK_DIR/.urls_wayback.txt" ] && log_debug "Waybackurls: $(wc -l < "$WORK_DIR/.urls_wayback.txt") URLs found"
    else
        log_debug "Waybackurls skipped (tool missing or no subdomains)"
    fi

    # GAU
    if check_tool gau && [ -f "$WORK_DIR/all_subs.txt" ] && [ -s "$WORK_DIR/all_subs.txt" ]; then
        log_phase "Gathering URLs with GAU..."
        log_debug "Input: $(wc -l < "$WORK_DIR/all_subs.txt") subdomains"
        cat "$WORK_DIR/all_subs.txt" | gau --threads ${DEFAULT_THREADS:-10} > "$WORK_DIR/.urls_gau.txt" 2>/dev/null || true
        [ -f "$WORK_DIR/.urls_gau.txt" ] && log_debug "GAU: $(wc -l < "$WORK_DIR/.urls_gau.txt") URLs found"
    else
        log_debug "GAU skipped (tool missing or no subdomains)"
    fi

    # Gauplus
    if check_tool gauplus && [ -f "$WORK_DIR/all_subs.txt" ] && [ -s "$WORK_DIR/all_subs.txt" ]; then
        log_phase "Executing GAU+ enumeration..."
        log_debug "Input: $(wc -l < "$WORK_DIR/all_subs.txt") subdomains"
        cat "$WORK_DIR/all_subs.txt" | gauplus -t ${DEFAULT_THREADS:-10} > "$WORK_DIR/.urls_gauplus.txt" 2>/dev/null || true
        [ -f "$WORK_DIR/.urls_gauplus.txt" ] && log_debug "GAU+: $(wc -l < "$WORK_DIR/.urls_gauplus.txt") URLs found"
    else
        log_debug "GAU+ skipped (tool missing or no subdomains)"
    fi

    # Katana
    if check_tool katana && [ -f "$WORK_DIR/all_alive.txt" ] && [ -s "$WORK_DIR/all_alive.txt" ]; then
        log_phase "Deploying Katana crawler..."
        log_debug "Input: $(wc -l < "$WORK_DIR/all_alive.txt") live URLs"
        if [ "$DEBUG" = "1" ]; then
            log_debug "Sample input URLs for Katana:"
            head -2 "$WORK_DIR/all_alive.txt" | while read url; do
                log_debug "  $url"
            done
        fi
        katana -list "$WORK_DIR/all_alive.txt" \
            -d 3 \
            -jc \
            -fx \
            -ef woff,woff2,css,png,svg,jpg,jpeg,gif,ico,ttf,eot \
            -silent \
            -o "$WORK_DIR/.urls_katana.txt" 2>/dev/null || true
        [ -f "$WORK_DIR/.urls_katana.txt" ] && log_debug "Katana: $(wc -l < "$WORK_DIR/.urls_katana.txt") URLs found"
    else
        log_debug "Katana skipped (tool missing or no live hosts)"
    fi

    # Hakrawler
    if check_tool hakrawler && [ -f "$WORK_DIR/all_alive.txt" ] && [ -s "$WORK_DIR/all_alive.txt" ]; then
        log_phase "Running hakrawler spider..."
        log_debug "Input: $(wc -l < "$WORK_DIR/all_alive.txt") live URLs"
        cat "$WORK_DIR/all_alive.txt" | hakrawler -depth 3 -plain > "$WORK_DIR/.urls_hakrawler.txt" 2>/dev/null || true
        [ -f "$WORK_DIR/.urls_hakrawler.txt" ] && log_debug "Hakrawler: $(wc -l < "$WORK_DIR/.urls_hakrawler.txt") URLs found"
    else
        log_debug "Hakrawler skipped (tool missing or no live hosts)"
    fi
    
    # Combine
    log_phase "Consolidating URL intelligence..."

    # Debug: Show which URL files were created
    if [ "$DEBUG" = "1" ]; then
        log_debug "URL sources created:"
        for f in "$WORK_DIR"/.urls_*.txt; do
            if [ -f "$f" ]; then
                COUNT=$(wc -l < "$f" 2>/dev/null || echo "0")
                log_debug "  $(basename "$f"): $COUNT URLs"
            fi
        done
    fi

    cat "$WORK_DIR"/.urls_*.txt 2>/dev/null | sort -u > "$WORK_DIR/.all_urls_raw.txt"
    RAW_COUNT=$(wc -l < "$WORK_DIR/.all_urls_raw.txt" 2>/dev/null || echo "0")
    log_debug "Combined raw URLs: $RAW_COUNT (before deduplication)"

    if check_tool uro && [ -f "$WORK_DIR/.all_urls_raw.txt" ] && [ -s "$WORK_DIR/.all_urls_raw.txt" ]; then
        log_debug "Applying uro deduplication"
        cat "$WORK_DIR/.all_urls_raw.txt" | uro > "$WORK_DIR/all_urls.txt" 2>/dev/null || \
        cp "$WORK_DIR/.all_urls_raw.txt" "$WORK_DIR/all_urls.txt"
    else
        log_debug "Uro not available, using raw URLs"
        cp "$WORK_DIR/.all_urls_raw.txt" "$WORK_DIR/all_urls.txt" 2>/dev/null || touch "$WORK_DIR/all_urls.txt"
    fi

    URL_COUNT=$(wc -l < "$WORK_DIR/all_urls.txt" 2>/dev/null || echo "0")
    log_success "URLs extracted: ${CYAN}$URL_COUNT${NC} unique endpoints"

    rm -f "$WORK_DIR"/.urls_*.txt "$WORK_DIR/.all_urls_raw.txt"
    
    # ═══════════════════════════════════════════════════════════
    # PHASE 6: Parameter Discovery
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}PHASE 6: Parameter Discovery${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -f "$WORK_DIR/all_urls.txt" ] && [ -s "$WORK_DIR/all_urls.txt" ]; then
        log_phase "Extracting parameterized URLs..."
        grep -E '\?' "$WORK_DIR/all_urls.txt" > "$WORK_DIR/all_params.txt" 2>/dev/null || touch "$WORK_DIR/all_params.txt"
        PARAM_COUNT=$(wc -l < "$WORK_DIR/all_params.txt")
        log_success "Parameters found: ${GREEN}$PARAM_COUNT${NC} potential injection points"
    else
        touch "$WORK_DIR/all_params.txt"
        log_info "No URLs available for parameter extraction"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # PHASE 7: JavaScript Discovery
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}             ${YELLOW}PHASE 7: JavaScript Discovery${NC}                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -f "$WORK_DIR/all_urls.txt" ] && [ -s "$WORK_DIR/all_urls.txt" ]; then
        log_debug "Extracting .js files from $(wc -l < "$WORK_DIR/all_urls.txt") URLs"
        # Match .js files but exclude .json
        # Handles: .js, .js?, .js#, .js;jsessionid, etc.
        # Excludes: .json, .jsonp
        grep -iE '\.js([?#;]|$)' "$WORK_DIR/all_urls.txt" | grep -viE '\.json[p]?([?#;]|$)' > "$WORK_DIR/all_js.txt" 2>/dev/null || touch "$WORK_DIR/all_js.txt"
        [ -s "$WORK_DIR/all_js.txt" ] && log_debug "Found $(wc -l < "$WORK_DIR/all_js.txt") .js files in URLs"
    else
        log_debug "No URLs available for JS extraction"
        touch "$WORK_DIR/all_js.txt"
    fi

    # Subjs
    if check_tool subjs && [ -f "$WORK_DIR/all_subs.txt" ] && [ -s "$WORK_DIR/all_subs.txt" ]; then
        log_phase "Hunting JavaScript files..."
        log_debug "Input: $(wc -l < "$WORK_DIR/all_subs.txt") subdomains"
        cat "$WORK_DIR/all_subs.txt" | subjs >> "$WORK_DIR/all_js.txt" 2>/dev/null || true
    else
        log_debug "Subjs skipped (tool missing or no subdomains)"
    fi

    # GetJS
    if check_tool getJS && [ -f "$WORK_DIR/all_alive.txt" ] && [ -s "$WORK_DIR/all_alive.txt" ]; then
        log_phase "Extracting JavaScript assets..."
        log_debug "Input: $(wc -l < "$WORK_DIR/all_alive.txt") live URLs"
        if [ "$DEBUG" = "1" ]; then
            log_debug "Sample input URLs for getJS:"
            head -2 "$WORK_DIR/all_alive.txt" | while read url; do
                log_debug "  $url"
            done
        fi
        getJS --input "$WORK_DIR/all_alive.txt" --complete >> "$WORK_DIR/all_js.txt" 2>/dev/null || true
    else
        log_debug "getJS skipped (tool missing or no live hosts)"
    fi

    if [ -f "$WORK_DIR/all_js.txt" ]; then
        sort -u "$WORK_DIR/all_js.txt" -o "$WORK_DIR/all_js.txt"
        JS_COUNT=$(wc -l < "$WORK_DIR/all_js.txt")
        log_success "JavaScript files: ${GREEN}$JS_COUNT${NC} sources identified"
        log_debug "Deduplicated JS files saved"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # PHASE 8: Sensitive File Discovery
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${YELLOW}PHASE 8: Sensitive File Discovery${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -f "$WORK_DIR/all_urls.txt" ] && [ -s "$WORK_DIR/all_urls.txt" ]; then
        log_phase "Scanning for sensitive exposures..."
        grep -iE '\.(env|config|backup|bak|sql|db|log|zip|tar\.gz|rar|old|swp|~)(\?|$)' \
            "$WORK_DIR/all_urls.txt" > "$WORK_DIR/sensitive_files.txt" 2>/dev/null || touch "$WORK_DIR/sensitive_files.txt"
        
        SENSITIVE_COUNT=$(wc -l < "$WORK_DIR/sensitive_files.txt")
        if [ $SENSITIVE_COUNT -gt 0 ]; then
            log_success "Sensitive files: ${YELLOW}$SENSITIVE_COUNT${NC} potential exposures detected"
        else
            log_info "No sensitive files detected"
        fi
    else
        touch "$WORK_DIR/sensitive_files.txt"
        log_info "No URLs to scan for sensitive files"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # Summary
    # ═══════════════════════════════════════════════════════════
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}              ${CYAN}RECONNAISSANCE PHASE COMPLETE${NC}                 ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Mission duration: ${CYAN}$((DURATION / 60))m $((DURATION % 60))s${NC}"
    log_success "Subdomains: ${CYAN}$(wc -l < "$WORK_DIR/all_subs.txt" 2>/dev/null || echo 0)${NC}"
    log_success "Live hosts: ${CYAN}$(wc -l < "$WORK_DIR/all_alive.txt" 2>/dev/null || echo 0)${NC}"
    log_success "URLs: ${CYAN}$(wc -l < "$WORK_DIR/all_urls.txt" 2>/dev/null || echo 0)${NC}"
    log_success "JavaScript: ${CYAN}$(wc -l < "$WORK_DIR/all_js.txt" 2>/dev/null || echo 0)${NC}"
    log_success "Parameters: ${CYAN}$(wc -l < "$WORK_DIR/all_params.txt" 2>/dev/null || echo 0)${NC}"
    echo ""
    log_success "Intelligence archived: ${MAGENTA}$WORK_DIR${NC}"
    
    echo "stage2_complete=$(date)" >> "$WORK_DIR/metadata.txt"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Stage 2 complete" >> "$WORK_DIR/logs/stage2_complete.log"
    
    # Auto-launch Stage 3
    STAGE3_SCRIPT="$SCRIPT_DIR/stage3.sh"
    if [ -f "$STAGE3_SCRIPT" ]; then
        if [ -s "$WORK_DIR/all_urls.txt" ] || [ -s "$WORK_DIR/all_alive.txt" ]; then
            echo ""
            log_info "Initiating vulnerability assessment phase..."
            sleep 2
            bash "$STAGE3_SCRIPT" "$WORK_DIR"
        else
            log_warning "No targets for vulnerability scanning - mission incomplete"
            log_info "Check DNS resolution: cat $WORK_DIR/all_resolved.txt"
        fi
    fi
}

main "$@"
