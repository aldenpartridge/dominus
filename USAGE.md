  # TROXXER Usage Guide

Quick reference for using TROXXER v2.0 with all new features.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Running Scans](#running-scans)
- [Using Wrappers](#using-wrappers)
- [Features](#features)
- [Output Files](#output-files)
- [Troubleshooting](#troubleshooting)

## Quick Start

### First Time Setup

```bash
# 1. Clone repository
git clone https://github.com/aldenpartridge/troxxer.git
cd troxxer

# 2. Make scripts executable
chmod +x start.sh scripts/*.sh

# 3. Verify tools (with automatic installation!)
./start.sh
# Select option 1: Verify Tools & Environment
# The script will check for missing tools and offer to install them automatically
# Answer 'yes' to auto-install Go tools, Python tools, and system packages

# 4. (Optional) Create configuration
cp recon_config.sh.example recon_config.sh
nano recon_config.sh
```

### Automatic Tool Installation (NEW!)

**Stage 1 now includes automatic installation capability:**

**What gets auto-installed:**
- **Go tools** (18 tools): subfinder, httpx, nuclei, dnsx, naabu, katana, etc.
- **Python tools** (3 tools via pipx): paramspider, arjun, uro
- **System packages** (2 tools): nmap, jq

**Manual installation required:**
- findomain (binary release)
- aquatone (binary release)
- massdns (compile from source)

**How it works:**
1. Run `./start.sh` and select option 1
2. Script checks all 25+ tools
3. Groups missing tools by installation method
4. Prompts: "Would you like to automatically install missing tools?"
5. If you answer 'yes':
   - Installs all Go tools via `go install`
   - Installs Python tools via `pipx install`
   - Installs system packages via detected package manager
6. Verifies installations and shows results
7. Provides PATH configuration hints if needed

**Prerequisites:**
- Go installed (for Go tools)
- pipx installed (for Python tools)
- sudo access (for system packages like nmap, jq)

**Supported package managers:**
- pacman (Arch Linux)
- apt (Debian/Ubuntu)
- yum/dnf (RHEL/Fedora)
- brew (macOS)

### Basic Scan

```bash
# Interactive mode (recommended for beginners)
./start.sh
# Select option 2: Execute Full Reconnaissance Pipeline
# Enter target domain when prompted
# Confirm authorization
```

## Configuration

### Creating Your Config File

```bash
# Copy example configuration
cp recon_config.sh.example recon_config.sh

# Edit configuration
nano recon_config.sh
```

### Key Settings to Configure

#### Performance Tuning
```bash
export DEFAULT_THREADS=25        # Adjust based on your CPU
export HTTPX_THREADS=50          # HTTP probing threads
export CONCURRENCY=25            # Concurrent tool executions
export RATE_LIMIT=150            # Requests per second
```

#### Notifications (Optional)
```bash
export ENABLE_NOTIFICATIONS=true
export TELEGRAM_BOT_TOKEN="your_bot_token"
export TELEGRAM_CHAT_ID="your_chat_id"
```

#### Features
```bash
export ENABLE_RESUME=true        # Resume interrupted scans
export ENABLE_JSON=true          # Generate JSON reports
export ENABLE_CACHE=true         # Cache results for 24h
export DRY_RUN=false             # Set true to test without running
```

### Telegram Bot Setup

1. Create bot with [@BotFather](https://t.me/botfather)
2. Copy bot token
3. Get your chat ID from [@userinfobot](https://t.me/userinfobot)
4. Add to config:
```bash
export TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
export TELEGRAM_CHAT_ID="123456789"
```

5. Test with option 3 in main menu

## Running Scans

### Method 1: Interactive Menu (Recommended)

```bash
./start.sh
```

**Menu Options:**
- **1** - Verify Tools & Environment
- **2** - Execute Full Reconnaissance Pipeline
- **3** - Test Notification Systems
- **4** - Clear Cache
- **5** - View Configuration
- **0** - Exit

### Method 2: Direct Execution

```bash
# Run stage 2 (reconnaissance) directly
bash scripts/stage2.sh example.com mycompany

# Run stage 3 (vulnerability scanning) directly
bash scripts/stage3.sh example.com mycompany
```

### Method 3: Enhanced Wrappers (v2.0 Features)

```bash
# Stage 2 with v2.0 features (resume, notifications, JSON)
bash scripts/stage2_wrapper.sh example.com mycompany

# Stage 3 with v2.0 features
bash scripts/stage3_wrapper.sh example.com mycompany
```

## Using Wrappers

The wrapper scripts add v2.0 features to the original reconnaissance logic.

### Stage 2 Wrapper Features

- ✅ Automatic resume of interrupted scans
- ✅ Scan start notification
- ✅ Progress tracking and state management
- ✅ JSON report generation
- ✅ Markdown report generation
- ✅ Scan completion notification
- ✅ Error notifications

**Example:**
```bash
# Set up notifications in recon_config.sh first
export ENABLE_NOTIFICATIONS=true
export TELEGRAM_BOT_TOKEN="..."
export TELEGRAM_CHAT_ID="..."

# Run wrapper
bash scripts/stage2_wrapper.sh example.com example-recon
```

### Stage 3 Wrapper Features

- ✅ All stage 2 wrapper features
- ✅ Critical vulnerability notifications
- ✅ HTML report generation
- ✅ Complete scan summary
- ✅ Progress report display

**Example:**
```bash
bash scripts/stage3_wrapper.sh example.com example-recon
```

## Features

### Resume Capability

Scans can be resumed if interrupted:

```bash
# Start a scan
./start.sh  # Option 2

# If interrupted (Ctrl+C), run again
./start.sh  # Option 2
# Enter same domain and operation name
# Select "yes" when asked to resume
```

**How it works:**
- Checkpoint saved after each phase
- Resume prompt shows last completed phase
- Skips completed phases automatically
- Continues from interruption point

### Dry Run Mode

Test what would be executed without running:

```bash
# In recon_config.sh
export DRY_RUN=true

# Run any scan
./start.sh  # Option 2
# Shows commands without executing them
```

### Notification Testing

```bash
./start.sh  # Option 3

# Tests all configured notification methods:
# - Telegram (if configured)
# - Slack (if configured)
# - Discord (if configured)
```

### Cache Management

```bash
# View cache status
./start.sh  # Option 5

# Clear all cached data
./start.sh  # Option 4
```

**What gets cached:**
- DNS resolver lists
- Wordlists
- Tool outputs (if ENABLE_CACHE=true)

**Cache TTL:** 24 hours (configurable via CACHE_TTL)

## Output Files

### Standard Output Files

Location: `$BASE_DIR/$ORG_NAME/`

```
example-recon/
├── rootdomain.txt              # Target domain
├── metadata.txt                # Scan metadata
├── all_subs.txt                # All subdomains found
├── all_resolved.txt            # DNS-resolved subdomains
├── all_alive.txt               # Live HTTP/HTTPS services
├── open_ports.txt              # Port scan results
├── all_urls.txt                # All discovered URLs
├── all_params.txt              # URLs with parameters
├── all_js.txt                  # JavaScript files
├── sensitive_files.txt         # Potentially sensitive files
└── logs/
    ├── stage2_complete.log
    └── stage3_complete.log
```

### v2.0 Report Files

```
example-recon/
├── report.json                 # JSON format (machine-readable)
├── report_detailed.json        # JSON with full findings
├── REPORT.md                   # Markdown report (human-readable)
├── report.html                 # HTML report (browser-viewable)
├── findings.csv                # CSV export
└── vulnerability_scan/
    ├── nuclei_all_findings.txt
    ├── critical_high_findings.txt
    └── [individual scan results]
```

### State Files (Hidden)

```
example-recon/
├── .checkpoint                 # Resume checkpoint
├── .state                      # Scan state (counters, status)
└── .cache/                     # Cached data
```

## Troubleshooting

### Tools Not Found

```bash
./start.sh  # Option 1
# Shows missing tools with installation commands
# Install tools as suggested
```

### Permission Errors (naabu)

```bash
# Grant capabilities to naabu
sudo setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip $(which naabu)
```

### Rate Limiting / Blocked

Edit `recon_config.sh`:
```bash
export RATE_LIMIT=50            # Lower from 150
export CONCURRENCY=10           # Lower from 25
```

### Notifications Not Working

```bash
./start.sh  # Option 3
# Tests each notification method
# Shows specific errors

# Common issues:
# - Wrong bot token
# - Wrong chat ID
# - Invalid webhook URL
# - Network restrictions
```

### Resume Not Working

Check these:
1. Using same domain and operation name?
2. Checkpoint file exists? `ls $BASE_DIR/$ORG_NAME/.checkpoint`
3. Checkpoint not too old? (24 hour limit)
4. ENABLE_RESUME=true in config?

### JSON Report Not Generated

Check:
```bash
./start.sh  # Option 5
# Look for ENABLE_JSON status

# If needed, enable in config:
export ENABLE_JSON=true
```

### High Memory Usage

Reduce concurrency:
```bash
export CONCURRENCY=10           # Lower from 25
export DEFAULT_THREADS=10       # Lower from 25
```

### Scan Takes Too Long

Speed up:
```bash
export HTTPX_THREADS=100        # Increase from 50
export RATE_LIMIT=300           # Increase from 150
export CONCURRENCY=50           # Increase from 25

# Skip port scanning (optional):
export SKIP_PORT_SCAN=true
```

## Advanced Usage

### Custom Wordlists

```bash
# In recon_config.sh
export SUBDOMAIN_WORDLIST="/path/to/custom/wordlist.txt"
export ENABLE_BRUTEFORCE=true
```

### Proxy Configuration

```bash
# In recon_config.sh
export HTTP_PROXY="http://proxy:8080"
export HTTPS_PROXY="http://proxy:8080"
```

### Passive Mode Only

```bash
# In recon_config.sh
export PASSIVE_ONLY=true        # No active DNS queries
export SKIP_PORT_SCAN=true      # No port scanning
```

### Custom Resolvers

```bash
# In recon_config.sh
export RESOLVERS_FILE="/path/to/resolvers.txt"
```

### Scope File

Create `scope.txt`:
```
example.com
*.example.com
api.example.com
# Comments allowed
```

Then:
```bash
# In recon_config.sh
export SCOPE_FILE="$PWD/scope.txt"
```

## Best Practices

### 1. Always Get Authorization
- Written permission for pentests
- Verify bug bounty scope
- Document authorization

### 2. Start Conservative
- Use default rate limits first
- Monitor for blocks
- Increase gradually if needed

### 3. Use Notifications
- Get updates on long scans
- Immediate alert for critical findings
- Track scan completion

### 4. Review Results
- Don't trust automated findings blindly
- Manually verify vulnerabilities
- Check for false positives

### 5. Organize Scans
- Use descriptive operation names
- Keep separate scans per program
- Archive old scans

## Getting Help

### Check Documentation
- README.md - General overview
- CLAUDE.md - Developer guide
- CHANGELOG.md - What's new
- This file - Usage examples

### Common Commands

```bash
# View configuration
./start.sh  # Option 5

# Test setup
./start.sh  # Option 1

# Clear cache if issues
./start.sh  # Option 4

# Check logs
tail -f $BASE_DIR/logs/troxxer.log
tail -f $BASE_DIR/$ORG_NAME/logs/stage2_complete.log
```

### Debug Mode

```bash
# In recon_config.sh
export VERBOSITY=3              # Enable debug output

# Run scan - will show detailed debug info
```

---

**Need more help?** Check the GitHub issues or create a new one with:
- Your configuration (sanitized)
- Error messages
- Steps to reproduce
- Expected vs actual behavior
