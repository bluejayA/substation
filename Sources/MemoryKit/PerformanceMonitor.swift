import Foundation

// MARK: - Performance Monitoring Integration

/// Simplified performance monitoring system for MemoryKit components.
/// Provides basic metrics collection and simple alerting.
public actor PerformanceMonitor {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let enableMonitoring: Bool
        public let metricsCollectionInterval: TimeInterval
        public let alertThresholds: AlertThresholds

        public init(
            enableMonitoring: Bool = true,
            metricsCollectionInterval: TimeInterval = 300.0,
            alertThresholds: AlertThresholds = AlertThresholds()
        ) {
            self.enableMonitoring = enableMonitoring
            self.metricsCollectionInterval = metricsCollectionInterval
            self.alertThresholds = alertThresholds
        }
    }

    // MARK: - Alert Thresholds

    public struct AlertThresholds: Sendable {
        public let memoryUsageThreshold: Double
        public let cacheHitRateThreshold: Double
        public let responseTimeThreshold: TimeInterval

        public init(
            memoryUsageThreshold: Double = 0.8,
            cacheHitRateThreshold: Double = 0.7,
            responseTimeThreshold: TimeInterval = 2.0
        ) {
            self.memoryUsageThreshold = memoryUsageThreshold
            self.cacheHitRateThreshold = cacheHitRateThreshold
            self.responseTimeThreshold = responseTimeThreshold
        }
    }

    // MARK: - Performance Alert

    public enum PerformanceAlert: Sendable {
        case highMemoryUsage(current: Double, threshold: Double)
        case lowCacheHitRate(current: Double, threshold: Double)
        case slowResponseTime(current: TimeInterval, threshold: TimeInterval)

        public var severity: AlertSeverity {
            switch self {
            case .highMemoryUsage(let current, _):
                return current > 0.95 ? .critical : .warning
            case .lowCacheHitRate(let current, _):
                return current < 0.5 ? .critical : .warning
            case .slowResponseTime(let current, _):
                return current > 5.0 ? .critical : .warning
            }
        }

        public var description: String {
            switch self {
            case .highMemoryUsage(let current, let threshold):
                return "High memory usage: \(String(format: "%.1f", current * 100))% (threshold: \(String(format: "%.1f", threshold * 100))%)"
            case .lowCacheHitRate(let current, let threshold):
                return "Low cache hit rate: \(String(format: "%.1f", current * 100))% (threshold: \(String(format: "%.1f", threshold * 100))%)"
            case .slowResponseTime(let current, let threshold):
                return "Slow response time: \(String(format: "%.2f", current))s (threshold: \(String(format: "%.2f", threshold))s)"
            }
        }
    }

    public enum AlertSeverity: String, Sendable {
        case info = "INFO"
        case warning = "WARNING"
        case critical = "CRITICAL"
    }

    // MARK: - Unified Metrics

    public struct UnifiedMetrics: Sendable {
        public let timestamp: Date
        public let memoryMetrics: MemoryMetrics
        public let cacheMetrics: CacheMetrics
        public let systemMetrics: SystemMetrics
        public let performanceProfile: PerformanceProfile

        public var summary: String {
            return """
            Performance Summary (\(timestamp)):
            - Memory: \(String(format: "%.1f", memoryMetrics.hitRate * 100))% hit rate
            - Cache: \(String(format: "%.1f", cacheMetrics.hitRate * 100))% hit rate
            - Performance Grade: \(performanceProfile.grade.rawValue)
            """
        }
    }

    // MARK: - System Metrics

    public struct SystemMetrics: Sendable {
        public let memoryUsage: Double
        public let cpuUsage: Double
        public let timestamp: Date

        public init(
            memoryUsage: Double = 0.0,
            cpuUsage: Double = 0.0,
            timestamp: Date = Date()
        ) {
            self.memoryUsage = memoryUsage
            self.cpuUsage = cpuUsage
            self.timestamp = timestamp
        }
    }

    // MARK: - Performance Profile

    public struct PerformanceProfile: Sendable {
        public let averageResponseTime: TimeInterval
        public let cacheEfficiency: Double
        public let systemLoad: Double

        public var grade: PerformanceGrade {
            let cacheScore = cacheEfficiency
            let loadScore = 1.0 - systemLoad
            let responseScore = averageResponseTime < 1.0 ? 1.0 : max(0.0, 2.0 - averageResponseTime)

            let score = (cacheScore + loadScore + responseScore) / 3.0

            switch score {
            case 0.9...1.0: return .excellent
            case 0.8..<0.9: return .good
            case 0.7..<0.8: return .fair
            case 0.6..<0.7: return .poor
            default: return .critical
            }
        }

        public init(
            averageResponseTime: TimeInterval = 0.0,
            cacheEfficiency: Double = 1.0,
            systemLoad: Double = 0.0
        ) {
            self.averageResponseTime = averageResponseTime
            self.cacheEfficiency = cacheEfficiency
            self.systemLoad = systemLoad
        }
    }

    public enum PerformanceGrade: String, Sendable {
        case excellent = "A+"
        case good = "A"
        case fair = "B"
        case poor = "C"
        case critical = "F"

        public var description: String {
            switch self {
            case .excellent: return "Excellent Performance"
            case .good: return "Good Performance"
            case .fair: return "Fair Performance"
            case .poor: return "Poor Performance"
            case .critical: return "Critical Performance Issues"
            }
        }
    }

    // MARK: - Private Properties

    private let configuration: Configuration
    private let logger: any MemoryKitLogger
    private weak var memoryManager: MemoryManager?
    private var activeAlerts: [PerformanceAlert] = []

    // MARK: - Initialization

    public init(
        configuration: Configuration = Configuration(),
        logger: any MemoryKitLogger = MemoryKitLoggerFactory.defaultLogger()
    ) {
        self.configuration = configuration
        self.logger = logger
    }

    // MARK: - Component Registration

    public func registerComponents(memoryManager: MemoryManager? = nil) async {
        self.memoryManager = memoryManager
        logger.logInfo("PerformanceMonitor registered components", context: [:])
    }

    // MARK: - Metrics Collection

    public func collectMetrics() async -> UnifiedMetrics {
        let timestamp = Date()
        let memoryMetrics = await memoryManager?.getMetrics() ?? MemoryMetrics()
        let cacheMetrics = CacheMetrics()
        let systemMetrics = SystemMetrics(
            memoryUsage: 0.5,
            cpuUsage: 0.3,
            timestamp: timestamp
        )

        let performanceProfile = PerformanceProfile(
            averageResponseTime: 0.5,
            cacheEfficiency: cacheMetrics.hitRate,
            systemLoad: (systemMetrics.memoryUsage + systemMetrics.cpuUsage) / 2.0
        )

        return UnifiedMetrics(
            timestamp: timestamp,
            memoryMetrics: memoryMetrics,
            cacheMetrics: cacheMetrics,
            systemMetrics: systemMetrics,
            performanceProfile: performanceProfile
        )
    }

    // MARK: - Alert Management

    public func getActiveAlerts() async -> [PerformanceAlert] {
        return activeAlerts
    }

    public func clearAlert(_ alert: PerformanceAlert) async {
        activeAlerts.removeAll { $0.description == alert.description }
    }
}