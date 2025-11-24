# MemoryKit API Reference

## Overview

MemoryKit is a high-performance, thread-safe memory management and caching framework for Swift applications. Built with Swift actors and modern concurrency patterns, it provides intelligent resource management, multi-level caching, and real-time performance monitoring capabilities specifically designed for the Substation OpenStack TUI.

### Key Features
- **Thread-Safe Architecture**: Built on Swift actors for guaranteed thread safety
- **Multi-Level Cache Hierarchy**: L1 (memory), L2 (compressed memory), and L3 (disk) caching
- **Intelligent Eviction Policies**: LRU, LFU, FIFO, TTL, and adaptive strategies
- **Performance Monitoring**: Real-time metrics and alerting
- **Memory Pressure Management**: Automatic cleanup and resource optimization
- **Type-Safe APIs**: Generic implementations with full type safety
- **Cross-Platform Support**: Works on macOS and Linux

## Installation and Integration

### Swift Package Manager

Add MemoryKit as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(path: "path/to/substation")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "MemoryKit", package: "substation")
        ]
    )
]
```

### Basic Setup

```swift
import MemoryKit

// Initialize MemoryKit with default configuration
let memoryKit = await MemoryKit()

// Or with custom configuration
let config = MemoryKit.Configuration(
    memoryManagerConfig: MemoryManager.Configuration(
        maxCacheSize: 5000,
        maxMemoryBudget: 100 * 1024 * 1024, // 100MB
        cleanupInterval: 600.0 // 10 minutes
    )
)
let memoryKit = await MemoryKit(configuration: config)
```

## Architecture

MemoryKit is structured as a modular system with the following components:

### Core Components

1. **MemoryKit** - Main orchestrator providing unified access
2. **MemoryManager** - Core memory management with automatic cleanup
3. **CacheManager** - Generic cache with eviction policies
4. **MultiLevelCacheManager** - Three-tier cache hierarchy
5. **PerformanceMonitor** - Real-time monitoring and alerting
6. **ResourcePool** - Pool for expensive object reuse

### Cache Hierarchy

```
+-------------------------------------+
|         L1 Cache (Memory)           |
|    Fast, Small, Frequently Used     |
+-------------------------------------+
                 v^
+-------------------------------------+
|      L2 Cache (Compressed)          |
|    Medium Speed, Compressed Data    |
+-------------------------------------+
                 v^
+-------------------------------------+
|         L3 Cache (Disk)             |
|    Slow, Large, Persistent          |
+-------------------------------------+
```

## API Reference

### MemoryKit (Main Interface)

The primary entry point for all MemoryKit functionality.

#### Initialization

```swift
public actor MemoryKit {
    public init(configuration: Configuration = Configuration()) async
}
```

#### Configuration

```swift
public struct Configuration: Sendable {
    public let memoryManagerConfig: MemoryManager.Configuration
    public let performanceMonitorConfig: PerformanceMonitor.Configuration

    public init(
        memoryManagerConfig: MemoryManager.Configuration = MemoryManager.Configuration(),
        performanceMonitorConfig: PerformanceMonitor.Configuration = PerformanceMonitor.Configuration()
    )
}
```

#### Methods

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `getHealthReport()` | Get comprehensive system health report | None | `SystemHealthReport` |
| `forceCleanup()` | Force comprehensive cleanup of all components | None | `Void` |
| `createTypedCacheManager<K,V>()` | Create a specialized cache manager | `keyType`, `valueType`, `configuration` | `CacheManager<K,V>` |
| `createResourcePool<R>()` | Create a resource pool | `resourceType`, `configuration`, `factory`, `cleanup`, `validator` | `ResourcePool<R>` |
| `createMultiLevelCacheManager<K,V>()` | Create multi-level cache | `keyType`, `valueType`, `configuration`, `logger` | `MultiLevelCacheManager<K,V>` |

### MemoryManager

Provides thread-safe memory management with automatic cleanup.

#### Singleton Access

```swift
let manager = MemoryManager.shared
```

#### Configuration

```swift
public struct Configuration: Sendable {
    public let maxCacheSize: Int              // Maximum number of entries
    public let maxMemoryBudget: Int          // Maximum memory in bytes
    public let cleanupInterval: TimeInterval  // Automatic cleanup interval
    public let pressureThreshold: Double      // Memory pressure threshold (0.0-1.0)
    public let enableMetrics: Bool           // Enable metrics collection
    public let enableLeakDetection: Bool     // Enable leak detection
    public let logger: any MemoryKitLogger   // Logger instance
}
```

#### Methods

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `store<T>(_ data: T, forKey: String)` | Store data in cache | `data: Sendable`, `key: String` | `Void` |
| `retrieve<T>(forKey: String, as: T.Type)` | Retrieve data from cache | `key: String`, `type: T.Type` | `T?` |
| `clearKey(_ key: String)` | Clear specific key | `key: String` | `Void` |
| `clearAll()` | Clear all cached data | None | `Void` |
| `getMetrics()` | Get memory metrics | None | `MemoryMetrics` |
| `getCacheStats()` | Get cache statistics | None | `CacheStats` |
| `forceCleanup()` | Force memory cleanup | None | `Void` |
| `isUnderMemoryPressure()` | Check memory pressure | None | `Bool` |
| `start()` | Start background tasks | None | `Void` |

### CacheManager<Key, Value>

Generic cache manager with intelligent eviction policies.

#### Configuration

```swift
public struct Configuration: Sendable {
    public let maxSize: Int                    // Maximum entries
    public let maxMemoryUsage: Int            // Maximum memory bytes
    public let defaultTTL: TimeInterval       // Default time-to-live
    public let enableTTL: Bool               // Enable TTL tracking
    public let evictionPolicy: EvictionPolicy // Eviction strategy
    public let compressionEnabled: Bool      // Enable compression
    public let enableMetrics: Bool          // Enable metrics
}
```

#### Eviction Policies

```swift
public enum EvictionPolicy: Sendable {
    case lru      // Least Recently Used
    case lfu      // Least Frequently Used
    case fifo     // First In, First Out
    case random   // Random eviction
    case ttl      // Time To Live based
    case adaptive // Adaptive based on access patterns
}
```

#### Methods

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `set(_ value: Value, forKey: Key, ttl: TimeInterval?)` | Store value | `value`, `key`, optional `ttl` | `Void` |
| `get(_ key: Key)` | Retrieve value | `key` | `Value?` |
| `remove(_ key: Key)` | Remove entry | `key` | `Void` |
| `removeAll()` | Clear all entries | None | `Void` |
| `count()` | Get entry count | None | `Int` |
| `memoryUsage()` | Get memory usage | None | `Int` |
| `getMetrics()` | Get cache metrics | None | `CacheMetrics` |
| `evictToSize(_ targetSize: Int)` | Force eviction | `targetSize` | `Void` |
| `contains(_ key: Key)` | Check key existence | `key` | `Bool` |
| `start()` | Start cleanup tasks | None | `Void` |

### MultiLevelCacheManager<Key, Value>

Three-tier cache with intelligent promotion and demotion.

#### Configuration

```swift
public struct Configuration: Sendable {
    public let l1MaxSize: Int          // L1 max entries
    public let l1MaxMemory: Int        // L1 max memory (bytes)
    public let l2MaxSize: Int          // L2 max entries
    public let l2MaxMemory: Int        // L2 max memory (bytes)
    public let l3MaxSize: Int          // L3 max entries
    public let l3CacheDirectory: URL?  // L3 disk location
    public let defaultTTL: TimeInterval // Default TTL
    public let enableCompression: Bool  // Enable compression
    public let enableMetrics: Bool      // Enable metrics
}
```

#### Cache Priority

```swift
public enum CachePriority: Int, CaseIterable, Sendable {
    case critical = 4  // Auth tokens, service endpoints
    case high = 3      // Active servers, current projects
    case normal = 2    // General resources
    case low = 1       // Historical data, rarely accessed
}
```

#### Methods

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `store(_ value: Value, forKey: Key, priority: CachePriority, customTTL: TimeInterval?)` | Store with priority | `value`, `key`, `priority`, optional `ttl` | `Void` |
| `retrieve(forKey: Key, as: Value.Type)` | Retrieve with promotion | `key`, `type` | `Value?` |
| `remove(forKey: Key)` | Remove from all levels | `key` | `Void` |
| `clearAll()` | Clear all cache levels | None | `Void` |
| `getStatistics()` | Get comprehensive stats | None | `MultiLevelCacheStatistics` |
| `start()` | Start maintenance tasks | None | `Void` |

### ResourcePool<Resource>

Thread-safe pool for expensive-to-create objects.

#### Configuration

```swift
public struct Configuration: Sendable {
    public let maxPoolSize: Int           // Maximum pool size
    public let minPoolSize: Int           // Minimum pool size
    public let idleTimeout: TimeInterval  // Idle resource timeout
    public let enableMetrics: Bool        // Enable metrics
}
```

#### Methods

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `acquire()` | Acquire resource from pool | None | `Resource` (throws) |
| `release(_ resource: Resource)` | Return resource to pool | `resource` | `Void` |
| `getStats()` | Get pool statistics | None | `PoolStats` |
| `cleanupIdleResources()` | Cleanup idle resources | None | `Void` |
| `start()` | Start cleanup tasks | None | `Void` |

### PerformanceMonitor

Real-time performance monitoring and alerting.

#### Configuration

```swift
public struct Configuration: Sendable {
    public let enableMonitoring: Bool
    public let metricsCollectionInterval: TimeInterval
    public let alertThresholds: AlertThresholds
}
```

#### Alert Types

```swift
public enum PerformanceAlert: Sendable {
    case highMemoryUsage(current: Double, threshold: Double)
    case lowCacheHitRate(current: Double, threshold: Double)
    case slowResponseTime(current: TimeInterval, threshold: TimeInterval)
}
```

#### Methods

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `collectMetrics()` | Collect current metrics | None | `UnifiedMetrics` |
| `getActiveAlerts()` | Get active alerts | None | `[PerformanceAlert]` |
| `registerComponents(memoryManager:)` | Register components | `memoryManager` | `Void` |

## Usage Examples

### Basic Cache Operations

```swift
// Store and retrieve simple data
let memoryManager = MemoryManager.shared
await memoryManager.start()

// Store data
await memoryManager.store("Hello, World!", forKey: "greeting")
await memoryManager.store(userData, forKey: "user_123")

// Retrieve data
if let greeting = await memoryManager.retrieve(forKey: "greeting", as: String.self) {
    print(greeting) // "Hello, World!"
}

// Check cache stats
let stats = await memoryManager.getCacheStats()
print("Cache hit rate: \(stats.hitRate * 100)%")
```

### Typed Cache Manager

```swift
// Create a typed cache for specific data types
let userCache = CacheManager<String, User>(
    configuration: CacheManager<String, User>.Configuration(
        maxSize: 1000,
        defaultTTL: 300,
        evictionPolicy: .lru
    )
)
await userCache.start()

// Store user data
let user = User(id: "123", name: "John Doe")
await userCache.set(user, forKey: "user_123", ttl: 600)

// Retrieve user data
if let cachedUser = await userCache.get("user_123") {
    print("Found user: \(cachedUser.name)")
}
```

### Multi-Level Cache

```swift
// Create multi-level cache for OpenStack resources
let resourceCache = MultiLevelCacheManager<String, Server>(
    configuration: MultiLevelCacheManager<String, Server>.Configuration(
        l1MaxSize: 100,      // Keep 100 hot items in memory
        l2MaxSize: 500,      // Keep 500 compressed items
        l3MaxSize: 10000,    // Keep 10k items on disk
        defaultTTL: 3600     // 1 hour TTL
    )
)
await resourceCache.start()

// Store server with priority
let server = Server(id: "srv-123", name: "production-web-01")
await resourceCache.store(
    server,
    forKey: server.id,
    priority: .high,     // High priority for production servers
    customTTL: 7200      // 2 hour TTL
)

// Retrieve (automatically promotes between levels)
if let cachedServer = await resourceCache.retrieve(
    forKey: "srv-123",
    as: Server.self
) {
    print("Server: \(cachedServer.name)")
}

// Get statistics
let stats = await resourceCache.getStatistics()
print(stats.description)
```

### Resource Pool

```swift
// Create a pool for expensive database connections
let dbPool = ResourcePool<DatabaseConnection>(
    configuration: ResourcePool<DatabaseConnection>.Configuration(
        maxPoolSize: 10,
        minPoolSize: 2,
        idleTimeout: 300
    ),
    factory: {
        // Create new connection
        return try await DatabaseConnection.create()
    },
    cleanup: { connection in
        // Clean up connection
        await connection.close()
    },
    validator: { connection in
        // Validate connection is still alive
        return await connection.isAlive()
    }
)
await dbPool.start()

// Use pooled resource
let connection = try await dbPool.acquire()
defer {
    Task {
        await dbPool.release(connection)
    }
}
// Use connection...
```

## Configuration Guide

### Memory Manager Configuration

```swift
let config = MemoryManager.Configuration(
    maxCacheSize: 5000,              // Entries before eviction
    maxMemoryBudget: 150_000_000,    // 150MB budget
    cleanupInterval: 600.0,          // Clean every 10 minutes
    pressureThreshold: 0.8,          // Trigger at 80% usage
    enableMetrics: true,             // Track performance
    enableLeakDetection: true,       // Detect memory leaks
    logger: CustomLogger()           // Custom logging
)
```

### Cache Manager Eviction Policies

- **LRU**: Best for general-purpose caching
- **LFU**: Good when access patterns are stable
- **FIFO**: Simple, predictable eviction
- **TTL**: When data has natural expiration
- **Adaptive**: Balances multiple factors
- **Random**: Low overhead, unpredictable

### Multi-Level Cache Tuning

```swift
// For read-heavy workloads
let readOptimized = MultiLevelCacheManager.Configuration(
    l1MaxSize: 2000,      // Large L1 for fast reads
    l1MaxMemory: 50_000_000,
    l2MaxSize: 10000,     // Large L2 backup
    l2MaxMemory: 100_000_000,
    l3MaxSize: 100000     // Massive L3 for historical data
)

// For write-heavy workloads
let writeOptimized = MultiLevelCacheManager.Configuration(
    l1MaxSize: 500,       // Small L1 to reduce write pressure
    l1MaxMemory: 10_000_000,
    l2MaxSize: 2000,      // Medium L2
    l2MaxMemory: 30_000_000,
    l3MaxSize: 50000,     // Large L3 for persistence
    enableCompression: true // Compress to reduce I/O
)
```

## Performance Considerations

### Memory Pressure

MemoryKit automatically manages memory pressure through:
- Periodic cleanup cycles
- Pressure-triggered eviction
- Adaptive scoring for cache entries
- Automatic tier demotion

### Eviction Strategies

| Policy | CPU Cost | Memory Efficiency | Best Use Case |
|--------|----------|-------------------|---------------|
| LRU | Low | High | General caching |
| LFU | Medium | High | Stable patterns |
| FIFO | Very Low | Medium | Queue-like data |
| TTL | Low | Medium | Time-sensitive data |
| Adaptive | High | Very High | Mixed workloads |

### Compression Trade-offs

- **L2 Compression**: Reduces memory by 50-80% for JSON data
- **L3 Compression**: Reduces disk I/O but increases CPU usage
- **Compression overhead**: ~0.5ms for 10KB JSON data

## Best Practices

### 1. Choose the Right Cache Level

```swift
// Critical, frequently accessed data -> L1
await cache.store(authToken, forKey: "auth", priority: .critical)

// Important but less frequent -> L2
await cache.store(userProfile, forKey: "user", priority: .high)

// Historical or archival -> L3
await cache.store(auditLog, forKey: "audit", priority: .low)
```

### 2. Set Appropriate TTLs

```swift
// Short TTL for volatile data
await cache.set(marketPrice, forKey: "price", ttl: 60) // 1 minute

// Medium TTL for semi-static data
await cache.set(userSession, forKey: "session", ttl: 3600) // 1 hour

// Long TTL for stable data
await cache.set(configuration, forKey: "config", ttl: 86400) // 1 day
```

### 3. Monitor Performance

```swift
// Regular health checks
let health = await memoryKit.getHealthReport()
if health.overallHealth == .poor {
    await memoryKit.forceCleanup()
}

// Track cache efficiency
let stats = await cache.getMetrics()
if stats.hitRate < 0.7 {
    // Consider adjusting cache size or TTL
}
```

### 4. Handle Memory Warnings

```swift
// Check memory pressure
if await memoryManager.isUnderMemoryPressure() {
    // Reduce cache usage or force cleanup
    await memoryManager.forceCleanup()
}
```

### 5. Use Resource Pools for Expensive Objects

```swift
// Pool expensive resources instead of creating new ones
let pool = ResourcePool<ExpensiveResource>(
    configuration: ResourcePool.Configuration(
        maxPoolSize: 20,
        minPoolSize: 5
    ),
    factory: { try await ExpensiveResource.create() }
)
```

## Migration Guide

### From Array-Based Caching

**Before (Legacy):**
```swift
class TUI {
    var cachedServers: [Server] = []

    func refreshServers() {
        cachedServers = fetchServers()
    }
}
```

**After (MemoryKit):**
```swift
class TUI {
    let cache = MemoryManager.shared

    func refreshServers() async {
        let servers = await fetchServers()
        await cache.store(servers, forKey: "servers")
    }

    func getServers() async -> [Server] {
        return await cache.retrieve(forKey: "servers", as: [Server].self) ?? []
    }
}
```

### From Dictionary Caching

**Before:**
```swift
var cache: [String: Any] = [:]
cache["user_123"] = user
```

**After:**
```swift
let cache = CacheManager<String, User>()
await cache.set(user, forKey: "user_123")
```

### Adding MemoryKit to Existing Project

1. Add MemoryKit as dependency
2. Initialize in app startup:
   ```swift
   let memoryKit = await MemoryKit()
   ```
3. Replace existing caches gradually
4. Monitor performance improvements
5. Tune configuration based on metrics

## Troubleshooting

### High Memory Usage

```swift
// Check current usage
let stats = await memoryManager.getCacheStats()
print("Memory pressure: \(stats.memoryPressure * 100)%")

// Force cleanup if needed
if stats.memoryPressure > 0.9 {
    await memoryManager.forceCleanup()
}
```

### Low Cache Hit Rate

```swift
// Analyze cache metrics
let metrics = await cache.getMetrics()
print("Hit rate: \(metrics.hitRate)")
print("Eviction rate: \(metrics.evictionRate)")

// Adjust configuration
// Increase cache size or TTL if eviction rate is high
```

### Debugging Cache Misses

```swift
// Enable detailed logging
let logger = DefaultMemoryKitLogger(
    prefix: "[Debug]",
    logToFile: true
)
let cache = CacheManager(
    configuration: CacheManager.Configuration(),
    logger: logger
)
```

## Thread Safety

All MemoryKit components are thread-safe through Swift actors:

```swift
// Safe to call from any thread/task
Task {
    await cache.set(data1, forKey: "key1")
}
Task {
    await cache.set(data2, forKey: "key2")
}
// No race conditions or data corruption
```

## Error Handling

MemoryKit operations are designed to be resilient:

```swift
// Safe retrieval with fallback
let data = await cache.retrieve(forKey: "key", as: MyType.self) ?? defaultValue

// Resource pool with error handling
do {
    let resource = try await pool.acquire()
    // Use resource
    await pool.release(resource)
} catch {
    print("Failed to acquire resource: \(error)")
}
```

## Performance Benchmarks

Typical performance metrics on modern hardware:

| Operation | Time | Throughput |
|-----------|------|------------|
| L1 Cache Hit | <1us | >1M ops/sec |
| L2 Cache Hit | ~100us | ~10K ops/sec |
| L3 Cache Hit | ~1ms | ~1K ops/sec |
| Cache Miss | ~10us | ~100K ops/sec |
| Compression (10KB) | ~500us | ~2K ops/sec |
| Eviction (1K items) | ~10ms | ~100 ops/sec |

## Support and Contributing

MemoryKit is maintained as part of the Substation project. For issues or contributions:

1. Check existing implementation in `/Sources/MemoryKit/`
2. Follow Swift 6.1 syntax requirements
3. Ensure all code is ASCII-only (no Unicode)
4. Add SwiftDoc comments for public APIs
5. Test with both macOS and Linux targets

## Version History

- **1.0.0** - Initial implementation with core caching
- **1.1.0** - Added multi-level cache support
- **1.2.0** - Performance monitoring integration
- **1.3.0** - Resource pool and typed cache managers
- **Current** - Optimized for Substation TUI performance