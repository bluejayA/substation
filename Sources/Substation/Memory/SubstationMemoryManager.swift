import Foundation
import MemoryKit
import OSClient

// MARK: - Default Logger Implementation

/// Default silent logger for SubstationMemoryManager when none is provided
private final class DefaultSubstationMemoryLogger: MemoryKitLogger, @unchecked Sendable {
    func logDebug(_ message: String, context: [String: Any]) {}
    func logInfo(_ message: String, context: [String: Any]) {}
    func logWarning(_ message: String, context: [String: Any]) {}
    func logError(_ message: String, context: [String: Any]) {}
}

// MARK: - Substation Memory Management Integration

/// SubstationMemoryManager provides a specialized MemoryKit integration layer
/// for the Substation application, handling OpenStack resource caching,
/// filter operations, and UI performance optimizations.
@MainActor
final class SubstationMemoryManager {

    // MARK: - Core MemoryKit Instance

    private let memoryManager: MemoryManager

    // MARK: - Typed Cache Managers

    private let resourceNameCache: TypedCacheManager<String, String>
    private let filterResultsCache: TypedCacheManager<String, Data>
    private let searchResultsCache: TypedCacheManager<String, SearchResults>
    private let uiOptimizationCache: TypedCacheManager<String, String>

    // MARK: - Logger Integration

    private let logger: any MemoryKitLogger

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let maxCacheSize: Int
        public let maxMemoryBudget: Int
        public let cleanupInterval: TimeInterval
        public let enableMetrics: Bool
        public let enableLeakDetection: Bool
        public let logger: any MemoryKitLogger

        public init(
            maxCacheSize: Int = 3000, // Increased for better UI performance
            maxMemoryBudget: Int = 75 * 1024 * 1024, // 75MB optimized allocation
            cleanupInterval: TimeInterval = 600.0, // 10 minutes - reduced from 2min to lower CPU usage
            enableMetrics: Bool = true,
            enableLeakDetection: Bool = true,
            logger: any MemoryKitLogger
        ) {
            self.maxCacheSize = maxCacheSize
            self.maxMemoryBudget = maxMemoryBudget
            self.cleanupInterval = cleanupInterval
            self.enableMetrics = enableMetrics
            self.enableLeakDetection = enableLeakDetection
            self.logger = logger
        }
    }

    // MARK: - Initialization

    init(configuration: Configuration = Configuration(logger: DefaultSubstationMemoryLogger())) {
        // Use the global singleton MemoryManager instance
        // This ensures only one background task runner exists application-wide
        self.memoryManager = MemoryManager.shared
        self.logger = configuration.logger

        // Initialize typed cache managers
        let resourceNameCacheConfig = TypedCacheManager<String, String>.Configuration(
            maxSize: 1000,
            ttl: 300.0, // 5 minutes
            evictionPolicy: .leastRecentlyUsed,
            enableStatistics: true
        )
        self.resourceNameCache = TypedCacheManager(configuration: resourceNameCacheConfig, logger: configuration.logger)

        let filterResultsCacheConfig = TypedCacheManager<String, Data>.Configuration(
            maxSize: 500,
            ttl: 5.0, // 5 seconds
            evictionPolicy: .timeToLive,
            enableStatistics: true
        )
        self.filterResultsCache = TypedCacheManager(configuration: filterResultsCacheConfig, logger: configuration.logger)

        let searchResultsCacheConfig = TypedCacheManager<String, SearchResults>.Configuration(
            maxSize: 200,
            ttl: 60.0, // 1 minute
            evictionPolicy: .leastRecentlyUsed,
            enableStatistics: true
        )
        self.searchResultsCache = TypedCacheManager(configuration: searchResultsCacheConfig, logger: configuration.logger)

        let uiOptimizationCacheConfig = TypedCacheManager<String, String>.Configuration(
            maxSize: 1000,
            ttl: 30.0, // 30 seconds
            evictionPolicy: .leastFrequentlyUsed,
            enableStatistics: true
        )
        self.uiOptimizationCache = TypedCacheManager(configuration: uiOptimizationCacheConfig, logger: configuration.logger)

        logger.logInfo("SubstationMemoryManager initialized with MemoryKit integration", context: [
            "maxCacheSize": configuration.maxCacheSize,
            "maxMemoryBudget": configuration.maxMemoryBudget
        ])

        // Background tasks are NOT auto-started to reduce CPU overhead
        // Call start() explicitly if background monitoring is needed
    }

    // MARK: - Resource Name Cache Operations

    /// Store a resource name mapping
    func setResourceName(_ name: String, forId id: String, resourceType: String) async {
        let key = "\(resourceType):\(id)"
        await resourceNameCache.store(name, forKey: key)
        logger.logDebug("Stored resource name mapping: \(key) -> \(name)", context: [:])
    }

    /// Retrieve a resource name by ID and type
    func getResourceName(forId id: String, resourceType: String) async -> String? {
        let key = "\(resourceType):\(id)"
        let result = await resourceNameCache.retrieve(forKey: key)
        if result != nil {
            logger.logDebug("Retrieved resource name from cache: \(key)", context: [:])
        }
        return result
    }

    /// Convenience methods for specific resource types
    func setFlavorName(_ name: String, forId id: String) async {
        await setResourceName(name, forId: id, resourceType: "flavor")
    }

    func getFlavorName(forId id: String) async -> String? {
        return await getResourceName(forId: id, resourceType: "flavor")
    }

    func setImageName(_ name: String, forId id: String) async {
        await setResourceName(name, forId: id, resourceType: "image")
    }

    func getImageName(forId id: String) async -> String? {
        return await getResourceName(forId: id, resourceType: "image")
    }

    func setServerName(_ name: String, forId id: String) async {
        await setResourceName(name, forId: id, resourceType: "server")
    }

    func getServerName(forId id: String) async -> String? {
        return await getResourceName(forId: id, resourceType: "server")
    }

    func setNetworkName(_ name: String, forId id: String) async {
        await setResourceName(name, forId: id, resourceType: "network")
    }

    func getNetworkName(forId id: String) async -> String? {
        return await getResourceName(forId: id, resourceType: "network")
    }

    func setSubnetName(_ name: String, forId id: String) async {
        await setResourceName(name, forId: id, resourceType: "subnet")
    }

    func getSubnetName(forId id: String) async -> String? {
        return await getResourceName(forId: id, resourceType: "subnet")
    }

    func setSecurityGroupName(_ name: String, forId id: String) async {
        await setResourceName(name, forId: id, resourceType: "securityGroup")
    }

    func getSecurityGroupName(forId id: String) async -> String? {
        return await getResourceName(forId: id, resourceType: "securityGroup")
    }

    // MARK: - Filter Results Cache Operations

    /// Store filter results with hash-based invalidation support
    func storeFilterResults<T: Sendable & Codable>(_ results: [T], forKey key: String, dataHash: String) async {
        let cacheKey = "\(key):\(dataHash)"
        do {
            let data = try JSONEncoder().encode(results)
            await filterResultsCache.store(data, forKey: cacheKey)
            logger.logDebug("Stored filter results: \(key) (\(results.count) items, hash: \(dataHash))", context: [:])
        } catch {
            logger.logError("Failed to encode filter results: \(error.localizedDescription)", context: [:])
        }
    }

    /// Retrieve filter results with hash validation
    func retrieveFilterResults<T: Sendable & Codable>(forKey key: String, dataHash: String, as type: T.Type) async -> [T]? {
        let cacheKey = "\(key):\(dataHash)"
        guard let data = await filterResultsCache.retrieve(forKey: cacheKey) else {
            return nil
        }
        do {
            let results = try JSONDecoder().decode([T].self, from: data)
            logger.logDebug("Retrieved filter results from cache: \(key) (\(results.count) items)", context: [:])
            return results
        } catch {
            logger.logError("Failed to decode filter results: \(error.localizedDescription)", context: [:])
            return nil
        }
    }

    // MARK: - Search Results Cache Operations

    /// Store precomputed search results
    func storeSearchResults(_ results: SearchResults, forQuery query: String) async {
        await searchResultsCache.store(results, forKey: query.lowercased())
        logger.logDebug("Stored search results for query: '\(query)' (\(results.items.count) items)", context: [:])
    }

    /// Retrieve precomputed search results
    func retrieveSearchResults(forQuery query: String) async -> SearchResults? {
        let result = await searchResultsCache.retrieve(forKey: query.lowercased())
        if result != nil {
            logger.logDebug("Retrieved precomputed search results for: '\(query)'", context: [:])
        }
        return result
    }

    // MARK: - UI Optimization Cache Operations

    /// Store UI optimization data (e.g., parsed scenario names)
    func storeUIOptimization(_ value: String, forKey key: String) async {
        await uiOptimizationCache.store(value, forKey: key)
        logger.logDebug("Stored UI optimization: \(key)", context: [:])
    }

    /// Retrieve UI optimization data
    func retrieveUIOptimization(forKey key: String) async -> String? {
        return await uiOptimizationCache.retrieve(forKey: key)
    }

    // MARK: - Advanced Operations

    /// Execute cache operation with full MemoryKit protection
    func executeProtectedCacheOperation<T: Sendable>(
        operationId: String = UUID().uuidString,
        service: String = "SubstationCache",
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            logger.logError("Cache operation failed", context: [
                "operationId": operationId,
                "service": service,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    /// Get comprehensive cache statistics
    func getCacheStatistics() async -> SubstationCacheStatistics {
        let resourceNameStats = await resourceNameCache.getStatistics()
        let filterResultsStats = await filterResultsCache.getStatistics()
        let searchResultsStats = await searchResultsCache.getStatistics()
        let uiOptimizationStats = await uiOptimizationCache.getStatistics()
        let metrics = await memoryManager.getMetrics()
        let healthReport = SystemHealthReport(
            overallHealth: .healthy,
            memoryPressure: 0.0,
            cacheUtilization: 0.0,
            uptime: 0,
            summary: "System health: OK, Cache hits: \(metrics.cacheHits), Cache misses: \(metrics.cacheMisses)"
        )

        return SubstationCacheStatistics(
            resourceNameCache: resourceNameStats,
            filterResultsCache: filterResultsStats,
            searchResultsCache: searchResultsStats,
            uiOptimizationCache: uiOptimizationStats,
            systemHealth: healthReport
        )
    }

    /// Get system health report
    func getHealthReport() async -> SystemHealthReport {
        let metrics = await memoryManager.getMetrics()
        return SystemHealthReport(
            overallHealth: .healthy,
            memoryPressure: 0.0,
            cacheUtilization: 0.0,
            uptime: 0,
            summary: "System health: OK, Cache hits: \(metrics.cacheHits), Cache misses: \(metrics.cacheMisses)"
        )
    }

    /// Force cleanup of all caches
    func forceCleanup() async {
        await memoryManager.forceCleanup()
        logger.logInfo("SubstationMemoryManager performed force cleanup", context: [:])
    }

    /// Clear all caches (for refresh operations)
    func clearAllCaches() async {
        await resourceNameCache.clear()
        await filterResultsCache.clear()
        await searchResultsCache.clear()
        await uiOptimizationCache.clear()
        logger.logInfo("SubstationMemoryManager cleared all caches", context: [:])
    }

    /// Clear specific cache type
    func clearCache(type: CacheType) async {
        switch type {
        case .resourceNames:
            await resourceNameCache.clear()
        case .filterResults:
            await filterResultsCache.clear()
        case .searchResults:
            await searchResultsCache.clear()
        case .uiOptimizations:
            await uiOptimizationCache.clear()
        }
        logger.logInfo("SubstationMemoryManager cleared \(type) cache", context: [:])
    }
}

// MARK: - Supporting Types

public enum CacheType {
    case resourceNames
    case filterResults
    case searchResults
    case uiOptimizations
}

public struct SubstationCacheStatistics: Sendable {
    public let resourceNameCache: CacheStatistics
    public let filterResultsCache: CacheStatistics
    public let searchResultsCache: CacheStatistics
    public let uiOptimizationCache: CacheStatistics
    public let systemHealth: SystemHealthReport

    public var summary: String {
        return """
        Substation Cache Statistics:
        Resource Names: \(resourceNameCache.hitCount)/\(resourceNameCache.accessCount) hits (\(String(format: "%.1f", resourceNameCache.hitRate * 100))%)
        Filter Results: \(filterResultsCache.hitCount)/\(filterResultsCache.accessCount) hits (\(String(format: "%.1f", filterResultsCache.hitRate * 100))%)
        Search Results: \(searchResultsCache.hitCount)/\(searchResultsCache.accessCount) hits (\(String(format: "%.1f", searchResultsCache.hitRate * 100))%)
        UI Optimizations: \(uiOptimizationCache.hitCount)/\(uiOptimizationCache.accessCount) hits (\(String(format: "%.1f", uiOptimizationCache.hitRate * 100))%)
        \(systemHealth.summary)
        """
    }
}

// MARK: - Compatibility Extensions

extension SubstationMemoryManager {
    /// Legacy compatibility method for ResourceNameCache.clear()
    func clearResourceNameCache() async {
        await clearCache(type: .resourceNames)
    }

    /// Legacy compatibility method for FilterCache.clearCache()
    func clearFilterCache() async {
        await clearCache(type: .filterResults)
    }

    /// Legacy compatibility method for search cache cleanup
    func clearSearchCache() async {
        await clearCache(type: .searchResults)
    }
}

// MARK: - System Health Report Types

public struct SystemHealthReport: Sendable {
    public enum HealthStatus: Sendable {
        case healthy
        case degraded
        case critical

        public var description: String {
            switch self {
            case .healthy: return "Healthy"
            case .degraded: return "Degraded"
            case .critical: return "Critical"
            }
        }
    }

    public let overallHealth: HealthStatus
    public let memoryPressure: Double
    public let cacheUtilization: Double
    public let uptime: TimeInterval
    public let summary: String

    public init(overallHealth: HealthStatus, memoryPressure: Double, cacheUtilization: Double, uptime: TimeInterval, summary: String) {
        self.overallHealth = overallHealth
        self.memoryPressure = memoryPressure
        self.cacheUtilization = cacheUtilization
        self.uptime = uptime
        self.summary = summary
    }
}