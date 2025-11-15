#!/bin/bash

# Notification system for TROXXER
# Supports: Telegram, Slack, Discord

# Source common library if not already loaded
if [ -z "$GREEN" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "$SCRIPT_DIR/lib/common.sh"
fi

# ============================================================================
# TELEGRAM NOTIFICATIONS
# ============================================================================

send_telegram() {
    local message="$1"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        log_debug "Telegram not configured, skipping notification"
        return 1
    fi

    local url="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

    curl -s -X POST "$url" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown" \
        >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_debug "Telegram notification sent"
        return 0
    else
        log_debug "Failed to send Telegram notification"
        return 1
    fi
}

# ============================================================================
# SLACK NOTIFICATIONS
# ============================================================================

send_slack() {
    local message="$1"

    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        log_debug "Slack not configured, skipping notification"
        return 1
    fi

    local payload=$(cat <<EOF
{
    "text": "$message",
    "username": "TROXXER",
    "icon_emoji": ":robot_face:"
}
EOF
)

    curl -s -X POST "$SLACK_WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_debug "Slack notification sent"
        return 0
    else
        log_debug "Failed to send Slack notification"
        return 1
    fi
}

# ============================================================================
# DISCORD NOTIFICATIONS
# ============================================================================

send_discord() {
    local message="$1"

    if [ -z "$DISCORD_WEBHOOK_URL" ]; then
        log_debug "Discord not configured, skipping notification"
        return 1
    fi

    local payload=$(cat <<EOF
{
    "username": "TROXXER",
    "avatar_url": "https://example.com/troxxer-icon.png",
    "content": "$message"
}
EOF
)

    curl -s -X POST "$DISCORD_WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_debug "Discord notification sent"
        return 0
    else
        log_debug "Failed to send Discord notification"
        return 1
    fi
}

# ============================================================================
# UNIFIED NOTIFICATION FUNCTION
# ============================================================================

send_notification() {
    local message="$1"
    local title="${2:-TROXXER Notification}"

    if [ "$ENABLE_NOTIFICATIONS" != "true" ]; then
        log_debug "Notifications disabled"
        return 0
    fi

    local full_message="*$title*%0A%0A$message"
    local sent=false

    # Try all configured notification methods
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        send_telegram "$full_message" && sent=true
    fi

    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        send_slack "$message" && sent=true
    fi

    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
        send_discord "$message" && sent=true
    fi

    if [ "$sent" = true ]; then
        log_debug "Notification sent: $title"
        return 0
    else
        log_debug "No notification methods configured"
        return 1
    fi
}

# ============================================================================
# PREDEFINED NOTIFICATION TEMPLATES
# ============================================================================

notify_scan_start() {
    local domain="$1"
    local org_name="$2"

    local message="🚀 *Scan Started*%0A%0A"
    message+="Target: \`$domain\`%0A"
    message+="Operation: \`$org_name\`%0A"
    message+="Time: $(date '+%Y-%m-%d %H:%M:%S')"

    send_notification "$message" "Scan Started"
}

notify_scan_complete() {
    local domain="$1"
    local org_name="$2"
    local duration="$3"
    local subdomains="${4:-0}"
    local live_hosts="${5:-0}"
    local vulnerabilities="${6:-0}"

    local message="✅ *Scan Complete*%0A%0A"
    message+="Target: \`$domain\`%0A"
    message+="Operation: \`$org_name\`%0A"
    message+="Duration: $duration%0A%0A"
    message+="*Results:*%0A"
    message+="• Subdomains: $subdomains%0A"
    message+="• Live Hosts: $live_hosts%0A"
    message+="• Vulnerabilities: $vulnerabilities"

    send_notification "$message" "Scan Complete"
}

notify_scan_error() {
    local domain="$1"
    local org_name="$2"
    local error="$3"

    local message="❌ *Scan Error*%0A%0A"
    message+="Target: \`$domain\`%0A"
    message+="Operation: \`$org_name\`%0A"
    message+="Error: $error"

    send_notification "$message" "Scan Error"
}

notify_phase_complete() {
    local phase_name="$1"
    local findings="${2:-0}"

    local message="✓ Phase Complete: *$phase_name*%0A"
    message+="Findings: $findings"

    send_notification "$message" "Phase Complete"
}

notify_critical_finding() {
    local domain="$1"
    local vulnerability="$2"
    local severity="${3:-high}"

    local emoji="🔴"
    [ "$severity" = "critical" ] && emoji="💀"

    local message="$emoji *Critical Finding*%0A%0A"
    message+="Domain: \`$domain\`%0A"
    message+="Vulnerability: $vulnerability%0A"
    message+="Severity: $severity"

    send_notification "$message" "Critical Finding"
}

# ============================================================================
# NOTIFICATION TESTING
# ============================================================================

test_notifications() {
    log_info "Testing notification systems..."

    local test_message="This is a test notification from TROXXER"
    local success=0
    local total=0

    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        total=$((total + 1))
        log_info "Testing Telegram..."
        if send_telegram "$test_message"; then
            log_success "Telegram: OK"
            success=$((success + 1))
        else
            log_error "Telegram: FAILED"
        fi
    fi

    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        total=$((total + 1))
        log_info "Testing Slack..."
        if send_slack "$test_message"; then
            log_success "Slack: OK"
            success=$((success + 1))
        else
            log_error "Slack: FAILED"
        fi
    fi

    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
        total=$((total + 1))
        log_info "Testing Discord..."
        if send_discord "$test_message"; then
            log_success "Discord: OK"
            success=$((success + 1))
        else
            log_error "Discord: FAILED"
        fi
    fi

    if [ $total -eq 0 ]; then
        log_warning "No notification methods configured"
        return 1
    fi

    echo ""
    log_info "Notification test complete: $success/$total successful"

    if [ $success -eq $total ]; then
        return 0
    else
        return 1
    fi
}
