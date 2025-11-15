# DOMINUS

**Automated Bug Bounty Reconnaissance Suite**

DOMINUS is a comprehensive bash-based security reconnaissance framework designed to automate the discovery of subdomains, URLs, vulnerabilities, and potential security issues for authorized bug bounty programs and penetration testing engagements.

## Features

- **Automatic Tool Installation:** One-command setup that auto-installs missing tools
- **Bug Bounty Program Discovery:** Browse and download scopes from 500+ programs (no API key needed!)
- **Bulk Scope Download:** Download ALL bug bounty scopes with one command to `./subdomains/`
- **Multi-Stage Pipeline:** Automated 3-stage reconnaissance workflow
- **25+ Tool Integration:** Seamlessly orchestrates popular security tools
- **Intelligent Error Handling:** Graceful degradation with fallback mechanisms
- **Organized Output:** Structured directory layout for all findings
- **Resume Capability:** Continue interrupted scans from last checkpoint
- **Flexible Configuration:** Customizable settings via configuration file
- **Notification Support:** Telegram, Slack, and Discord integration
- **JSON Export:** Machine-readable output formats

## Quick Start

```bash
# Clone repository
git clone https://github.com/aldenpartridge/dominus.git
cd dominus

# Make scripts executable
chmod +x start.sh scripts/*.sh

# Verify tools and setup environment (with auto-install!)
./start.sh
# Select option 1: Verify Tools & Environment
# Answer 'yes' when prompted to automatically install missing tools

# Run reconnaissance (with explicit authorization)
./start.sh
# Select option 2: Execute Full Reconnaissance Pipeline
```

## Prerequisites

### Operating System
- Linux-based system (tested on Arch Linux)
- Bash 4.0 or higher

### Core Tools (Minimum)
- subfinder
- httpx
- nuclei
- dnsx
- waybackurls

### Enhanced Tools (Recommended)
See full list in `scripts/stage1.sh` or run the tool verification script.

Install most tools via Go:
```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
```

## Configuration

Copy the example configuration and customize:
```bash
cp recon_config.sh.example recon_config.sh
nano recon_config.sh
```

Configure API keys for enhanced results:
- Subfinder: `~/.config/subfinder/provider-config.yaml`
- GitHub token for archive access
- Notification webhook URLs (optional)

## Usage

### Browse Bug Bounty Programs (NEW!)

Discover and download scopes from 500+ bug bounty programs using ProjectDiscovery's public Chaos data:

```bash
# Bulk download ALL program scopes (via interactive menu)
./start.sh
# Select option 6: Download All Bug Bounty Scopes
# Choose to filter by bounty-only or download all
# Scopes saved to: ./subdomains/{program-name}/

# Individual program operations
bash scripts/chaos-programs.sh list          # List all programs
bash scripts/chaos-programs.sh search uber   # Search for programs
bash scripts/chaos-programs.sh download uber # Download single program
bash scripts/chaos-programs.sh stats         # Show statistics
```

**No API key required!** All data is publicly available.

**Bulk Download Benefits:**
- Download 500+ program scopes at once
- **Parallel downloads** - 5-10x faster with GNU Parallel or xargs
- Configurable concurrency (default: 10 parallel downloads)
- Organized in `./subdomains/{program-name}/`
- Auto-extraction of zip files
- Skip already downloaded programs
- Filter by bounty-only programs
- Automatic retry on failures
- Progress tracking and statistics
- Great for building a local scope database

**Performance:**
- Sequential: ~1-2 programs/second
- With xargs -P: ~5-8 programs/second (5x faster)
- With GNU Parallel: ~10-15 programs/second (10x faster!)

### Interactive Mode
```bash
./start.sh
```

### Direct Stage Execution (Advanced)
```bash
# Stage 1: Verify tools and environment
bash scripts/stage1.sh

# Stage 2: Run reconnaissance
bash scripts/stage2.sh example.com mycompany

# Stage 3: Vulnerability scanning
bash scripts/stage3.sh example.com mycompany
```

## Pipeline Stages

### Stage 1: Tool Verification
- Checks for 25+ security tools
- Sets up directory structure
- Downloads required wordlists and resolvers
- Provides installation commands for missing tools

### Stage 2: Reconnaissance (8 Phases)
1. Subdomain Enumeration
2. DNS Resolution
3. HTTP Probing
4. Port Scanning
5. URL Discovery
6. Parameter Discovery
7. JavaScript Discovery
8. Sensitive File Discovery

### Stage 3: Vulnerability Scanning (20 Scan Types)
- CVE scanning (critical/high and full database)
- Exposed admin panels
- Security misconfigurations
- XSS, SQLi, SSRF, RCE, LFI, IDOR
- Open redirects
- Default credentials
- Subdomain takeovers
- And more...

## Output Structure

```
$BASE_DIR/$ORG_NAME/
├── rootdomain.txt
├── metadata.txt
├── report.json                 # JSON format report
├── all_subs.txt               # All discovered subdomains
├── all_resolved.txt           # DNS-resolved hosts
├── all_alive.txt              # Live HTTP services
├── open_ports.txt             # Port scan results
├── all_urls.txt               # Discovered URLs
├── all_params.txt             # Parameterized URLs
├── all_js.txt                 # JavaScript files
├── sensitive_files.txt        # Potentially sensitive files
├── logs/
│   ├── stage2_complete.log
│   └── stage3_complete.log
└── vulnerability_scan/
    ├── nuclei_all_findings.txt
    ├── critical_high_findings.txt
    └── [individual scan results]
```

## Legal & Ethical Use

**IMPORTANT:** This tool is designed for authorized security testing only.

- ✅ Use for authorized bug bounty programs
- ✅ Use for penetration testing with written permission
- ✅ Use for security research on your own infrastructure
- ✅ Use for educational purposes in controlled environments
- ❌ **NEVER** scan targets without explicit authorization
- ❌ **NEVER** use for unauthorized access or malicious purposes

Unauthorized scanning may violate computer fraud and abuse laws in your jurisdiction. Always obtain proper authorization before testing.

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Follow existing code style and conventions (see CLAUDE.md)
4. Test thoroughly
5. Submit a pull request

## Documentation

- **README.md** - This file (user documentation)
- **CLAUDE.md** - Comprehensive guide for AI assistants and developers
- **USAGE.md** - Detailed usage guide with examples
- **CHANGELOG.md** - Version history and changes
- **TODO.md** - Roadmap and future features
- **recon_config.sh.example** - Configuration template

## Troubleshooting

### Common Issues

**Tools not found:**
```bash
./start.sh  # Select option 1 to verify tools
# Follow installation commands provided
```

**Permission errors with naabu:**
```bash
sudo setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip $(which naabu)
```

**Rate limiting / blocking:**
- Reduce `RATE_LIMIT` in configuration
- Lower `CONCURRENCY` settings
- Add delays between phases

## Performance

Typical execution times (varies by target):
- Stage 1: 1-2 minutes
- Stage 2: 15-45 minutes
- Stage 3: 20-60 minutes

## License

[Specify license here]

## Disclaimer

This tool is provided for educational and authorized security testing purposes only. Users are responsible for complying with all applicable laws and regulations. The authors assume no liability for misuse or damage caused by this tool.

## Author

Created for bug bounty automation and security research.

## Acknowledgments

This tool integrates and orchestrates the following excellent projects:
- ProjectDiscovery tools (subfinder, httpx, nuclei, dnsx, naabu, etc.)
- OWASP Amass
- TomNomNom's tools (waybackurls, anew, etc.)
- And many more in the security community

---

**Version:** 2.0
**Last Updated:** 2025-11-14
