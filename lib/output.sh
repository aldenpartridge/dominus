#!/bin/bash

# Output formatting for DOMINUS
# Supports: JSON, Markdown, HTML, CSV

# Source common library if not already loaded
if [ -z "$GREEN" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "$SCRIPT_DIR/lib/common.sh"
fi

# ============================================================================
# JSON OUTPUT
# ============================================================================

# Generate JSON report
generate_json_report() {
    local work_dir="${1:-$WORK_DIR}"
    local output_file="$work_dir/report.json"

    if [ "$ENABLE_JSON" != "true" ]; then
        log_debug "JSON output disabled"
        return 0
    fi

    log_info "Generating JSON report..."

    # Count findings
    local subdomains=$(count_lines "$work_dir/all_subs.txt")
    local resolved=$(count_lines "$work_dir/all_resolved.txt")
    local alive=$(count_lines "$work_dir/all_alive.txt")
    local ports=$(count_lines "$work_dir/open_ports.txt")
    local urls=$(count_lines "$work_dir/all_urls.txt")
    local params=$(count_lines "$work_dir/all_params.txt")
    local js_files=$(count_lines "$work_dir/all_js.txt")
    local sensitive=$(count_lines "$work_dir/sensitive_files.txt")
    local vulns=$(count_lines "$work_dir/vulnerability_scan/nuclei_all_findings.txt")
    local critical_vulns=$(count_lines "$work_dir/vulnerability_scan/critical_high_findings.txt")

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$(calc_duration ${SCAN_START_TIME:-$end_time} $end_time)

    # Generate JSON
    cat > "$output_file" << EOF
{
  "scan_info": {
    "target": "$DOMAIN",
    "operation_name": "$ORG_NAME",
    "scan_date": "$(date -Iseconds)",
    "duration": "$duration",
    "dominus_version": "2.0"
  },
  "statistics": {
    "subdomains": {
      "total": $subdomains,
      "resolved": $resolved,
      "alive": $alive
    },
    "network": {
      "open_ports": $ports
    },
    "web": {
      "urls": $urls,
      "parameters": $params,
      "js_files": $js_files,
      "sensitive_files": $sensitive
    },
    "vulnerabilities": {
      "total": $vulns,
      "critical_high": $critical_vulns
    }
  },
  "files": {
    "subdomains": "all_subs.txt",
    "resolved_hosts": "all_resolved.txt",
    "live_hosts": "all_alive.txt",
    "open_ports": "open_ports.txt",
    "urls": "all_urls.txt",
    "parameters": "all_params.txt",
    "javascript": "all_js.txt",
    "sensitive": "sensitive_files.txt",
    "vulnerabilities": "vulnerability_scan/nuclei_all_findings.txt"
  },
  "metadata": {
    "base_dir": "$BASE_DIR",
    "work_dir": "$work_dir",
    "config": {
      "threads": ${DEFAULT_THREADS:-25},
      "rate_limit": ${RATE_LIMIT:-150},
      "concurrency": ${CONCURRENCY:-25}
    }
  }
}
EOF

    if [ $? -eq 0 ]; then
        log_success "JSON report generated: $output_file"
        return 0
    else
        log_error "Failed to generate JSON report"
        return 1
    fi
}

# Generate detailed JSON with all findings
generate_detailed_json() {
    local work_dir="${1:-$WORK_DIR}"
    local output_file="$work_dir/report_detailed.json"

    log_info "Generating detailed JSON report..."

    # Read arrays
    local subdomains_array="[]"
    if [ -f "$work_dir/all_subs.txt" ]; then
        subdomains_array=$(jq -R -s -c 'split("\n")[:-1]' < "$work_dir/all_subs.txt" 2>/dev/null || echo "[]")
    fi

    local alive_array="[]"
    if [ -f "$work_dir/all_alive.txt" ]; then
        alive_array=$(jq -R -s -c 'split("\n")[:-1]' < "$work_dir/all_alive.txt" 2>/dev/null || echo "[]")
    fi

    # Generate JSON (simplified version)
    cat > "$output_file" << EOF
{
  "scan_info": {
    "target": "$DOMAIN",
    "operation_name": "$ORG_NAME",
    "scan_date": "$(date -Iseconds)"
  },
  "findings": {
    "subdomains": $subdomains_array,
    "live_hosts": $alive_array
  }
}
EOF

    log_success "Detailed JSON report generated: $output_file"
}

# ============================================================================
# MARKDOWN OUTPUT
# ============================================================================

# Generate Markdown report
generate_markdown_report() {
    local work_dir="${1:-$WORK_DIR}"
    local output_file="$work_dir/REPORT.md"

    log_info "Generating Markdown report..."

    # Count findings
    local subdomains=$(count_lines "$work_dir/all_subs.txt")
    local resolved=$(count_lines "$work_dir/all_resolved.txt")
    local alive=$(count_lines "$work_dir/all_alive.txt")
    local ports=$(count_lines "$work_dir/open_ports.txt")
    local urls=$(count_lines "$work_dir/all_urls.txt")
    local params=$(count_lines "$work_dir/all_params.txt")
    local js_files=$(count_lines "$work_dir/all_js.txt")
    local sensitive=$(count_lines "$work_dir/sensitive_files.txt")
    local vulns=$(count_lines "$work_dir/vulnerability_scan/nuclei_all_findings.txt")
    local critical_vulns=$(count_lines "$work_dir/vulnerability_scan/critical_high_findings.txt")

    cat > "$output_file" << EOF
# DOMINUS Reconnaissance Report

## Scan Information

- **Target:** \`$DOMAIN\`
- **Operation:** \`$ORG_NAME\`
- **Date:** $(date '+%Y-%m-%d %H:%M:%S')
- **Duration:** $(calc_duration ${SCAN_START_TIME:-$(date +%s)} $(date +%s))

---

## Executive Summary

This reconnaissance scan was performed using DOMINUS v2.0 against the target domain **$DOMAIN**.

### Key Findings

| Category | Count |
|----------|-------|
| Subdomains Discovered | $subdomains |
| Resolved Hosts | $resolved |
| Live HTTP Services | $alive |
| Open Ports | $ports |
| URLs Discovered | $urls |
| Parameterized URLs | $params |
| JavaScript Files | $js_files |
| Sensitive Files | $sensitive |
| Vulnerabilities | $vulns |
| Critical/High Severity | $critical_vulns |

---

## Detailed Findings

### 1. Subdomain Enumeration

**Total Subdomains:** $subdomains

Top 10 subdomains:
\`\`\`
$(head -10 "$work_dir/all_subs.txt" 2>/dev/null || echo "No data")
\`\`\`

### 2. Live Hosts

**Total Live Hosts:** $alive

Top 10 live hosts:
\`\`\`
$(head -10 "$work_dir/all_alive.txt" 2>/dev/null || echo "No data")
\`\`\`

### 3. Vulnerabilities

**Total Vulnerabilities:** $vulns
**Critical/High Severity:** $critical_vulns

Top 10 critical/high findings:
\`\`\`
$(head -10 "$work_dir/vulnerability_scan/critical_high_findings.txt" 2>/dev/null || echo "No critical findings")
\`\`\`

---

## Files Generated

- \`all_subs.txt\` - All discovered subdomains
- \`all_resolved.txt\` - DNS-resolved hosts
- \`all_alive.txt\` - Live HTTP services
- \`open_ports.txt\` - Port scan results
- \`all_urls.txt\` - Discovered URLs
- \`all_params.txt\` - Parameterized URLs
- \`all_js.txt\` - JavaScript files
- \`sensitive_files.txt\` - Potentially sensitive files
- \`vulnerability_scan/\` - Vulnerability scan results

---

## Recommendations

1. Review all critical and high severity vulnerabilities immediately
2. Investigate exposed admin panels and misconfigurations
3. Analyze parameterized URLs for injection vulnerabilities
4. Review sensitive files for information disclosure
5. Verify all findings manually before reporting

---

**Generated by DOMINUS v2.0**
EOF

    log_success "Markdown report generated: $output_file"
}

# ============================================================================
# HTML OUTPUT
# ============================================================================

# Generate HTML report
generate_html_report() {
    local work_dir="${1:-$WORK_DIR}"
    local output_file="$work_dir/report.html"

    log_info "Generating HTML report..."

    # Count findings
    local subdomains=$(count_lines "$work_dir/all_subs.txt")
    local alive=$(count_lines "$work_dir/all_alive.txt")
    local vulns=$(count_lines "$work_dir/vulnerability_scan/nuclei_all_findings.txt")

    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>DOMINUS Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        .stat-box { display: inline-block; margin: 10px; padding: 20px; background: #ecf0f1; border-radius: 5px; min-width: 150px; }
        .stat-number { font-size: 32px; font-weight: bold; color: #3498db; }
        .stat-label { color: #7f8c8d; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #3498db; color: white; }
        .critical { color: #e74c3c; font-weight: bold; }
        .high { color: #e67e22; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 DOMINUS Reconnaissance Report</h1>

        <h2>Scan Information</h2>
        <p><strong>Target:</strong> DOMAIN_PLACEHOLDER</p>
        <p><strong>Date:</strong> DATE_PLACEHOLDER</p>

        <h2>Summary Statistics</h2>
        <div class="stat-box">
            <div class="stat-number">SUBDOMAINS_PLACEHOLDER</div>
            <div class="stat-label">Subdomains</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">ALIVE_PLACEHOLDER</div>
            <div class="stat-label">Live Hosts</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">VULNS_PLACEHOLDER</div>
            <div class="stat-label">Vulnerabilities</div>
        </div>

        <h2>Files Generated</h2>
        <ul>
            <li>all_subs.txt - All discovered subdomains</li>
            <li>all_alive.txt - Live HTTP services</li>
            <li>vulnerability_scan/ - Vulnerability findings</li>
        </ul>
    </div>
</body>
</html>
EOF

    # Replace placeholders
    sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$output_file"
    sed -i "s/DATE_PLACEHOLDER/$(date)/g" "$output_file"
    sed -i "s/SUBDOMAINS_PLACEHOLDER/$subdomains/g" "$output_file"
    sed -i "s/ALIVE_PLACEHOLDER/$alive/g" "$output_file"
    sed -i "s/VULNS_PLACEHOLDER/$vulns/g" "$output_file"

    log_success "HTML report generated: $output_file"
}

# ============================================================================
# CSV OUTPUT
# ============================================================================

# Generate CSV of findings
generate_csv_export() {
    local work_dir="${1:-$WORK_DIR}"
    local output_file="$work_dir/findings.csv"

    log_info "Generating CSV export..."

    # Create header
    echo "Type,Value,Status,Timestamp" > "$output_file"

    # Add subdomains
    if [ -f "$work_dir/all_subs.txt" ]; then
        while IFS= read -r subdomain; do
            echo "subdomain,$subdomain,discovered,$(date -Iseconds)" >> "$output_file"
        done < "$work_dir/all_subs.txt"
    fi

    # Add live hosts
    if [ -f "$work_dir/all_alive.txt" ]; then
        while IFS= read -r host; do
            echo "live_host,$host,alive,$(date -Iseconds)" >> "$output_file"
        done < "$work_dir/all_alive.txt"
    fi

    log_success "CSV export generated: $output_file"
}

# ============================================================================
# UNIFIED REPORT GENERATION
# ============================================================================

# Generate all reports
generate_all_reports() {
    local work_dir="${1:-$WORK_DIR}"

    log_phase "Generating Reports"

    generate_json_report "$work_dir"
    generate_markdown_report "$work_dir"
    generate_html_report "$work_dir"
    generate_csv_export "$work_dir"

    log_success "All reports generated"
}
