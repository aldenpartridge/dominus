#!/bin/bash

# DOMINUS Stage 3 Wrapper - Enhanced version with v2.0 features
# This script wraps the original stage3.sh with new capabilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/notifications.sh"
source "$SCRIPT_DIR/lib/resume.sh"
source "$SCRIPT_DIR/lib/output.sh"

# Get parameters
DOMAIN="$1"
ORG_NAME="$2"

# Validate inputs
if [ -z "$DOMAIN" ] || [ -z "$ORG_NAME" ]; then
    log_error "Usage: $0 <domain> <organization>"
    exit 1
fi

# Set up work directory
export WORK_DIR="$BASE_DIR/$ORG_NAME"

# Load scan state
load_scan_state "$WORK_DIR"

# Execute original stage3.sh
log_phase "Executing Vulnerability Scanning Pipeline"

if [ -f "$SCRIPT_DIR/scripts/stage3.sh" ]; then
    bash "$SCRIPT_DIR/scripts/stage3.sh" "$DOMAIN" "$ORG_NAME"
    EXIT_CODE=$?
else
    log_error "stage3.sh not found"
    EXIT_CODE=1
fi

# Update reports and notifications if successful
if [ $EXIT_CODE -eq 0 ]; then
    # Update counters
    export VULNERABILITIES=$(count_lines "$WORK_DIR/vulnerability_scan/nuclei_all_findings.txt")
    local critical_vulns=$(count_lines "$WORK_DIR/vulnerability_scan/critical_high_findings.txt")
    save_scan_state "$WORK_DIR"

    # Regenerate reports with vulnerability data
    if [ "$ENABLE_JSON" = "true" ]; then
        generate_json_report "$WORK_DIR"
    fi

    generate_markdown_report "$WORK_DIR"
    generate_html_report "$WORK_DIR"

    # Send notification for critical findings
    if [ "$ENABLE_NOTIFICATIONS" = "true" ] && [ $critical_vulns -gt 0 ]; then
        notify_critical_finding "$DOMAIN" "$critical_vulns critical/high vulnerabilities found" "critical"
    fi

    # Final completion notification
    if [ "$ENABLE_NOTIFICATIONS" = "true" ]; then
        local duration=$(calc_duration $SCAN_START_TIME $(get_epoch))
        notify_scan_complete "$DOMAIN" "$ORG_NAME" "$duration" \
            "${SUBDOMAINS_FOUND:-0}" "${LIVE_HOSTS:-0}" "$VULNERABILITIES"
    fi

    log_success "Full scan pipeline completed!"
    generate_progress_report "$WORK_DIR"

else
    mark_scan_failed "$WORK_DIR" "Stage 3 failed with code $EXIT_CODE"

    if [ "$ENABLE_NOTIFICATIONS" = "true" ]; then
        notify_scan_error "$DOMAIN" "$ORG_NAME" "Stage 3 failed"
    fi
fi

exit $EXIT_CODE
