import Foundation

// MARK: - Advanced Cache Management Utilities

/// Advanced cache manager with intelligent eviction policies, memory pressure handling,
/// and performance optimization for high-throughput applications.
public actor CacheManager<Key: Hashable & Sendable, Value: Sendable> {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let maxSize: Int
        public let maxMemoryUsage: Int // bytes
        public let defaultTTL: TimeInterval
        public let enableTTL: Bool
        public let evictionPolicy: EvictionPolicy
        public let compressionEnabled: Bool
        public let enableMetrics: Bool

        public init(
            maxSize: Int = 1000,
            maxMemoryUsage: Int = 50 * 1024 * 1024, // 50MB
            defaultTTL: TimeInterval = 300,
            enableTTL: Bool = true,
            evictionPolicy: EvictionPolicy = .lru,
            compressionEnabled: Bool = true,
            enableMetrics: Bool = true
        ) {
            self.maxSize = maxSize
            self.maxMemoryUsage = maxMemoryUsage
            self.defaultTTL = defaultTTL
            self.enableTTL = enableTTL
            self.evictionPolicy = evictionPolicy
            self.compressionEnabled = compressionEnabled
            self.enableMetrics = enableMetrics
        }
    }

    // MARK: - Eviction Policy

    public enum EvictionPolicy: Sendable {
        case lru    // Least Recently Used
        case lfu    // Least Frequently Used
        case fifo   // First In, First Out
        case random // Random eviction
        case ttl    // Time To Live based
        case adaptive // Adaptive based on access patterns
    }

    // MARK: - Cache Entry

    private struct CacheEntry {
        let value: Value
        let timestamp: Date
        let ttl: TimeInterval?
        let size: Int
        var accessCount: Int
        var lastAccessed: Date

        var isExpired: Bool {
            guard let ttl = ttl else { return false }
            return Date().timeIntervalSince(timestamp) > ttl
        }

        var age: TimeInterval {
            return Date().timeIntervalSince(timestamp)
        }

        var accessFrequency: Double {
            let timeSpan = Date().timeIntervalSince(timestamp)
            return timeSpan > 0 ? Double(accessCount) / timeSpan : 0
        }

        mutating func recordAccess() {
            accessCount += 1
            lastAccessed = Date()
        }
    }

    // MARK: - Private Properties

    private let configuration: Configuration
    private let logger: any MemoryKitLogger
    private var cache: [Key: CacheEntry] = [:]
    private var accessOrder: [Key] = [] // For LRU
    private var metrics: CacheMetrics
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        configuration: Configuration = Configuration(),
        logger: any MemoryKitLogger = MemoryKitLoggerFactory.defaultLogger()
    ) {
        self.configuration = configuration
        self.logger = logger
        self.metrics = CacheMetrics()

        logger.logInfo("CacheManager initialized", context: [
            "maxSize": configuration.maxSize,
            "maxMemoryUsage": configuration.maxMemoryUsage,
            "evictionPolicy": String(describing: configuration.evictionPolicy),
            "enableTTL": configuration.enableTTL,
            "defaultTTL": configuration.defaultTTL
        ])
    }

    /// Start the cache manager (call after initialization)
    public func start() {
        logger.logInfo("CacheManager starting cleanup task", context: [:])
        startCleanupTask()
    }

    deinit {
        cleanupTask?.cancel()
    }

    // MARK: - Public API

    /// Store value in cache with optional TTL
    public func set(_ value: Value, forKey key: Key, ttl: TimeInterval? = nil) async {
        let effectiveTTL = ttl ?? (configuration.enableTTL ? configuration.defaultTTL : nil)
        let size = estimateSize(of: value)
        let isUpdate = cache[key] != nil

        let entry = CacheEntry(
            value: value,
            timestamp: Date(),
            ttl: effectiveTTL,
            size: size,
            accessCount: 0,
            lastAccessed: Date()
        )

        // Remove existing entry if present
        if cache[key] != nil {
            await removeFromAccessOrder(key)
        }

        cache[key] = entry
        accessOrder.append(key)

        metrics.recordWrite(size: size)

        logger.logDebug("CacheManager stored entry", context: [
            "key": String(describing: key),
            "size": size,
            "ttl": effectiveTTL ?? -1,
            "isUpdate": isUpdate,
            "totalEntries": cache.count
        ])

        // Check if eviction is needed
        await evictIfNeeded()
    }

    /// Retrieve value from cache
    public func get(_ key: Key) async -> Value? {
        guard var entry = cache[key] else {
            metrics.recordMiss()
            logger.logDebug("CacheManager cache miss", context: [
                "key": String(describing: key)
            ])
            return nil
        }

        // Check expiration
        if entry.isExpired {
            await remove(key)
            metrics.recordExpiration()
            logger.logDebug("CacheManager entry expired", context: [
                "key": String(describing: key),
                "age": entry.age
            ])
            return nil
        }

        // Update access information
        entry.recordAccess()
        cache[key] = entry

        // Update access order for LRU
        await updateAccessOrder(key)

        metrics.recordHit(size: entry.size)
        logger.logDebug("CacheManager cache hit", context: [
            "key": String(describing: key),
            "accessCount": entry.accessCount,
            "size": entry.size
        ])
        return entry.value
    }

    /// Remove specific key
    public func remove(_ key: Key) async {
        if let entry = cache.removeValue(forKey: key) {
            await removeFromAccessOrder(key)
            metrics.recordEviction(size: entry.size)
            logger.logDebug("CacheManager removed entry", context: [
                "key": String(describing: key),
                "size": entry.size,
                "remainingEntries": cache.count
            ])
        }
    }

    /// Clear all entries
    public func removeAll() async {
        let entriesCleared = cache.count
        let totalSize = cache.values.reduce(0) { $0 + $1.size }
        cache.removeAll()
        accessOrder.removeAll()
        metrics.recordMassEviction(size: totalSize)

        logger.logInfo("CacheManager cleared all entries", context: [
            "entriesCleared": entriesCleared,
            "memoryReclaimed": totalSize
        ])
    }

    /// Get current size
    public func count() async -> Int {
        return cache.count
    }

    /// Get memory usage
    public func memoryUsage() async -> Int {
        return cache.values.reduce(0) { $0 + $1.size }
    }

    /// Get cache metrics
    public func getMetrics() async -> CacheMetrics {
        return metrics.snapshot()
    }


    /// Force eviction to target size
    public func evictToSize(_ targetSize: Int) async {
        await performEviction(targetCount: targetSize)
    }

    /// Get all keys (for debugging)
    public func getAllKeys() async -> [Key] {
        return Array(cache.keys)
    }

    /// Check if key exists and is not expired
    public func contains(_ key: Key) async -> Bool {
        guard let entry = cache[key] else { return false }

        if entry.isExpired {
            await remove(key)
            return false
        }

        return true
    }

    // MARK: - Private Methods

    private func startCleanupTask() {
        logger.logInfo("CacheManager starting periodic cleanup task", context: [
            "cleanupInterval": "5 minutes"
        ])

        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await self?.cleanupExpiredEntries()
            }
        }
    }

    private func cleanupExpiredEntries() async {
        logger.logDebug("CacheManager starting cleanup of expired entries", context: [:])
        let expiredKeys = cache.compactMap { (key, entry) in
            entry.isExpired ? key : nil
        }

        for key in expiredKeys {
            await remove(key)
        }

        if !expiredKeys.isEmpty {
            logger.logInfo("CacheManager cleaned up expired entries", context: [
                "expiredCount": expiredKeys.count,
                "remainingEntries": cache.count
            ])
        }
    }

    private func evictIfNeeded() async {
        let currentSize = cache.count
        let currentMemory = await memoryUsage()

        // Check size limits
        if currentSize > configuration.maxSize {
            logger.logInfo("CacheManager triggering size-based eviction", context: [
                "currentSize": currentSize,
                "maxSize": configuration.maxSize,
                "evictionPolicy": String(describing: configuration.evictionPolicy)
            ])
            let targetSize = Int(Double(configuration.maxSize) * 0.8) // Evict to 80% of max
            await performEviction(targetCount: targetSize)
        }

        // Check memory limits
        if currentMemory > configuration.maxMemoryUsage {
            logger.logInfo("CacheManager triggering memory-based eviction", context: [
                "currentMemory": currentMemory,
                "maxMemory": configuration.maxMemoryUsage
            ])
            let targetMemory = Int(Double(configuration.maxMemoryUsage) * 0.8)
            await performMemoryEviction(targetMemory: targetMemory)
        }
    }

    private func performEviction(targetCount: Int) async {
        let keysToEvict = selectKeysForEviction(targetCount: targetCount)

        logger.logInfo("CacheManager performing eviction", context: [
            "keysToEvict": keysToEvict.count,
            "targetCount": targetCount,
            "policy": String(describing: configuration.evictionPolicy)
        ])

        for key in keysToEvict {
            await remove(key)
        }

        logger.logInfo("CacheManager completed eviction", context: [
            "keysEvicted": keysToEvict.count,
            "finalCount": cache.count
        ])
    }

    private func performMemoryEviction(targetMemory: Int) async {
        var currentMemory = await memoryUsage()

        while currentMemory > targetMemory && !cache.isEmpty {
            let keysToEvict = selectKeysForEviction(targetCount: cache.count - 1)

            if let keyToEvict = keysToEvict.first {
                await remove(keyToEvict)
                currentMemory = await memoryUsage()
            } else {
                break
            }
        }
    }

    private func selectKeysForEviction(targetCount: Int) -> [Key] {
        let evictionCount = cache.count - targetCount
        guard evictionCount > 0 else { return [] }

        switch configuration.evictionPolicy {
        case .lru:
            return Array(accessOrder.prefix(evictionCount))

        case .lfu:
            let sortedByFrequency = cache.sorted { $0.value.accessFrequency < $1.value.accessFrequency }
            return Array(sortedByFrequency.prefix(evictionCount).map { $0.key })

        case .fifo:
            let sortedByAge = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            return Array(sortedByAge.prefix(evictionCount).map { $0.key })

        case .random:
            return Array(cache.keys.shuffled().prefix(evictionCount))

        case .ttl:
            let sortedByTTL = cache.compactMap { (key, entry) -> (Key, TimeInterval)? in
                guard let ttl = entry.ttl else { return nil }
                let remainingTTL = ttl - entry.age
                return (key, remainingTTL)
            }.sorted { $0.1 < $1.1 }
            return Array(sortedByTTL.prefix(evictionCount).map { $0.0 })

        case .adaptive:
            return selectAdaptiveEvictionKeys(evictionCount: evictionCount)
        }
    }

    private func selectAdaptiveEvictionKeys(evictionCount: Int) -> [Key] {
        // Adaptive policy combines LRU and LFU with size consideration
        let entries = cache.map { (key, entry) in
            let ageScore = min(1.0, entry.age / 3600.0) // Normalize by 1 hour
            let frequencyScore = 1.0 - min(1.0, entry.accessFrequency / 10.0) // Invert frequency
            let sizeScore = min(1.0, Double(entry.size) / 1024.0) // Normalize by 1KB

            let adaptiveScore = (ageScore * 0.4) + (frequencyScore * 0.4) + (sizeScore * 0.2)
            return (key, adaptiveScore)
        }.sorted { $0.1 > $1.1 } // Higher score = more likely to evict

        return Array(entries.prefix(evictionCount).map { $0.0 })
    }

    private func updateAccessOrder(_ key: Key) async {
        await removeFromAccessOrder(key)
        accessOrder.append(key)
    }

    private func removeFromAccessOrder(_ key: Key) async {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }

    private func estimateSize(of value: Value) -> Int {
        // Basic size estimation - could be improved with specific type handling
        switch value {
        case let data as Data:
            return data.count
        case let string as String:
            return string.utf8.count
        case let array as [Any]:
            return array.count * 100 // Rough estimate
        case let dict as [String: Any]:
            return dict.count * 150 // Rough estimate
        default:
            return 64 // Default estimate
        }
    }
}


// MARK: - Cache Metrics

public struct CacheMetrics: Sendable {
    public private(set) var hits: Int = 0
    public private(set) var misses: Int = 0
    public private(set) var writes: Int = 0
    public private(set) var evictions: Int = 0
    public private(set) var expirations: Int = 0
    public private(set) var bytesStored: Int = 0
    public private(set) var bytesEvicted: Int = 0

    public var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0.0
    }

    public var evictionRate: Double {
        return writes > 0 ? Double(evictions) / Double(writes) : 0.0
    }

    mutating func recordHit(size: Int) {
        hits += 1
    }

    mutating func recordMiss() {
        misses += 1
    }

    mutating func recordWrite(size: Int) {
        writes += 1
        bytesStored += size
    }

    mutating func recordEviction(size: Int) {
        evictions += 1
        bytesEvicted += size
        bytesStored = max(0, bytesStored - size)
    }

    mutating func recordExpiration() {
        expirations += 1
    }

    mutating func recordMassEviction(size: Int) {
        evictions += 1
        bytesEvicted += size
        bytesStored = 0
    }

    func snapshot() -> CacheMetrics {
        return self
    }
}


// MARK: - Resource Pool

/// Thread-safe resource pool for expensive-to-create objects with automatic cleanup
public actor ResourcePool<Resource: Sendable> {

    public struct Configuration: Sendable {
        public let maxPoolSize: Int
        public let minPoolSize: Int
        public let idleTimeout: TimeInterval
        public let enableMetrics: Bool

        public init(
            maxPoolSize: Int = 10,
            minPoolSize: Int = 2,
            idleTimeout: TimeInterval = 300,
            enableMetrics: Bool = true
        ) {
            self.maxPoolSize = maxPoolSize
            self.minPoolSize = minPoolSize
            self.idleTimeout = idleTimeout
            self.enableMetrics = enableMetrics
        }
    }

    // MARK: - Pool Entry

    private struct PoolEntry {
        let resource: Resource
        let createdAt: Date
        var lastUsed: Date
        var useCount: Int

        var isIdle: Bool {
            Date().timeIntervalSince(lastUsed) > 300 // 5 minutes
        }

        mutating func recordUse() {
            useCount += 1
            lastUsed = Date()
        }
    }

    // MARK: - Private Properties

    private let configuration: Configuration
    private let factory: @Sendable () async throws -> Resource
    private let cleanup: @Sendable (Resource) async -> Void
    private let validator: @Sendable (Resource) async -> Bool

    private var available: [PoolEntry] = []
    private var inUse: [ObjectIdentifier: PoolEntry] = [:]
    private var metrics: PoolMetrics
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        configuration: Configuration = Configuration(),
        factory: @escaping @Sendable () async throws -> Resource,
        cleanup: @escaping @Sendable (Resource) async -> Void = { _ in },
        validator: @escaping @Sendable (Resource) async -> Bool = { _ in true }
    ) {
        self.configuration = configuration
        self.factory = factory
        self.cleanup = cleanup
        self.validator = validator
        self.metrics = PoolMetrics()
    }

    /// Start the resource pool (call after initialization)
    public func start() {
        startCleanupTask()
    }

    deinit {
        cleanupTask?.cancel()
    }

    // MARK: - Public API

    /// Acquire a resource from the pool
    public func acquire() async throws -> Resource {
        // Try to get from available pool
        if let entry = available.popLast() {
            // Validate resource
            if await validator(entry.resource) {
                var updatedEntry = entry
                updatedEntry.recordUse()
                inUse[ObjectIdentifier(entry.resource as AnyObject)] = updatedEntry

                metrics.recordAcquisition(fromPool: true)
                return entry.resource
            } else {
                // Resource is invalid, clean it up
                await cleanup(entry.resource)
                metrics.recordValidationFailure()
            }
        }

        // Create new resource
        let resource = try await factory()
        let entry = PoolEntry(
            resource: resource,
            createdAt: Date(),
            lastUsed: Date(),
            useCount: 1
        )

        inUse[ObjectIdentifier(resource as AnyObject)] = entry
        metrics.recordAcquisition(fromPool: false)

        return resource
    }

    /// Return a resource to the pool
    public func release(_ resource: Resource) async {
        let identifier = ObjectIdentifier(resource as AnyObject)

        guard let entry = inUse.removeValue(forKey: identifier) else {
            return // Resource not from this pool
        }

        // Check if pool is full
        if available.count < configuration.maxPoolSize {
            available.append(entry)
            metrics.recordRelease(toPool: true)
        } else {
            // Pool is full, cleanup resource
            await cleanup(resource)
            metrics.recordRelease(toPool: false)
        }
    }

    /// Get pool statistics
    public func getStats() async -> PoolStats {
        return PoolStats(
            availableCount: available.count,
            inUseCount: inUse.count,
            maxPoolSize: configuration.maxPoolSize,
            metrics: metrics.snapshot()
        )
    }

    /// Force cleanup of idle resources
    public func cleanupIdleResources() async {
        let idleThreshold = Date().addingTimeInterval(-configuration.idleTimeout)

        let idleResources = available.filter { $0.lastUsed < idleThreshold }
        available.removeAll { $0.lastUsed < idleThreshold }

        for entry in idleResources {
            await cleanup(entry.resource)
            metrics.recordIdleCleanup()
        }
    }

    // MARK: - Private Methods

    private func startCleanupTask() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 1 minute
                await self?.cleanupIdleResources()
                await self?.ensureMinimumPool()
            }
        }
    }

    private func ensureMinimumPool() async {
        while available.count < configuration.minPoolSize {
            do {
                let resource = try await factory()
                let entry = PoolEntry(
                    resource: resource,
                    createdAt: Date(),
                    lastUsed: Date(),
                    useCount: 0
                )
                available.append(entry)
                metrics.recordPreCreation()
            } catch {
                break // Stop trying if factory fails
            }
        }
    }
}

// MARK: - Pool Metrics and Stats

public struct PoolMetrics: Sendable {
    public private(set) var acquisitionsFromPool: Int = 0
    public private(set) var acquisitionsCreated: Int = 0
    public private(set) var releasesToPool: Int = 0
    public private(set) var releasesDiscarded: Int = 0
    public private(set) var validationFailures: Int = 0
    public private(set) var idleCleanups: Int = 0
    public private(set) var preCreations: Int = 0

    public var poolHitRate: Double {
        let total = acquisitionsFromPool + acquisitionsCreated
        return total > 0 ? Double(acquisitionsFromPool) / Double(total) : 0.0
    }

    mutating func recordAcquisition(fromPool: Bool) {
        if fromPool {
            acquisitionsFromPool += 1
        } else {
            acquisitionsCreated += 1
        }
    }

    mutating func recordRelease(toPool: Bool) {
        if toPool {
            releasesToPool += 1
        } else {
            releasesDiscarded += 1
        }
    }

    mutating func recordValidationFailure() {
        validationFailures += 1
    }

    mutating func recordIdleCleanup() {
        idleCleanups += 1
    }

    mutating func recordPreCreation() {
        preCreations += 1
    }

    func snapshot() -> PoolMetrics {
        return self
    }
}

public struct PoolStats: Sendable {
    public let availableCount: Int
    public let inUseCount: Int
    public let maxPoolSize: Int
    public let metrics: PoolMetrics

    public var utilization: Double {
        let total = availableCount + inUseCount
        return total > 0 ? Double(inUseCount) / Double(total) : 0.0
    }

    public var description: String {
        let utilizationPercentage = String(format: "%.1f", utilization * 100)
        let hitRatePercentage = String(format: "%.1f", metrics.poolHitRate * 100)

        return "Pool: \(availableCount) available, \(inUseCount) in use, \(maxPoolSize) max, \(utilizationPercentage)% utilization, \(hitRatePercentage)% hit rate"
    }
}