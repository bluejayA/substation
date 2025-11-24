# Substation - OpenStack TUI

![Substation Logo](assets/substation-logo-icon.png#only-light)
![Substation Logo](assets/substation-logo-icon-lt.png#only-dark)

## TUI (Terminal User Interface) for OpenStack Cloud Management

Substation is a comprehensive terminal user interface for OpenStack that provides operators with powerful, efficient, and intuitive cloud infrastructure management capabilities.

**Translation**: It's a terminal app for managing OpenStack that doesn't make you want to rage-quit at 3 AM.

![Substation Dashboard](assets/substation-enjoy.gif)

## Why Substation?

### Performance First (Because Slow Tools Cost Sleep)

- **Designed for up to 60-80% API call reduction** through multi-level caching
- **Target: Sub-second response times** for most operations (actual performance depends on OpenStack deployment)
- **Parallel search** across 6 OpenStack services simultaneously
- **Real-time performance monitoring** with automatic regression detection

### Operator Focused (Built By Operators Who've Been There)

- **Keyboard-driven** navigation (mouse optional)
- **Context-aware help** (press `?` when lost)
- **Multi-region support** for distributed clouds
- **Comprehensive error recovery** with exponential backoff retry

## Quick Links

### Getting Started

- **[Quick Start Guide](quick-start.md)** - Get up and running in 1 minute
- **[Installation](installation/index.md)** - Detailed installation instructions
- **[Configuration](configuration/index.md)** - clouds.yaml setup

### For Operators

- **[Navigation Guide](reference/operators/keyboard-shortcuts.md)** - Master keyboard shortcuts
- **[Common Workflows](reference/operators/workflows.md)** - Everyday operations
- **[Troubleshooting](troubleshooting/index.md)** - When things go wrong

### For Developers

- **[Developer Guide](reference/developers/index.md)** - Contributing to Substation
- **[FormBuilder Guide](reference/developers/formbuilder-guide.md)** - Building forms
- **[API Reference](reference/api/index.md)** - Using Substation packages

### Deep Dives

- **[Architecture](architecture/index.md)** - System design and patterns
- **[Performance](performance/index.md)** - Optimization and benchmarks
- **[Security](concepts/security.md)** - Protection and best practices
- **[Object Storage](concepts/object-storage.md)** - Swift integration, ETAG optimization, and best practices

## What You Get

### Complete OpenStack Resource Management

- **Compute (Nova)**: Servers, flavors, keypairs, server groups
- **Networking (Neutron)**: Networks, subnets, routers, security groups, floating IPs
- **Storage (Cinder)**: Volumes, snapshots, backups
- **Object Storage (Swift)**: Containers, objects, bulk transfers with ETAG optimization
- **Images (Glance)**: OS images and snapshots
- **Secrets (Barbican)**: Secure credential storage

### Advanced Features

- **Intelligent Caching** - Multi-level (L1/L2/L3) cache hierarchy
- **Parallel Search** - Cross-service search in < 500ms (target)
- **Batch Operations** - Process 100+ resources simultaneously
- **Real-time Updates** - Auto-refresh with configurable intervals
- **Health Monitoring** - Performance metrics and alerting

## System Requirements

- **OS**: macOS 13+ or Linux
- **Terminal**: Any terminal with ncurses support
- **OpenStack**: Designed for Queens or later releases (Caracal+ recommended for full feature compatibility)
  - Note: Version detection is not enforced - Substation will attempt to work with any Keystone v3 endpoint
  - Older releases may have limited functionality or compatibility issues
- **Memory**: 200MB+ (with 100MB cache for 10K resources)

## Getting Help

- **Built-in Help**: Press `?` at any time in Substation
- **[FAQ](reference/faq.md)** - Frequently asked questions
- **[Troubleshooting Guide](troubleshooting/index.md)** - Common issues and solutions
- **GitHub Issues**: [Report bugs and request features](https://github.com/cloudnull/substation/issues)

## License

Substation is open-source software licensed under the MIT License.

**Translation**: Free as in beer and speech. Use it. Fork it. Break it. Fix it. Share it.

---

**Remember**: You're not alone. Every OpenStack operator has been woken up at 3 AM. At least now you have a tool that doesn't make it worse.

*Built by operators who've been there. For operators who are there now.*
