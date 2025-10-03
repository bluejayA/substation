import Foundation
import MemoryKit
import OSClient

// MARK: - Default Logger Implementation

/// Default silent logger for internal use
private final class PrivateDefaultLogger: MemoryKitLogger, @unchecked Sendable {
    func logDebug(_ message: String, context: [String: Any]) {}
    func logInfo(_ message: String, context: [String: Any]) {}
    func logWarning(_ message: String, context: [String: Any]) {}
    func logError(_ message: String, context: [String: Any]) {}
}

// MARK: - Substation Memory Container

/// SubstationMemoryContainer provides centralized dependency injection
/// for MemoryKit components throughout the Substation application.
/// This ensures consistent configuration and shared instances.
@MainActor
final class SubstationMemoryContainer {

    // MARK: - Singleton

    static let shared = SubstationMemoryContainer()

    // MARK: - Core Components

    private var _memoryManager: SubstationMemoryManager?
    private var _resourceCacheAdapter: ResourceCacheAdapter?
    private var _openStackResourceCache: OpenStackResourceCache?
    private var _searchIndexCache: SearchIndexCache?
    private var _topologyCache: TopologyCache?
    private var _relationshipCache: RelationshipCache?

    // MARK: - Shared Logger

    private var logger: any MemoryKitLogger = PrivateDefaultLogger()

    // MARK: - Initialization State

    private var isInitialized = false

    // MARK: - Private Initialization

    private init() {
        logger.logInfo("SubstationMemoryContainer initialized", context: [:])
    }

    // MARK: - Initialization

    /// Initialize all MemoryKit components with default configuration
    func initialize() async throws {
        guard !isInitialized else {
            logger.logWarning("SubstationMemoryContainer already initialized", context: [:])
            return
        }

        logger.logInfo("SubstationMemoryContainer starting initialization", context: [:])

        // Initialize core memory manager - this should be passed from TUI/Substation later
        let config = SubstationMemoryManager.Configuration(logger: PrivateDefaultLogger())

        _memoryManager = SubstationMemoryManager(configuration: config)

        // Initialize adapters
        _resourceCacheAdapter = ResourceCacheAdapter(memoryManager: _memoryManager!)
        _openStackResourceCache = OpenStackResourceCache(memoryManager: _memoryManager!)
        _searchIndexCache = SearchIndexCache(memoryManager: _memoryManager!)
        _topologyCache = TopologyCache(memoryManager: _memoryManager!)
        _relationshipCache = RelationshipCache(memoryManager: _memoryManager!)

        isInitialized = true
        logger.logInfo("SubstationMemoryContainer initialization completed", context: [:])
    }

    // MARK: - Component Access

    /// Get the main memory manager
    var memoryManager: SubstationMemoryManager {
        guard let manager = _memoryManager else {
            logger.logError("SubstationMemoryContainer not initialized - call initialize() first", context: [:])
            fatalError("SubstationMemoryContainer not initialized")
        }
        return manager
    }

    /// Get the resource cache adapter
    var resourceCacheAdapter: ResourceCacheAdapter {
        guard let adapter = _resourceCacheAdapter else {
            logger.logError("SubstationMemoryContainer not initialized - call initialize() first", context: [:])
            fatalError("SubstationMemoryContainer not initialized")
        }
        return adapter
    }



    /// Get the OpenStack resource cache
    var openStackResourceCache: OpenStackResourceCache {
        guard let cache = _openStackResourceCache else {
            logger.logError("SubstationMemoryContainer not initialized - call initialize() first", context: [:])
            fatalError("SubstationMemoryContainer not initialized")
        }
        return cache
    }

    /// Get the search index cache
    var searchIndexCache: SearchIndexCache {
        guard let cache = _searchIndexCache else {
            logger.logError("SubstationMemoryContainer not initialized - call initialize() first", context: [:])
            fatalError("SubstationMemoryContainer not initialized")
        }
        return cache
    }

    /// Get the topology cache
    var topologyCache: TopologyCache {
        guard let cache = _topologyCache else {
            logger.logError("SubstationMemoryContainer not initialized - call initialize() first", context: [:])
            fatalError("SubstationMemoryContainer not initialized")
        }
        return cache
    }

    /// Get the relationship cache
    var relationshipCache: RelationshipCache {
        guard let cache = _relationshipCache else {
            logger.logError("SubstationMemoryContainer not initialized - call initialize() first", context: [:])
            fatalError("SubstationMemoryContainer not initialized")
        }
        return cache
    }

    // MARK: - Legacy Component Factories

    /// Create ResourceNameCache with MemoryKit integration
    func createResourceNameCache() -> ResourceNameCache {
        return ResourceNameCache(adapter: resourceCacheAdapter)
    }

    // MARK: - System Operations

    /// Get comprehensive system health report
    func getSystemHealthReport() async -> SystemHealthReport {
        return await memoryManager.getHealthReport()
    }

    /// Force cleanup of all caches
    func forceCleanup() async {
        await memoryManager.forceCleanup()
        logger.logInfo("SubstationMemoryContainer performed force cleanup", context: [:])
    }

    /// Clear all caches
    func clearAllCaches() async {
        await memoryManager.clearAllCaches()
        logger.logInfo("SubstationMemoryContainer cleared all caches", context: [:])
    }

    /// Get performance statistics
    func getPerformanceStatistics() async -> SubstationPerformanceStatistics {
        let cacheStats = await memoryManager.getCacheStatistics()
        let resourceStats = await resourceCacheAdapter.getStatistics()
        let searchStats = await searchIndexCache.getStatistics()
        let topologyStats = await topologyCache.getStatistics()
        let relationshipStats = await relationshipCache.getStatistics()

        return SubstationPerformanceStatistics(
            systemHealth: cacheStats.systemHealth,
            resourceCacheStats: resourceStats,
            searchCacheStats: searchStats,
            topologyStats: topologyStats,
            relationshipStats: relationshipStats,
            overallCacheStats: cacheStats
        )
    }
}

// MARK: - Performance Statistics

public struct SubstationPerformanceStatistics: Sendable {
    public let systemHealth: SystemHealthReport
    public let resourceCacheStats: ResourceCacheStatistics
    public let searchCacheStats: SearchIndexCacheStatistics
    public let topologyStats: TopologyCacheStatistics
    public let relationshipStats: RelationshipCacheStatistics
    public let overallCacheStats: SubstationCacheStatistics

    public var summary: String {
        return """
        Substation Performance Statistics:
        System Health: \(systemHealth.overallHealth.description)
        \(resourceCacheStats.summary)
        \(searchCacheStats.summary)
        \(topologyStats.summary)
        \(relationshipStats.summary)
        Overall Cache Performance:
        \(overallCacheStats.summary)
        """
    }
}

// MARK: - Convenience Extensions

extension SubstationMemoryContainer {
    /// Initialize with custom configuration
    func initialize(with customConfig: SubstationMemoryManager.Configuration) async throws {
        guard !isInitialized else {
            logger.logWarning("SubstationMemoryContainer already initialized", context: [:])
            return
        }

        // Update logger from config
        self.logger = customConfig.logger
        logger.logInfo("SubstationMemoryContainer starting initialization with custom config", context: [:])

        _memoryManager = SubstationMemoryManager(configuration: customConfig)
        _resourceCacheAdapter = ResourceCacheAdapter(memoryManager: _memoryManager!)
        _openStackResourceCache = OpenStackResourceCache(memoryManager: _memoryManager!)
        _searchIndexCache = SearchIndexCache(memoryManager: _memoryManager!)
        _topologyCache = TopologyCache(memoryManager: _memoryManager!)
        _relationshipCache = RelationshipCache(memoryManager: _memoryManager!)

        isInitialized = true
        logger.logInfo("SubstationMemoryContainer initialization completed with custom config", context: [:])
    }

    /// Check if container is properly initialized
    var isReady: Bool {
        return isInitialized && _memoryManager != nil
    }

    /// Shutdown and cleanup all components
    func shutdown() async {
        if isInitialized {
            await forceCleanup()
            _memoryManager = nil
            _resourceCacheAdapter = nil
            _openStackResourceCache = nil
            _searchIndexCache = nil
            _topologyCache = nil
            _relationshipCache = nil
            isInitialized = false
            logger.logInfo("SubstationMemoryContainer shutdown completed", context: [:])
        }
    }
}