import Foundation

// MARK: - Simplified Cache Metrics System

/// Simplified cache metrics and monitoring for MemoryKit components.
/// Provides basic cache performance insights and statistics.
public actor ComprehensiveCacheMetrics {
    private let logger: any MemoryKitLogger

    public init(logger: any MemoryKitLogger, enablePeriodicReporting: Bool = false) {
        self.logger = logger
    }

    // MARK: - Metrics Collection

    /// Collect basic metrics from cache managers
    public func collectMetrics(
        cacheManagers: [String: any CacheManagerProtocol] = [:],
        typedCacheManagers: [String: any TypedCacheManagerProtocol] = [:]
    ) async -> ComprehensiveMetrics {
        let timestamp = Date()

        var cacheManagerMetrics: [String: CacheMetrics] = [:]
        for (name, manager) in cacheManagers {
            cacheManagerMetrics[name] = await manager.getMetrics()
        }

        var typedCacheMetrics: [String: CacheStatistics] = [:]
        for (name, manager) in typedCacheManagers {
            typedCacheMetrics[name] = await manager.getStatistics()
        }

        return ComprehensiveMetrics(
            timestamp: timestamp,
            cacheManagers: cacheManagerMetrics,
            typedCacheManagers: typedCacheMetrics
        )
    }
}

// MARK: - Supporting Data Structures

/// Basic metrics snapshot for MemoryKit cache systems
public struct ComprehensiveMetrics: Sendable {
    public let timestamp: Date
    public let cacheManagers: [String: CacheMetrics]
    public let typedCacheManagers: [String: CacheStatistics]

    public var overallStats: OverallCacheStats {
        var totalEntries = 0
        var totalSize = 0
        var totalHits = 0
        var totalRequests = 0

        for stats in cacheManagers.values {
            totalHits += stats.hits
            totalRequests += (stats.hits + stats.misses)
            totalSize += stats.bytesStored
        }

        for stats in typedCacheManagers.values {
            totalEntries += stats.currentSize
            totalSize += stats.currentSize * 100
            totalHits += stats.hitCount
            totalRequests += stats.accessCount
        }

        let hitRate = totalRequests > 0 ? Double(totalHits) / Double(totalRequests) : 0.0

        return OverallCacheStats(
            totalEntries: totalEntries,
            totalSize: totalSize,
            hitRate: hitRate
        )
    }
}

public struct OverallCacheStats: Sendable {
    public let totalEntries: Int
    public let totalSize: Int
    public let hitRate: Double

    public init(
        totalEntries: Int,
        totalSize: Int,
        hitRate: Double
    ) {
        self.totalEntries = totalEntries
        self.totalSize = totalSize
        self.hitRate = hitRate
    }

    public var description: String {
        return "Total: \(totalEntries) entries, \(totalSize) bytes, \(String(format: "%.1f", hitRate * 100))% hit rate"
    }
}

// MARK: - Protocols for Cache Integration

public protocol CacheManagerProtocol: Actor {
    func getMetrics() async -> CacheMetrics
}

public protocol TypedCacheManagerProtocol: Actor {
    func getStatistics() async -> CacheStatistics
}