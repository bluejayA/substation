# Frequently Asked Questions

## General Questions

### What is Substation?

Substation is a terminal user interface (TUI) for managing OpenStack clouds. Think of it as what happens when you realize clicking through web UIs is a waste of your life - you get a keyboard-driven interface that lets you batch-process hundreds of resources while sipping coffee instead of RSI-inducing point-and-click marathons. It's designed to cut API calls by 60-80% through intelligent caching, because waiting for OpenStack APIs to respond is what they do in the special circle of hell reserved for people who reply-all to company emails.

### Why use Substation instead of Skyline/Horizon or the OpenStack CLI?

Because you value your time and your sanity. Horizon was built for executives who need pretty charts, not for operators who need to actually get work done. The CLI is great if you enjoy typing the same commands 500 times with slight variations. Substation is built for people who manage real infrastructure:

- Terminal-native design - not a web UI awkwardly shoved into a terminal
- 60-80% fewer API calls - your OpenStack cluster will thank you
- Batch operations - delete 100 servers in one go, not 100 individual commands
- Real-time updates - see status changes without hitting refresh like a woodpecker
- Keyboard-driven - because mice are for CAD software and Solitaire

### What OpenStack versions are supported?

Queens and later. We recommend Caracal (2024.1) or newer because nobody should still be running Queens in 2025. If you're on Mitaka, we need to have a conversation about your life choices. The latest LTS versions are extensively tested, older versions work but we're not losing sleep over edge cases from 2017.

### Is Substation open source?

Yes, MIT licensed. Fork it, modify it, sell it to your enterprise for millions - we don't care. Just don't blame us when your changes break everything.

## Installation & Setup

### What are the system requirements?

- Operating System: macOS 13+ or Linux (Windows folks, see WSL question below)
- Swift: 6.1 or later - no compromises, no legacy support
- Terminal: Anything with ncurses support
- Memory: 256MB minimum, 512MB if you value performance
- Network: Access to OpenStack APIs (preferably ones that respond this century)

### Where should I put my clouds.yaml file?

Substation looks in these locations, in this order:

1. `./clouds.yaml` - current directory (useful for testing, terrible for security)
2. `~/.config/openstack/clouds.yaml` - the correct answer
3. `/etc/openstack/clouds.yaml` - if you're running as root, we need to talk

Pro tip: `chmod 600 ~/.config/openstack/clouds.yaml` unless you enjoy explaining security incidents to your boss.

### Can I use environment variables instead of clouds.yaml?

No. We don't support OpenStack environment variables. Use clouds.yaml like a civilized operator. If you're using environment variables because you're afraid of YAML, we get it, but YAML is the least of your problems when managing OpenStack.

## Usage Questions

### How do I connect to multiple clouds?

Define multiple clouds in your clouds.yaml and switch between them with `--cloud`:

```yaml
clouds:
  production:
    auth: {...}
  staging:
    auth: {...}
```

Then switch between them:

```bash
substation --cloud production
substation --cloud staging
```

We don't support connecting to multiple clouds simultaneously because that's how you accidentally delete production servers while thinking you're in staging. We're protecting you from yourself.

### How do I search for resources?

![Substation Search](../assets/substation-search.png)

Two methods, pick your weapon:

- Quick search (`/`) - filters what's visible right now, instant results
- Advanced search (`z`) - searches across all services, takes a few seconds

For the gory details, see the [Search Engine Guide](../concepts/search.md).

## Performance Questions

### Why is everything slow? (The Most Common Question)

Short answer: It's probably your OpenStack API, not Substation.

Long answer: We get this question constantly, and 95% of the time it's because OpenStack APIs are slower than government bureaucracy. Here's how to verify:

```bash
# Enable wiretap mode to see actual API response times
substation --cloud mycloud --wiretap

# In another terminal
tail -f ~/substation.log | grep "ms)"
```

What you'll see:

```
CACHE HIT: servers (L1, 0.8ms)      <- Substation is fast
GET /servers/detail <- 200 (2134ms) <- OpenStack is slow
```

Translation:

- Cache HIT < 20ms: Substation working perfectly, caching is your friend
- API calls < 2 seconds: Normal OpenStack performance (sadly)
- API calls 2-5 seconds: OpenStack under load - common in production
- API calls > 5 seconds: Your OpenStack cluster is having a bad day

The cold hard truth: If your network is slow, Substation will be slow. We can't fix physics. But our caching helps minimize the pain by reducing how often you have to wait for those glacial API responses.

### How does Substation achieve 60-80% API call reduction?

Through a multi-level caching system called MemoryKit. For the full technical breakdown,
see the [Caching System Guide](../concepts/caching.md).

Quick overview of our caching layers:

1. L1 Cache (Memory): < 1ms retrieval, 80% hit rate target
2. L2 Cache (Larger Memory): ~5ms retrieval, 15% hit rate target
3. L3 Cache (Disk): ~20ms retrieval, 3% hit rate target
4. API Call: 2+ seconds, 2% miss rate (when everything else fails)

Note: These are design targets. Your actual cache hit rates will vary based on how often your resources change and whether you keep mashing the cache purge key (don't do that).

See [Performance Tuning](../performance/tuning.md) if you want to tweak the cache configuration.

### Why is Substation using so much memory?

Because we're caching everything to avoid hitting your slow APIs. This is a feature, not a bug.

Expected memory usage:

- Base application: ~200MB
- Cache for 10,000 resources: ~100MB additional
- Total typical: 200-400MB

For large deployments (you know who you are):

- 50,000 resources: ~500MB
- 100,000 resources: ~800MB

If memory is constrained:

- Use `/` to filter views (reduces visible resources)
- Use project-scoped credentials (reduces total resources)
- Use `:cache-purge<Enter>` (or `:cc<Enter>`) to manually purge cache
- Question why you're running Substation on a potato

Automatic eviction kicks in at 85% memory threshold to prevent OOM crashes. We'd rather drop cache than crash.

### Why is my cache hit rate low?

Press `h` to view the Health Dashboard and check your cache hit rate.

Target: 80%+

Common causes of low hit rate:

1. You're constantly pressing `c` (cache purge) - Stop doing that unless data is actually stale
2. Switching views rapidly - Each view may trigger cache refresh, give it a second
3. Large dataset (50K+ resources) - First-time cache warming takes a while, be patient
4. Memory pressure - System is evicting cache due to low RAM

Let the cache warm up. After the initial load, your hit rate should stabilize at 80%+. If it doesn't, check if your resources are churning constantly (in which case, the cache can't help you).

### How can I improve response times?

1. Let the cache work - don't constantly purge it, don't hammer refresh. First view is slow while cache warms, subsequent views are fast. This is by design.

2. If OpenStack API is slow (> 2s per call) - talk to your OpenStack administrator. We can't make their cluster faster from our end. Consider API performance tuning or check if the cluster is melting under load.

3. For large datasets (50K+ resources) - use project-scoped credentials to reduce visible resources, filter views with `/` for instant local filtering, and be patient on first load while cache warms.

## Troubleshooting Questions

### Why can't I connect to OpenStack?

Common causes (in order of frequency):

1. Wrong auth URL - must include `/v3`:

   ```yaml
   # Correct
   auth_url: https://keystone.example.com:5000/v3  [x]

   # Wrong - this will not work
   auth_url: https://keystone.example.com:5000     [ ]
   ```

2. Missing domain fields - required even for default domain:

   ```yaml
   auth:
     username: operator
     password: secret
     project_name: myproject
     project_domain_name: default  # Required even if "default"
     user_domain_name: default      # Required even if "default"
   ```

3. Network issues - check connectivity before blaming Substation:

   ```bash
   curl -k https://keystone.example.com:5000/v3
   ```

4. SSL certificate problems - for testing only (don't run this in production):

   ```yaml
   verify: false  # Disable SSL verification
   ```

### Why do I see "Endpoint not found" errors?

It means the service isn't in your Keystone catalog. Common causes:

- Service not installed (e.g., your cloud doesn't have Octavia)
- Wrong region specified
- Service is disabled by admins

Verify with:

```bash
# List available services
openstack catalog list

# Check specific service in your region
openstack endpoint list --service nova --region RegionOne
```

If the service is missing, it's not available in your OpenStack deployment. Substation will skip it gracefully and continue working. We're not going to crash just because you don't have load balancers.

### Why is my data stale or wrong?

Because you're looking at cached data. Use `:cache-purge<Enter>` (or `:cc<Enter>`) to purge all caches (L1, L2, and L3).

Next operations will be slower while cache rebuilds, but data will be fresh.

When to purge cache:

- Just launched 50 servers, they're not showing up
- Deleted resources still visible
- Resource states incorrect (shows ACTIVE, actually ERROR)
- After major cluster changes

When not to purge cache: every five seconds because you're impatient. Let the cache work for you. Only purge when data is actually wrong.

### Why did authentication fail with "401 Unauthorized"?

Your token expired or your credentials are wrong. Substation automatically refreshes tokens, so if you're seeing this:

1. Verify credentials work with OpenStack CLI:

   ```bash
   openstack --os-cloud mycloud token issue
   ```

2. Check domain configuration in clouds.yaml - both domains required:

   ```yaml
   project_domain_name: default
   user_domain_name: default
   ```

3. Try application credentials instead (more reliable than passwords):

   ```bash
   openstack application credential create substation
   ```

### Should I use project_id or project_name in clouds.yaml?

Use `project_id`. IDs don't change, names can be renamed by admins who think "prod" should be "production-environment-v2-final-FINAL".

```yaml
clouds:
  mycloud:
    auth:
      auth_url: https://keystone.example.com:5000/v3
      username: operator
      password: secret
      project_id: a1b2c3d4e5f6g7h8i9j0  # Use this
      user_domain_id: default
      project_domain_id: default
```

Benefits:

- IDs never change (names can be modified by admins)
- Faster authentication (no name-to-ID lookups)
- Less likely to break when someone renames things

Find your project ID:

```bash
openstack project show <project-name> -f value -c id
```

For more details, see [ID-based Authentication](../configuration/index.md#id-based-authentication-recommended).

### Why do I get "403 Forbidden" errors?

You're authenticated (OpenStack knows who you are) but you don't have permission to do what you're trying to do.

Common causes:

1. Insufficient role - need admin, member, or reader role
2. Wrong project scope - viewing resources in a different project
3. Quota exhausted - can't create more resources

Check your setup:

```bash
# Check your role assignments
openstack role assignment list --user myuser --project myproject

# Check quotas
openstack quota show myproject

# Request admin to adjust roles or quotas (or do it yourself if you're admin)
```

### Why are colors not displaying correctly?

Your terminal doesn't support 256 colors or is misconfigured. Check:

```bash
echo $TERM  # Should be xterm-256color or similar
tput colors  # Should return 256
```

Fix:

```bash
export TERM=xterm-256color
substation --cloud mycloud
```

If you're using a terminal from 1995, consider upgrading. We live in the future now.

### How do I debug connection issues?

Enable wiretap mode for detailed API logging:

```bash
# Enable detailed logging
substation --cloud mycloud --wiretap

# View logs in real-time
tail -f ~/substation.log
```

Wiretap shows:

- All HTTP requests (method, URL, headers)
- All HTTP responses (status, body, timing)
- Authentication token exchange
- Service catalog discovery
- Cache hit/miss statistics

Note: Wiretap redacts all sensitive information (tokens, passwords, secrets). We're paranoid about security so you don't have to be.

### What do I do if the display is corrupted?

Quick fix:

```bash
reset
```

Full terminal reset (when things are really broken):

```bash
tput reset
clear
```

If this happens frequently, your terminal emulator might be trash. Try a different one.

### Why does search take so long?

Advanced search (`z`) searches across 6 services in parallel. This is a lot of API calls.

Expected performance:

- With cache: < 500ms (most searches after first one)
- Without cache (first search): up to 5 seconds

If search takes > 5 seconds: your OpenStack APIs are slow. Enable wiretap to see which service is the bottleneck:

```bash
substation --wiretap | grep "search"
```

Search has a 5-second timeout per service. If a service doesn't respond in time, you'll get partial results from other services. This prevents one slow service from blocking your entire search.

## Technical Questions

### What programming language is Substation written in?

Swift 6.1 with strict concurrency enforcement.

Why Swift when everyone expects Python for OpenStack tools?

- Actor-based concurrency - no race conditions by design
- Compile-time thread safety guarantees - the compiler won't let you write buggy concurrent code
- Memory safety without garbage collection - predictable performance
- Cross-platform (macOS and Linux) - one codebase, multiple platforms
- Minimal external dependencies - we know our entire supply chain

We're not masochists, we just value correctness over convenience.

Code organization:

- OSClient - OpenStack API library
- MemoryKit - caching system
- Substation - main app and UI coordination
- Service Layer - business logic
- SwiftNCurses - terminal UI framework (custom implementation)

### Does Substation work on Windows?

Not yet. Use WSL2 (Windows Subsystem for Linux) if you're on Windows.

Why not native Windows? Because Windows terminal APIs are fundamentally different (not ncurses), Swift on Windows has limited server-side support, and cross-platform terminal abstraction is complex. We'd rather do Linux/macOS well than do Windows poorly.

Workaround:

```bash
# Install WSL2 and Ubuntu
wsl --install

# Inside WSL2
git clone https://github.com/cloudnull/substation.git
cd substation
~/.swiftly/bin/swift build -c release
```

### Why Swift 6.1? Can I use Swift 5.x?

No. Swift 6 strict concurrency is non-negotiable.

Substation enforces a zero-warning build standard with Swift 6 strict concurrency checking. This eliminates entire classes of bugs:

- Race conditions - prevented at compile time
- Data races - impossible with actor isolation
- Thread safety bugs - guaranteed by the compiler

We're not going back to the bad old days of "it compiles with warnings, ship it."

Build requirement:

```bash
# Swift 6.1 or later required
~/.swiftly/bin/swift --version
# Must show: Swift version 6.1 or later
```

If you're on Swift 5.x, upgrade. If you can't upgrade, Substation isn't for you.

### What is MemoryKit?

MemoryKit is Substation's multi-level caching system. It's the reason we can reduce API calls by 60-80%.

Components:

- `MultiLevelCacheManager.swift` - L1/L2/L3 cache hierarchy
- `CacheManager.swift` - primary cache engine with TTL management
- `MemoryManager.swift` - memory pressure detection and cleanup
- `TypedCacheManager.swift` - type-safe caching (because Swift)
- `PerformanceMonitor.swift` - real-time metrics and alerts

Features:

- L1 (Memory): < 1ms retrieval, 80% hit rate target
- L2 (Larger Memory): ~5ms retrieval, 15% hit rate target
- L3 (Disk): ~20ms retrieval, 3% hit rate target
- Automatic eviction at 85% memory threshold
- Resource-specific TTLs (2 minutes to 1 hour depending on resource type)

### How does actor-based concurrency work in Substation?

All shared state is protected by actors (Swift 6 strict concurrency). The compiler guarantees no data races.

Examples:

```swift
// Token manager is an actor
public actor CoreTokenManager {
    private var encryptedToken: Data?  // Protected by actor

    public func getValidToken() async throws -> String {
        // Automatic serialization by Swift runtime
    }
}

// OpenStack client core is an actor
public actor OpenStackClientCore {
    private let tokenManager: CoreTokenManager

    public func request<T: Decodable>(...) async throws -> T {
        let token = try await ensureAuthenticated()
        // Thread-safe by design
    }
}
```

UI is MainActor:

```swift
@MainActor final class TUI {
    // All UI operations on main thread
}
```

Result: zero race conditions, guaranteed by the compiler. If the code compiles, it's thread-safe. This is what type safety looks like in 2025.

## Security Questions

### How are credentials stored?

We implement comprehensive security measures for credential protection. For complete details, see the [Security Guide](../concepts/security.md).

Quick summary:

- Credentials from clouds.yaml are read once at startup, never written to disk
- Tokens are encrypted in memory using platform-specific encryption
- Tokens are automatically refreshed before expiration
- All sensitive data is cleared on exit

Best practice:

```bash
# Secure your clouds.yaml
chmod 600 ~/.config/openstack/clouds.yaml
```

If your clouds.yaml is world-readable, that's a you problem, not a Substation problem.

### Are tokens logged in wiretap mode?

No. Wiretap mode redacts all sensitive information. For complete security details, see the [Security Guide](../concepts/security.md).

Wiretap logs HTTP methods, URLs, response codes, and timing - but never logs tokens, passwords, or secrets. We're not going to be responsible for your security incident.

### How do I report a security vulnerability?

Do not file public GitHub issues for security vulnerabilities. That's how you get your name in the news for all the wrong reasons.

Instead:

1. Email security contact (check repository README)
2. Include detailed description
3. Provide steps to reproduce
4. Allow time for patch before public disclosure

We follow responsible disclosure practices. Don't be the person who tweets vulnerabilities before they're fixed.

## Development Questions

### How do I contribute to Substation?

We welcome contributions. Here's the process:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure zero warnings: `~/.swiftly/bin/swift build` must have zero warnings
5. Add tests if applicable
6. Submit a pull request

Code standards:

- Swift 6.1 strict concurrency
- Zero warnings build requirement (warnings are errors)
- Actor-based concurrency for shared state
- Never use Unicode (ASCII only)
- Document your code with SwiftDoc comments

If your PR has warnings, it won't be merged. Fix the warnings.

### Why the zero-warning requirement?

Because warnings become bugs in production. Every time. Without exception.

Substation enforces zero-warning builds to ensure:

- No concurrency issues (data races, race conditions)
- No memory safety issues
- No undefined behavior
- Production-ready code quality

We're building production infrastructure software, not a toy project. Every warning must be fixed before merge. No exceptions, no "I'll fix it later," no "it's just a warning."

## Getting Help

### Where can I find more documentation?

- Built-in help: press `?` at any time
- Online docs: [substation.cloud](https://substation.cloud)
- GitHub Wiki: detailed guides and tutorials
- API Reference: [substation.cloud/api](https://substation.cloud/api)

### How do I report bugs?

Report issues on GitHub:

1. Check existing issues first - your bug might already be reported
2. Provide reproduction steps - "it doesn't work" is not helpful
3. Include version and configuration - we can't debug what we can't see
4. Attach debug logs if possible - wiretap mode is your friend

### Where can I ask questions?

- GitHub Discussions: community forum for general questions
- Stack Overflow: tag `substation-tui` for searchable Q&A
