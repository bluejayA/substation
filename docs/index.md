# Substation - OpenStack TUI

![Substation Logo](assets/substation-logo-icon.png#only-light)
![Substation Logo](assets/substation-logo-icon-lt.png#only-dark)

You know the feeling. It's 3 AM and your monitoring system just woke you up because some server in your OpenStack cluster decided to throw a tantrum. You reach for your laptop, open a browser, wait for Horizon to load, authenticate, navigate through six clicks to find the server, and... the session timed out. Start over.

Substation exists because we got tired of that.

![Substation Dashboard](assets/substation-enjoy.gif)

## The Reality of OpenStack Operations

Managing OpenStack at scale is like conducting an orchestra where half the musicians are in different time zones and the other half are on fire. Horizon is fine for demos and light use, but when you're juggling hundreds of servers across multiple regions at ungodly hours, clicking through web interfaces feels like running a marathon in concrete shoes. The CLI tools work, but piecing together information from a dozen different `openstack` commands while your terminal scrolls past critical details is its own special kind of hell. You need something faster. Something that respects the fact that your brain works in context, not in disconnected command outputs. Something that doesn't fight you when you're already fighting a production incident.

## How Substation Changes This

**We built Substation for the operator who lives in the terminal.** Every design decision starts with a simple question: will this save you time at 3 AM? The entire interface is keyboard-driven because your hands are already on the keyboard. Navigation is contextual because you think in terms of "this server's volumes" not "list all volumes and grep for the one I care about." Press `?` at any time and you get help that's actually relevant to what you're looking at. Multi-region support isn't bolted on as an afterthought - it's fundamental, because we know your infrastructure doesn't fit in a single availability zone. This is a tool built by people who have been paged at 3 AM, for people who will be paged at 3 AM.

**Performance isn't a feature, it's a requirement.** When you're troubleshooting a production issue, every second of latency is another second of downtime. We designed Substation to reduce API calls by 60-80% through intelligent multi-level caching. Most operations complete in under a second. The parallel search system queries six OpenStack services simultaneously and returns results in under 500 milliseconds on typical deployments. We track performance metrics in real-time and alert on regressions because slow tools cost sleep. Your OpenStack API might be slow, but Substation won't make it worse.

**Complete coverage with the features that matter.** Substation gives you full control over Compute, Networking, Storage, Object Storage, Images, and Secrets. But it's not just about ticking boxes on a feature matrix. The object storage implementation includes ETAG optimization for bulk transfers because we've moved terabytes of data at 2 AM and learned what matters. Batch operations handle hundreds of resources simultaneously because sometimes you need to tag an entire environment. Real-time updates with configurable refresh intervals because stale data makes bad decisions. Health monitoring with automatic performance regression detection because you should know when something's getting slower before it becomes a problem. Every feature exists because someone needed it while their pager was going off.

## What You Get

Substation is a complete terminal interface for OpenStack. You get resource management across Nova, Neutron, Cinder, Swift, Glance, and Barbican. You get intelligent caching that reduces API load and improves response times. You get parallel search that makes finding resources fast. You get batch operations, real-time updates, and health monitoring. You get keyboard shortcuts that make sense and context-aware help that doesn't make you leave your current view. You get multi-region support and comprehensive error recovery with exponential backoff retry. You get a tool that works the way you think.

## Navigation

**Getting Started**: [Quick Start Guide](quick-start.md) gets you running in one minute. [Installation](installation/index.md) has the detailed instructions. [Configuration](configuration/index.md) covers clouds.yaml setup.

**For Operators**: [Keyboard Shortcuts](reference/operators/keyboard-shortcuts.md) for navigation mastery. [Common Workflows](reference/operators/workflows.md) for everyday operations. [Troubleshooting](troubleshooting/index.md) for when things go wrong.

**For Developers**: [Developer Guide](reference/developers/index.md) for contributing. [FormBuilder Guide](reference/developers/formbuilder-guide.md) for building forms. [API Reference](reference/api/index.md) for using Substation packages.

**Deep Dives**: [Architecture](architecture/index.md) for system design. [Performance](performance/index.md) for optimization details. [Security](concepts/security.md) for protection and best practices. [Object Storage](concepts/object-storage.md) for Swift integration and ETAG optimization.

## System Requirements

Substation runs on macOS 13 or later and modern Linux distributions. Any terminal with ncurses support works fine. We designed it for OpenStack Queens or later, though Caracal and newer releases give you full feature compatibility. That said, version detection isn't enforced - if you have a Keystone v3 endpoint, Substation will attempt to work with it. Older releases may have limited functionality or compatibility issues, but we won't stop you from trying. You need about 200MB of memory for the application itself, plus around 100MB of cache if you're managing 10,000 resources. Your terminal emulator probably uses more memory than Substation does.

## Getting Help

Press `?` at any time in Substation for context-aware help. Check the [FAQ](reference/faq.md) for frequently asked questions. Read the [Troubleshooting Guide](troubleshooting/index.md) for common issues and solutions. [Report bugs and request features](https://github.com/cloudnull/substation/issues) on GitHub.

## License

Substation is open-source software licensed under the MIT License. Free as in beer and speech. Use it. Fork it. Break it. Fix it. Share it.

---

**You're not alone.** Every OpenStack operator has been woken up at 3 AM. At least now you have a tool that doesn't make it worse.

*Built by operators who've been there. For operators who are there now.*
