import Foundation
import MemoryKit
import OSClient

// MARK: - Topology Cache

/// TopologyCache provides MemoryKit-backed storage for topology graph data
/// with synchronous accessors for rendering performance
@MainActor
final class TopologyCache {

    // MARK: - Properties

    private let memoryManager: SubstationMemoryManager

    // MARK: - Configuration

    private let cacheExpiry: TimeInterval = 60.0 // 1 minute
    private let maxViewCacheSize = 50
    private let maxConnectionCacheSize = 100

    // MARK: - Synchronous Cache (for fast access)

    private var viewCache: [String: CachedTopologyView] = [:]
    private var connectionCache: [String: CachedServerConnections] = [:]
    private var statsCache: CachedTopologyStats?
    private var lastUpdate = Date()

    // MARK: - Statistics

    private var cacheHits = 0
    private var cacheMisses = 0
    private var lastCleanup = Date()
    private let cleanupInterval: TimeInterval = 120.0 // Clean every 2 minutes

    // MARK: - Cache Entry Types

    private struct CachedTopologyView {
        let view: TopologyView
        let timestamp: Date
    }

    private struct CachedServerConnections {
        let connections: ServerConnections
        let timestamp: Date
    }

    private struct CachedTopologyStats {
        let stats: TopologyStats
        let timestamp: Date
    }

    // MARK: - Initialization

    init(memoryManager: SubstationMemoryManager) {
        self.memoryManager = memoryManager
        Logger.shared.logInfo("TopologyCache initialized with MemoryKit integration")
    }

    // MARK: - View Cache Operations

    /// Get cached topology view
    func getView(for key: String) async -> TopologyView? {
        await performPeriodicCleanup()

        guard let entry = viewCache[key] else {
            cacheMisses += 1
            return nil
        }

        // Check expiry
        if Date().timeIntervalSince(entry.timestamp) > cacheExpiry {
            viewCache.removeValue(forKey: key)
            cacheMisses += 1
            return nil
        }

        cacheHits += 1
        Logger.shared.logDebug("TopologyCache hit for view key: \(key)")
        return entry.view
    }

    /// Cache topology view
    func cacheView(_ view: TopologyView, for key: String) async {
        let entry = CachedTopologyView(view: view, timestamp: Date())
        viewCache[key] = entry
        lastUpdate = Date()

        // Maintain cache size with LRU eviction
        if viewCache.count > maxViewCacheSize {
            await evictOldestViewEntry()
        }

        Logger.shared.logDebug("TopologyCache stored view for key: \(key)")
    }

    // MARK: - Connection Cache Operations

    /// Get cached server connections
    func getConnection(for serverId: String) async -> ServerConnections? {
        await performPeriodicCleanup()

        guard let entry = connectionCache[serverId] else {
            cacheMisses += 1
            return nil
        }

        // Check expiry
        if Date().timeIntervalSince(entry.timestamp) > cacheExpiry {
            connectionCache.removeValue(forKey: serverId)
            cacheMisses += 1
            return nil
        }

        cacheHits += 1
        Logger.shared.logDebug("TopologyCache hit for server connections: \(serverId)")
        return entry.connections
    }

    /// Cache server connections
    func cacheConnection(_ connection: ServerConnections, for serverId: String) async {
        let entry = CachedServerConnections(connections: connection, timestamp: Date())
        connectionCache[serverId] = entry
        lastUpdate = Date()

        // Maintain cache size with LRU eviction
        if connectionCache.count > maxConnectionCacheSize {
            await evictOldestConnectionEntry()
        }

        Logger.shared.logDebug("TopologyCache stored connections for server: \(serverId)")
    }

    // MARK: - Stats Cache Operations

    /// Get cached topology stats
    func getStats() async -> TopologyStats? {
        guard let entry = statsCache else {
            return nil
        }

        // Check expiry
        if Date().timeIntervalSince(entry.timestamp) > cacheExpiry {
            statsCache = nil
            return nil
        }

        return entry.stats
    }

    /// Cache topology stats
    func cacheStats(_ stats: TopologyStats) async {
        statsCache = CachedTopologyStats(stats: stats, timestamp: Date())
        lastUpdate = Date()
        Logger.shared.logDebug("TopologyCache stored topology stats")
    }

    // MARK: - Clear Operations

    /// Clear all caches
    func clearAll() async {
        viewCache.removeAll()
        connectionCache.removeAll()
        statsCache = nil
        lastUpdate = Date()
        cacheHits = 0
        cacheMisses = 0
        Logger.shared.logInfo("TopologyCache cleared all caches")
    }

    /// Clear view cache only
    func clearViewCache() async {
        viewCache.removeAll()
        Logger.shared.logDebug("TopologyCache cleared view cache")
    }

    /// Clear connection cache only
    func clearConnectionCache() async {
        connectionCache.removeAll()
        Logger.shared.logDebug("TopologyCache cleared connection cache")
    }

    /// Clear stats cache only
    func clearStatsCache() async {
        statsCache = nil
        Logger.shared.logDebug("TopologyCache cleared stats cache")
    }

    // MARK: - Statistics

    /// Get cache statistics
    func getStatistics() async -> TopologyCacheStatistics {
        let hitRate = cacheHits + cacheMisses > 0 ?
            Double(cacheHits) / Double(cacheHits + cacheMisses) : 0.0

        let cacheAge = Date().timeIntervalSince(lastUpdate)

        return TopologyCacheStatistics(
            viewCacheSize: viewCache.count,
            connectionCacheSize: connectionCache.count,
            hasStats: statsCache != nil,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            hitRate: hitRate,
            cacheAge: cacheAge,
            maxViewCacheSize: maxViewCacheSize,
            maxConnectionCacheSize: maxConnectionCacheSize
        )
    }

    /// Reset statistics
    func resetStatistics() {
        cacheHits = 0
        cacheMisses = 0
        Logger.shared.logDebug("TopologyCache statistics reset")
    }

    /// Get cache info
    func getCacheInfo() -> (viewCount: Int, hasStats: Bool, connectionCount: Int, age: TimeInterval) {
        return (
            viewCount: viewCache.count,
            hasStats: statsCache != nil,
            connectionCount: connectionCache.count,
            age: Date().timeIntervalSince(lastUpdate)
        )
    }

    // MARK: - Private Helpers

    private func evictOldestViewEntry() async {
        guard let oldestKey = viewCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else {
            return
        }

        viewCache.removeValue(forKey: oldestKey)
        Logger.shared.logDebug("TopologyCache evicted oldest view entry")
    }

    private func evictOldestConnectionEntry() async {
        guard let oldestKey = connectionCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else {
            return
        }

        connectionCache.removeValue(forKey: oldestKey)
        Logger.shared.logDebug("TopologyCache evicted oldest connection entry")
    }

    private func performPeriodicCleanup() async {
        let now = Date()
        guard now.timeIntervalSince(lastCleanup) > cleanupInterval else {
            return
        }

        lastCleanup = now
        let beforeViewCount = viewCache.count
        let beforeConnectionCount = connectionCache.count

        // Remove expired entries
        viewCache = viewCache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= cacheExpiry
        }

        connectionCache = connectionCache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= cacheExpiry
        }

        // Check stats expiry
        if let stats = statsCache, now.timeIntervalSince(stats.timestamp) > cacheExpiry {
            statsCache = nil
        }

        let removedViews = beforeViewCount - viewCache.count
        let removedConnections = beforeConnectionCount - connectionCache.count
        if removedViews > 0 || removedConnections > 0 {
            Logger.shared.logDebug("TopologyCache periodic cleanup removed \(removedViews) views, \(removedConnections) connections")
        }
    }
}

// MARK: - Statistics

public struct TopologyCacheStatistics: Sendable {
    public let viewCacheSize: Int
    public let connectionCacheSize: Int
    public let hasStats: Bool
    public let cacheHits: Int
    public let cacheMisses: Int
    public let hitRate: Double
    public let cacheAge: TimeInterval
    public let maxViewCacheSize: Int
    public let maxConnectionCacheSize: Int

    public var summary: String {
        return """
        Topology Cache Statistics:
        View Cache: \(viewCacheSize)/\(maxViewCacheSize)
        Connection Cache: \(connectionCacheSize)/\(maxConnectionCacheSize)
        Has Stats: \(hasStats)
        Hit Rate: \(String(format: "%.1f", hitRate * 100))%
        Hits: \(cacheHits), Misses: \(cacheMisses)
        Cache Age: \(String(format: "%.1f", cacheAge))s
        """
    }
}