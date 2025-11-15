#!/bin/bash

# Resume capability for TROXXER
# Allows interrupted scans to continue from last checkpoint

# Source common library if not already loaded
if [ -z "$GREEN" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "$SCRIPT_DIR/lib/common.sh"
fi

# ============================================================================
# CHECKPOINT MANAGEMENT
# ============================================================================

# Save checkpoint
save_checkpoint() {
    local phase="$1"
    local work_dir="${2:-$WORK_DIR}"
    local checkpoint_file="$work_dir/.checkpoint"

    if [ "$ENABLE_RESUME" != "true" ]; then
        return 0
    fi

    safe_mkdir "$work_dir"

    cat > "$checkpoint_file" << EOF
PHASE=$phase
TIMESTAMP=$(date +%s)
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DOMAIN=$DOMAIN
ORG_NAME=$ORG_NAME
EOF

    log_debug "Checkpoint saved: $phase"
}

# Load checkpoint
load_checkpoint() {
    local work_dir="${1:-$WORK_DIR}"
    local checkpoint_file="$work_dir/.checkpoint"

    if [ ! -f "$checkpoint_file" ]; then
        return 1
    fi

    source "$checkpoint_file"

    log_debug "Checkpoint loaded: $PHASE"
    return 0
}

# Get last completed phase
get_last_phase() {
    local work_dir="${1:-$WORK_DIR}"
    local checkpoint_file="$work_dir/.checkpoint"

    if [ -f "$checkpoint_file" ]; then
        grep "^PHASE=" "$checkpoint_file" | cut -d'=' -f2
    else
        echo ""
    fi
}

# Get checkpoint timestamp
get_checkpoint_timestamp() {
    local work_dir="${1:-$WORK_DIR}"
    local checkpoint_file="$work_dir/.checkpoint"

    if [ -f "$checkpoint_file" ]; then
        grep "^TIMESTAMP=" "$checkpoint_file" | cut -d'=' -f2
    else
        echo "0"
    fi
}

# Clear checkpoint
clear_checkpoint() {
    local work_dir="${1:-$WORK_DIR}"
    local checkpoint_file="$work_dir/.checkpoint"

    if [ -f "$checkpoint_file" ]; then
        rm -f "$checkpoint_file"
        log_debug "Checkpoint cleared"
    fi
}

# ============================================================================
# RESUME DETECTION
# ============================================================================

# Check if resume is possible
can_resume() {
    local work_dir="${1:-$WORK_DIR}"
    local checkpoint_file="$work_dir/.checkpoint"

    if [ "$ENABLE_RESUME" != "true" ]; then
        return 1
    fi

    if [ ! -f "$checkpoint_file" ]; then
        return 1
    fi

    # Check if checkpoint is not too old (24 hours)
    local checkpoint_time=$(get_checkpoint_timestamp "$work_dir")
    local current_time=$(date +%s)
    local age=$((current_time - checkpoint_time))

    if [ $age -gt 86400 ]; then
        log_warning "Checkpoint is older than 24 hours, ignoring"
        return 1
    fi

    return 0
}

# Prompt user to resume
prompt_resume() {
    local work_dir="${1:-$WORK_DIR}"

    if ! can_resume "$work_dir"; then
        return 1
    fi

    load_checkpoint "$work_dir"

    local last_phase="$PHASE"
    local checkpoint_date="$DATE"

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}                  ${CYAN}Previous Scan Detected${NC}                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  Domain: ${CYAN}$DOMAIN${NC}"
    echo -e "${YELLOW}║${NC}  Operation: ${CYAN}$ORG_NAME${NC}"
    echo -e "${YELLOW}║${NC}  Last Phase: ${CYAN}$last_phase${NC}"
    echo -e "${YELLOW}║${NC}  Time: ${CYAN}$checkpoint_date${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${GREEN}Resume from last checkpoint? \(y/n\): ${NC})" resume_choice

    if [ "$resume_choice" = "y" ] || [ "$resume_choice" = "yes" ]; then
        log_success "Resuming scan from: $last_phase"
        export RESUME_FROM="$last_phase"
        return 0
    else
        log_info "Starting fresh scan"
        clear_checkpoint "$work_dir"
        export RESUME_FROM=""
        return 1
    fi
}

# ============================================================================
# PHASE MANAGEMENT
# ============================================================================

# Check if phase should be skipped
should_skip_phase() {
    local current_phase="$1"
    local resume_phase="${RESUME_FROM:-}"

    if [ -z "$resume_phase" ]; then
        return 1  # Don't skip if not resuming
    fi

    # Define phase order
    local -A phase_order=(
        ["subdomain_enum"]=1
        ["dns_resolution"]=2
        ["http_probing"]=3
        ["port_scanning"]=4
        ["url_discovery"]=5
        ["parameter_discovery"]=6
        ["js_discovery"]=7
        ["sensitive_files"]=8
        ["vulnerability_scanning"]=9
    )

    local current_order="${phase_order[$current_phase]:-999}"
    local resume_order="${phase_order[$resume_phase]:-0}"

    if [ $current_order -le $resume_order ]; then
        return 0  # Skip this phase
    else
        return 1  # Don't skip
    fi
}

# Execute phase with checkpoint
execute_phase() {
    local phase_name="$1"
    local phase_function="$2"
    local work_dir="${3:-$WORK_DIR}"

    # Check if should skip
    if should_skip_phase "$phase_name"; then
        log_info "Skipping phase (already completed): $phase_name"
        return 0
    fi

    # Execute phase
    log_phase "$phase_name"

    if [ -n "$phase_function" ] && [ "$(type -t $phase_function)" = "function" ]; then
        $phase_function
    else
        log_error "Phase function not found: $phase_function"
        return 1
    fi

    # Save checkpoint
    save_checkpoint "$phase_name" "$work_dir"

    return 0
}

# ============================================================================
# SCAN STATE MANAGEMENT
# ============================================================================

# Save scan state
save_scan_state() {
    local work_dir="${1:-$WORK_DIR}"
    local state_file="$work_dir/.state"

    cat > "$state_file" << EOF
# TROXXER Scan State
SCAN_START_TIME=${SCAN_START_TIME:-$(date +%s)}
DOMAIN=$DOMAIN
ORG_NAME=$ORG_NAME
BASE_DIR=$BASE_DIR
WORK_DIR=$WORK_DIR

# Counters
SUBDOMAINS_FOUND=${SUBDOMAINS_FOUND:-0}
RESOLVED_HOSTS=${RESOLVED_HOSTS:-0}
LIVE_HOSTS=${LIVE_HOSTS:-0}
OPEN_PORTS=${OPEN_PORTS:-0}
URLS_FOUND=${URLS_FOUND:-0}
PARAMS_FOUND=${PARAMS_FOUND:-0}
JS_FILES_FOUND=${JS_FILES_FOUND:-0}
SENSITIVE_FILES=${SENSITIVE_FILES:-0}
VULNERABILITIES=${VULNERABILITIES:-0}

# Status
CURRENT_PHASE=${CURRENT_PHASE:-starting}
STATUS=${STATUS:-running}
EOF

    log_debug "Scan state saved"
}

# Load scan state
load_scan_state() {
    local work_dir="${1:-$WORK_DIR}"
    local state_file="$work_dir/.state"

    if [ -f "$state_file" ]; then
        source "$state_file"
        log_debug "Scan state loaded"
        return 0
    fi

    return 1
}

# Update scan counter
update_counter() {
    local counter_name="$1"
    local value="$2"
    local work_dir="${3:-$WORK_DIR}"

    # Export variable
    export "$counter_name=$value"

    # Update state file
    save_scan_state "$work_dir"

    log_debug "Counter updated: $counter_name=$value"
}

# ============================================================================
# PROGRESS REPORTING
# ============================================================================

# Generate progress report
generate_progress_report() {
    local work_dir="${1:-$WORK_DIR}"

    load_scan_state "$work_dir" 2>/dev/null || return 1

    local current_time=$(date +%s)
    local elapsed=$((current_time - SCAN_START_TIME))
    local duration=$(calc_duration $SCAN_START_TIME $current_time)

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}Progress Report${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  Domain: ${GREEN}$DOMAIN${NC}"
    echo -e "${CYAN}║${NC}  Operation: ${GREEN}$ORG_NAME${NC}"
    echo -e "${CYAN}║${NC}  Duration: ${GREEN}$duration${NC}"
    echo -e "${CYAN}║${NC}  Current Phase: ${GREEN}$CURRENT_PHASE${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}Findings:${NC}"
    echo -e "${CYAN}║${NC}    Subdomains: ${GREEN}${SUBDOMAINS_FOUND:-0}${NC}"
    echo -e "${CYAN}║${NC}    Resolved Hosts: ${GREEN}${RESOLVED_HOSTS:-0}${NC}"
    echo -e "${CYAN}║${NC}    Live Hosts: ${GREEN}${LIVE_HOSTS:-0}${NC}"
    echo -e "${CYAN}║${NC}    Open Ports: ${GREEN}${OPEN_PORTS:-0}${NC}"
    echo -e "${CYAN}║${NC}    URLs: ${GREEN}${URLS_FOUND:-0}${NC}"
    echo -e "${CYAN}║${NC}    Parameters: ${GREEN}${PARAMS_FOUND:-0}${NC}"
    echo -e "${CYAN}║${NC}    JS Files: ${GREEN}${JS_FILES_FOUND:-0}${NC}"
    echo -e "${CYAN}║${NC}    Sensitive Files: ${GREEN}${SENSITIVE_FILES:-0}${NC}"
    echo -e "${CYAN}║${NC}    Vulnerabilities: ${GREEN}${VULNERABILITIES:-0}${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================================
# CLEANUP
# ============================================================================

# Mark scan as complete
mark_scan_complete() {
    local work_dir="${1:-$WORK_DIR}"

    # Update state
    export STATUS="completed"
    export CURRENT_PHASE="completed"
    save_scan_state "$work_dir"

    # Clear checkpoint
    clear_checkpoint "$work_dir"

    log_success "Scan marked as complete"
}

# Mark scan as failed
mark_scan_failed() {
    local work_dir="${1:-$WORK_DIR}"
    local error="${2:-Unknown error}"

    # Update state
    export STATUS="failed"
    export SCAN_ERROR="$error"
    save_scan_state "$work_dir"

    log_error "Scan marked as failed: $error"
}
