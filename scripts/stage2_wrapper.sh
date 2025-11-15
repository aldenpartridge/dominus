#!/bin/bash

# TROXXER Stage 2 Wrapper - Enhanced version with v2.0 features
# This script wraps the original stage2.sh with new capabilities

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
safe_mkdir "$WORK_DIR"
safe_mkdir "$WORK_DIR/logs"

# Initialize scan state
export SCAN_START_TIME=$(get_epoch)
save_scan_state "$WORK_DIR"

# Check for resume
if can_resume "$WORK_DIR"; then
    prompt_resume "$WORK_DIR"
fi

# Send start notification
if [ "$ENABLE_NOTIFICATIONS" = "true" ]; then
    notify_scan_start "$DOMAIN" "$ORG_NAME"
fi

# Execute original stage2.sh
log_phase "Executing Reconnaissance Pipeline"

if [ -f "$SCRIPT_DIR/scripts/stage2.sh" ]; then
    bash "$SCRIPT_DIR/scripts/stage2.sh" "$DOMAIN" "$ORG_NAME"
    EXIT_CODE=$?
else
    log_error "stage2.sh not found"
    EXIT_CODE=1
fi

# Generate reports if successful
if [ $EXIT_CODE -eq 0 ]; then
    log_phase "Generating Reports"

    # Update counters
    export SUBDOMAINS_FOUND=$(count_lines "$WORK_DIR/all_subs.txt")
    export LIVE_HOSTS=$(count_lines "$WORK_DIR/all_alive.txt")
    save_scan_state "$WORK_DIR"

    # Generate outputs
    if [ "$ENABLE_JSON" = "true" ]; then
        generate_json_report "$WORK_DIR"
    fi

    generate_markdown_report "$WORK_DIR"

    # Send completion notification
    if [ "$ENABLE_NOTIFICATIONS" = "true" ]; then
        local duration=$(calc_duration $SCAN_START_TIME $(get_epoch))
        notify_scan_complete "$DOMAIN" "$ORG_NAME" "$duration" \
            "$SUBDOMAINS_FOUND" "$LIVE_HOSTS" "0"
    fi

    mark_scan_complete "$WORK_DIR"
else
    mark_scan_failed "$WORK_DIR" "Stage 2 failed with code $EXIT_CODE"

    if [ "$ENABLE_NOTIFICATIONS" = "true" ]; then
        notify_scan_error "$DOMAIN" "$ORG_NAME" "Stage 2 failed"
    fi
fi

exit $EXIT_CODE
