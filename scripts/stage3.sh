#!/bin/bash

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../recon_config.sh" 2>/dev/null || {
    export BASE_DIR="$HOME/recon"
    export DEFAULT_THREADS=25
    export RATE_LIMIT=150
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_critical() { echo -e "${PURPLE}[!!]${NC} ${RED}$1${NC}"; }
log_phase() { echo -e "${MAGENTA}[>>]${NC} ${CYAN}$1${NC}"; }

# Check nuclei
if ! command -v nuclei &> /dev/null; then
    log_error "Nuclei not installed!"
    log_info "Install: go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    exit 1
fi

main() {
    if [ $# -lt 1 ]; then
        log_error "Usage: $0 <work_directory>"
        exit 1
    fi

    WORK_DIR="$1"
    
    if [ ! -d "$WORK_DIR" ]; then
        log_error "Target directory not found: $WORK_DIR"
        exit 1
    fi
    
    VULN_DIR="$WORK_DIR/vulnerability_scan"
    mkdir -p "$VULN_DIR"
    
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}           ${YELLOW}VULNERABILITY ASSESSMENT PHASE${NC}                   ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_info "Target base: ${CYAN}$WORK_DIR${NC}"
    log_info "Results cache: ${CYAN}$VULN_DIR${NC}"
    echo ""
    
    START_TIME=$(date +%s)
    
    # Update templates
    log_phase "Synchronizing vulnerability database..."
    nuclei -update-templates -silent 2>/dev/null || log_warning "Template sync incomplete"
    
    # Determine targets
    TARGET_FILE=""
    if [ -f "$WORK_DIR/all_urls.txt" ] && [ -s "$WORK_DIR/all_urls.txt" ]; then
        TARGET_FILE="$WORK_DIR/all_urls.txt"
        TARGET_COUNT=$(wc -l < "$TARGET_FILE")
        log_success "Target set: ${GREEN}$TARGET_COUNT${NC} URLs loaded"
    elif [ -f "$WORK_DIR/all_alive.txt" ] && [ -s "$WORK_DIR/all_alive.txt" ]; then
        TARGET_FILE="$WORK_DIR/all_alive.txt"
        TARGET_COUNT=$(wc -l < "$TARGET_FILE")
        log_success "Target set: ${GREEN}$TARGET_COUNT${NC} hosts loaded"
    else
        log_error "No viable targets found!"
        log_info "Required: all_urls.txt or all_alive.txt"
        exit 1
    fi
    
    # Template directory
    TEMPLATE_DIR="$HOME/nuclei-templates"
    if [ ! -d "$TEMPLATE_DIR" ]; then
        log_warning "Template directory not found"
        log_phase "Downloading vulnerability templates..."
        nuclei -update-templates
        if [ ! -d "$TEMPLATE_DIR" ]; then
            log_error "Template download failed"
            exit 1
        fi
    fi
    
    log_info "Template source: ${CYAN}$TEMPLATE_DIR${NC}"
    echo ""
    log_warning "Vulnerability scan initiated - ETA: ${YELLOW}20-60 minutes${NC}"
    echo ""
    
    # ═══════════════════════════════════════════════════════════
    # Nuclei Scans - FIXED SYNTAX
    # ═══════════════════════════════════════════════════════════
    
    # Scan 1: Critical/High CVEs
    log_phase "[1/20] Scanning: CVEs (Critical/High severity)"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/cves/" \
        -severity critical,high \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/cves_critical_high.txt" \
        -silent 2>/dev/null || log_warning "Scan completed with warnings"
    
    # Scan 2: All CVEs
    log_phase "[2/20] Scanning: All CVE database"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/cves/" \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/cves_all.txt" \
        -silent 2>/dev/null || true
    
    # Scan 3: Exposed Panels
    log_phase "[3/20] Scanning: Exposed admin panels"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/exposed-panels/" \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/exposed_panels.txt" \
        -silent 2>/dev/null || true
    
    # Scan 4: Misconfigurations
    log_phase "[4/20] Scanning: Security misconfigurations"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/misconfiguration/" \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/misconfigurations.txt" \
        -silent 2>/dev/null || true
    
    # Scan 5: Exposures
    log_phase "[5/20] Scanning: Information exposures"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/exposures/" \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/exposures.txt" \
        -silent 2>/dev/null || true
    
    # Scan 6: Technologies
    log_phase "[6/20] Scanning: Technology fingerprinting"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/technologies/" \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/technologies.txt" \
        -silent 2>/dev/null || true
    
    # Scan 7: Vulnerabilities
    log_phase "[7/20] Scanning: General vulnerabilities"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/vulnerabilities/" \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/vulnerabilities.txt" \
        -silent 2>/dev/null || true
    
    # Scan 8: Default Logins
    log_phase "[8/20] Scanning: Default credentials"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/default-logins/" \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/default_logins.txt" \
        -silent 2>/dev/null || true
    
    # Scan 9: Takeovers
    log_phase "[9/20] Scanning: Subdomain takeovers"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/takeovers/" \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/takeovers.txt" \
        -silent 2>/dev/null || true
    
    # Scan 10: Fuzzing
    log_phase "[10/20] Scanning: Fuzzing templates"
    nuclei -l "$TARGET_FILE" \
        -t "$TEMPLATE_DIR/http/fuzzing/" \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/fuzzing.txt" \
        -silent 2>/dev/null || true
    
    # Tag-based scans
    log_phase "[11/20] Scanning: XSS vulnerabilities"
    nuclei -l "$TARGET_FILE" \
        -tags xss \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/xss.txt" \
        -silent 2>/dev/null || true
    
    log_phase "[12/20] Scanning: SQL injection"
    nuclei -l "$TARGET_FILE" \
        -tags sqli \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/sqli.txt" \
        -silent 2>/dev/null || true
    
    log_phase "[13/20] Scanning: SSRF vulnerabilities"
    nuclei -l "$TARGET_FILE" \
        -tags ssrf \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/ssrf.txt" \
        -silent 2>/dev/null || true
    
    log_phase "[14/20] Scanning: Remote code execution"
    nuclei -l "$TARGET_FILE" \
        -tags rce \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/rce.txt" \
        -silent 2>/dev/null || true
    
    log_phase "[15/20] Scanning: Local file inclusion"
    nuclei -l "$TARGET_FILE" \
        -tags lfi \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/lfi.txt" \
        -silent 2>/dev/null || true
    
    log_phase "[16/20] Scanning: IDOR vulnerabilities"
    nuclei -l "$TARGET_FILE" \
        -tags idor \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/idor.txt" \
        -silent 2>/dev/null || true
    
    log_phase "[17/20] Scanning: Open redirects"
    nuclei -l "$TARGET_FILE" \
        -tags redirect \
        -concurrency ${DEFAULT_THREADS:-25} \
        -rate-limit ${RATE_LIMIT:-150} \
        -o "$VULN_DIR/redirect.txt" \
        -silent 2>/dev/null || true
    
    # Parameter scans
    if [ -f "$WORK_DIR/all_params.txt" ] && [ -s "$WORK_DIR/all_params.txt" ]; then
        log_phase "[18/20] Scanning: Parameterized XSS"
        nuclei -l "$WORK_DIR/all_params.txt" \
            -tags xss \
            -concurrency ${DEFAULT_THREADS:-25} \
            -rate-limit ${RATE_LIMIT:-150} \
            -o "$VULN_DIR/params_xss.txt" \
            -silent 2>/dev/null || true
        
        log_phase "[19/20] Scanning: Parameterized SQLi"
        nuclei -l "$WORK_DIR/all_params.txt" \
            -tags sqli \
            -concurrency ${DEFAULT_THREADS:-25} \
            -rate-limit ${RATE_LIMIT:-150} \
            -o "$VULN_DIR/params_sqli.txt" \
            -silent 2>/dev/null || true
    else
        log_warning "[18/20] Parameter scans skipped (no parameters)"
        log_warning "[19/20] Parameter scans skipped (no parameters)"
    fi
    
    # JavaScript analysis
    if [ -f "$WORK_DIR/all_js.txt" ] && [ -s "$WORK_DIR/all_js.txt" ]; then
        log_phase "[20/20] Scanning: JavaScript analysis"
        nuclei -l "$WORK_DIR/all_js.txt" \
            -tags javascript,exposure \
            -concurrency ${DEFAULT_THREADS:-25} \
            -rate-limit ${RATE_LIMIT:-150} \
            -o "$VULN_DIR/js_analysis.txt" \
            -silent 2>/dev/null || true
    else
        log_warning "[20/20] JavaScript scan skipped (no JS files)"
    fi
    
    # Combine results
    echo ""
    log_phase "Compiling threat intelligence..."
    
    cat "$VULN_DIR"/*.txt 2>/dev/null | sort -u > "$VULN_DIR/nuclei_all_findings.txt"
    
    # Extract critical findings
    grep -iE "(critical|high)" "$VULN_DIR/nuclei_all_findings.txt" > "$VULN_DIR/critical_high_findings.txt" 2>/dev/null || touch "$VULN_DIR/critical_high_findings.txt"
    
    # Summary
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}          ${CYAN}VULNERABILITY ASSESSMENT COMPLETE${NC}                ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    TOTAL_FINDINGS=$(wc -l < "$VULN_DIR/nuclei_all_findings.txt" 2>/dev/null || echo 0)
    CRITICAL_HIGH=$(wc -l < "$VULN_DIR/critical_high_findings.txt" 2>/dev/null || echo 0)
    
    log_success "Assessment duration: ${CYAN}$((DURATION / 60))m $((DURATION % 60))s${NC}"
    log_success "Total findings: ${CYAN}$TOTAL_FINDINGS${NC}"
    
    if [ $CRITICAL_HIGH -gt 0 ]; then
        log_critical "Critical/High severity: ${RED}$CRITICAL_HIGH${NC} ⚠️"
    else
        log_success "Critical/High severity: ${GREEN}0${NC}"
    fi
    
    echo ""
    log_info "Results manifest:"
    log_info "  ${CYAN}•${NC} All findings: ${MAGENTA}$VULN_DIR/nuclei_all_findings.txt${NC}"
    log_info "  ${CYAN}•${NC} Critical/High: ${MAGENTA}$VULN_DIR/critical_high_findings.txt${NC}"
    echo ""
    
    # Show sample findings
    if [ $TOTAL_FINDINGS -gt 0 ]; then
        log_info "Sample discoveries:"
        head -n 5 "$VULN_DIR/nuclei_all_findings.txt" | while read -r line; do
            echo "  ${YELLOW}→${NC} $line"
        done
        if [ $TOTAL_FINDINGS -gt 5 ]; then
            echo "  ${CYAN}...${NC}"
        fi
        echo ""
    fi
    
    # Save metadata
    echo "stage3_complete=$(date)" >> "$WORK_DIR/metadata.txt"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Stage 3 complete - $TOTAL_FINDINGS findings" >> "$WORK_DIR/logs/stage3_complete.log"
    
    log_success "Mission complete - threat assessment archived"
}

main "$@"
