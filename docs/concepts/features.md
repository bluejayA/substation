# Features

Substation is not "another OpenStack tool." Every feature exists because an
operator somewhere lost sleep over a problem that shouldn't have been that hard.

Performance that respects your time? We cache everything aggressively because
waiting 2 seconds for a server list today is unacceptable. Keyboard-driven
navigation? Because reaching for a mouse during an incident is cognitive
overhead you don't need. Intelligent flavor recommendations? Because picking
from 47 flavors named "m1.xlarge.v2.20231015.amd.special" shouldn't require
a decoder ring.

Let's talk about what you actually get.

## What Makes Substation Different

Most OpenStack tools fall into two camps: web UIs that force you to click
through 17 pages to create a server, or CLIs that make you memorize incantations
like a wizard. Substation rejects both approaches.

We built a terminal interface that's fast, keyboard-driven, and designed for
muscle memory. It provides complete CRUD operations for all major OpenStack
resources - Compute (Nova), Networking (Neutron), Storage (Cinder), Images
(Glance), Secrets (Barbican), and Object Storage (Swift). Everything you need
to manage servers, networks, volumes, security groups, and the rest of your
infrastructure lives in one place.

The interface uses Swift 6.1 and actor-based concurrency for true thread safety
without locks. We're targeting sub-second response times for most operations
through intelligent caching that reduces API calls by 60-80%. When you manage
10,000+ resources, these numbers matter.

## The Performance Story

We spent months getting caching right because nobody should wait for data that
hasn't changed. Substation's caching architecture uses predictive prefetching
for common workflows and request coalescing to minimize network overhead. When
you open the server list, we're already loading flavor details in the background
because we know what you'll click next.

Memory pressure handling ensures the cache doesn't eat your system alive. TTL
management keeps data fresh without hammering your API endpoints. Connection
pooling and request batching mean bulk operations don't turn into connection
storms. The result? Actor-based concurrency that handles massive resource counts
without breaking a sweat.

Batch operations process 100+ resources simultaneously with intelligent dependency
resolution and rollback capabilities for failed operations. You can configure
parallelism from 1-20 threads depending on your deployment's tolerance. Progress
tracking provides real-time updates so you're never wondering if something froze.

## The Interface Philosophy

Keyboard-driven doesn't mean "we have hotkeys." It means every interaction is
optimized for hands staying on the home row. Tab-based view switching, breadcrumb
navigation showing your current location, and quick jumps using number keys make
navigation feel instant. Search-as-you-type filtering means you're never scrolling
through pages of resources to find the one you need.

Context-aware help appears when you need it. The responsive layout adapts to
any terminal size. Color-coded status indicators communicate state at a glance.
Progress bars for long-running operations mean you can see deployment progress
without refresh spam. Modal dialogs confirm destructive operations because "are
you sure?" matters at 3 AM.

Auto-refresh with configurable intervals keeps data current. Live status updates
show resource state changes in real-time. Background operation monitoring means
long-running tasks don't block your workflow. Change highlighting shows exactly
what updated since your last view.

The interface includes bookmarks for frequently accessed resources and history
tracking of recent actions. A command palette provides access to all operations
without memorizing every hotkey. We support macro recording and playback for
repetitive workflows, plus custom shortcut definitions for team-specific operations.

## Security Without Compromise

Security isn't a checkbox - it's a foundation. Substation implements AES-256-GCM
encryption for all credentials with memory-safe SecureString and SecureBuffer
implementations. Automatic memory zeroing on cleanup ensures no plaintext
credentials appear in memory dumps. Full SSL/TLS chain validation with system
CA bundle integration means certificate validation works correctly across platforms.

Input validation protects against 14 SQL injection patterns, 6 command injection
patterns, and 3 path traversal attack vectors. The SecureCredentialStorage actor
provides thread-safe credential management. Tokens live in memory only and never
persist to disk. Password input handling prevents echoing to the terminal.

Read-only mode supports safe browsing without modification risk. Operation
whitelisting enables restricted access for compliance scenarios. The audit trail
captures timestamps and user attribution for all actions. Policy enforcement
validates resource creation against organizational standards.

See [Security Documentation](security.md) for comprehensive security architecture
details.

## The Flavor Recommendations System

Because choosing server specs shouldn't feel like playing roulette with your
infrastructure budget.

When creating a new server, Substation's workload-aware recommendation engine
analyzes your cloud's entire flavor catalog and serves up the perfect match for
your use case. No more scrolling through 47 flavors named things like
"m1.xlarge.v2.20231015.amd.special" trying to decode what any of it means.

### How It Works (The Magic Behind the Curtain)

Press TAB to switch from manual mode to the recommendation engine. Choose your
workload type: Balanced for general-purpose workloads like web apps and dev
environments. Compute Intensive when your CPUs need to go brrrr for batch
processing or scientific computing. Memory Intensive for RAM-heavy workloads
like Redis or in-memory databases. Storage Intensive for file servers and backup
systems.

Network Intensive for load balancers and API gateways. GPU Accelerated
for ML models (we actually check if GPUs exist). Hardware Accelerated for PCI
passthrough and FPGA wizardry.

The engine doesn't just look at vCPUs and RAM like some primitive CLI tool from
2010. It dives into the flavor's extra_specs like a truffle pig hunting for
performance gold. IOPS quotas? We detect read/write IOPS limits because 24K
read IOPS matters. Network bandwidth? We find actual Mbps limits (750 Mbps peak
gets a chef's kiss). CPU pinning? We identify dedicated CPU cores for consistent
performance without noisy neighbors. NVMe detection spots high-performance storage
that makes databases happy. GPU presence gets validated (no recommending unicorn
flavors). Architecture info covers x86 and ARM. Hardware optimization includes
multi-queue networking and memory page sizes.

### Smart Scoring Algorithm

Each flavor gets rated based on what actually matters for your workload. Compute
workloads earn +30% bonus for CPU pinning and +20% for CPU-heavy ratios. Memory
workloads get +20% for RAM-heavy configs and +15% for 32GB+ allocations. Storage
workloads receive +40% for NVMe and +20% for high IOPS limits. Network workloads
gain +40% for network optimization and +25% for 500+ Mbps bandwidth. GPU workloads?
Either you have a GPU or you score 0 - we don't do false hope here.

We analyze CPU:RAM ratios to find optimal balance (1:8 for general-purpose, 1:16
for memory-heavy). The system checks aggregate_instance_extra_specs to match
specialized hardware requirements. It validates quota limits (quota:disk_\*_iops_sec,
quota:vif_outbound_\*) for performance guarantees. Hardware capabilities
(hw:cpu_policy, hw:mem_page_size, hw:vif_multiqueue_enabled) get detected and
scored. Impossible matches get zero scores - GPU workload without GPU hardware
equals nope.

### Human-Readable Explanations

Instead of cryptic spec sheets, you get actual explanations like "This flavor
provides 500GB disk storage with NVMe SSD for high IOPS, 24576 read/8192 write
IOPS, 100GB ephemeral storage. Backed by 16 vCPUs and 32GB RAM. Ideal for file
servers, backup systems, media streaming, and log aggregation."

Not "m1.large.storage.v3.20240815 - 16/32/500."

We show the top 3 recommendations per category, scored and sorted. No analysis
paralysis from 47 similar-looking flavors. If your flavors include :price in
their extra_specs, we display hourly costs right in the selection screen for
budget optimization.

### Why This Matters

Remember the last time you picked a flavor, deployed a server, then realized you
needed more RAM but picked a CPU-optimized instance? Or paid for a GPU flavor
that didn't actually have a GPU? Or wondered why your storage-heavy workload
was crawling on a compute-optimized instance? Those days are over. Start creating
a server, get to flavor selection, press TAB, pick your workload category, press
SPACE to drill into recommendations, marvel at the detailed explanations, select
your perfect flavor, and actually deploy something that makes sense.

Because life's too short to pick the wrong server flavor. Again.

## Developer Experience

The form building system eliminates the tedium of resource creation. FormBuilder
provides a unified component with validation, navigation, and state management.
FormTextField handles text input with cursor control and history. FormSelector
manages advanced multi-column selection with search and scrolling for large
datasets. FormSelectorRenderer preserves OpenStack resource types through
type-safe rendering.

Single API for all field types: text, number, toggle, select, selector,
multi-select, info, and custom. Built-in keyboard navigation uses TAB and
Shift-TAB between fields with SPACE to activate. Automatic validation displays
field-level error messages. Search-as-you-type filtering works in selector
fields. Support for 10+ OpenStack resource types comes out of the box.
Conditional field visibility based on form state keeps interfaces clean.

Developers get to eliminate cursor tracking, history management, and validation
boilerplate. Type-safe resource selection preserves OSClient types. Extension
for new resource types follows straightforward patterns. See
[Developer Documentation](../reference/developers/index.md) for implementation
guides.

Testing happens through dry-run mode for safe validation. Mock data generation
enables isolated testing. Load testing utilities validate performance
characteristics. Configuration validation tools catch errors before deployment.
The regression testing framework ensures changes don't break existing workflows.

Debug mode provides verbose logging. API call tracing includes timing information.
Performance profiling capabilities identify bottlenecks. Memory usage analysis
catches leaks before production. Network traffic inspection debugs connectivity
issues.

## Advanced Capabilities

Cross-service resource search finds related resources across Nova, Neutron, and
Cinder. Full-text search works across all attributes. Smart filtering includes
type-ahead suggestions. Saved searches and quick filters speed up common queries.
Resource relationship mapping shows dependencies. Sub-second search on 10,000+
items makes large deployments manageable.

Templates and automation provide pre-built infrastructure patterns. One-click
deployment handles complex topologies. The recipe system captures common
configurations. Template versioning enables rollback. Dry-run validation catches
errors before deployment. Parameter validation and type checking prevent runtime
failures.

Telemetry includes real-time health scoring on a 0-100 scale. Performance metrics
tracking identifies degradation. Anomaly detection and alerting catches problems
early. Optimization suggestions improve efficiency. Historical trend analysis
shows patterns. Custom metric definitions support organization-specific needs.

Multi-region support manages cross-region resources. Region-specific endpoint
configuration adapts to deployment topology. Failover support provides high
availability. Region priority configuration optimizes latency.

Configuration management supports export/import of entire environments.
Configuration versioning enables rollback. Environment profiles handle different
setups. Backup and restore capabilities prevent data loss. Configuration
validation runs before apply operations.

## How We Compare

Substation occupies a unique position: terminal-first design built specifically
for terminal environments, not a CLI afterthought. Real-time performance provides
instant feedback through intelligent caching. Batch operations, telemetry, and
automation come built-in. Single binary deployment with minimal dependencies
simplifies installation. Swift-powered implementation ensures modern, safe, and
performant code. Actor-based concurrency provides true thread safety without
locks. Operator-focused design comes from operators building for operators.

| Feature | Substation | Horizon | OpenStack CLI |
|---------|------------|---------|---------------|
| Interface | Terminal UI | Web UI | CLI |
| Real-time Updates | Yes | Yes | No |
| Batch Operations | Yes | Limited | No |
| Performance | Excellent | Good | Fair |
| Learning Curve | Low | Low | Medium |
| Automation | Yes | No | Yes |
| Cache-Based Offline | Yes | No | No |
