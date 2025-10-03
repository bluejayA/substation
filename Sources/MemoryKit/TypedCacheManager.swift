import Foundation

// MARK: - Typed Cache Manager

/// A type-safe cache manager that provides specialized caching for specific types
public actor TypedCacheManager<Key: Hashable & Sendable, Value: Sendable> {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let maxSize: Int
        public let ttl: TimeInterval
        public let evictionPolicy: EvictionPolicy
        public let enableStatistics: Bool

        public init(
            maxSize: Int = 1000,
            ttl: TimeInterval = 300.0,
            evictionPolicy: EvictionPolicy = .leastRecentlyUsed,
            enableStatistics: Bool = true
        ) {
            self.maxSize = maxSize
            self.ttl = ttl
            self.evictionPolicy = evictionPolicy
            self.enableStatistics = enableStatistics
        }
    }

    public enum EvictionPolicy: Sendable {
        case leastRecentlyUsed
        case leastFrequentlyUsed
        case timeToLive
        case fifo
    }

    // MARK: - Cache Entry

    private struct CacheEntry: Sendable {
        let value: Value
        let timestamp: Date
        let lastAccessed: Date
        let accessCount: Int

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }

        let ttl: TimeInterval

        func withAccess() -> CacheEntry {
            CacheEntry(
                value: value,
                timestamp: timestamp,
                lastAccessed: Date(),
                accessCount: accessCount + 1,
                ttl: ttl
            )
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let logger: any MemoryKitLogger
    private var cache: [Key: CacheEntry] = [:]
    private var statistics: CacheStatistics

    // MARK: - Initialization

    public init(configuration: Configuration, logger: any MemoryKitLogger = SilentMemoryKitLogger()) {
        self.configuration = configuration
        self.logger = logger
        self.statistics = CacheStatistics()

        logger.logInfo("TypedCacheManager initialized", context: [
            "maxSize": configuration.maxSize,
            "ttl": configuration.ttl,
            "evictionPolicy": String(describing: configuration.evictionPolicy)
        ])
    }

    // MARK: - Cache Operations

    /// Store a value in the cache
    public func store(_ value: Value, forKey key: Key) async {
        let entry = CacheEntry(
            value: value,
            timestamp: Date(),
            lastAccessed: Date(),
            accessCount: 0,
            ttl: configuration.ttl
        )

        cache[key] = entry

        if configuration.enableStatistics {
            statistics.recordWrite()
        }

        logger.logDebug("Stored value in typed cache", context: [
            "key": String(describing: key),
            "cacheSize": cache.count
        ])

        // Cleanup if needed
        await performCleanupIfNeeded()
    }

    /// Retrieve a value from the cache
    public func retrieve(forKey key: Key) async -> Value? {
        guard let entry = cache[key] else {
            if configuration.enableStatistics {
                statistics.recordMiss()
            }
            logger.logDebug("Cache miss", context: ["key": String(describing: key)])
            return nil
        }

        if entry.isExpired {
            cache.removeValue(forKey: key)
            if configuration.enableStatistics {
                statistics.recordExpiry()
            }
            logger.logDebug("Cache entry expired", context: ["key": String(describing: key)])
            return nil
        }

        // Update access information
        cache[key] = entry.withAccess()

        if configuration.enableStatistics {
            statistics.recordHit()
        }

        logger.logDebug("Cache hit", context: [
            "key": String(describing: key),
            "accessCount": entry.accessCount + 1
        ])

        return entry.value
    }

    /// Remove a specific key from cache
    public func remove(forKey key: Key) async {
        if cache.removeValue(forKey: key) != nil {
            if configuration.enableStatistics {
                statistics.recordEviction()
            }
            logger.logDebug("Removed cache entry", context: ["key": String(describing: key)])
        }
    }

    /// Clear all cached values
    public func clear() async {
        let count = cache.count
        cache.removeAll()

        if configuration.enableStatistics {
            statistics.recordMassEviction(count: count)
        }

        logger.logInfo("Cleared typed cache", context: ["entriesRemoved": count])
    }

    /// Get cache statistics
    public func getStatistics() async -> CacheStatistics {
        var stats = statistics
        stats.currentSize = cache.count
        stats.maxSize = configuration.maxSize
        return stats
    }

    // MARK: - Private Methods

    private func performCleanupIfNeeded() async {
        guard cache.count > configuration.maxSize else { return }

        let entriesToRemove = cache.count - configuration.maxSize
        let sortedEntries = getSortedEntriesForEviction()

        var removed = 0
        for (key, _) in sortedEntries.prefix(entriesToRemove) {
            cache.removeValue(forKey: key)
            removed += 1
        }

        if configuration.enableStatistics {
            statistics.recordCleanup(entriesRemoved: removed)
        }

        logger.logInfo("Performed cache cleanup", context: [
            "entriesRemoved": removed,
            "remainingEntries": cache.count,
            "evictionPolicy": String(describing: configuration.evictionPolicy)
        ])
    }

    private func getSortedEntriesForEviction() -> [(Key, CacheEntry)] {
        switch configuration.evictionPolicy {
        case .leastRecentlyUsed:
            return cache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        case .leastFrequentlyUsed:
            return cache.sorted { $0.value.accessCount < $1.value.accessCount }
        case .timeToLive:
            return cache.sorted { $0.value.timestamp < $1.value.timestamp }
        case .fifo:
            return cache.sorted { $0.value.timestamp < $1.value.timestamp }
        }
    }
}

// MARK: - Cache Statistics

public struct CacheStatistics: Sendable {
    public var hits: Int = 0
    public var misses: Int = 0
    public var writes: Int = 0
    public var evictions: Int = 0
    public var expiries: Int = 0
    public var cleanups: Int = 0
    public var currentSize: Int = 0
    public var maxSize: Int = 0

    public var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0.0
    }

    public var hitCount: Int { hits }
    public var accessCount: Int { hits + misses }

    mutating func recordHit() {
        hits += 1
    }

    mutating func recordMiss() {
        misses += 1
    }

    mutating func recordWrite() {
        writes += 1
    }

    mutating func recordEviction() {
        evictions += 1
    }

    mutating func recordExpiry() {
        expiries += 1
    }

    mutating func recordMassEviction(count: Int) {
        evictions += count
    }

    mutating func recordCleanup(entriesRemoved: Int) {
        cleanups += 1
        evictions += entriesRemoved
    }
}

// MARK: - Enhanced MemoryManager Extensions

extension MemoryManager {
    /// Create a typed cache manager that uses this MemoryManager as the backing store
    public func createTypedCacheManager<Key: Hashable & Sendable, Value: Sendable>(
        keyType: Key.Type,
        valueType: Value.Type,
        configuration: TypedCacheManager<Key, Value>.Configuration,
        logger: any MemoryKitLogger = SilentMemoryKitLogger()
    ) -> TypedCacheManager<Key, Value> {
        return TypedCacheManager<Key, Value>(configuration: configuration, logger: logger)
    }
}