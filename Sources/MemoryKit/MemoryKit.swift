import Foundation

// MARK: - MemoryKit Public Interface

/// MemoryKit provides a unified, high-performance memory management solution
/// for Swift applications with advanced monitoring and caching.
///
/// Key Features:
/// - Thread-safe memory management using Swift actors
/// - Advanced cache management with intelligent eviction policies
/// - Real-time performance monitoring and alerting
/// - Cross-platform compatibility (macOS/Linux)
///
/// Usage:
/// ```swift
/// // Initialize the memory management system
/// let memoryKit = await MemoryKit()
///
/// // Use individual components
/// await memoryKit.memoryManager.store(data, forKey: "key")
/// let stats = await memoryKit.memoryManager.getCacheStats()
/// ```
public actor MemoryKit {

    // MARK: - Public Components

    /// Advanced memory manager with cache and resource management
    public let memoryManager: MemoryManager

    /// Performance monitor for real-time metrics and alerting
    public let performanceMonitor: PerformanceMonitor

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let memoryManagerConfig: MemoryManager.Configuration
        public let performanceMonitorConfig: PerformanceMonitor.Configuration

        public init(
            memoryManagerConfig: MemoryManager.Configuration = MemoryManager.Configuration(),
            performanceMonitorConfig: PerformanceMonitor.Configuration = PerformanceMonitor.Configuration()
        ) {
            self.memoryManagerConfig = memoryManagerConfig
            self.performanceMonitorConfig = performanceMonitorConfig
        }
    }

    // MARK: - Initialization

    public init(configuration: Configuration = Configuration()) async {
        // Initialize components
        self.memoryManager = MemoryManager(configuration: configuration.memoryManagerConfig)
        self.performanceMonitor = PerformanceMonitor(configuration: configuration.performanceMonitorConfig)

        // Wire up components for integrated monitoring
        await performanceMonitor.registerComponents(memoryManager: memoryManager)
    }

    // MARK: - High-Level Operations

    /// Get comprehensive system health report
    public func getHealthReport() async -> SystemHealthReport {
        let memoryStats = await memoryManager.getCacheStats()
        let performanceMetrics = await performanceMonitor.collectMetrics()
        let activeAlerts = await performanceMonitor.getActiveAlerts()

        return SystemHealthReport(
            timestamp: Date(),
            memoryStats: memoryStats,
            performanceMetrics: performanceMetrics,
            activeAlerts: activeAlerts,
            overallHealth: calculateOverallHealth(
                memoryStats: memoryStats,
                performanceMetrics: performanceMetrics
            )
        )
    }

    /// Force comprehensive cleanup of all components
    public func forceCleanup() async {
        await memoryManager.forceCleanup()
    }

    // MARK: - Private Methods

    private func calculateOverallHealth(
        memoryStats: CacheStats,
        performanceMetrics: PerformanceMonitor.UnifiedMetrics
    ) -> SystemHealth {
        var score: Double = 1.0

        // Memory health (50%)
        let memoryHealth = min(1.0, memoryStats.hitRate)
        score *= (0.5 + 0.5 * memoryHealth)

        // Performance health (50%)
        let performanceHealth = performanceMetrics.performanceProfile.grade == .excellent ? 1.0 :
                               performanceMetrics.performanceProfile.grade == .good ? 0.8 :
                               performanceMetrics.performanceProfile.grade == .fair ? 0.6 :
                               performanceMetrics.performanceProfile.grade == .poor ? 0.4 : 0.2
        score *= (0.5 + 0.5 * performanceHealth)

        switch score {
        case 0.9...1.0: return .excellent
        case 0.8..<0.9: return .good
        case 0.7..<0.8: return .fair
        case 0.5..<0.7: return .poor
        default: return .critical
        }
    }
}

// MARK: - System Health Report

public struct SystemHealthReport: Sendable {
    public let timestamp: Date
    public let memoryStats: CacheStats
    public let performanceMetrics: PerformanceMonitor.UnifiedMetrics
    public let activeAlerts: [PerformanceMonitor.PerformanceAlert]
    public let overallHealth: SystemHealth

    public var summary: String {
        let alertCount = activeAlerts.count
        let criticalAlerts = activeAlerts.filter { $0.severity == .critical }.count

        return """
        System Health Report (\(timestamp)):
        Overall Health: \(overallHealth.description)
        Active Alerts: \(alertCount) (\(criticalAlerts) critical)
        \(memoryStats.description)
        Performance Grade: \(performanceMetrics.performanceProfile.grade.description)
        """
    }
}

public enum SystemHealth: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"

    public var description: String {
        return rawValue
    }

    public var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "lightgreen"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Convenience Extensions

extension MemoryKit {
    /// Create a specialized cache manager for a specific data type
    public func createTypedCacheManager<Key: Hashable & Sendable, Value: Sendable>(
        keyType: Key.Type,
        valueType: Value.Type,
        configuration: CacheManager<Key, Value>.Configuration = CacheManager<Key, Value>.Configuration()
    ) -> CacheManager<Key, Value> {
        return CacheManager<Key, Value>(configuration: configuration)
    }

    /// Create a specialized resource pool for expensive objects
    public func createResourcePool<Resource: Sendable>(
        resourceType: Resource.Type,
        configuration: ResourcePool<Resource>.Configuration = ResourcePool<Resource>.Configuration(),
        factory: @escaping @Sendable () async throws -> Resource,
        cleanup: @escaping @Sendable (Resource) async -> Void = { _ in },
        validator: @escaping @Sendable (Resource) async -> Bool = { _ in true }
    ) -> ResourcePool<Resource> {
        return ResourcePool<Resource>(
            configuration: configuration,
            factory: factory,
            cleanup: cleanup,
            validator: validator
        )
    }

    /// Create a multi-level cache manager with specified configuration
    public func createMultiLevelCacheManager<Key: Hashable & Sendable, Value: Codable & Sendable>(
        keyType: Key.Type,
        valueType: Value.Type,
        configuration: MultiLevelCacheManager<Key, Value>.Configuration = MultiLevelCacheManager<Key, Value>.Configuration(),
        logger: (any MemoryKitLogger)? = nil
    ) -> MultiLevelCacheManager<Key, Value> {
        return MultiLevelCacheManager<Key, Value>(configuration: configuration, logger: logger)
    }
}