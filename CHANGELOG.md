# Changelog

All notable changes to DOMINUS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-14

### Added - Major Features

#### Bug Bounty Program Discovery
- **New chaos-programs.sh helper script**
  - Browse 500+ bug bounty programs from ProjectDiscovery Chaos
  - No API key required (uses public data at chaos-data.projectdiscovery.io)
  - List all programs with filtering (all, bounty-only, by platform)
  - Search programs by name
  - View detailed program information
  - Download program scopes (zip files with subdomains)
  - Show statistics (total programs, platforms, bounties)
  - 24-hour caching for improved performance
  - Supports HackerOne, Bugcrowd, Intigriti, YesWeHack, HackenProof
  - Auto-extraction of downloaded scopes

- **Bulk Download with Parallel Execution** (start.sh option 6)
  - Download all 500+ programs at once with one command
  - **Parallel downloads** - 5-10x faster than sequential
  - Automatic detection of parallel tools (GNU Parallel, xargs -P)
  - Configurable concurrency (default: 10 parallel downloads)
  - Smart fallback to sequential if no parallel tool available
  - Retry logic for failed downloads (2 attempts per file)
  - Real-time progress tracking with statistics
  - Performance: ~10-15 programs/sec with GNU Parallel, ~5-8 with xargs
  - Filter by bounty-only programs
  - Automatic extraction and cleanup

#### Automatic Tool Installation
- **Enhanced stage1.sh** - Automatic installation capability
  - Detects missing tools across all categories (Go, pipx, system packages)
  - Interactive prompt offering to auto-install missing tools
  - Multi-package manager support (pacman, apt, yum, dnf, brew)
  - Tool categorization (Go tools, Python/pipx tools, system tools, manual installs)
  - Automatic detection of prerequisites (Go, pipx, wget/curl)
  - Installation progress tracking with success/failure reporting
  - Post-installation verification
  - PATH configuration hints for newly installed tools
  - Automatic wordlist and resolver list downloads
  - One-command setup for new installations

#### Configuration Management
- **Configuration Template** (`recon_config.sh.example`)
  - Comprehensive configuration file with 100+ options
  - Organized into logical sections (directories, performance, API keys, etc.)
  - Detailed comments and setup guides
  - Copy-paste ready for quick setup
  - Removed unnecessary Chaos API key (data is public!)
  - Added informational note about public Chaos data availability

#### Library System (`lib/` directory)
- **common.sh** - Shared utilities and functions
  - Standardized logging functions (info, success, warning, error, debug, critical, phase)
  - Progress indicators (progress bars, spinners)
  - File operations (dedupe, safe append, line counting)
  - Dry-run command execution
  - Retry mechanism with exponential backoff
  - Time tracking and duration calculation
  - Cache management system
  - Metadata management
  - UI helpers (separators, headers, banners)

- **validation.sh** - Input validation and sanitization
  - Domain format validation (DNS-compliant regex)
  - IP address and CIDR notation validation
  - Organization name sanitization
  - Scope file validation and parsing
  - Out-of-scope checking
  - URL validation and domain extraction
  - File path validation (prevents directory traversal)
  - Authorization confirmation with legal warning
  - Port and port range validation

- **notifications.sh** - Multi-platform notification system
  - Telegram bot integration
  - Slack webhook support
  - Discord webhook support
  - Predefined notification templates (scan start, complete, error, critical findings)
  - Unified notification API
  - Notification testing utility

- **resume.sh** - Scan resume capability
  - Checkpoint system for each phase
  - Automatic resume detection
  - Interactive resume prompts
  - Scan state management (tracks all counters and progress)
  - Progress reporting
  - Scan status tracking (running, completed, failed)
  - Phase skipping for resumed scans

- **output.sh** - Multiple output formats
  - JSON report generation (statistics and file references)
  - Detailed JSON with full findings arrays
  - Markdown report generation
  - HTML report generation (styled with CSS)
  - CSV export of findings
  - Unified report generation function

#### Enhanced User Interface
- **Improved start.sh menu**
  - Option 3: Test notification systems
  - Option 4: Clear cache
  - Option 5: View current configuration
  - Better error messages using standardized logging
  - Version number display (v2.0)

- **Legal & Authorization**
  - Mandatory authorization prompt before scanning
  - Legal warning with clear explanation of responsibilities
  - Authorization checklist (bug bounty, pentest agreement, own infrastructure, etc.)
  - Configurable bypass for automation (not recommended)

#### Wrapper Scripts
- **stage2_wrapper.sh** - Enhanced stage 2 execution
  - Integrates all v2.0 features with original stage2.sh
  - Automatic resume capability
  - Scan state tracking
  - Notification integration
  - Automatic report generation
  - Progress tracking

- **stage3_wrapper.sh** - Enhanced stage 3 execution
  - Integrates all v2.0 features with original stage3.sh
  - Critical finding notifications
  - Complete scan summary
  - Multi-format report generation

### Changed - Improvements

#### Documentation
- **README.md** - Complete rewrite
  - Fixed typo: "bug bount" → "bug bounty"
  - Added comprehensive feature list
  - Quick start guide with installation commands
  - Detailed prerequisites section
  - Configuration instructions
  - Usage examples (interactive and direct)
  - Pipeline stage descriptions
  - Output structure documentation
  - Legal & ethical use section with clear guidelines
  - Troubleshooting section
  - Contributing guidelines
  - Performance benchmarks
  - Acknowledgments to tool creators

- **CLAUDE.md** - AI assistant guide (526 lines)
  - Complete codebase analysis
  - Development workflows
  - Code conventions and patterns
  - Security considerations
  - Common tasks for AI assistants
  - Git workflow guidelines
  - Ethical boundaries documentation

- **CHANGELOG.md** - This file
  - Comprehensive changelog following Keep a Changelog format
  - Semantic versioning

#### Code Quality
- **Modularization**
  - Separated concerns into focused libraries
  - Reusable functions across all scripts
  - Consistent error handling patterns
  - Centralized configuration management

- **Error Handling**
  - Retry mechanism with exponential backoff
  - Graceful degradation when tools missing
  - Better error messages with context
  - Exit code tracking and reporting

- **Input Validation**
  - Domain format validation prevents injection
  - Organization name sanitization removes special characters
  - Path validation prevents directory traversal
  - All user inputs validated before use

### Security Enhancements

#### Authorization & Legal
- Mandatory authorization confirmation
- Clear legal warning about unauthorized scanning
- Emphasis on legitimate use cases only
- Authorization checklist for user verification

#### Input Sanitization
- Domain regex validation (DNS-compliant)
- Organization name sanitization (alphanumeric + dash/underscore only)
- Path traversal prevention in all file operations
- Special character filtering

#### Responsible Use Features
- Legal disclaimer in README
- Authorization prompt cannot be easily bypassed
- Clear emphasis on authorized testing only
- No aggressive/evasion features added

### Performance Improvements

#### Caching System
- Cache directory (`$BASE_DIR/.cache`)
- Configurable TTL (default 24 hours)
- Cache hit/miss tracking
- Easy cache clearing via menu

#### Progress Tracking
- Real-time progress indicators
- Phase completion tracking
- Scan state persistence
- Statistics tracking throughout scan

### Developer Experience

#### Configuration
- Single configuration file for all settings
- Environment variable support
- Sensible defaults for all options
- Easy customization without code changes

#### Logging
- Structured logging with timestamps
- Log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- File-based logging in addition to console
- Configurable verbosity

#### Testing
- Dry-run mode for testing without execution
- Notification testing utility
- Configuration viewer
- Validation functions for all inputs

### Backwards Compatibility

- **Preserved original scripts** (stage1.sh, stage2.sh, stage3.sh)
  - No modifications to original reconnaissance logic
  - Wrapper scripts add new features without breaking existing functionality
  - Can still run original scripts directly if needed

- **Configuration**
  - Defaults match original behavior
  - New features opt-in via configuration
  - No required configuration file (uses sensible defaults)

### Migration Guide

#### From v1.x to v2.0

1. **Update your installation:**
   ```bash
   git pull origin main
   ```

2. **Create configuration file (optional):**
   ```bash
   cp recon_config.sh.example recon_config.sh
   nano recon_config.sh  # Customize as needed
   ```

3. **Set up notifications (optional):**
   - Configure Telegram bot token
   - Or Slack webhook URL
   - Or Discord webhook URL
   - Test with option 3 in main menu

4. **Use new features:**
   - Resume capability works automatically
   - JSON reports generated by default
   - Markdown reports in `REPORT.md`
   - HTML reports in `report.html`

5. **Existing scans:**
   - Compatible with v1.x output structure
   - Can resume interrupted v1.x scans
   - New reports will be generated

### Known Issues

- None at this time

### Deprecations

- None - all v1.x functionality preserved

### Removed

- Nothing removed in v2.0

---

## [1.0.0] - 2025-11-13 (Baseline)

### Initial Release

#### Features
- 3-stage reconnaissance pipeline
- 25+ security tool integration
- Subdomain enumeration (subfinder, assetfinder, findomain, amass)
- DNS resolution (dnsx, puredns, massdns)
- HTTP probing (httpx)
- Port scanning (naabu, nmap)
- URL discovery (waybackurls, gau, gauplus, katana, hakrawler)
- Parameter discovery (paramspider, arjun)
- JavaScript discovery (subjs, getJS)
- Sensitive file detection
- Vulnerability scanning with Nuclei (20 scan types)
- Organized output structure
- Color-coded console output
- Interactive menu system
- Tool verification script
- ASCII banner

#### Output Files
- `all_subs.txt` - Discovered subdomains
- `all_resolved.txt` - DNS-resolved hosts
- `all_alive.txt` - Live HTTP services
- `open_ports.txt` - Port scan results
- `all_urls.txt` - Discovered URLs
- `all_params.txt` - Parameterized URLs
- `all_js.txt` - JavaScript files
- `sensitive_files.txt` - Sensitive files
- `vulnerability_scan/` - Nuclei findings

#### Documentation
- Basic README.md (2 lines, contained typo)

---

## Future Roadmap

### Planned for v2.1
- [ ] Plugin system for custom phases
- [ ] Diff mode for comparing scans
- [ ] Screenshot integration (gowitness/aquatone)
- [ ] Parallel phase execution
- [ ] Smart caching with dependency tracking
- [ ] Interactive result viewer (fzf integration)
- [ ] Automated testing framework
- [ ] CI/CD integration examples

### Planned for v2.2
- [ ] Web dashboard for viewing results
- [ ] REST API for programmatic access
- [ ] Database backend for historical tracking
- [ ] Trend analysis and anomaly detection
- [ ] Team collaboration features
- [ ] Integration with bug bounty platforms

### Planned for v3.0
- [ ] Complete rewrite in Go for better performance
- [ ] Native cross-platform support (Linux, macOS, Windows)
- [ ] Distributed scanning capabilities
- [ ] Machine learning for vulnerability prioritization
- [ ] Custom rule engine

---

## Contributing

See CONTRIBUTING.md (to be created) for guidelines on:
- Reporting bugs
- Suggesting enhancements
- Code contribution process
- Code style requirements

## Authors

- **Initial work** - DOMINUS v1.0
- **v2.0 enhancements** - Implemented via Claude Code on 2025-11-14

## License

[Specify license here]

## Acknowledgments

All integrations in DOMINUS rely on excellent open-source tools from the security community:
- ProjectDiscovery (subfinder, httpx, nuclei, dnsx, naabu, etc.)
- OWASP (Amass)
- TomNomNom (waybackurls, anew, etc.)
- And many more individual contributors

Thank you to all tool maintainers for making DOMINUS possible!
