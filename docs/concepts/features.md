# Features

Substation provides a comprehensive set of features designed to simplify and enhance OpenStack cloud management through an intuitive terminal interface.

## Core Features

### Complete Resource Management

Substation provides full CRUD (Create, Read, Update, Delete) operations for all major OpenStack resources:

- **Compute (Nova)**: Servers, flavors, keypairs, server groups
- **Networking (Neutron)**: Networks, subnets, routers, security groups, floating IPs, ports
- **Storage (Cinder)**: Volumes, snapshots, volume types, backups
- **Images (Glance)**: Operating system images, snapshots
- **Secrets (Barbican)**: Secrets, containers, certificates
- **Load Balancing (Octavia)**: Load balancers, pools, listeners, health monitors
- **Object Storage (Swift)**: Containers, objects, account management

### High-Performance Architecture

- **60-80% API call reduction** through intelligent caching
- **Sub-second response times** for most operations
- **Actor-based concurrency** ensuring thread safety
- **Memory-efficient** handling of 10,000+ resources
- **Predictive prefetching** for common workflows
- **Request coalescing** to minimize network overhead

#### Batch Operations

- Process 100+ resources simultaneously
- Intelligent dependency resolution
- Progress tracking with real-time updates
- Rollback capabilities for failed operations
- Configurable parallelism (1-20 threads)

#### Telemetry & Monitoring

- Real-time health scoring (0-100 scale)
- Performance metrics tracking
- Anomaly detection and alerting
- Optimization suggestions
- Historical trend analysis
- Custom metric definitions

#### Advanced Search & Discovery

- Cross-service resource search
- Full-text search across all attributes
- Smart filtering with type-ahead suggestions
- Saved searches and quick filters
- Resource relationship mapping
- Sub-second search on 10,000+ items

#### Templates & Automation

- Pre-built infrastructure patterns
- One-click deployment of complex topologies
- Recipe system for common configurations
- Template versioning and rollback
- Dry-run validation before deployment
- Parameter validation and type checking

## User Interface Features

### Intuitive Terminal UI

- **Keyboard-driven workflow** for maximum efficiency
- **Context-aware help** available at any time
- **Responsive layout** adapting to terminal size
- **Color-coded status** indicators
- **Progress bars** for long-running operations
- **Modal dialogs** for confirmations

### Smart Navigation

- **Tab-based view** switching
- **Breadcrumb navigation** showing current location
- **Quick jumps** using number keys
- **Search-as-you-type** filtering
- **Bookmarks** for frequently accessed resources
- **History** of recent actions

### Real-Time Updates

- **Auto-refresh** with configurable intervals
- **Live status** updates for resources
- **Push notifications** for important events
- **Background operation** monitoring
- **Change highlighting** for updated values

## Security Features

> See [Security Documentation](security.md) for comprehensive security architecture details.

### Authentication & Authorization

- **Multiple auth methods**: Password, application credentials, token-based
- **Project/domain** isolation for multi-tenant environments
- **Secure token management** with automatic refresh
- **Token encryption** using AES-256-GCM (cross-platform)

### Data Protection

- **AES-256-GCM encryption** for all credentials (macOS + Linux)
  - Industry-standard authenticated encryption
  - Memory-safe `SecureString` and `SecureBuffer` implementations
  - Automatic memory zeroing on cleanup
  - No plaintext credentials in memory dumps
- **Certificate validation** on all platforms
  - Full SSL/TLS chain validation
  - No certificate bypass vulnerabilities
  - System CA bundle integration (Linux)
  - Security framework validation (macOS)
- **Input validation** protecting against:
  - SQL injection (14 attack patterns detected)
  - Command injection (6 attack patterns detected)
  - Path traversal attacks (3 attack patterns detected)
  - Buffer overflow via length validation
- **Secure storage**:
  - Encrypted credential storage with `SecureCredentialStorage` actor
  - Memory-only token storage (never persisted to disk)
  - Secure password input handling (no echoing)
  - Thread-safe actor-based credential management

### Compliance & Governance

- **Read-only mode** for safe browsing
- **Operation whitelisting** for restricted access
- **Audit trail** with timestamps and user attribution
- **Policy enforcement** for resource creation
- **Compliance checks** against organizational standards

## Operational Features

### Multi-Region Support

- **Cross-region resource** management
- **Region-specific** endpoint configuration
- **Failover support** for high availability
- **Region priority** configuration

### Configuration Management

- **Export/Import** entire environments
- **Configuration versioning** with rollback
- **Environment profiles** for different setups
- **Backup and restore** capabilities
- **Configuration validation** before apply

### Performance Optimization

- **Intelligent caching** with TTL management
- **Memory pressure** handling
- **Connection pooling** for efficiency
- **Request batching** for bulk operations
- **Compression** for large payloads

## Integration Features

### API Compatibility

- **OpenStack API** version negotiation
- **Microversion** support
- **Backwards compatibility** with older releases
- **Service discovery** through catalog
- **Custom endpoint** configuration

## Productivity Features

### Quick Actions

- **One-key shortcuts** for common operations
- **Command palette** for all actions
- **Macro recording** and playback
- **Custom shortcuts** definition
- **Context menus** for resources

### Smart Assistance

- **Suggestion engine** for next actions
- **Error recovery** suggestions
- **Performance tips** based on usage
- **Resource recommendations**

### Intelligent Flavor Recommendations

**Because choosing server specs shouldn't feel like playing roulette with your infrastructure budget.**

When creating a new server, Substation's workload-aware recommendation engine analyzes your cloud's entire flavor catalog and serves up the *perfect* match for your use case. No more scrolling through 47 flavors named things like `m1.xlarge.v2.20231015.amd.special` trying to decode what any of it means.

**How It Works (The Magic Behind the Curtain)**:

1. **Workload-First Selection**: Press TAB to switch from boring manual mode to our recommendation engine. Choose your workload type:
   - **Balanced**: For when you need a little bit of everything (web apps, dev environments)
   - **Compute Intensive**: When your CPUs need to go brrrr (batch processing, video encoding, scientific computing)
   - **Memory Intensive**: RAM > everything else (Redis, in-memory databases, big data analytics)
   - **Storage Intensive**: Disk space for days (file servers, backup systems, media streaming)
   - **Network Intensive**: Packets galore (load balancers, API gateways, VPN endpoints)
   - **GPU Accelerated**: For your ML models and rendering needs (actually checks if GPUs exist!)
   - **Hardware Accelerated**: PCI passthrough and FPGA wizardry

2. **Deep Spec Analysis**: The engine doesn't just look at vCPUs and RAM like some primitive CLI tool from 2010. Oh no. It dives into the flavor's `extra_specs` like a truffle pig hunting for performance gold:
   - **IOPS Quotas**: Detects read/write IOPS limits (because 24K read IOPS > your neighbor's spinner drive)
   - **Network Bandwidth**: Finds actual Mbps limits (750 Mbps peak? *Chef's kiss*)
   - **CPU Pinning**: Identifies dedicated CPU cores (for when you need consistent performance, not noisy neighbors)
   - **NVMe Detection**: Spots high-performance NVMe storage (your database will thank you)
   - **GPU Presence**: Actually validates GPU hardware exists (instead of recommending unicorn flavors)
   - **Architecture Info**: x86? ARM? We got you covered
   - **Hardware Optimization**: Multi-queue networking, memory page sizes, the works

3. **Smart Scoring Algorithm**: Each flavor gets rated based on what actually matters for your workload:
   - Compute workloads? +30% bonus for CPU pinning, +20% for CPU-heavy ratios
   - Memory workloads? +20% for RAM-heavy configs, +15% for 32GB+ allocations
   - Storage workloads? +40% for NVMe, +20% for high IOPS limits
   - Network workloads? +40% for network optimization, +25% for 500+ Mbps bandwidth
   - GPU workloads? Either you have a GPU or you score 0 (we don't do false hope here)

4. **Human-Readable Explanations**: Instead of cryptic spec sheets, you get actual explanations like:
   > "This flavor provides 500GB disk storage with NVMe SSD for high IOPS, 24576 read/8192 write IOPS, 100GB ephemeral storage. Backed by 16 vCPUs and 32GB RAM. Ideal for file servers, backup systems, media streaming, and log aggregation."

   Not:
   > "m1.large.storage.v3.20240815 - 16/32/500"

5. **Top 3 Recommendations Per Category**: We show you the best 3 options for each workload type, scored and sorted. No analysis paralysis from 47 similar-looking flavors.

6. **Price-Aware** (when your cloud provides it): If your flavors have `:price` in their extra_specs, we'll show hourly costs right in the selection screen. Budget optimization? Yeah, we do that.

**The Technical Flex**:

- Analyzes CPU:RAM ratios to find optimal balance (1:8 for general-purpose, 1:16 for memory-heavy)
- Checks for `aggregate_instance_extra_specs` to match specialized hardware requirements
- Validates quota limits (`quota:disk_*_iops_sec`, `quota:vif_outbound_*`) for performance guarantees
- Detects hardware capabilities (`hw:cpu_policy`, `hw:mem_page_size`, `hw:vif_multiqueue_enabled`)
- Zero scores for impossible matches (GPU workload without GPU hardware = nope)

**Why This Matters**:

Remember the last time you picked a flavor, deployed a server, then realized you needed more RAM but picked a CPU-optimized instance? Or paid for a GPU flavor that didn't actually have a GPU? Or wondered why your storage-heavy workload was crawling on a compute-optimized instance?

Yeah, those days are over.

**Usage**:

1. Start creating a server
2. Get to flavor selection
3. Press TAB to enter recommendation mode
4. Pick your workload category
5. Press SPACE to drill into the top 3 recommendations
6. Marvel at the detailed explanations
7. Select your perfect flavor
8. Actually deploy something that makes sense

*Because life's too short to pick the wrong server flavor. Again.*

### Workflow Optimization

- **Task queuing** for sequential operations
- **Parallel execution** where possible
- **Dependency detection** and resolution
- **Operation scheduling** with cron-like syntax
- **Batch scripting** support

## Monitoring & Alerting

### Health Monitoring

- **Service availability** checking
- **Resource utilization** tracking
- **Quota usage** monitoring
- **Performance baseline** establishment
- **Trend analysis** and forecasting

### Alert Management

- **Configurable thresholds** for metrics
- **Multiple notification** channels
- **Alert suppression** and deduplication
- **Escalation policies** for critical issues
- **Alert history** and acknowledgment

### Reporting

- **Customizable dashboards** for metrics
- **Scheduled reports** generation
- **Export to CSV/PDF** formats
- **Trend visualization** with graphs
- **Comparative analysis** across periods

## Form Building System

### Declarative Form Components

Substation includes a comprehensive form building system designed specifically for OpenStack resource management:

- **FormBuilder**: Unified component for creating forms with validation, navigation, and state management
- **FormTextField**: Text input with cursor control, history, and inline validation
- **FormSelector**: Advanced multi-column selection with search and scrolling for large datasets
- **FormSelectorRenderer**: Type-safe rendering helper that preserves OpenStack resource types
- **FormBuilderState**: Centralized state management for complex forms

**Key Features:**

- Single API for all form field types (text, number, toggle, select, selector, multi-select, info, custom)
- Built-in keyboard navigation (TAB/Shift-TAB between fields, SPACE to activate)
- Automatic validation display with field-level error messages
- Search-as-you-type filtering in selector fields
- Support for 10+ OpenStack resource types out of the box
- Conditional field visibility based on form state
- Consistent styling and behavior across all forms

**Developer Benefits:**

- Eliminate cursor tracking, history management, and validation boilerplate
- Type-safe resource selection that preserves OSClient types
- Easy extension for new resource types

See [Developer Documentation](../guides/developers/index.md) for implementation guides.

## Developer Features

### Debugging Tools

- **Debug mode** with verbose logging
- **API call tracing** with timing
- **Performance profiling** capabilities
- **Memory usage** analysis
- **Network traffic** inspection

### Testing Support

- **Dry-run mode** for safe testing
- **Mock data** generation
- **Load testing** utilities
- **Validation tools** for configurations
- **Regression testing** framework

### Documentation

- **Built-in help** system
- **Command documentation** with examples
- **API reference** generation
- **Configuration schemas** with validation
- **Tutorial mode** for learning

## Unique Differentiators

### What Sets Substation Apart

1. **Terminal-First Design**: Built specifically for terminal environments, not a CLI afterthought
2. **Real-Time Performance**: Instant feedback with intelligent caching
3. **Features**: Batch operations, telemetry, and automation built-in
4. **Zero Dependencies**: Single binary with everything included
5. **Swift-Powered**: Modern, safe, and performant implementation
6. **Actor-Based**: True concurrent safety without locks
7. **Operator-Focused**: Designed by operators, for operators

### Comparison with Alternatives

| Feature | Substation | Horizon | OpenStack CLI |
|---------|------------|---------|---------------|
| Interface | Terminal UI | Web UI | CLI |
| Real-time Updates | ✓ | ✓ | ✗ |
| Batch Operations | ✓ | Limited | ✗ |
| Performance | Excellent | Good | Fair |
| Learning Curve | Low | Low | Medium |
| Automation | ✓ | ✗ | ✓ |
| Cache-Based Offline | ✓ | ✗ | ✗ |

## Upcoming Features

### Roadmap

- **Heat UI Views**: Complete UI implementation for orchestration
- **Machine Learning**: Predictive analytics and anomaly detection
- **Multi-Cloud**: Support for multiple cloud providers
