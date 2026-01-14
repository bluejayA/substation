import Foundation

// MARK: - Unified Memory Management Actor

/// Unified memory manager that provides thread-safe, high-performance memory management
/// with advanced monitoring, cache management, and automatic cleanup capabilities.
/// Uses Swift actors for thread safety and modern async/await patterns.
public actor MemoryManager {

    // MARK: - Singleton Instance

    /// Global shared instance for application-wide memory management
    /// This singleton is automatically started and reduces overhead from multiple instances
    nonisolated public static let shared: MemoryManager = {
        let instance = MemoryManager(configuration: Configuration(
            maxCacheSize: 5000,
            maxMemoryBudget: 150 * 1024 * 1024, // 150MB for global cache
            cleanupInterval: 60.0, // 1 minutes
            pressureThreshold: 0.8,
            enableMetrics: true,
            enableLeakDetection: true
        ))
        return instance
    }()

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let maxCacheSize: Int
        public let maxMemoryBudget: Int // bytes
        public let cleanupInterval: TimeInterval
        public let pressureThreshold: Double // 0.0 to 1.0
        public let enableMetrics: Bool
        public let enableLeakDetection: Bool
        public let logger: any MemoryKitLogger

        public init(
            maxCacheSize: Int = 1000,
            maxMemoryBudget: Int = 100 * 1024 * 1024, // 100MB
            cleanupInterval: TimeInterval = 600.0, // 10 minutes - reduced from 5min to lower CPU usage
            pressureThreshold: Double = 0.8,
            enableMetrics: Bool = true,
            enableLeakDetection: Bool = true, // Disabled by default to reduce CPU overhead
            logger: any MemoryKitLogger = MemoryKitLoggerFactory.defaultLogger()
        ) {
            self.maxCacheSize = maxCacheSize
            self.maxMemoryBudget = maxMemoryBudget
            self.cleanupInterval = cleanupInterval
            self.pressureThreshold = pressureThreshold
            self.enableMetrics = enableMetrics
            self.enableLeakDetection = enableLeakDetection
            self.logger = logger
        }
    }

    // MARK: - Private Properties

    private let configuration: Configuration
    private let logger: any MemoryKitLogger
    private var cache: [String: CacheEntry] = [:]
    private var metrics: MemoryMetrics
    private var cleanupTask: Task<Void, Never>?
    private var pressureMonitorTask: Task<Void, Never>?

    // MARK: - Cache Entry

    private struct CacheEntry: Sendable {
        let data: any Sendable
        let timestamp: Date
        let size: Int
        let accessCount: Int
        let lastAccessed: Date

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }

        var priority: Double {
            // Higher priority = more valuable to keep
            let age = Date().timeIntervalSince(lastAccessed)
            let ageScore = max(0.0, 1.0 - (age / 3600.0)) // Decay over 1 hour
            let accessScore = min(1.0, Double(accessCount) / 10.0)
            return (ageScore * 0.7) + (accessScore * 0.3)
        }

        func withAccess() -> CacheEntry {
            CacheEntry(
                data: data,
                timestamp: timestamp,
                size: size,
                accessCount: accessCount + 1,
                lastAccessed: Date()
            )
        }
    }

    // MARK: - Initialization

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.logger = configuration.logger
        self.metrics = MemoryMetrics()
    }

    /// Start the memory manager (call after initialization)
    public func start() {
        logger.logInfo("Starting MemoryManager background tasks", context: [:])
        startBackgroundTasks()
        logger.logInfo("MemoryManager started successfully", context: [:])
    }

    deinit {
        cleanupTask?.cancel()
        pressureMonitorTask?.cancel()
    }

    // MARK: - Public API

    /// Store data in cache with automatic eviction and size management
    public func store<T: Sendable>(_ data: T, forKey key: String) async {
        let size = estimateSize(of: data)
        logger.logDebug("Storing item in cache", context: [
            "key": key,
            "size": size,
            "type": String(describing: type(of: data))
        ])

        let entry = CacheEntry(
            data: data,
            timestamp: Date(),
            size: size,
            accessCount: 0,
            lastAccessed: Date()
        )

        cache[key] = entry
        metrics.recordCacheWrite(size: size)

        logger.logDebug("Item stored successfully", context: [
            "key": key,
            "cacheSize": cache.count
        ])

        // Check if cleanup is needed
        await checkMemoryPressureAndCleanup()
    }

    /// Retrieve data from cache with access tracking
    public func retrieve<T: Sendable>(forKey key: String, as type: T.Type) async -> T? {
        logger.logDebug("Retrieving item from cache", context: [
            "key": key,
            "type": String(describing: type)
        ])

        guard let entry = cache[key] else {
            logger.logDebug("Cache miss", context: ["key": key])
            metrics.recordCacheMiss()
            return nil
        }

        if entry.isExpired {
            logger.logDebug("Cache entry expired", context: ["key": key])
            cache.removeValue(forKey: key)
            metrics.recordCacheExpiry()
            return nil
        }

        // Update access information
        cache[key] = entry.withAccess()
        metrics.recordCacheHit(size: entry.size)

        logger.logDebug("Cache hit", context: [
            "key": key,
            "size": entry.size,
            "accessCount": entry.accessCount + 1
        ])

        return entry.data as? T
    }

    /// Clear specific key from cache
    public func clearKey(_ key: String) async {
        logger.logDebug("Clearing cache key", context: ["key": key])

        if let entry = cache.removeValue(forKey: key) {
            metrics.recordCacheEviction(size: entry.size)

            logger.logDebug("Cache key cleared", context: [
                "key": key,
                "size": entry.size,
                "remainingEntries": cache.count
            ])
        } else {
            logger.logDebug("Cache key not found for clearing", context: ["key": key])
        }
    }

    /// Clear all cached data
    public func clearAll() async {
        let entryCount = cache.count
        let totalSize = cache.values.reduce(0) { $0 + $1.size }

        logger.logInfo("Clearing all cache entries", context: [
            "entryCount": entryCount,
            "totalSize": totalSize
        ])

        cache.removeAll()
        metrics.recordMassEviction(size: totalSize)
    }

    /// Get current memory statistics
    public func getMetrics() async -> MemoryMetrics {
        return metrics.snapshot()
    }

    /// Get cache statistics
    public func getCacheStats() async -> CacheStats {
        let totalSize = cache.values.reduce(0) { $0 + $1.size }
        let averageAge = cache.values.isEmpty ? 0 :
            cache.values.reduce(0.0) { $0 + Date().timeIntervalSince($1.timestamp) } / Double(cache.count)

        return CacheStats(
            entryCount: cache.count,
            totalSize: totalSize,
            hitRate: metrics.hitRate,
            averageAge: averageAge,
            memoryPressure: calculateMemoryPressure()
        )
    }

    /// Force memory cleanup
    public func forceCleanup() async {
        logger.logInfo("Force cleanup requested", context: [:])
        await performCleanup(aggressive: true)
    }

    /// Check if memory is under pressure
    public func isUnderMemoryPressure() async -> Bool {
        return calculateMemoryPressure() > configuration.pressureThreshold
    }

    // MARK: - Private Methods

    private func startBackgroundTasks() {
        logger.logInfo("MemoryManager starting background tasks", context: [
            "cleanupInterval": configuration.cleanupInterval,
            "pressureMonitorInterval": "60 seconds"
        ])

        // Periodic cleanup task
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.configuration.cleanupInterval ?? 300.0 * 1_000_000_000))
                await self?.performCleanup(aggressive: false)
            }
        }

        // Memory pressure monitoring - reduced frequency to avoid CPU overhead
        pressureMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 1 minutes (reduced from 60s)
                await self?.checkMemoryPressureAndCleanup()
            }
        }

        logger.logInfo("MemoryManager background tasks started", context: [:])
    }

    private func checkMemoryPressureAndCleanup() async {
        let pressure = calculateMemoryPressure()

        if pressure > configuration.pressureThreshold {
            logger.logWarning("Memory pressure detected, triggering cleanup", context: [
                "pressure": pressure,
                "threshold": configuration.pressureThreshold,
                "aggressive": pressure > 0.9
            ])
            await performCleanup(aggressive: pressure > 0.9)
        }

        // Trigger cleanup if cache is too large
        if cache.count > configuration.maxCacheSize {
            logger.logInfo("Cache size limit exceeded, triggering cleanup", context: [
                "currentSize": cache.count,
                "maxSize": configuration.maxCacheSize
            ])
            await performCleanup(aggressive: false)
        }
    }

    private func performCleanup(aggressive: Bool) async {
        let oldCount = cache.count
        let oldSize = cache.values.reduce(0) { $0 + $1.size }

        // Remove expired entries first
        let expired = cache.filter { $0.value.isExpired }
        for (key, _) in expired {
            cache.removeValue(forKey: key)
        }

        // Only log if we're doing significant cleanup
        let willDoCleanup = !expired.isEmpty || aggressive || oldCount > configuration.maxCacheSize || oldSize > configuration.maxMemoryBudget

        if willDoCleanup {
            logger.logInfo("Starting cache cleanup", context: [
                "aggressive": aggressive,
                "currentEntries": oldCount,
                "currentSize": oldSize,
                "expiredEntries": expired.count
            ])
        }

        if !expired.isEmpty {
            logger.logDebug("Removed expired entries", context: ["count": expired.count])
        }

        // If still over limits or under pressure, perform priority-based eviction
        if cache.count > configuration.maxCacheSize || aggressive {
            let targetCount = aggressive ?
                Int(Double(configuration.maxCacheSize) * 0.5) : // Remove 50% if aggressive
                configuration.maxCacheSize

            if cache.count > targetCount {
                let sortedEntries = cache.sorted { $0.value.priority < $1.value.priority }
                let toRemove = cache.count - targetCount

                for i in 0..<min(toRemove, sortedEntries.count) {
                    cache.removeValue(forKey: sortedEntries[i].key)
                }
            }
        }

        let newCount = cache.count
        let newSize = cache.values.reduce(0) { $0 + $1.size }
        let cleanedSize = oldSize - newSize

        if cleanedSize > 0 {
            metrics.recordCleanup(
                entriesRemoved: oldCount - newCount,
                bytesFreed: cleanedSize,
                wasAggressive: aggressive
            )

            logger.logInfo("Cache cleanup completed", context: [
                "entriesRemoved": oldCount - newCount,
                "bytesFreed": cleanedSize,
                "remainingEntries": newCount,
                "remainingSize": newSize,
                "aggressive": aggressive
            ])
        }
        // No longer log "No cleanup needed" to reduce verbosity
    }

    private func calculateMemoryPressure() -> Double {
        let currentSize = cache.values.reduce(0) { $0 + $1.size }
        return min(1.0, Double(currentSize) / Double(configuration.maxMemoryBudget))
    }

    private func estimateSize<T: Sendable>(of data: T) -> Int {
        switch data {
        case let array as [Any]:
            return array.count * 100 // Rough estimate
        case let string as String:
            return string.utf8.count
        case let data as Data:
            return data.count
        case let dict as [String: Any]:
            return dict.count * 150 // Rough estimate
        default:
            return 64 // Default estimate for unknown types
        }
    }
}

// MARK: - Memory Metrics

public struct MemoryMetrics: Sendable {
    /// Total cache hits since initialization
    public private(set) var cacheHits: Int = 0
    /// Total cache misses since initialization
    public private(set) var cacheMisses: Int = 0
    /// Total cache evictions since initialization
    public private(set) var cacheEvictions: Int = 0
    /// Total bytes written to cache (cumulative)
    public private(set) var bytesWritten: Int = 0
    /// Total bytes read from cache (cumulative)
    public private(set) var bytesRead: Int = 0
    /// Total bytes evicted from cache (cumulative)
    public private(set) var bytesEvicted: Int = 0
    /// Current cache size in bytes
    public private(set) var currentCacheSize: Int = 0
    /// Total cleanup operations performed
    public private(set) var cleanupOperations: Int = 0
    /// Number of aggressive cleanup operations
    public private(set) var aggressiveCleanups: Int = 0
    /// Timestamp of last cleanup operation
    public private(set) var lastCleanupTime: Date?

    /// Cache hit rate as a ratio (0.0 to 1.0).
    public var hitRate: Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) : 0.0
    }

    /// Write efficiency ratio (bytes written / bytes read).
    public var efficiency: Double {
        return bytesRead > 0 ? Double(bytesWritten) / Double(bytesRead) : 0.0
    }

    /// Records a cache hit.
    ///
    /// - Parameter size: Size of the cached data in bytes
    mutating func recordCacheHit(size: Int) {
        cacheHits += 1
        bytesRead += size
    }

    /// Records a cache miss.
    mutating func recordCacheMiss() {
        cacheMisses += 1
    }

    /// Records a cache write.
    ///
    /// - Parameter size: Size of the data written in bytes
    mutating func recordCacheWrite(size: Int) {
        bytesWritten += size
        currentCacheSize += size
    }

    /// Records a cache eviction.
    ///
    /// - Parameter size: Size of the evicted data in bytes
    mutating func recordCacheEviction(size: Int) {
        cacheEvictions += 1
        bytesEvicted += size
        currentCacheSize = max(0, currentCacheSize - size)
    }

    /// Records a cache entry expiry.
    mutating func recordCacheExpiry() {
        cacheEvictions += 1
    }

    /// Records a mass eviction (cache clear).
    ///
    /// - Parameter size: Total size of evicted data in bytes
    mutating func recordMassEviction(size: Int) {
        cacheEvictions += 1
        bytesEvicted += size
        currentCacheSize = 0
    }

    /// Records a cleanup operation.
    ///
    /// - Parameters:
    ///   - entriesRemoved: Number of entries removed
    ///   - bytesFreed: Number of bytes freed
    ///   - wasAggressive: Whether this was an aggressive cleanup
    mutating func recordCleanup(entriesRemoved: Int, bytesFreed: Int, wasAggressive: Bool) {
        cleanupOperations += 1
        cacheEvictions += entriesRemoved
        bytesEvicted += bytesFreed
        currentCacheSize = max(0, currentCacheSize - bytesFreed)
        lastCleanupTime = Date()

        if wasAggressive {
            aggressiveCleanups += 1
        }
    }

    /// Returns a snapshot of current metrics.
    func snapshot() -> MemoryMetrics {
        return self
    }
}

// MARK: - Cache Statistics

public struct CacheStats: Sendable {
    public let entryCount: Int
    public let totalSize: Int
    public let hitRate: Double
    public let averageAge: TimeInterval
    public let memoryPressure: Double

    public init(
        entryCount: Int,
        totalSize: Int,
        hitRate: Double,
        averageAge: TimeInterval = 0.0,
        memoryPressure: Double = 0.0
    ) {
        self.entryCount = entryCount
        self.totalSize = totalSize
        self.hitRate = hitRate
        self.averageAge = averageAge
        self.memoryPressure = memoryPressure
    }

    public var description: String {
        let hitRatePercentage = String(format: "%.1f", hitRate * 100)
        let pressurePercentage = String(format: "%.1f", memoryPressure * 100)
        let avgAgeSeconds = String(format: "%.1f", averageAge)

        return "Cache: \(entryCount) entries, \(totalSize) bytes, \(hitRatePercentage)% hit rate, \(avgAgeSeconds)s avg age, \(pressurePercentage)% pressure"
    }
}