# CLAUDE.md - AI Assistant Guide for TROXXER

## Project Overview

**Project Name:** TROXXER
**Purpose:** Automated Bug Bounty Reconnaissance Suite
**Type:** Security reconnaissance framework
**Language:** Bash shell scripts
**License:** Not specified
**Status:** Active development

TROXXER is a comprehensive bash-based security reconnaissance framework designed to automate the discovery of subdomains, URLs, vulnerabilities, and potential security issues for bug bounty programs and penetration testing. The tool orchestrates 25+ security tools through a streamlined 3-stage pipeline.

### Key Characteristics
- **Automated Pipeline:** Multi-stage reconnaissance from subdomain discovery to vulnerability scanning
- **Tool Integration:** Seamlessly integrates popular security tools (subfinder, httpx, nuclei, etc.)
- **User-Friendly:** Interactive menu-driven interface with color-coded output
- **Resilient:** Extensive error handling with fallback mechanisms
- **Organized Output:** Structured directory layout for all reconnaissance data

## Repository Structure

```
/home/user/troxxer/
├── README.md              # Minimal project description (needs expansion)
├── start.sh               # Main entry point - interactive launcher
├── scripts/               # Core reconnaissance scripts
│   ├── stage1.sh         # Tool verification and environment setup
│   ├── stage2.sh         # Full reconnaissance pipeline (8 phases)
│   └── stage3.sh         # Vulnerability scanning (20 scan types)
└── .git/                  # Git repository
```

### File Purposes

#### start.sh (126 lines)
**Main orchestrator and entry point**
- Interactive menu system with ASCII banner
- Routes execution to stage scripts
- Accepts user input for target domain and operation name
- Sources optional `recon_config.sh` configuration file
- Default base directory: `$HOME/recon`

#### scripts/stage1.sh (216 lines)
**Tool verification and environment setup**
- Creates directory structure for reconnaissance data
- Verifies installation of 25+ security tools
- Downloads required resources (wordlists, resolvers, templates)
- Provides installation commands for missing tools
- Recommends API key configuration

**Tool Categories Verified:**
- Subdomain enumeration: subfinder, assetfinder, amass, findomain
- DNS resolution: dnsx, puredns, massdns
- HTTP probing: httpx, katana, hakrawler, gau, gauplus, waybackurls
- Port scanning: naabu, nmap
- Vulnerability scanning: nuclei
- Parameter discovery: paramspider, arjun, subjs, getJS
- Screenshots: gowitness, aquatone
- Utilities: anew, uro, qsreplace, gf, jq

#### scripts/stage2.sh (400 lines)
**Core reconnaissance pipeline - 8 phases**

1. **Subdomain Enumeration** → `all_subs.txt`
2. **DNS Resolution** → `all_resolved.txt`
3. **HTTP Probing** → `all_alive.txt`
4. **Port Scanning** → `open_ports.txt`
5. **URL Discovery** → `all_urls.txt`
6. **Parameter Discovery** → `all_params.txt`
7. **JavaScript Discovery** → `all_js.txt`
8. **Sensitive File Discovery** → `sensitive_files.txt`

Auto-chains to stage3.sh upon completion.

#### scripts/stage3.sh (342 lines)
**Automated vulnerability scanning with Nuclei**

Performs 20 comprehensive vulnerability scans:
- CVE scanning (critical/high and full database)
- Exposed admin panels
- Security misconfigurations
- Information exposures
- Technology fingerprinting
- XSS, SQLi, SSRF, RCE, LFI, IDOR, Open Redirect
- Parameterized vulnerability testing
- JavaScript analysis

**Output:** Individual scan results + combined findings in `vulnerability_scan/`

## Development Workflows

### Initial Setup
1. Clone repository
2. Run `./start.sh` and select option 1 (Verify Tools & Environment)
3. Install missing tools following provided commands
4. Configure API keys for enhanced results:
   - Subfinder: `~/.config/subfinder/provider-config.yaml`
   - GitHub tokens for archive access
5. Set capabilities for naabu: `sudo setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip $(which naabu)`

### Running Reconnaissance
1. Execute: `./start.sh`
2. Select option 2 (Execute Full Reconnaissance Pipeline)
3. Provide target domain (e.g., `example.com`)
4. Provide operation name (e.g., `example-recon`)
5. Pipeline runs automatically through stages 2 and 3
6. Results saved to: `$BASE_DIR/$ORG_NAME/`

### Output Directory Structure
```
$BASE_DIR/$ORG_NAME/
├── rootdomain.txt
├── metadata.txt
├── all_subs.txt
├── all_resolved.txt
├── all_alive.txt
├── open_ports.txt
├── all_urls.txt
├── all_params.txt
├── all_js.txt
├── sensitive_files.txt
├── logs/
│   ├── stage2_complete.log
│   └── stage3_complete.log
└── vulnerability_scan/
    ├── cves_critical_high.txt
    ├── nuclei_all_findings.txt
    └── [18 more vulnerability scan results]
```

## Key Conventions for AI Assistants

### Code Style and Patterns

#### 1. Color Coding System
**Strictly follow the established color scheme:**
```bash
RED='\033[0;31m'       # Errors
GREEN='\033[0;32m'     # Success
YELLOW='\033[1;33m'    # Warnings
BLUE='\033[0;34m'      # Info
CYAN='\033[0;36m'      # Phase/data highlights
MAGENTA='\033[0;35m'   # Paths/directories
NC='\033[0m'           # No color (reset)
```

#### 2. Logging Functions
**Use these standardized logging functions:**
```bash
log_info()     # Blue [*]   - General information
log_success()  # Green [✓]  - Successful operations
log_warning()  # Yellow [!] - Warnings
log_error()    # Red [✗]    - Errors
log_critical() # Purple [!!]- Critical issues
log_phase()    # Magenta [>>] - Phase announcements
```

**Example:**
```bash
log_info "Starting subdomain enumeration"
log_success "Found 150 subdomains"
log_warning "API key not configured"
log_error "Tool 'subfinder' not found"
```

#### 3. File Naming Conventions
- **Temporary files:** `.filename.txt` (hidden, deleted after processing)
- **Final outputs:** `filename.txt` (persistent)
- **Logs:** `logs/stage*_complete.log`
- **Metadata:** `metadata.txt` (scan details)

#### 4. Error Handling Patterns
```bash
# Continue pipeline even if tool fails
tool_command || true

# Fallback mechanism
if [ ! -s output.txt ]; then
    log_warning "No results, using fallback"
    cp fallback.txt output.txt
fi

# Tool availability check
if command -v tool_name &>/dev/null; then
    # Execute tool
else
    log_error "Tool not found"
fi
```

#### 5. Progressive Enhancement
- **Core principle:** Work with minimal tools, enhance with full suite
- **Graceful degradation:** Skip unavailable tools without breaking pipeline
- **Fallback logic:** Use previous stage results if current stage fails

### Configuration Management

#### Default Values
```bash
BASE_DIR="$HOME/recon"
WORDLISTS_DIR="$HOME/recon/wordlists"
DEFAULT_THREADS=25
HTTPX_THREADS=50
CONCURRENCY=25
RATE_LIMIT=150
```

#### Configuration File (Optional)
- **Location:** `recon_config.sh` in project root
- **Status:** Not present in repository (uses defaults)
- **Usage:** Sourced by start.sh if exists

**When creating configuration:**
- Export all variables
- Maintain backward compatibility
- Document all options
- Provide sensible defaults

### Security Considerations

#### Input Sanitization
```bash
# Domain validation
if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    log_error "Invalid domain format"
    exit 1
fi

# Remove special characters from org name
org_name=$(echo "$org_name" | tr -cd '[:alnum:]_-')
```

#### Rate Limiting
- Always use rate limiting to avoid detection/blocking
- Respect target resources
- Configurable concurrency for different network conditions

#### Responsible Use
- No automatic exploitation
- Focus on reconnaissance only
- User must explicitly provide targets
- **IMPORTANT:** This is a security tool - never suggest improvements that would make it more aggressive or evasive

### Testing Approach

**Current Status:** No automated testing framework

**Manual Testing:**
- Tool verification through stage1.sh
- Real-world target testing (authorized only)
- Log file review for errors

**When Adding Features:**
- Test with minimal tool set
- Test with full tool suite
- Verify error handling with missing tools
- Check output file creation
- Validate log entries

### Git Workflow

**Current Branch:** `claude/create-codebase-documentation-014xWmnF6knqGxNLPh2eAGob`
**Remote:** `http://local_proxy@127.0.0.1:28533/git/aldenpartridge/troxxer`

**For AI Assistants:**
1. Always develop on the designated Claude branch
2. Commit with clear, descriptive messages
3. Push with: `git push -u origin <branch-name>`
4. Branch naming: Must start with `claude/` and end with session ID
5. If push fails with 403, verify branch name format
6. Network failures: Retry up to 4 times with exponential backoff (2s, 4s, 8s, 16s)

**Commit Message Format:**
```
<type>: <concise description>

<detailed explanation if needed>
```

**Types:** feat, fix, docs, refactor, test, chore

### Common Tasks for AI Assistants

#### Adding a New Tool to Stage1
1. Add tool name to appropriate category section
2. Create verification check: `command -v tool_name`
3. Provide installation command
4. Add to tool count
5. Test verification script

#### Adding a New Phase to Stage2
1. Increment phase number
2. Add `log_phase "PHASE X: Description"`
3. Create output file in work directory
4. Implement tool execution with error handling
5. Add deduplication if needed
6. Update final file count
7. Document in metadata.txt

#### Adding a New Scan to Stage3
1. Choose appropriate template/tag
2. Add scan counter
3. Create descriptive output filename
4. Add progress logging
5. Append to `nuclei_all_findings.txt`
6. Update scan count in final summary

#### Modifying Output Structure
1. Update directory creation in stage2
2. Modify output paths in all stages
3. Update this CLAUDE.md documentation
4. Maintain backward compatibility if possible

#### Improving Error Messages
1. Use appropriate logging function
2. Include context (what was being attempted)
3. Suggest remediation if possible
4. Maintain consistent formatting

### Documentation Standards

**When updating documentation:**
- Keep README.md user-focused and concise
- Use CLAUDE.md for AI assistant guidance
- Document all configuration options
- Provide examples for complex features
- Update version/date information

**Current Documentation Issues:**
- README.md has typo: "bug bount" → "bug bounty"
- Missing installation guide
- No usage examples
- No legal disclaimers
- No troubleshooting guide

### Important Patterns to Preserve

#### 1. Tool Execution Pattern
```bash
log_info "Running tool_name"
if command -v tool_name &>/dev/null; then
    tool_name --options > .temp_output.txt 2>/dev/null || true
    if [ -s .temp_output.txt ]; then
        cat .temp_output.txt >> final_output.txt
        rm -f .temp_output.txt
        log_success "Found $(wc -l < final_output.txt) items"
    else
        log_warning "No results from tool_name"
    fi
else
    log_warning "tool_name not installed"
fi
```

#### 2. Deduplication Pattern
```bash
sort -u input.txt -o output.txt
# or with anew
cat input.txt | anew output.txt
```

#### 3. Phase Header Pattern
```bash
echo ""
log_phase "PHASE X: Description"
echo ""
```

#### 4. Silent Error Handling
```bash
# Continue pipeline even on error
command 2>/dev/null || true

# Suppress tool output but capture results
tool --options > output.txt 2>/dev/null
```

### Dependencies and Prerequisites

**Operating System:**
- Linux (tested on Arch-based systems)
- Bash 4.0+

**Package Managers:**
- `go install` (for Go tools)
- `pipx` (for Python tools)
- `pacman` (for system packages on Arch)

**Core Tools (minimum for basic functionality):**
- subfinder
- httpx
- nuclei
- dnsx
- waybackurls

**Enhanced Tools (for full functionality):**
- All 25+ tools listed in stage1.sh
- API keys for subfinder, amass
- GitHub tokens for archive access

### Performance Considerations

**Typical Execution Times:**
- Stage 1 (verification): 1-2 minutes
- Stage 2 (reconnaissance): 15-45 minutes (varies by target size)
- Stage 3 (vulnerability scanning): 20-60 minutes (varies by findings)

**Resource Usage:**
- Concurrent connections: Configurable (default: 25)
- Rate limiting: 150 req/sec (default)
- Disk space: 10-500MB per target (varies by findings)

**Optimization Tips:**
- Adjust `CONCURRENCY` based on network capability
- Lower `RATE_LIMIT` if getting blocked
- Use SSD for faster file operations
- Increase threads on powerful machines

## Project-Specific Quirks

1. **README Typo:** "bug bount automation" was fixed to "bug bounty automation" in v2.0
2. **Auto-Chaining:** stage2 automatically launches stage3 (no user confirmation)
3. **Hidden Files:** Temporary files use `.` prefix and are deleted automatically
4. **Silent Failures:** Tools fail silently with `|| true` to continue pipeline
5. **Config Template:** `recon_config.sh.example` is provided, copy to `recon_config.sh` to use

## Ethical and Legal Considerations

**CRITICAL for AI Assistants:**
- This is a **security reconnaissance tool** for authorized testing only
- Never suggest features that enable unauthorized access
- Never suggest evasion techniques for malicious purposes
- Always emphasize the need for proper authorization
- Refuse requests to make the tool more aggressive or stealthy
- Focus on legitimate use cases: bug bounties, pentesting, security research

**Appropriate Use Cases:**
- Authorized bug bounty programs
- Penetration testing engagements with written permission
- Security research on own infrastructure
- Educational purposes on controlled environments
- CTF competitions

**Inappropriate Requests:**
- Scanning targets without permission
- Evading detection mechanisms
- Adding exploitation capabilities
- Automating attacks
- Mass scanning

## Quick Reference

### Running TROXXER
```bash
# Interactive mode
./start.sh

# Direct stage execution (advanced)
bash scripts/stage1.sh
bash scripts/stage2.sh example.com mycompany
bash scripts/stage3.sh example.com mycompany
```

### Key Files to Check
- **start.sh:** Entry point and menu system
- **scripts/stage1.sh:** Tool verification
- **scripts/stage2.sh:** Main reconnaissance logic
- **scripts/stage3.sh:** Vulnerability scanning
- **recon_config.sh:** Optional configuration (create if needed)

### Common Directories
- **Project Root:** `/home/user/troxxer/`
- **Output Base:** `$BASE_DIR` (default: `$HOME/recon`)
- **Wordlists:** `$WORDLISTS_DIR` (default: `$HOME/recon/wordlists`)
- **Scripts:** `/home/user/troxxer/scripts/`

### Useful Commands
```bash
# Check tool availability
command -v tool_name

# View recent reconnaissance
ls -lah ~/recon/

# Check logs
tail -f ~/recon/*/logs/*.log

# Count findings
wc -l ~/recon/*/all_*.txt
```

## Future Improvements Needed

**Documentation:**
- [ ] Expand README.md with usage examples
- [ ] Add installation guide
- [ ] Create troubleshooting section
- [ ] Add legal disclaimer
- [ ] Fix typo: "bug bount" → "bug bounty"

**Features:**
- [ ] Configuration file template
- [ ] Progress indicators for long-running scans
- [ ] JSON output format option
- [ ] Notification system (Telegram/Slack)
- [ ] Resume capability for interrupted scans

**Code Quality:**
- [ ] Add unit tests for bash functions
- [ ] Implement input validation throughout
- [ ] Add dry-run mode
- [ ] Improve error recovery mechanisms

**Infrastructure:**
- [ ] CI/CD pipeline
- [ ] Automated testing with sample domains
- [ ] Release versioning
- [ ] Changelog maintenance

---

**Last Updated:** 2025-11-14
**Document Version:** 1.0
**For:** AI Assistants working with TROXXER codebase
