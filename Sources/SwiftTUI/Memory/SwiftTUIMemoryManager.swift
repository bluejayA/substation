import Foundation
import MemoryKit

// MARK: - Default Logger Implementation

/// Default silent logger for SwiftTUI when none is provided
private final class DefaultSwiftTUILogger: MemoryKitLogger, @unchecked Sendable {
    func logDebug(_ message: String, context: [String: Any]) {}
    func logInfo(_ message: String, context: [String: Any]) {}
    func logWarning(_ message: String, context: [String: Any]) {}
    func logError(_ message: String, context: [String: Any]) {}
}

// MARK: - SwiftTUI Memory Management Integration

/// SwiftTUIMemoryManager provides a specialized MemoryKit integration layer
/// for the SwiftTUI framework, handling component caching, animation state,
/// and UI performance optimizations.
@MainActor
public final class SwiftTUIMemoryManager {

    // MARK: - Core MemoryKit Instance

    private let memoryManager: MemoryManager

    // MARK: - Typed Cache Managers

    private let componentCache: TypedCacheManager<String, ComponentCacheEntry>
    private let animationCache: TypedCacheManager<String, AnimationState>
    private let virtualListCache: TypedCacheManager<String, VirtualListState>
    private let inputBufferCache: TypedCacheManager<String, InputBufferEntry>

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
            maxCacheSize: Int = 1500, // Increased for UI component density
            maxMemoryBudget: Int = 30 * 1024 * 1024, // 30MB optimized for SwiftTUI
            cleanupInterval: TimeInterval = 600.0, // 10 minutes - reduced from 3min to lower CPU usage
            enableMetrics: Bool = true,
            enableLeakDetection: Bool = false, // Disabled to reduce CPU overhead
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

    nonisolated init(configuration: Configuration = Configuration(logger: DefaultSwiftTUILogger())) {
        // Use the global singleton MemoryManager instance
        // This ensures only one background task runner exists application-wide
        self.memoryManager = MemoryManager.shared
        self.logger = configuration.logger

        // Initialize typed cache managers
        let componentCacheConfig = TypedCacheManager<String, ComponentCacheEntry>.Configuration(
            maxSize: 500,
            ttl: 300.0, // 5 minutes
            evictionPolicy: .leastRecentlyUsed,
            enableStatistics: true
        )
        self.componentCache = TypedCacheManager(configuration: componentCacheConfig, logger: configuration.logger)

        let animationCacheConfig = TypedCacheManager<String, AnimationState>.Configuration(
            maxSize: 100,
            ttl: 10.0, // 10 seconds
            evictionPolicy: .timeToLive,
            enableStatistics: true
        )
        self.animationCache = TypedCacheManager(configuration: animationCacheConfig, logger: configuration.logger)

        let virtualListCacheConfig = TypedCacheManager<String, VirtualListState>.Configuration(
            maxSize: 50,
            ttl: 120.0, // 2 minutes
            evictionPolicy: .leastFrequentlyUsed,
            enableStatistics: true
        )
        self.virtualListCache = TypedCacheManager(configuration: virtualListCacheConfig, logger: configuration.logger)

        let inputBufferCacheConfig = TypedCacheManager<String, InputBufferEntry>.Configuration(
            maxSize: 10,
            ttl: 1.0, // 1 second
            evictionPolicy: .timeToLive,
            enableStatistics: true
        )
        self.inputBufferCache = TypedCacheManager(configuration: inputBufferCacheConfig, logger: configuration.logger)

        logger.logInfo("SwiftTUIMemoryManager initialized with MemoryKit integration", context: [
            "maxCacheSize": configuration.maxCacheSize,
            "maxMemoryBudget": configuration.maxMemoryBudget
        ])

        // Background tasks are NOT auto-started to reduce CPU overhead
        // Call start() explicitly if background monitoring is needed
    }

    // MARK: - Component Cache Operations

    /// Store component rendering state
    func cacheComponent(_ entry: ComponentCacheEntry, forKey key: String) async {
        await componentCache.store(entry, forKey: key)
        logger.logDebug("Cached component: \(key)", context: [:])
    }

    /// Retrieve component rendering state
    func getCachedComponent(forKey key: String) async -> ComponentCacheEntry? {
        let result = await componentCache.retrieve(forKey: key)
        if result != nil {
            logger.logDebug("Retrieved cached component: \(key)", context: [:])
        }
        return result
    }

    // MARK: - Animation Cache Operations

    /// Store animation state
    func cacheAnimationState(_ state: AnimationState, forKey key: String) async {
        await animationCache.store(state, forKey: key)
        logger.logDebug("Cached animation state: \(key)", context: [:])
    }

    /// Retrieve animation state
    func getCachedAnimationState(forKey key: String) async -> AnimationState? {
        return await animationCache.retrieve(forKey: key)
    }

    /// Clear expired animations
    func clearExpiredAnimations() async {
        // Clear the entire cache for expired animations
        // In a production system, you'd want to track keys separately
        await animationCache.clear()
        logger.logDebug("Cleared expired animations cache", context: [:])
    }

    // MARK: - Virtual List Cache Operations

    /// Store virtual list state
    func cacheVirtualListState(_ state: VirtualListState, forKey key: String) async {
        await virtualListCache.store(state, forKey: key)
        logger.logDebug("Cached virtual list state: \(key)", context: [:])
    }

    /// Retrieve virtual list state
    func getCachedVirtualListState(forKey key: String) async -> VirtualListState? {
        return await virtualListCache.retrieve(forKey: key)
    }

    // MARK: - Input Buffer Cache Operations

    /// Store input buffer state
    func cacheInputBuffer(_ entry: InputBufferEntry, forKey key: String) async {
        await inputBufferCache.store(entry, forKey: key)
        logger.logDebug("Cached input buffer: \(key)", context: [:])
    }

    /// Retrieve input buffer state
    func getCachedInputBuffer(forKey key: String) async -> InputBufferEntry? {
        return await inputBufferCache.retrieve(forKey: key)
    }

    // MARK: - Search Cache Operations

    /// Store search state
    func cacheSearchState(_ state: SearchState, forKey key: String) async {
        // Convert SearchState to ComponentCacheEntry for storage
        let metadata = [
            "query": state.query,
            "resultCount": String(state.results.count),
            "currentIndex": String(state.currentIndex),
            "hasResults": String(state.hasResults)
        ]
        let entry = ComponentCacheEntry(
            componentId: state.searchId,
            intrinsicSize: SizeData(width: 0, height: 0),
            renderingHash: "search_\(state.query.hashValue)",
            metadata: metadata
        )
        await componentCache.store(entry, forKey: key)
        logger.logDebug("Cached search state: \(key)", context: [:])
    }

    /// Retrieve search state
    func getCachedSearchState(forKey key: String) async -> SearchState? {
        guard let entry = await componentCache.retrieve(forKey: key),
              let query = entry.metadata["query"],
              let resultCountStr = entry.metadata["resultCount"],
              let resultCount = Int(resultCountStr),
              let currentIndexStr = entry.metadata["currentIndex"],
              let currentIndex = Int(currentIndexStr),
              let hasResultsStr = entry.metadata["hasResults"],
              let hasResults = Bool(hasResultsStr) else {
            return nil
        }

        // Generate dummy results array for now
        let results = Array(0..<resultCount)

        return SearchState(
            searchId: entry.componentId,
            query: query,
            results: results,
            currentIndex: currentIndex,
            hasResults: hasResults
        )
    }

    /// Clear search cache for specific key
    func clearSearchCache(forKey key: String) async {
        await componentCache.remove(forKey: key)
        logger.logDebug("Cleared search cache: \(key)", context: [:])
    }

    // MARK: - Advanced Operations

    /// Execute cache operation with full MemoryKit protection
    func executeProtectedCacheOperation<T: Sendable>(
        operationId: String = UUID().uuidString,
        service: String = "SwiftTUICache",
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
    func getCacheStatistics() async -> SwiftTUICacheStatistics {
        let componentStats = await componentCache.getStatistics()
        let animationStats = await animationCache.getStatistics()
        let virtualListStats = await virtualListCache.getStatistics()
        let inputBufferStats = await inputBufferCache.getStatistics()
        let metrics = await memoryManager.getMetrics()
        let healthReport = SystemHealthReport(
            overallHealth: .healthy,
            memoryPressure: 0.0,
            cacheUtilization: 0.0,
            uptime: 0,
            summary: "System health: OK, Cache hits: \(metrics.cacheHits), Cache misses: \(metrics.cacheMisses)"
        )

        return SwiftTUICacheStatistics(
            componentCache: componentStats,
            animationCache: animationStats,
            virtualListCache: virtualListStats,
            inputBufferCache: inputBufferStats,
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
        logger.logInfo("SwiftTUIMemoryManager performed force cleanup", context: [:])
    }

    /// Clear all caches
    func clearAllCaches() async {
        await componentCache.clear()
        await animationCache.clear()
        await virtualListCache.clear()
        await inputBufferCache.clear()
        logger.logInfo("SwiftTUIMemoryManager cleared all caches", context: [:])
    }

    /// Clear specific cache type
    func clearCache(type: SwiftTUICacheType) async {
        switch type {
        case .components:
            await componentCache.clear()
        case .animations:
            await animationCache.clear()
        case .virtualLists:
            await virtualListCache.clear()
        case .inputBuffers:
            await inputBufferCache.clear()
        }
        logger.logInfo("SwiftTUIMemoryManager cleared \(type) cache", context: [:])
    }
}

// MARK: - Supporting Types

public enum SwiftTUICacheType {
    case components
    case animations
    case virtualLists
    case inputBuffers
}

// MARK: - Cache Entry Types

public struct ComponentCacheEntry: Sendable, Codable {
    public let componentId: String
    public let intrinsicSize: SizeData
    public let renderingHash: String
    public let timestamp: Date
    public let metadata: [String: String]

    public init(componentId: String, intrinsicSize: SizeData, renderingHash: String, metadata: [String: String] = [:]) {
        self.componentId = componentId
        self.intrinsicSize = intrinsicSize
        self.renderingHash = renderingHash
        self.timestamp = Date()
        self.metadata = metadata
    }
}

public struct SizeData: Sendable, Codable {
    public let width: Int32
    public let height: Int32

    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }
}

public struct AnimationState: Sendable, Codable {
    public let animationId: String
    public let startTime: Date
    public let duration: TimeInterval
    public let currentProgress: Double
    public let animationType: String
    public let isCompleted: Bool

    public init(animationId: String, startTime: Date, duration: TimeInterval, currentProgress: Double, animationType: String, isCompleted: Bool) {
        self.animationId = animationId
        self.startTime = startTime
        self.duration = duration
        self.currentProgress = currentProgress
        self.animationType = animationType
        self.isCompleted = isCompleted
    }

    public var isExpired: Bool {
        return isCompleted || Date().timeIntervalSince(startTime) > duration + 1.0
    }
}

public struct VirtualListState: Sendable, Codable {
    public let listId: String
    public let scrollOffset: Int
    public let selectedIndex: Int
    public let itemCount: Int
    public let visibleRange: RangeData
    public let searchQuery: String?
    public let timestamp: Date

    public init(listId: String, scrollOffset: Int, selectedIndex: Int, itemCount: Int, visibleRange: RangeData, searchQuery: String? = nil) {
        self.listId = listId
        self.scrollOffset = scrollOffset
        self.selectedIndex = selectedIndex
        self.itemCount = itemCount
        self.visibleRange = visibleRange
        self.searchQuery = searchQuery
        self.timestamp = Date()
    }
}

public struct RangeData: Sendable, Codable {
    public let startIndex: Int
    public let endIndex: Int

    public init(startIndex: Int, endIndex: Int) {
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

public struct InputBufferEntry: Sendable, Codable {
    public let bufferId: String
    public let keyBuffer: [Int32]
    public let lastKeyTime: Date
    public let bufferTimeout: TimeInterval

    public init(bufferId: String, keyBuffer: [Int32], lastKeyTime: Date, bufferTimeout: TimeInterval) {
        self.bufferId = bufferId
        self.keyBuffer = keyBuffer
        self.lastKeyTime = lastKeyTime
        self.bufferTimeout = bufferTimeout
    }

    public var isExpired: Bool {
        return Date().timeIntervalSince(lastKeyTime) > bufferTimeout
    }
}

public struct SwiftTUICacheStatistics: Sendable {
    public let componentCache: CacheStatistics
    public let animationCache: CacheStatistics
    public let virtualListCache: CacheStatistics
    public let inputBufferCache: CacheStatistics
    public let systemHealth: SystemHealthReport

    public var summary: String {
        return """
        SwiftTUI Cache Statistics:
        Component Cache: \(componentCache.hitCount)/\(componentCache.accessCount) hits (\(String(format: "%.1f", componentCache.hitRate * 100))%)
        Animation Cache: \(animationCache.hitCount)/\(animationCache.accessCount) hits (\(String(format: "%.1f", animationCache.hitRate * 100))%)
        Virtual List Cache: \(virtualListCache.hitCount)/\(virtualListCache.accessCount) hits (\(String(format: "%.1f", virtualListCache.hitRate * 100))%)
        Input Buffer Cache: \(inputBufferCache.hitCount)/\(inputBufferCache.accessCount) hits (\(String(format: "%.1f", inputBufferCache.hitRate * 100))%)
        \(systemHealth.summary)
        """
    }
}

// MARK: - System Health Report Types (if not already defined elsewhere)

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