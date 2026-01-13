# Performance Tuning Guide

Configuration strategies, monitoring best practices, and optimization techniques for production OpenStack environments.

## Do You Even Need to Tune?

Before you start tweaking settings, let's figure out if you actually need to. We've seen too many operators spend hours optimizing systems that were already performing fine. Here's how to tell if tuning is worth your time.

**You probably need to tune if**:
You're seeing cache hit rates below 70%, memory usage regularly exceeding 150MB, API response times over 3 seconds for cached operations, or search operations timing out more than occasionally. These are the red flags that mean something's actually wrong and tuning will help.

**You probably don't need to tune if**:
Everything feels snappy, the health dashboard shows green metrics, and you're not getting complaints. The defaults were battle-tested in environments with 10K+ resources. If it works, don't fix it. Go build something instead.

**The "it depends" zone**:
Your OpenStack environment has unusual characteristics - maybe you're running on a Raspberry Pi cluster (we've seen it), or your network crosses three continents (also seen it), or you have 200 operators all searching for servers simultaneously (sadly, also seen it). In these cases, read on.

## Cache Tuning

> **Note**: For complete details on cache architecture, multi-level caching (L1/L2/L3), eviction policies, and the full MemoryKit API, see the [MemoryKit API Reference](../reference/api/memorykit.md).

### Understanding Resource TTL Configuration

We set default TTL values based on how often things actually change in real OpenStack deployments. Authentication tokens last an hour because Keystone says they do. Service endpoints basically never change unless someone's having a really bad day. Flavors and volume types change when admins remember they exist, which is roughly quarterly. Everything else falls somewhere on the spectrum from "moderately dynamic" to "changes every time you blink."

Here's what we configured and why (from `CacheManager.swift:100`):

```swift
// Default configuration (from CacheManager.swift:100)
case .authentication:
    return 3600.0  // 1 hour - Keystone tokens last this long anyway

case .serviceEndpoints, .quotas:
    return 1800.0  // 30 minutes - these basically never change

case .flavor, .flavorList, .volumeType, .volumeTypeList:
    return 900.0   // 15 minutes - admins add new types occasionally

case .keypair, .image, .network, .subnet, .router, .securityGroup:
    return 300.0   // 5 minutes - moderately dynamic resources

case .volumeSnapshot, .objectStorage:
    return 180.0   // 3 minutes - storage operations moderately frequent

case .server, .serverList, .port, .volume, .floatingIP:
    return 120.0   // 2 minutes - highly dynamic (state changes frequently)
```

### When Longer TTLs Make Sense

If you're working in a stable development environment where you control when things get created, you can get away with longer cache times. This means fewer API calls, which makes everyone happy - your network team, your OpenStack API, and especially you when things load instantly.

Try something like this for development environments:

```swift
// Increase for less API traffic
case .server: return 300.0  // 5 minutes instead of 2
case .network: return 600.0  // 10 minutes instead of 5
case .flavor: return 1800.0  // 30 minutes instead of 15
```

The tradeoff is obvious: you'll see staler data, and new resources won't show up immediately. But if you're the one creating those resources, you already know when to expect them. This works great when your OpenStack API is slow, network latency is killing you, or you're testing on a laptop while connected to hotel wifi.

Don't do this in production unless you enjoy explaining to your manager why operators couldn't see the servers they just created.

### When Shorter TTLs Make Sense

Production environments with auto-scaling or multiple operators creating resources simultaneously need fresher data. The cost is more API calls, but the benefit is operators actually seeing reality instead of cached fiction from two minutes ago.

For chaotic production environments:

```swift
// Decrease for fresher data
case .server: return 60.0   // 1 minute instead of 2
case .network: return 180.0 // 3 minutes instead of 5
```

Use this when data freshness matters more than API load, when auto-scaling is actively creating and destroying instances, or when you have multiple operators who will absolutely create tickets if they can't immediately see the resource they just provisioned.

### How to Actually Tune TTLs

Start with the defaults. They work for most people. Then monitor your cache hit rates - you want 80% or better. If you're way above that and operators are complaining about stale data, reduce TTLs on the resource types that matter. If you're way below that, increase TTLs and reduce the API hammering.

Identify which resources actually churn in your environment. Maybe your servers change constantly but your networks are frozen in time since 2019. Adjust accordingly. Make changes incrementally - tune one resource type at a time and measure what happens. Did your cache hit rate improve? Did your API load go down? Did anything get worse? Document it and move on to the next adjustment.

## Search Performance Tuning

### Understanding Search Concurrency

The SearchEngine uses concurrent execution across multiple OpenStack services with a 5-second timeout per service. It aggregates results automatically and backs everything with cache. This means search is usually fast even when the API isn't.

The implementation is an actor with built-in concurrency control. You configure search through query parameters, not initialization settings:

```swift
let query = SearchQuery(
    text: "server-name",
    services: [.compute, .network, .storage],  // Specify which services to search
    scope: .all                                 // or .currentProject for faster results
)
```

For slower systems or networks, reduce the number of services you're searching. Use more specific search terms to cut down the result set size. Leverage the cache by avoiding unique queries - if you search for the same thing repeatedly, the second search will be nearly instant.

### Service Priority Configuration

We prioritized services based on what operators actually search for. Nova is highest priority because everyone searches for servers constantly. Neutron is second because network troubleshooting is half of every operator's job. Cinder comes third, Glance fourth, and Keystone and Swift are lowest because searching for users and objects is relatively rare.

Here's the default prioritization:

| Service | Priority | Why |
|---------|----------|-----|
| Nova (Compute) | 5 (Highest) | Operators search servers most |
| Neutron (Network) | 4 | Networking is second-most searched |
| Cinder (Storage) | 3 | Storage queries are common |
| Glance (Images) | 2 | Images searched occasionally |
| Keystone/Swift | 1 (Lowest) | Users/objects searched rarely |

If your workflow is different, adjust accordingly. Storage-heavy environment? Bump Cinder's priority. Running an image repository? Increase Glance's priority. The priorities affect timeout and resource allocation, so tune them to match your actual usage patterns.

## Memory Optimization

### Design Targets and Reality

We designed Substation to run in under 200MB steady state. The cache system should use less than 100MB for 10K resources. The search index should fit in 50MB. UI rendering should need less than 20MB. These are targets, not guarantees - your actual memory usage depends on how many resources you have and what types they are.

Most systems will be fine with the defaults. But if you're running on a machine with 2GB of RAM total, or if you have a beefy server with 64GB and want to cache everything forever, read on.

### Adjusting Memory Limits for Low-Memory Systems

If you have less than 2GB available, you'll want to be more aggressive about cache eviction and reduce cache sizes. This means less caching benefit but at least the application won't get killed by the OOM reaper at 3 AM.

```swift
// Reduce cache eviction threshold
let evictionThreshold = 0.70  // Evict at 70% instead of 85%

// Reduce cache sizes
cacheManager.configure(
    maxSize: 50_000_000,  // 50MB instead of 100MB
    defaultTTL: 180.0     // Reduce TTL to compensate
)
```

### Adjusting Memory Limits for High-Memory Systems

If you have more than 8GB available and want to maximize caching benefits, increase the eviction threshold and cache sizes. More cache means more hits, which means faster operations and less API load.

```swift
// Increase cache eviction threshold
let evictionThreshold = 0.90  // Evict at 90% instead of 85%

// Increase cache sizes
cacheManager.configure(
    maxSize: 200_000_000,  // 200MB instead of 100MB
    defaultTTL: 300.0      // Keep default TTL
)
```

### Handling Memory Pressure

Substation automatically cleans up cache when memory pressure hits 85%. L1 cache gets evicted first since it's the most ephemeral. If pressure continues, L2 cache goes next. L3 cache sticks around because it survives restarts and is expensive to rebuild.

You can manually trigger cleanup with `:cache-purge<Enter>` (or `:cc<Enter>`) in Substation. Do this when memory usage is high and you want to start fresh. The cache rebuilds on next access, so there's no permanent harm done.

## Network Optimization

### Understanding Connection Configuration

The default settings assume a reasonably fast network with occasional hiccups. We timeout after 30 seconds, retry 3 times, and validate SSL certificates because we're not barbarians.

```swift
public struct OpenStackConfig {
    public let timeout: TimeInterval = 30      // 30 second timeout
    public let retryCount: Int = 3             // 3 retry attempts
    public let validateCertificates: Bool = true
}
```

### Tuning for Network Conditions

If you have a fast, reliable network on a local data center, you can be more aggressive with timeouts and reduce retry attempts. Operations fail faster, which feels more responsive.

```swift
OpenStackConfig(
    authUrl: "https://keystone.local:5000/v3",
    timeout: 10,                // Reduce timeout
    retryCount: 2,              // Fewer retries
    validateCertificates: true
)
```

If your network is slow or unreliable - maybe you're connecting over VPN, or your OpenStack cluster is on the other side of the planet, or you're using satellite internet because why not - increase timeouts and retry counts. Better to wait than to fail.

```swift
OpenStackConfig(
    authUrl: "https://keystone.remote:5000/v3",
    timeout: 60,                // Increase timeout
    retryCount: 5,              // More retries
    validateCertificates: true
)
```

For VPN connections or high-latency scenarios where even 60 seconds might not be enough:

```swift
OpenStackConfig(
    authUrl: "https://keystone.vpn:5000/v3",
    timeout: 90,                // Much longer timeout
    retryCount: 5,              // More retries
    validateCertificates: false // Consider if cert issues
)
```

### Understanding Retry Logic

We use exponential backoff because hammering a failing API helps nobody. First attempt is immediate. Second attempt waits 1 second. Third waits 2 seconds. Fourth waits 4 seconds. This gives transient failures time to clear while not making you wait forever for permanent failures.

Reduce retry counts if you want fast failure in development environments. Increase them for unreliable networks in production where eventual success is more important than immediate feedback. Adjust the backoff timing if your API has specific behavior patterns - some APIs recover quickly, others need more breathing room.

## Monitoring Configuration

### Continuous Performance Monitoring

Substation has a health dashboard built in. Press `:health<Enter>` (or `:h<Enter>`) to see real-time metrics for cache hit rates, memory usage, and API response times. Check this regularly to establish your baseline and track trends over time.

Watch these metrics:
Cache hit rate should be 80% or better. Memory usage should stay under 200MB in steady state. API response times should be under 2 seconds for uncached requests. Search should complete in under 500ms. If any of these are consistently out of range, you've found your tuning target.

### Responding to Performance Alerts

Substation automatically alerts when cache hit rate drops below 60%, memory usage exceeds 85%, API response times go over 2 seconds, or search timeout rate climbs above 10%. These aren't suggestions - they're warnings that something is wrong.

When cache hit rate tanks, either increase TTLs or investigate what's churning. When memory usage spikes, reduce cache sizes or increase the eviction threshold. When API response times climb, check OpenStack service health - the problem might not be Substation. When search times out frequently, check network connectivity and service health.

### Regular Benchmark Reviews

Automated benchmarks run on a schedule: cache every 5 minutes, memory every 3 minutes, search every 10 minutes. Full suite runs on-demand or nightly. Review these regularly to catch performance regressions before they become incidents.

Look for performance drops of 10% or more - that's regression territory. Watch for gradual declines over time - that's usually a sign of growing data or slowly degrading infrastructure. Investigate sudden changes immediately - something broke or changed configuration. If your score drops below 0.8, optimization is needed.

## Configuration Examples by Environment Type

### Development Environment Configuration

Development environments can tolerate stale data in exchange for reduced API traffic. You're probably the only operator, you know when you create resources, and you'd rather have things load quickly than see real-time updates.

```swift
// Longer TTLs, less API traffic
case .server: return 300.0       // 5 minutes
case .network: return 600.0      // 10 minutes
case .flavor: return 1800.0      // 30 minutes

// Less aggressive memory management
let evictionThreshold = 0.90     // Evict at 90%

// Shorter timeouts (fast failure)
OpenStackConfig(
    timeout: 10,
    retryCount: 2
)
```

### Production Environment Configuration

Production needs balance between data freshness and API load. Multiple operators are working simultaneously. Resources change frequently but not constantly. Reliability matters more than raw speed.

```swift
// Default TTLs (balanced)
case .server: return 120.0       // 2 minutes
case .network: return 300.0      // 5 minutes
case .flavor: return 900.0       // 15 minutes

// Conservative memory management
let evictionThreshold = 0.85     // Evict at 85%

// Longer timeouts (reliability)
OpenStackConfig(
    timeout: 30,
    retryCount: 3
)
```

### High-Churn Environment Configuration

Auto-scaling, continuous deployment, or chaos engineering environments need the freshest possible data. API load is a secondary concern to data accuracy.

```swift
// Shorter TTLs (fresher data)
case .server: return 60.0        // 1 minute
case .network: return 180.0      // 3 minutes
case .flavor: return 900.0       // 15 minutes (still static)

// Standard memory management
let evictionThreshold = 0.85

// Standard timeouts
OpenStackConfig(
    timeout: 30,
    retryCount: 3
)
```

## Best Practices Summary

**Configuration management**: Start with defaults. Monitor metrics. Adjust based on actual measured performance in your environment, not theoretical optimization. Document why you changed things so the next operator doesn't undo your carefully tuned settings.

**Monitoring strategy**: Use the health dashboard regularly. Establish your baseline. Watch for trends. Respond to alerts promptly. Run benchmarks regularly and compare against baseline. Investigate any regression over 10%.

**Optimization workflow**: Accept slightly stale data in exchange for cache benefits. Let Substation handle retries automatically. Use specific search queries. Consider your actual system resources when tuning. Low RAM means smaller caches. Fast CPU means you can handle more concurrency. Slow network means longer timeouts.

**Maintenance tasks**: Review performance targets quarterly. Clean up benchmark data older than 7 days. Monitor memory patterns over days and weeks to catch slow leaks. Review cache configurations after major environment changes or when usage patterns shift.

---

**See Also**:

- [Performance Overview](index.md) - Architecture and key components
- [Performance Benchmarks](benchmarks.md) - Metrics and scoring
- [MemoryKit API Reference](../reference/api/memorykit.md) - Deep dive into caching

**Note**: All tuning recommendations and targets are based on design goals and testing with 10K+ resource environments. Actual performance will vary based on your specific OpenStack deployment, network conditions, and system resources. Start with defaults and adjust based on measured metrics in your environment.
