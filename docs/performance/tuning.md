# Performance Tuning Guide

Configuration strategies, monitoring best practices, and optimization techniques for production OpenStack environments.

## Cache Tuning

### Resource-Specific TTL Configuration

**Location**: `CacheManager.swift:100`

Default TTL values are tuned for typical environments, but you may need to adjust based on your specific use case:

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

### When to Increase TTLs

**Stable development environment**:

```swift
// Increase for less API traffic
case .server: return 300.0  // 5 minutes instead of 2
case .network: return 600.0  // 10 minutes instead of 5
case .flavor: return 1800.0  // 30 minutes instead of 15
```

**Benefits**:

- Fewer API calls (better API performance)
- Lower network traffic
- Faster operations (more cache hits)

**Tradeoffs**:

- Staler data
- Longer delay seeing new resources
- Not suitable for production

**Use when**:

- Development/testing environments
- OpenStack API is slow
- Network latency is high
- You control resource creation timing

### When to Decrease TTLs

**Chaotic production with auto-scaling**:

```swift
// Decrease for fresher data
case .server: return 60.0   // 1 minute instead of 2
case .network: return 180.0 // 3 minutes instead of 5
```

**Benefits**:

- Fresher data
- See new resources faster
- Better for auto-scaling environments

**Tradeoffs**:

- More API calls
- Higher API load
- Potentially slower operations

**Use when**:

- Production with frequent changes
- Auto-scaling is active
- Multiple operators creating resources
- Data freshness is critical

### TTL Tuning Strategy

1. **Start with defaults** (they're tuned for typical environments)
2. **Monitor cache hit rates** (target: 80%+)
3. **Identify resource churn** (which resources change most?)
4. **Adjust TTLs incrementally** (don't change everything at once)
5. **Measure impact** (did hit rate improve? Did API load decrease?)

## Search Performance Tuning

### Concurrency Configuration

**Default configuration**:

The SearchEngine uses concurrent execution with automatic timeout handling:

```swift
// SearchEngine is configured with:
// - Concurrent execution across multiple services
// - 5 second timeout per service
// - Automatic result aggregation
// - Cache-backed search results
```

### Adjust for System Capabilities

**Note**: The SearchEngine is implemented as an actor with built-in concurrency control. Configuration is managed through the search query parameters rather than initialization.

**Search query configuration**:

```swift
let query = SearchQuery(
    text: "server-name",
    services: [.compute, .network, .storage],  // Specify which services to search
    scope: .all                                 // or .currentProject for faster results
)
```

**For slower systems or networks**:

- Reduce the number of services in the search query
- Use more specific search terms to reduce result set size
- Leverage the cache by avoiding frequent unique queries

### Service Priority Tuning

Default service prioritization:

| Service | Priority | Why |
|---------|----------|-----|
| Nova (Compute) | 5 (Highest) | Operators search servers most |
| Neutron (Network) | 4 | Networking is second-most searched |
| Cinder (Storage) | 3 | Storage queries are common |
| Glance (Images) | 2 | Images searched occasionally |
| Keystone/Swift | 1 (Lowest) | Users/objects searched rarely |

**Adjust if your workflow differs**:

- Storage-heavy environment? Increase Cinder priority
- Image management focus? Increase Glance priority

## Memory Optimization

### Cache Size Configuration

**Design targets**:

- Total application: < 200MB steady state
- Cache system: < 100MB for 10k resources
- Search index: < 50MB for full catalog
- UI rendering: < 20MB framebuffer

Note: Actual memory usage will vary based on your specific resource count and types.

### Adjust Memory Limits

**Low-memory systems** (< 2GB available):

```swift
// Reduce cache eviction threshold
let evictionThreshold = 0.70  // Evict at 70% instead of 85%

// Reduce cache sizes
cacheManager.configure(
    maxSize: 50_000_000,  // 50MB instead of 100MB
    defaultTTL: 180.0     // Reduce TTL to compensate
)
```

**High-memory systems** (> 8GB available):

```swift
// Increase cache eviction threshold
let evictionThreshold = 0.90  // Evict at 90% instead of 85%

// Increase cache sizes
cacheManager.configure(
    maxSize: 200_000_000,  // 200MB instead of 100MB
    defaultTTL: 300.0      // Keep default TTL
)
```

### Memory Pressure Handling

**Automatic cleanup triggers**:

- At 85% memory utilization (default)
- L1 cache evicted first (most ephemeral)
- L2 cache evicted if pressure continues
- L3 cache kept (survives restarts)

**Manual cleanup**:

- Use `:cache-purge<Enter>` (or `:cc<Enter>`) in Substation to purge all caches
- Use when memory usage is high
- Rebuilds cache on next access

## Network Optimization

### Connection Configuration

**Default settings**:

```swift
public struct OpenStackConfig {
    public let timeout: TimeInterval = 30      // 30 second timeout
    public let retryCount: Int = 3             // 3 retry attempts
    public let validateCertificates: Bool = true
}
```

### Adjust for Network Conditions

**Fast, reliable network**:

```swift
OpenStackConfig(
    authUrl: "https://keystone.local:5000/v3",
    timeout: 10,                // Reduce timeout
    retryCount: 2,              // Fewer retries
    validateCertificates: true
)
```

**Slow or unreliable network**:

```swift
OpenStackConfig(
    authUrl: "https://keystone.remote:5000/v3",
    timeout: 60,                // Increase timeout
    retryCount: 5,              // More retries
    validateCertificates: true
)
```

**VPN or high-latency connection**:

```swift
OpenStackConfig(
    authUrl: "https://keystone.vpn:5000/v3",
    timeout: 90,                // Much longer timeout
    retryCount: 5,              // More retries
    validateCertificates: false // Consider if cert issues
)
```

### Retry Logic Configuration

**Exponential backoff strategy**:

- Attempt 1: Immediate
- Attempt 2: 1 second delay
- Attempt 3: 2 seconds delay
- Attempt 4: 4 seconds delay

**When to adjust**:

- Reduce retries for fast failure (dev environments)
- Increase retries for unreliable networks (production)
- Adjust backoff for specific API behavior

## Monitoring Configuration

### Enable Continuous Performance Monitoring

**In Substation TUI**:

- Use `:health<Enter>` (or `:h<Enter>`) for health dashboard
- Real-time metrics display
- Cache hit rates, memory usage, API response times

**Key metrics to watch**:

- Cache hit rate (design target: 80%+)
- Memory usage (design target: < 200MB)
- API response time (design target: < 2s uncached)
- Search performance (design target: < 500ms)

### Set Up Performance Alerts

**Automatic alerts trigger when**:

- Cache hit rate < 60%
- Memory usage > 85%
- API response time > 2s
- Search timeout rate > 10%

**How to respond**:

- Low cache hit rate -> Increase TTLs or investigate churn
- High memory usage -> Reduce cache sizes or increase eviction threshold
- Slow API -> Check OpenStack service health
- High search timeouts -> Check network or service health

### Regular Benchmark Reviews

**Automated benchmark schedule**:

- Cache benchmarks: Every 5 minutes
- Memory benchmarks: Every 3 minutes
- Search benchmarks: Every 10 minutes
- Full suite: On-demand or nightly

**What to look for**:

- Performance regressions (10%+ degradation)
- Trends over time (gradual decline)
- Sudden changes (investigate immediately)
- Score below 0.8 threshold (optimization needed)

## Best Practices

### 1. Configuration Management

**Set appropriate TTL values**:

- Start with defaults
- Adjust based on environment stability
- Monitor cache hit rates
- Iterate based on metrics

**Adjust memory limits**:

- Design target: < 200MB steady state
- Allow headroom for spikes
- Monitor actual usage patterns
- Adjust eviction threshold as needed

**Tune search concurrency**:

- Default 6 concurrent searches
- Reduce for lower-end systems
- Keep at 6 for high-performance systems

**Configure retry logic**:

- Default: 3 retries with exponential backoff
- Increase for unreliable networks
- Decrease for fast-failure environments

### 2. Monitoring Strategy

**Enable continuous monitoring**:

- Use health dashboard (`h` key)
- Check metrics regularly
- Establish baseline performance
- Track trends over time

**Set up alerts**:

- Configure threshold alerts
- Monitor critical metrics
- Respond to alerts promptly
- Document alert responses

**Review benchmark reports**:

- Run benchmarks regularly
- Compare with baseline
- Investigate regressions
- Document optimizations

**Monitor for regressions**:

- Automatic 10%+ drop alerts
- Compare current vs historical
- Investigate sudden changes
- Track after code changes

### 3. Optimization Workflow

**Use cached operations**:

- Cache-first architecture
- Accept slightly stale data
- Leverage L1/L2/L3 hierarchy
- Monitor cache effectiveness

**Implement proper error handling**:

- Let Substation handle retries
- Don't retry client errors (4xx)
- Do retry server errors (5xx)
- Log failures for analysis

**Optimize search queries**:

- Use specific queries
- Filter by service when possible
- Leverage cached searches
- Accept partial results on timeout

**Consider system resources**:

- Low RAM -> Reduce cache sizes
- Fast CPU -> Increase concurrency
- Slow network -> Increase timeouts
- Monitor resource usage

### 4. Maintenance Tasks

**Regular reviews**:

- Review performance targets quarterly
- Update TTL configurations
- Adjust memory limits
- Optimize based on trends

**Clean up benchmark data**:

- Keep last 7 days for trends
- Archive older data
- Clear periodically
- Export for long-term analysis

**Monitor memory patterns**:

- Track over days/weeks
- Look for memory leaks
- Adjust eviction threshold
- Document usage patterns

**Review cache configurations**:

- Every few months
- After major environment changes
- When usage patterns change
- Document configuration rationale

## Production Horror Story: The Great API Meltdown of 2023

**The Scenario**: One operator's OpenStack cluster served 50K servers across 1000 projects. They tried to list all servers using the Python CLI (no caching).

**What Happened**:

- API request took 3 minutes
- Database connections maxed out
- Other API requests started timing out
- Monitoring alerted (ironically, monitoring couldn't query the API)
- On-call got paged at 4:17 AM
- Incident report: "Operator overwhelmed API with bulk query"

**With Substation**:

- First query: 2 seconds (API call)
- Second query: < 1ms (L1 cache hit)
- Cache valid for 2 minutes
- API only hit every 2 minutes, not every second
- No database meltdown
- No 4 AM pages

**Lesson**: Caching isn't just performance. It's reliability.

## Configuration Examples

### Development Environment

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

### Production Environment

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

### High-Churn Environment

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

---

**See Also**:

- [Performance Overview](overview.md) - Architecture and key components
- [Performance Benchmarks](benchmarks.md) - Metrics and scoring
- [Troubleshooting](troubleshooting.md) - Performance issue diagnosis
- [Caching Concepts](../concepts/caching.md) - Deep dive into caching

**Note**: All tuning recommendations and targets are based on design goals and testing with 10K+ resource environments. Actual performance will vary based on your specific OpenStack deployment, network conditions, and system resources. Start with defaults and adjust based on measured metrics in your environment.
