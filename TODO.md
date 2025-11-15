# DOMINUS TODO - Future Improvements & Features

Organized roadmap for future development of DOMINUS.

**Legend:**
- 🔥 High Priority / Quick Win
- ⭐ Medium Priority / Feature Enhancement
- 🚀 Long Term / Major Feature
- 💡 Idea / Nice to Have
- 🔧 Technical Debt / Refactoring

---

## 🔥 High Priority (v2.1)

### Performance & Efficiency

- [🔥] **Diff Mode for Comparing Scans**
  - Compare current scan with previous scan
  - Show new subdomains, URLs, vulnerabilities
  - Highlight changes and additions
  - Track scope expansion over time
  - Output: `changes_YYYY-MM-DD.txt` with diff summary
  - Use case: Track new attack surface in bug bounty programs

- [🔥] **Smart Caching with Dependency Tracking**
  - Cache subdomain enumeration results (24h TTL)
  - Cache DNS resolutions (12h TTL)
  - Skip phases if cached data is fresh
  - Invalidate cache when dependencies change
  - Configurable cache behavior per phase
  - Estimated time savings: 30-50% on repeated scans

- [🔥] **Progress Bars and ETA**
  - Real-time progress for each phase
  - Estimated time remaining
  - Speed metrics (subdomains/sec, URLs/sec)
  - Better UX for long-running operations
  - Use `pv` if available, fallback to custom implementation

- [🔥] **Resume from Checkpoint Improvements**
  - Currently exists in lib/resume.sh but not fully integrated
  - Add checkpoint after each phase in stage2/stage3
  - Auto-resume on interrupt detection
  - Show resume prompt with progress summary
  - Clean up stale checkpoints (>24h old)

### Usability Enhancements

- [🔥] **Interactive Result Viewer with fzf**
  - Browse findings interactively
  - Filter by severity, type, domain
  - Quick preview of vulnerability details
  - Copy-paste URLs/findings
  - Launch browser for quick validation
  - Integration: `./start.sh` → Option 7: Browse Results

- [🔥] **Better Error Messages and Debugging**
  - Structured error logging with context
  - Debug mode with verbose output (`VERBOSITY=3`)
  - Error categorization (network, permissions, missing tools)
  - Suggested remediation for common errors
  - Error summary at end of scan

- [🔥] **Installation Script Improvements**
  - Create `install.sh` for one-command setup
  - Install GNU Parallel automatically (major speedup)
  - Configure API keys interactively
  - Set up systemd service for scheduled scans (optional)
  - Verify all prerequisites and dependencies

---

## ⭐ Medium Priority (v2.2)

### Reconnaissance Features

- [⭐] **Screenshot Integration (gowitness/aquatone)**
  - Capture screenshots of all live HTTP services
  - Organize by subdomain/URL
  - Generate thumbnail gallery in HTML report
  - Identify interesting pages visually
  - Integration point: After stage2 phase 3 (HTTP probing)

- [⭐] **Technology Fingerprinting**
  - Detect web frameworks (React, Vue, Django, etc.)
  - Identify WAF/CDN (Cloudflare, Akamai)
  - Version detection for common software
  - CMS detection (WordPress, Joomla, Drupal)
  - Output: `technologies.json` with organized data
  - Tools: `wappalyzer`, `whatweb`, nuclei templates

- [⭐] **API Endpoint Discovery**
  - Extract API endpoints from JavaScript
  - Parse Swagger/OpenAPI specs
  - Identify GraphQL endpoints
  - Test common API paths
  - Output: `api_endpoints.txt` with methods
  - Tools: `katana`, custom JS parser, `arjun`

- [⭐] **Subdomain Permutation**
  - Generate subdomain permutations (dev-, staging-, api-, etc.)
  - Test common patterns
  - Use wordlist-based permutation
  - Integration: Add to stage2 phase 1
  - Tools: `dnsgen`, `altdns`, `gotator`

- [⭐] **Cloud Asset Enumeration**
  - S3 bucket discovery
  - Azure blob storage enumeration
  - GCP bucket finding
  - Digital Ocean Spaces
  - Output: `cloud_assets.txt`
  - Tools: `cloud_enum`, `S3Scanner`

### Output & Reporting

- [⭐] **Enhanced HTML Reports**
  - Modern responsive design
  - Interactive charts (timeline, severity distribution)
  - Collapsible sections
  - Search/filter functionality
  - Dark mode support
  - Export individual sections

- [⭐] **JSON Schema Validation**
  - Define JSON schema for reports
  - Validate output structure
  - Enable programmatic consumption
  - Support for CI/CD integration

- [⭐] **Markdown Report Enhancements**
  - Add timeline visualization
  - Include statistics and graphs (ASCII art)
  - Executive summary section
  - Remediation recommendations
  - CVSS scoring for vulnerabilities

- [⭐] **Export to Bug Bounty Platforms**
  - Pre-formatted reports for HackerOne
  - Bugcrowd template export
  - Intigriti format
  - Severity mapping to platform standards

### Integration & Automation

- [⭐] **Webhook Notifications**
  - Generic webhook support (not just Telegram/Slack/Discord)
  - Custom payload templates
  - Conditional notifications (only on critical findings)
  - Rate limiting to prevent spam

- [⭐] **CI/CD Integration Examples**
  - GitHub Actions workflow template
  - GitLab CI example
  - Jenkins pipeline
  - Scheduled scans with cron
  - Automated diff reports

- [⭐] **Scope Management**
  - Import scope from Bugcrowd/HackerOne
  - Parse in-scope/out-of-scope rules
  - Validate findings against scope
  - Auto-filter out-of-scope results
  - Support for CIDR notation, wildcards

---

## 🚀 Long Term (v3.0+)

### Architecture & Performance

- [🚀] **Parallel Phase Execution**
  - Run independent phases concurrently
  - Example: URL discovery + param discovery + JS discovery in parallel
  - Resource-aware scheduling
  - Dependency graph for phases
  - Estimated speedup: 30-40%

- [🚀] **Distributed Scanning**
  - Split work across multiple machines
  - Worker/coordinator architecture
  - Shared state via Redis/database
  - Scale horizontally for massive scopes
  - Use case: Enterprise-scale reconnaissance

- [🚀] **Complete Rewrite in Go**
  - Better performance and concurrency
  - Native cross-platform support (Linux, macOS, Windows)
  - Single binary distribution
  - Easier installation and updates
  - Maintain bash scripts as legacy option

### Advanced Features

- [🚀] **Web Dashboard**
  - Real-time scan monitoring
  - Historical trend analysis
  - Vulnerability tracking over time
  - Team collaboration features
  - Asset inventory management
  - RESTful API backend

- [🚀] **Database Backend**
  - Store all findings in SQLite/PostgreSQL
  - Query capabilities for analysis
  - Trend detection
  - Deduplication across scans
  - Historical comparison queries

- [🚀] **Machine Learning Integration**
  - Vulnerability prioritization using ML
  - False positive reduction
  - Pattern recognition in findings
  - Anomaly detection
  - Intelligent scope expansion suggestions

- [🚀] **Plugin System**
  - Custom phase plugins
  - User-defined scan types
  - Community-contributed modules
  - Plugin marketplace
  - Hot-reloading of plugins

### Intelligence & Analysis

- [🚀] **Correlation Engine**
  - Link related findings across subdomains
  - Identify attack chains
  - Suggest exploitation paths
  - Risk scoring based on context

- [🚀] **OSINT Integration**
  - Shodan integration
  - Censys integration
  - GitHub code search
  - Certificate transparency logs
  - Historical DNS records
  - WHOIS enrichment

- [🚀] **Automated Validation**
  - Verify vulnerability findings
  - Reduce false positives
  - PoC generation for valid findings
  - Safe exploitation testing

---

## 💡 Ideas / Nice to Have

### Workflow Enhancements

- [💡] **Multi-Target Support**
  - Scan multiple domains in one session
  - Shared output directory with org structure
  - Aggregate statistics across targets
  - Useful for multi-domain programs

- [💡] **Scan Profiles/Presets**
  - Quick scan (passive only, fast)
  - Standard scan (current default)
  - Deep scan (all tools, aggressive)
  - Stealth scan (rate-limited, passive-first)
  - Custom profiles via config

- [💡] **Smart Recommendations**
  - Suggest next steps based on findings
  - Recommend additional tools
  - Highlight high-value targets
  - Prioritize testing order

- [💡] **Live Monitoring Mode**
  - Continuous monitoring of scope
  - Alert on new subdomains/changes
  - RSS feed of findings
  - Integration with monitoring services

### Collaboration Features

- [💡] **Team Sharing**
  - Export findings for team members
  - Import findings from teammates
  - Merge scan results
  - Claim/assign vulnerabilities
  - Comments and notes on findings

- [💡] **Template Library**
  - Reusable scan configurations
  - Share templates community-wide
  - Import templates from repository
  - Version control for templates

### Quality of Life

- [💡] **Configuration Wizard**
  - Interactive setup on first run
  - Guide through API key configuration
  - Performance tuning based on system specs
  - Notification setup wizard

- [💡] **Update Checker**
  - Check for new DOMINUS versions
  - Auto-update capability (opt-in)
  - Changelog display
  - Tool version checking

- [💡] **Scan Scheduling**
  - Cron-based scheduling
  - Recurring scans (daily, weekly)
  - Off-peak scheduling
  - Email reports on completion

- [💡] **Resource Monitoring**
  - Track CPU/memory usage
  - Bandwidth monitoring
  - Disk space alerts
  - Auto-throttle on resource constraints

### Data Management

- [💡] **Scan Archive Management**
  - Compress old scans
  - Auto-cleanup of old data
  - Export/import scan archives
  - Cloud backup integration (S3, GCS)

- [💡] **Data Deduplication**
  - Dedupe findings across scans
  - Identify unique vs. recurring issues
  - Track when issues were first/last seen

---

## 🔧 Technical Debt / Refactoring

### Code Quality

- [🔧] **Automated Testing Framework**
  - Unit tests for library functions
  - Integration tests for full pipeline
  - Mock data for testing
  - CI/CD test execution
  - Coverage reporting

- [🔧] **Code Linting and Standards**
  - ShellCheck integration
  - Consistent formatting (shfmt)
  - Pre-commit hooks
  - Style guide documentation

- [🔧] **Input Validation Hardening**
  - Comprehensive validation in validation.sh
  - Prevent command injection
  - Path traversal prevention (already started)
  - Rate limiting user inputs

- [🔧] **Error Handling Standardization**
  - Consistent error codes
  - Structured error responses
  - Proper cleanup on errors
  - Transaction-like operations

### Documentation

- [🔧] **CONTRIBUTING.md**
  - Contribution guidelines
  - Code style requirements
  - PR process
  - Issue templates

- [🔧] **API Documentation**
  - Document all library functions
  - Parameter descriptions
  - Return value specifications
  - Usage examples

- [🔧] **Troubleshooting Guide**
  - Common error scenarios
  - Resolution steps
  - FAQ section
  - Known issues

### Modularization

- [🔧] **Extract Core Functions**
  - Separate tool execution logic
  - Reusable pipeline components
  - Abstract tool interfaces
  - Plugin-ready architecture

- [🔧] **Configuration Refactoring**
  - Centralized config management
  - Config validation on load
  - Environment variable support
  - Config merging (user + default)

---

## Recently Completed ✅

### v2.0 (2025-11-14)

- ✅ Comprehensive CLAUDE.md documentation
- ✅ Bug bounty program discovery (chaos-programs.sh)
- ✅ Automatic tool installation (stage1.sh)
- ✅ Configuration template (recon_config.sh.example)
- ✅ Library system (lib/ directory)
- ✅ Notification system (Telegram, Slack, Discord)
- ✅ Resume capability (lib/resume.sh)
- ✅ Multiple output formats (JSON, Markdown, HTML, CSV)
- ✅ Enhanced start.sh menu
- ✅ Legal authorization prompt
- ✅ Bulk download with parallel execution (GNU Parallel, xargs -P)
- ✅ Fixed hardcoded /home/grox paths
- ✅ Fixed JSON parsing in bulk download
- ✅ Performance optimizations (5-10x faster bulk downloads)
- ✅ README.md improvements
- ✅ CHANGELOG.md
- ✅ USAGE.md

---

## Contributing

Have an idea for DOMINUS?

1. Check if it's already in this TODO
2. Open an issue describing the feature
3. Discuss feasibility and approach
4. Submit a PR if you'd like to implement it!

**Priority Guidelines:**
- Security improvements → Always high priority
- Performance optimizations → Usually high priority
- User experience → Medium-high priority
- New features → Medium priority (unless critical)
- Nice-to-haves → Low priority (but still welcome!)

---

## Notes

### Version Planning

**v2.1 Focus:** Performance & UX
- Diff mode
- Smart caching
- Progress bars
- fzf integration
- Better error handling

**v2.2 Focus:** Advanced Recon & Reporting
- Screenshots
- Technology fingerprinting
- Enhanced reports
- CI/CD integration
- Webhook improvements

**v3.0 Focus:** Architecture & Scale
- Go rewrite
- Web dashboard
- Database backend
- Distributed scanning
- ML integration

### Philosophy

DOMINUS should remain:
- **Easy to use** - Simple for beginners, powerful for experts
- **Fast** - Performance is a feature
- **Reliable** - Handle errors gracefully
- **Flexible** - Configurable for different use cases
- **Safe** - Security-first design
- **Open** - Community-driven development

### Help Wanted

These features would benefit from community contributions:
- Web dashboard (React/Vue frontend developers)
- Go rewrite (Go developers familiar with concurrency)
- ML integration (Data science background)
- CI/CD examples (DevOps experience)
- Mobile app (React Native/Flutter)

---

**Last Updated:** 2025-11-14
**Version:** 2.0
**Maintainer:** @aldenpartridge
