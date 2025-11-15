#!/bin/bash

# Stage 1: Setup & Tool Verification with Auto-Installation
# This script checks installed tools, downloads wordlists, and sets up the environment
# v2.0: Now includes automatic installation capability!

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../recon_config.sh" 2>/dev/null || {
    echo "[!] Warning: Could not source config, using defaults"
    export BASE_DIR="$HOME/recon"
    export WORDLISTS_DIR="$HOME/recon/wordlists"
}

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
    log_phase() { echo ""; echo -e "${MAGENTA}[>>]${NC} ${CYAN}$1${NC}"; echo ""; }
fi

# Arrays to track missing tools
declare -a MISSING_GO_TOOLS
declare -a MISSING_PIPX_TOOLS
declare -a MISSING_SYSTEM_TOOLS
declare -a MISSING_MANUAL_TOOLS

# Tool installation commands (tool_name:install_command)
declare -A TOOL_INSTALL_COMMANDS

# Initialize tool installation mapping
init_tool_mapping() {
    # Go tools
    TOOL_INSTALL_COMMANDS["subfinder"]="go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    TOOL_INSTALL_COMMANDS["assetfinder"]="go install github.com/tomnomnom/assetfinder@latest"
    TOOL_INSTALL_COMMANDS["amass"]="go install -v github.com/owasp-amass/amass/v4/...@master"
    TOOL_INSTALL_COMMANDS["dnsx"]="go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    TOOL_INSTALL_COMMANDS["puredns"]="go install github.com/d3mondev/puredns/v2@latest"
    TOOL_INSTALL_COMMANDS["httpx"]="go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
    TOOL_INSTALL_COMMANDS["katana"]="go install -v github.com/projectdiscovery/katana/cmd/katana@latest"
    TOOL_INSTALL_COMMANDS["hakrawler"]="go install github.com/hakluke/hakrawler@latest"
    TOOL_INSTALL_COMMANDS["gau"]="go install github.com/lc/gau/v2/cmd/gau@latest"
    TOOL_INSTALL_COMMANDS["gauplus"]="go install github.com/bp0lr/gauplus@latest"
    TOOL_INSTALL_COMMANDS["waybackurls"]="go install github.com/tomnomnom/waybackurls@latest"
    TOOL_INSTALL_COMMANDS["naabu"]="go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    TOOL_INSTALL_COMMANDS["nuclei"]="go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    TOOL_INSTALL_COMMANDS["subjs"]="go install github.com/lc/subjs@latest"
    TOOL_INSTALL_COMMANDS["getJS"]="go install github.com/003random/getJS@latest"
    TOOL_INSTALL_COMMANDS["gowitness"]="go install github.com/sensepost/gowitness@latest"
    TOOL_INSTALL_COMMANDS["anew"]="go install github.com/tomnomnom/anew@latest"
    TOOL_INSTALL_COMMANDS["qsreplace"]="go install github.com/tomnomnom/qsreplace@latest"
    TOOL_INSTALL_COMMANDS["gf"]="go install github.com/tomnomnom/gf@latest"

    # Pipx tools
    TOOL_INSTALL_COMMANDS["paramspider"]="pipx install paramspider"
    TOOL_INSTALL_COMMANDS["arjun"]="pipx install arjun"
    TOOL_INSTALL_COMMANDS["uro"]="pipx install uro"

    # System tools (pacman - adjust for your distro)
    TOOL_INSTALL_COMMANDS["nmap"]="sudo pacman -S nmap"
    TOOL_INSTALL_COMMANDS["jq"]="sudo pacman -S jq"
}

# Detect package manager
detect_package_manager() {
    if command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v apt &>/dev/null; then
        echo "apt"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# Get system tool install command based on package manager
get_system_install_cmd() {
    local tool="$1"
    local pkg_mgr=$(detect_package_manager)

    case "$pkg_mgr" in
        pacman)
            echo "sudo pacman -S --noconfirm $tool"
            ;;
        apt)
            echo "sudo apt install -y $tool"
            ;;
        yum|dnf)
            echo "sudo $pkg_mgr install -y $tool"
            ;;
        brew)
            echo "brew install $tool"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Check prerequisites for installation
check_prerequisites() {
    local missing_prereqs=()

    # Check for Go
    if ! command -v go &>/dev/null; then
        missing_prereqs+=("go")
        log_warning "Go is not installed (required for most tools)"
        echo "  Install Go: https://golang.org/doc/install"
    else
        local go_version=$(go version | awk '{print $3}')
        log_success "Go installed: $go_version"
    fi

    # Check for pipx
    if ! command -v pipx &>/dev/null; then
        missing_prereqs+=("pipx")
        log_warning "pipx is not installed (required for Python tools)"
        echo "  Install pipx: python3 -m pip install --user pipx"
    else
        log_success "pipx installed"
    fi

    # Check for wget/curl
    if ! command -v wget &>/dev/null && ! command -v curl &>/dev/null; then
        missing_prereqs+=("wget or curl")
        log_warning "wget or curl not found (required for downloads)"
    fi

    if [ ${#missing_prereqs[@]} -gt 0 ]; then
        return 1
    fi
    return 0
}

# Check if a tool is installed
check_tool() {
    local tool="$1"
    local install_cmd="$2"
    local tool_type="$3"  # go, pipx, system, manual

    if command -v "$tool" &>/dev/null; then
        log_success "$tool installed"
        return 0
    else
        log_error "$tool not found"
        if [ -n "$install_cmd" ]; then
            echo "  Install: $install_cmd"
        fi

        # Add to appropriate missing tools array
        case "$tool_type" in
            go)
                MISSING_GO_TOOLS+=("$tool")
                ;;
            pipx)
                MISSING_PIPX_TOOLS+=("$tool")
                ;;
            system)
                MISSING_SYSTEM_TOOLS+=("$tool")
                ;;
            manual)
                MISSING_MANUAL_TOOLS+=("$tool")
                ;;
        esac

        return 1
    fi
}

# Install a single tool
install_tool() {
    local tool="$1"
    local install_cmd="${TOOL_INSTALL_COMMANDS[$tool]}"

    if [ -z "$install_cmd" ]; then
        log_error "No installation command for $tool"
        return 1
    fi

    log_info "Installing $tool..."

    # Execute installation command
    if eval "$install_cmd" &>/dev/null; then
        # Verify installation
        if command -v "$tool" &>/dev/null; then
            log_success "$tool installed successfully"
            return 0
        else
            log_warning "$tool installation completed but command not found in PATH"
            log_info "You may need to add \$GOPATH/bin to your PATH"
            return 1
        fi
    else
        log_error "Failed to install $tool"
        return 1
    fi
}

# Install all Go tools
install_go_tools() {
    if [ ${#MISSING_GO_TOOLS[@]} -eq 0 ]; then
        return 0
    fi

    log_phase "Installing Go Tools (${#MISSING_GO_TOOLS[@]} tools)"

    local installed=0
    local failed=0

    for tool in "${MISSING_GO_TOOLS[@]}"; do
        if install_tool "$tool"; then
            ((installed++))
        else
            ((failed++))
        fi
    done

    echo ""
    log_info "Go tools installation complete: $installed installed, $failed failed"
    return 0
}

# Install all pipx tools
install_pipx_tools() {
    if [ ${#MISSING_PIPX_TOOLS[@]} -eq 0 ]; then
        return 0
    fi

    log_phase "Installing Python Tools via pipx (${#MISSING_PIPX_TOOLS[@]} tools)"

    local installed=0
    local failed=0

    for tool in "${MISSING_PIPX_TOOLS[@]}"; do
        if install_tool "$tool"; then
            ((installed++))
        else
            ((failed++))
        fi
    done

    echo ""
    log_info "Python tools installation complete: $installed installed, $failed failed"
    return 0
}

# Install system tools
install_system_tools() {
    if [ ${#MISSING_SYSTEM_TOOLS[@]} -eq 0 ]; then
        return 0
    fi

    log_phase "Installing System Tools (${#MISSING_SYSTEM_TOOLS[@]} tools)"

    local installed=0
    local failed=0

    for tool in "${MISSING_SYSTEM_TOOLS[@]}"; do
        if install_tool "$tool"; then
            ((installed++))
        else
            ((failed++))
        fi
    done

    echo ""
    log_info "System tools installation complete: $installed installed, $failed failed"
    return 0
}

# Prompt user for auto-installation
prompt_auto_install() {
    local total_missing=$((${#MISSING_GO_TOOLS[@]} + ${#MISSING_PIPX_TOOLS[@]} + ${#MISSING_SYSTEM_TOOLS[@]}))

    if [ $total_missing -eq 0 ]; then
        return 1  # Nothing to install
    fi

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}              ${CYAN}Automatic Installation Available${NC}              ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  Found $total_missing missing tool(s) that can be auto-installed:    ${YELLOW}║${NC}"

    if [ ${#MISSING_GO_TOOLS[@]} -gt 0 ]; then
        echo -e "${YELLOW}║${NC}    ${GREEN}Go tools:${NC} ${#MISSING_GO_TOOLS[@]}                                          ${YELLOW}║${NC}"
    fi

    if [ ${#MISSING_PIPX_TOOLS[@]} -gt 0 ]; then
        echo -e "${YELLOW}║${NC}    ${GREEN}Python tools:${NC} ${#MISSING_PIPX_TOOLS[@]}                                      ${YELLOW}║${NC}"
    fi

    if [ ${#MISSING_SYSTEM_TOOLS[@]} -gt 0 ]; then
        echo -e "${YELLOW}║${NC}    ${GREEN}System tools:${NC} ${#MISSING_SYSTEM_TOOLS[@]}                                     ${YELLOW}║${NC}"
    fi

    if [ ${#MISSING_MANUAL_TOOLS[@]} -gt 0 ]; then
        echo -e "${YELLOW}║${NC}    ${RED}Manual install required:${NC} ${#MISSING_MANUAL_TOOLS[@]}                        ${YELLOW}║${NC}"
    fi

    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${GREEN}Would you like to automatically install missing tools? \(y/n\): ${NC})" response

    if [ "$response" = "y" ] || [ "$response" = "yes" ] || [ "$response" = "Y" ]; then
        return 0  # User wants auto-install
    else
        return 1  # User declined
    fi
}

# Main function
main() {
    echo ""
    log_info "═══════════════════════════════════════════════════════════"
    log_info "STAGE 1: Setup & Tool Verification v2.0"
    log_info "═══════════════════════════════════════════════════════════"
    echo ""

    # Initialize tool mapping
    init_tool_mapping

    # Create necessary directories
    log_info "Setting up directories..."
    mkdir -p "$BASE_DIR"
    mkdir -p "$WORDLISTS_DIR"
    mkdir -p "$BASE_DIR/scripts"
    log_success "Directories created"
    echo ""

    # Check prerequisites
    log_info "Checking prerequisites..."
    check_prerequisites
    echo ""

    # Check installed tools
    log_info "Checking installed tools..."
    echo ""

    # Core Tools
    echo -e "${CYAN}Core Tools:${NC}"
    check_tool "subfinder" "${TOOL_INSTALL_COMMANDS[subfinder]}" "go"
    check_tool "assetfinder" "${TOOL_INSTALL_COMMANDS[assetfinder]}" "go"
    check_tool "amass" "${TOOL_INSTALL_COMMANDS[amass]}" "go"
    check_tool "findomain" "Download from: https://github.com/Findomain/Findomain/releases" "manual"
    echo ""

    # DNS & Resolution
    echo -e "${CYAN}DNS & Resolution:${NC}"
    check_tool "dnsx" "${TOOL_INSTALL_COMMANDS[dnsx]}" "go"
    check_tool "puredns" "${TOOL_INSTALL_COMMANDS[puredns]}" "go"
    check_tool "massdns" "git clone https://github.com/blechschmidt/massdns && cd massdns && make" "manual"
    echo ""

    # HTTP Probing & Crawling
    echo -e "${CYAN}HTTP Probing & Crawling:${NC}"
    check_tool "httpx" "${TOOL_INSTALL_COMMANDS[httpx]}" "go"
    check_tool "katana" "${TOOL_INSTALL_COMMANDS[katana]}" "go"
    check_tool "hakrawler" "${TOOL_INSTALL_COMMANDS[hakrawler]}" "go"
    check_tool "gau" "${TOOL_INSTALL_COMMANDS[gau]}" "go"
    check_tool "gauplus" "${TOOL_INSTALL_COMMANDS[gauplus]}" "go"
    check_tool "waybackurls" "${TOOL_INSTALL_COMMANDS[waybackurls]}" "go"
    echo ""

    # Port Scanning
    echo -e "${CYAN}Port Scanning:${NC}"
    check_tool "naabu" "${TOOL_INSTALL_COMMANDS[naabu]}" "go"
    check_tool "nmap" "$(get_system_install_cmd nmap)" "system"
    echo ""

    # Vulnerability Scanning
    echo -e "${CYAN}Vulnerability Scanning:${NC}"
    check_tool "nuclei" "${TOOL_INSTALL_COMMANDS[nuclei]}" "go"
    echo ""

    # Parameter & JS Discovery
    echo -e "${CYAN}Parameter & JS Discovery:${NC}"
    check_tool "paramspider" "${TOOL_INSTALL_COMMANDS[paramspider]}" "pipx"
    check_tool "arjun" "${TOOL_INSTALL_COMMANDS[arjun]}" "pipx"
    check_tool "subjs" "${TOOL_INSTALL_COMMANDS[subjs]}" "go"
    check_tool "getJS" "${TOOL_INSTALL_COMMANDS[getJS]}" "go"
    echo ""

    # Screenshots & Visualization
    echo -e "${CYAN}Screenshots & Visualization:${NC}"
    check_tool "gowitness" "${TOOL_INSTALL_COMMANDS[gowitness]}" "go"
    check_tool "aquatone" "Download from: https://github.com/michenriksen/aquatone/releases" "manual"
    echo ""

    # Utilities
    echo -e "${CYAN}Utilities:${NC}"
    check_tool "anew" "${TOOL_INSTALL_COMMANDS[anew]}" "go"
    check_tool "uro" "${TOOL_INSTALL_COMMANDS[uro]}" "pipx"
    check_tool "qsreplace" "${TOOL_INSTALL_COMMANDS[qsreplace]}" "go"
    check_tool "gf" "${TOOL_INSTALL_COMMANDS[gf]}" "go"
    check_tool "jq" "$(get_system_install_cmd jq)" "system"
    echo ""

    # Offer auto-installation
    if prompt_auto_install; then
        echo ""
        log_phase "Starting Automatic Installation"

        # Install Go tools
        if [ ${#MISSING_GO_TOOLS[@]} -gt 0 ]; then
            install_go_tools
        fi

        # Install pipx tools
        if [ ${#MISSING_PIPX_TOOLS[@]} -gt 0 ]; then
            install_pipx_tools
        fi

        # Install system tools
        if [ ${#MISSING_SYSTEM_TOOLS[@]} -gt 0 ]; then
            install_system_tools
        fi

        # Show manual installation reminder
        if [ ${#MISSING_MANUAL_TOOLS[@]} -gt 0 ]; then
            echo ""
            log_warning "The following tools require manual installation:"
            for tool in "${MISSING_MANUAL_TOOLS[@]}"; do
                echo "  - $tool"
            done
        fi

        echo ""
        log_success "Automatic installation complete!"
        log_info "Verifying installations..."
        echo ""

        # Re-verify critical tools
        local still_missing=0
        for tool in subfinder httpx nuclei; do
            if ! command -v "$tool" &>/dev/null; then
                log_warning "$tool still not found - may need to configure PATH"
                ((still_missing++))
            fi
        done

        if [ $still_missing -eq 0 ]; then
            log_success "All critical tools are now installed!"
        else
            log_warning "Some tools still missing. Check your \$PATH configuration"
            echo "  Add to ~/.bashrc or ~/.zshrc:"
            echo "  export PATH=\$PATH:\$HOME/go/bin:\$HOME/.local/bin"
        fi
    fi

    echo ""

    # Update Nuclei templates
    if command -v nuclei >/dev/null 2>&1; then
        log_info "Updating Nuclei templates..."
        nuclei -update-templates -silent 2>/dev/null

        # Verify templates directory
        TEMPLATE_DIR="$HOME/nuclei-templates"
        if [ -d "$TEMPLATE_DIR" ]; then
            TEMPLATE_COUNT=$(find "$TEMPLATE_DIR" -name "*.yaml" 2>/dev/null | wc -l)
            log_success "Nuclei templates updated ($TEMPLATE_COUNT templates)"
        else
            log_warning "Nuclei templates directory not found"
            log_info "Run: nuclei -update-templates"
        fi
    else
        log_warning "Nuclei not installed, skipping template update"
    fi
    echo ""

    # Check wordlists
    log_info "Checking wordlists..."

    SUBDOMAIN_WORDLIST="$WORDLISTS_DIR/subdomains.txt"
    if [ ! -f "$SUBDOMAIN_WORDLIST" ]; then
        log_info "Downloading subdomain wordlist..."
        if wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-110000.txt -O "$SUBDOMAIN_WORDLIST" 2>/dev/null; then
            WORDLIST_SIZE=$(wc -l < "$SUBDOMAIN_WORDLIST")
            log_success "Subdomain wordlist downloaded ($WORDLIST_SIZE entries)"
        else
            log_warning "Could not download subdomain wordlist"
            echo "  Manual download: wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-110000.txt -O $SUBDOMAIN_WORDLIST"
        fi
    else
        WORDLIST_SIZE=$(wc -l < "$SUBDOMAIN_WORDLIST")
        log_success "Subdomain wordlist found ($WORDLIST_SIZE entries)"
    fi
    echo ""

    # Check resolver lists
    log_info "Checking resolver lists..."

    RESOLVERS_FILE="$WORDLISTS_DIR/resolvers.txt"
    if [ ! -f "$RESOLVERS_FILE" ]; then
        log_info "Downloading public DNS resolvers..."

        # Try multiple sources
        if wget -q https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt -O "$RESOLVERS_FILE" 2>/dev/null; then
            log_success "Resolvers downloaded from trickest"
        elif wget -q https://raw.githubusercontent.com/janmasarik/resolvers/master/resolvers.txt -O "$RESOLVERS_FILE" 2>/dev/null; then
            log_success "Resolvers downloaded from janmasarik"
        else
            log_warning "Could not download resolvers automatically"
            echo "  Manual download: https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt"
        fi
    else
        RESOLVER_COUNT=$(wc -l < "$RESOLVERS_FILE")
        log_success "Resolvers found ($RESOLVER_COUNT entries)"
    fi
    echo ""

    # Summary
    log_info "═══════════════════════════════════════════════════════════"
    log_success "Stage 1 setup check complete!"
    log_info "═══════════════════════════════════════════════════════════"
    echo ""

    # Recommendations
    log_info "Recommendations:"
    echo "  1. Configure API keys for subfinder (~/.config/subfinder/provider-config.yaml)"
    echo "  2. Add GitHub tokens for better enumeration"
    echo "  3. Configure Telegram notifications in recon_config.sh"
    echo "  4. Ensure \$GOPATH/bin and ~/.local/bin are in your PATH"
    echo ""

    # Check naabu permissions
    if command -v naabu >/dev/null 2>&1; then
        NAABU_PATH=$(which naabu)
        if ! getcap "$NAABU_PATH" 2>/dev/null | grep -q "cap_net_raw"; then
            log_warning "Naabu needs raw socket capabilities"
            echo "  Run: sudo setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip $NAABU_PATH"
            echo ""
        fi
    fi

    # Count missing critical tools
    MISSING=0
    for tool in subfinder httpx nuclei; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            ((MISSING++))
        fi
    done

    if [ $MISSING -eq 0 ]; then
        log_success "All critical tools installed! Ready to start scanning."
    else
        log_warning "$MISSING critical tool(s) missing. Install them before scanning."
    fi
    echo ""

    log_success "All operations completed!"
}

main "$@"
