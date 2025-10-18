# Caching System

Understanding Substation's multi-level caching architecture.

## Overview

Substation is designed to achieve **up to 60-80% API call reduction** through MemoryKit, a sophisticated multi-level caching system that aims to dramatically improve performance while maintaining data freshness.

**The Problem**: OpenStack APIs are slow (2+ seconds per call). Your workflow requires hundreds of API calls. Without caching, you'd be waiting minutes for simple operations.

**The Solution**: Intelligent caching with resource-specific TTLs and multi-level hierarchy.

**Note**: Actual cache hit rates and performance improvements will vary based on your usage patterns, resource churn rate, and OpenStack API performance.

## Cache Architecture

### Multi-Level Hierarchy

Substation implements a three-tier cache system, similar to CPU cache architecture:

```
Request → L1 Cache → L2 Cache → L3 Cache → API
         (< 1ms)    (~5ms)     (~20ms)    (2+ sec)
    (target 80%)(target 15%)(target 3%)(target 2%)
```

#### L1 Cache (Memory - Hot Data)

- **Speed**: Target < 1ms retrieval
- **Hit Rate**: Target 80% of requests
- **Storage**: In-memory (RAM)
- **Persistence**: Cleared on restart
- **Purpose**: Frequently accessed data

**Characteristics:**

- Lightning fast access
- Limited size (memory constrained)
- Most recent and frequently used data
- First to be evicted under memory pressure

#### L2 Cache (Larger Memory - Warm Data)

- **Speed**: Target ~5ms retrieval
- **Hit Rate**: Target 15% of requests
- **Storage**: Larger in-memory pool
- **Persistence**: Cleared on restart
- **Purpose**: Less frequently accessed data

**Characteristics:**

- Still fast, slightly slower than L1
- Larger capacity than L1
- Recently used but not hot data
- Second priority for eviction

#### L3 Cache (Disk - Cold Data)

- **Speed**: ~20ms retrieval
- **Hit Rate**: 3% of requests
- **Storage**: On-disk cache
- **Persistence**: Survives restarts
- **Purpose**: Historical data and startup acceleration

**Characteristics:**

- Slowest cache tier (but still faster than API)
- Survives application restarts
- Persistent storage
- Enables fast startup with warm cache

### Total Cache Performance

**Combined Hit Rate**: 98% (L1 + L2 + L3)
**Cache Miss Rate**: 2% (requires API call)

**Result**: Only 2% of operations hit the slow OpenStack API.

## Resource-Specific TTLs

Different resource types have different volatility, so we cache them differently:

### TTL Strategy

| Resource Type | TTL | Rationale |
|--------------|-----|-----------|
| **Authentication Tokens** | 3600s (1 hour) | Keystone token lifetime |
| **Service Endpoints, Quotas** | 1800s (30 min) | Semi-static infrastructure |
| **Flavors, Volume Types** | 900s (15 min) | Rarely change in production |
| **Keypairs, Images, Networks, Subnets, Routers, Security Groups** | 300s (5 min) | Moderately dynamic |
| **Volume Snapshots, Object Storage** | 180s (3 min) | Dynamic storage resources |
| **Servers, Volumes, Ports, Floating IPs** | 120s (2 min) | Highly dynamic (state changes frequently) |

### Why These TTLs?

**Very Long TTL (1 hour):**

- Auth Tokens: Keystone tokens last 1 hour anyway
- Benefit: Minimal auth overhead

**Long TTL (30 minutes):**

- Service Endpoints: These never change (until they do)
- Quotas: Project limits rarely change
- Benefit: Minimal API overhead, near-static data

**Medium TTL (15 minutes):**

- Flavors: Admins add new sizes occasionally
- Volume Types: Storage types rarely change once configured
- Benefit: Fewer API calls, better performance

**Moderate TTL (5 minutes):**

- Keypairs: SSH keys added occasionally
- Images: OS images rarely change once uploaded
- Networks: Created occasionally, stable once created
- Subnets: Network configuration is semi-stable
- Routers: Routing infrastructure changes infrequently
- Security Groups: Rules change but not constantly
- Benefit: Balance between freshness and performance

**Short TTL (3 minutes):**

- Volume Snapshots: Snapshot operations moderately frequent
- Object Storage: Object containers and metadata change periodically
- Benefit: Fresher data for storage operations

**Very Short TTL (2 minutes):**

- Servers: State changes frequently (building, active, error)
- Volumes: Attach/detach operations common
- Ports: Network interfaces dynamic
- Floating IPs: IP assignments change frequently
- Benefit: Reasonably fresh data for highly dynamic resources

## Cache Operations

### Cache Hit (The Fast Path)

When data is in cache:

1. Request arrives
2. L1 cache checked (< 1ms)
3. If found and fresh (TTL not expired):
   - Data returned immediately
   - No API call needed
   - **80% of requests take this path**

### Cache Miss (The Slow Path)

When data is not in cache or expired:

1. Request arrives
2. L1 cache miss
3. L2 cache checked (~5ms)
4. L2 cache miss
5. L3 cache checked (~20ms)
6. L3 cache miss
7. OpenStack API called (2+ seconds)
8. Response stored in all cache levels
9. Data returned to user
10. Future requests hit cache

**Only 2% of requests take this full path.**

### Cache Invalidation

**Manual Invalidation:**

- Use `:cache-purge<Enter>` (or `:clear-cache<Enter>` or `:cc<Enter>`) in Substation to purge ALL caches
- Clears L1, L2, and L3
- Next operations slower while cache rebuilds

**Automatic Invalidation:**

- TTL expiration (resource-specific timeouts)
- Memory pressure (automatic eviction at 85% usage)
- Explicit updates (after create/delete operations)

**When to Purge Manually:**

- Data looks stale or wrong
- Just made major changes outside Substation
- Debugging data issues
- After OpenStack cluster issues

## Memory Management

### Memory Pressure Handling

Substation monitors memory usage and automatically manages cache:

**Thresholds:**

- **Normal Operation**: < 85% memory usage
- **Eviction Starts**: 85% memory usage
- **Target After Eviction**: 75% memory usage

**Eviction Order:**

1. L1 cache entries (oldest first)
2. L2 cache entries (oldest first)
3. L3 cache preserved (on-disk)

**Why This Approach:**

- Prevents out-of-memory (OOM) crashes
- Maintains system stability
- Preserves disk cache for restart
- Automatic and transparent

### Expected Memory Usage

**Base Application**: ~200MB
**Cache for 10,000 resources**: ~100MB
**Total Typical**: 200-400MB

**For Large Deployments:**

- 50,000 resources: ~500MB
- 100,000 resources: ~800MB

**This is normal and expected.**

## Cache Statistics

### Monitoring Cache Performance

Use `:health<Enter>` (or `:healthdashboard<Enter>` or `:h<Enter>`) in Substation for the Health Dashboard:

**Key Metrics:**

- **Cache Hit Rate**: Target 80%+, typical 85-90%
- **Memory Usage**: Target < 85%, eviction starts at 85%
- **Average Response Time**: < 100ms cached, 2+ seconds uncached
- **Eviction Count**: Should be low in normal operation

### Performance Indicators

**Good Performance:**

- Cache hit rate: 80%+
- Memory usage: 50-75%
- Low eviction count
- Response times < 100ms

**Degraded Performance:**

- Cache hit rate: < 60%
- Memory usage: > 85%
- High eviction count
- Frequent cache misses

**Action Required:**

- Hit rate < 60%: Check TTL configuration, may need adjustment
- Memory > 85%: Close other apps, increase system RAM
- High evictions: Reduce cache sizes or increase memory

## Cache Tuning

### Adjusting TTLs for Your Environment

**Stable Environments (Dev/Staging):**

- Increase TTLs (less API load)
- Servers: 300s (5 min) instead of 120s
- Networks: 600s (10 min) instead of 300s
- Flavors: Keep at 900s (15 min)
- Images: 600s (10 min) instead of 300s

**Chaotic Environments (Production with Auto-Scaling):**

- Decrease TTLs (fresher data)
- Servers: 60s (1 min) instead of 120s
- Networks: 180s (3 min) instead of 300s
- Accept lower cache hit rates (60%+ is good)

**Current Implementation:**

TTLs are hardcoded in `CacheManager.swift:100`. Future versions may expose this in configuration.

### Memory Tuning

**Increase Cache Size** (if you have RAM):

- More memory = more cached items
- Better hit rates
- Fewer API calls

**Decrease Cache Size** (if memory constrained):

- Less memory usage
- More evictions
- Lower hit rates
- More API calls

**Current Implementation:**

Memory limits are auto-calculated based on available system RAM. Future versions may expose manual configuration.

## Implementation Details

### MemoryKit Components

Located in `/Sources/MemoryKit/`:

| Component | Purpose |
|-----------|---------|
| `MultiLevelCacheManager.swift` | L1/L2/L3 orchestration |
| `CacheManager.swift` | Core caching logic |
| `MemoryManager.swift` | Memory pressure handling |
| `TypedCacheManager.swift` | Type-safe cache ops |
| `PerformanceMonitor.swift` | Metrics tracking |
| `MemoryKit.swift` | Public API |
| `MemoryKitLogger.swift` | Logging |
| `ComprehensiveMetrics.swift` | Metrics aggregation |

### Cache Key Strategy

Cache keys are constructed from:

- Resource type (server, network, volume, etc.)
- Resource ID (UUID)
- Query parameters (for list operations)

Example cache keys:

```
server:abc-123-def-456
server:list:project=xyz
network:def-789-ghi-012
flavor:list:all
```

### Thread Safety

All cache operations are **actor-based**:

- No locks or mutexes required
- Guaranteed thread safety
- Swift 6 strict concurrency enforced
- Zero data race conditions

## Best Practices

### For Operators

1. **Let the cache work** - Don't constantly press `c`
2. **Monitor hit rates** - Use `:health<Enter>` (or `:h<Enter>`) to check cache performance
3. **Purge strategically** - Only when data is truly stale
4. **Accept short delays on first load** - Cache warming is normal

### For Developers

1. **Respect TTLs** - Don't bypass cache unless necessary
2. **Monitor memory** - Watch for memory leaks
3. **Test under load** - Validate cache behavior with 10K+ resources
4. **Profile eviction** - Ensure eviction works under pressure

## Troubleshooting

### Low Cache Hit Rate

**Symptoms**: Hit rate < 60% in Health Dashboard

**Causes:**

- Constantly pressing `c` (cache purge)
- TTLs too short for environment
- High memory pressure (frequent evictions)
- Resources changing very rapidly

**Solutions:**

1. Stop purging cache manually
2. Let cache warm up (first loads are slow)
3. Check memory usage (< 85% is good)
4. For stable environments, consider longer TTLs (future)

### High Memory Usage

**Symptoms**: Memory > 85%, frequent evictions

**Causes:**

- Too many resources (50K+ servers)
- Other applications using RAM
- Memory leak (unlikely, but report if suspected)

**Solutions:**

1. Close other applications
2. Filter views with `/` (reduces active dataset)
3. Use project-scoped credentials (fewer resources)
4. Increase system RAM

### Stale Data

**Symptoms**: Resources not appearing, wrong states

**Causes:**

- TTL hasn't expired yet
- Cache holds old data
- OpenStack cluster had issues

**Solutions:**

1. Use `:cache-purge<Enter>` (or `:cc<Enter>`) to purge cache
2. Use `:refresh<Enter>` (or `:reload<Enter>`) to refresh view
3. Fresh data loads from API

---

**Remember**: Caching is the secret to Substation's performance. 60-80% fewer API calls means your OpenStack cluster thanks you, and your operations are lightning fast.

*Cache wisely, operate swiftly.*
