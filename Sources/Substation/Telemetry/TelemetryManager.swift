import Foundation
import SwiftTUI
import CrossPlatformTimer

// MARK: - Core Telemetry Types

/// Performance metric data point for telemetry
public struct TelemetryMetric: Sendable {
    public let name: String
    public let value: Double
    public let unit: String
    public let timestamp: Date
    public let context: [String: String]

    public init(name: String, value: Double, unit: String = "", context: [String: String] = [:]) {
        self.name = name
        self.value = value
        self.unit = unit
        self.timestamp = Date()
        self.context = context
    }
}

/// System health score with component breakdown
public struct SystemHealth: Sendable {
    public let overallScore: Double        // 0-100
    public let performanceScore: Double    // API response times, throughput
    public let reliabilityScore: Double    // Success rates, error frequency
    public let efficiencyScore: Double     // Resource utilization, cache hit rates
    public let trends: [SystemHealthTrend]       // Historical performance trends
    public let timestamp: Date
    public let issues: [TelemetryHealthIssue]       // Current system issues

    public init(performanceScore: Double, reliabilityScore: Double, efficiencyScore: Double,
                trends: [SystemHealthTrend] = [], issues: [TelemetryHealthIssue] = []) {
        self.performanceScore = max(0, min(100, performanceScore))
        self.reliabilityScore = max(0, min(100, reliabilityScore))
        self.efficiencyScore = max(0, min(100, efficiencyScore))
        self.overallScore = (performanceScore + reliabilityScore + efficiencyScore) / 3.0
        self.trends = trends
        self.timestamp = Date()
        self.issues = issues
    }
}

/// System health trend data over time
public struct SystemHealthTrend: Sendable {
    public let metric: String
    public let values: [(Date, Double)]
    public let direction: TrendDirection

    public enum TrendDirection: String, Sendable {
        case improving = "improving"
        case declining = "declining"
        case stable = "stable"
    }
}

/// System health issue detected by monitoring
public struct TelemetryHealthIssue: Sendable {
    public let id: String
    public let severity: IssueSeverity
    public let category: IssueCategory
    public let title: String
    public let description: String
    public let recommendation: String?
    public let detectedAt: Date

    public enum IssueSeverity: String, CaseIterable, Sendable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }

    public enum IssueCategory: String, CaseIterable, Sendable {
        case performance = "performance"
        case reliability = "reliability"
        case resource = "resource"
        case security = "security"
        case configuration = "configuration"
    }

    public init(severity: IssueSeverity, category: IssueCategory, title: String,
                description: String, recommendation: String? = nil) {
        self.id = UUID().uuidString.prefix(8).uppercased()
        self.severity = severity
        self.category = category
        self.title = title
        self.description = description
        self.recommendation = recommendation
        self.detectedAt = Date()
    }
}

// MARK: - Telemetry Manager

/// High-performance telemetry and monitoring system with <1% overhead
@MainActor
public final class TelemetryManager: Sendable {

    // MARK: - Public Properties

    public private(set) var currentHealth: SystemHealth
    public private(set) var recentMetrics: [TelemetryMetric] = []
    public private(set) var isEnabled: Bool = true

    // MARK: - Private Properties

    private var metricsBuffer: [TelemetryMetric] = []
    private var healthHistory: [SystemHealth] = []
    private var aggregatedMetrics: [String: MetricAggregation] = [:]
    private var anomalyDetector: AnomalyDetector
    private var healthUpdateTimer: AnyObject?

    // Configuration
    private let maxMetricsInMemory = 1000
    private let healthUpdateInterval: TimeInterval = 30.0
    private let metricRetentionHours: TimeInterval = 24.0
    private let performanceTargets = PerformanceTargets()

    // MARK: - Initialization

    public init() {
        // Initialize with baseline health
        self.currentHealth = SystemHealth(
            performanceScore: 100.0,
            reliabilityScore: 100.0,
            efficiencyScore: 100.0
        )
        self.anomalyDetector = AnomalyDetector()

        startHealthMonitoring()
    }

    // Timer will be automatically invalidated when the object is deallocated

    // MARK: - Metric Collection (Ultra-lightweight)

    /// Record a performance metric with minimal overhead
    public func recordMetric(name: String, value: Double, unit: String = "", context: [String: String] = [:]) {
        guard isEnabled else { return }

        let metric = TelemetryMetric(name: name, value: value, unit: unit, context: context)

        // Use fast buffer approach to minimize main thread impact
        metricsBuffer.append(metric)

        // Efficient batch processing when buffer reaches threshold
        if metricsBuffer.count >= 50 {
            processMetricsBatch()
        }
    }

    /// Record API call timing and success
    public func recordAPICall(endpoint: String, duration: TimeInterval, success: Bool, statusCode: Int? = nil) {
        guard isEnabled else { return }

        var context: [String: String] = [
            "endpoint": endpoint,
            "success": String(success)
        ]
        if let code = statusCode {
            context["status_code"] = String(code)
        }

        recordMetric(name: "api_call_duration", value: duration * 1000, unit: "ms", context: context)
        recordMetric(name: "api_call_success_rate", value: success ? 1.0 : 0.0, context: context)
    }

    /// Record cache performance
    public func recordCacheMetrics(hits: Int, misses: Int, size: Int) {
        guard isEnabled else { return }

        let total = hits + misses
        let hitRate = total > 0 ? Double(hits) / Double(total) : 0.0

        recordMetric(name: "cache_hit_rate", value: hitRate * 100, unit: "%")
        recordMetric(name: "cache_size", value: Double(size), unit: "items")
    }

    /// Record resource utilization
    public func recordResourceUsage(memory: Double, cpu: Double? = nil, networkBytes: Double? = nil) {
        guard isEnabled else { return }

        recordMetric(name: "memory_usage", value: memory, unit: "MB")
        if let cpu = cpu {
            recordMetric(name: "cpu_usage", value: cpu, unit: "%")
        }
        if let network = networkBytes {
            recordMetric(name: "network_usage", value: network, unit: "bytes")
        }
    }

    // MARK: - Health Monitoring

    private func startHealthMonitoring() {
        healthUpdateTimer = createCompatibleTimer(interval: healthUpdateInterval, repeats: true, action: { [weak self] in
            Task { @MainActor in
                self?.updateSystemHealth()
            }
        })
    }

    private func updateSystemHealth() {
        // Process any pending metrics
        if !metricsBuffer.isEmpty {
            processMetricsBatch()
        }

        // Calculate component scores
        let performanceScore = calculatePerformanceScore()
        let reliabilityScore = calculateReliabilityScore()
        let efficiencyScore = calculateEfficiencyScore()

        // Generate trends
        let trends = generateSystemHealthTrends()

        // Detect issues
        let issues = detectTelemetryHealthIssues()

        // Create new health snapshot
        let newHealth = SystemHealth(
            performanceScore: performanceScore,
            reliabilityScore: reliabilityScore,
            efficiencyScore: efficiencyScore,
            trends: trends,
            issues: issues
        )

        // Update published state
        currentHealth = newHealth
        healthHistory.append(newHealth)

        // Maintain history size
        if healthHistory.count > 100 {
            healthHistory.removeFirst(healthHistory.count - 100)
        }

        // Run anomaly detection
        anomalyDetector.analyze(health: newHealth, metrics: aggregatedMetrics)
    }

    // MARK: - Score Calculations

    private func calculatePerformanceScore() -> Double {
        guard let apiDurationMetrics = aggregatedMetrics["api_call_duration"] else { return 100.0 }

        let avgDuration = apiDurationMetrics.average
        let target = performanceTargets.apiResponseTimeMs

        // Score based on how close we are to target (lower is better)
        if avgDuration <= target {
            return 100.0
        } else {
            let ratio = avgDuration / target
            return max(0, 100.0 - (ratio - 1.0) * 50.0)
        }
    }

    private func calculateReliabilityScore() -> Double {
        guard let successMetrics = aggregatedMetrics["api_call_success_rate"] else { return 100.0 }

        let successRate = successMetrics.average
        return successRate * 100.0
    }

    private func calculateEfficiencyScore() -> Double {
        guard let cacheMetrics = aggregatedMetrics["cache_hit_rate"] else { return 100.0 }

        let hitRate = cacheMetrics.average
        let memoryScore = calculateMemoryEfficiencyScore()

        return (hitRate + memoryScore) / 2.0
    }

    private func calculateMemoryEfficiencyScore() -> Double {
        guard let memoryMetrics = aggregatedMetrics["memory_usage"] else { return 100.0 }

        let avgMemory = memoryMetrics.average
        let target = performanceTargets.maxMemoryUsageMB

        if avgMemory <= target {
            return 100.0
        } else {
            let ratio = avgMemory / target
            return max(0, 100.0 - (ratio - 1.0) * 100.0)
        }
    }

    // MARK: - Trend Analysis

    private func generateSystemHealthTrends() -> [SystemHealthTrend] {
        var trends: [SystemHealthTrend] = []

        // Analyze performance trend over last 10 health updates
        let recentHistory = Array(healthHistory.suffix(10))
        if recentHistory.count >= 5 {
            let performanceValues = recentHistory.map { ($0.timestamp, $0.performanceScore) }
            let direction = analyzeTrendDirection(values: performanceValues.map { $0.1 })
            trends.append(SystemHealthTrend(metric: "performance", values: performanceValues, direction: direction))

            let reliabilityValues = recentHistory.map { ($0.timestamp, $0.reliabilityScore) }
            let reliabilityDirection = analyzeTrendDirection(values: reliabilityValues.map { $0.1 })
            trends.append(SystemHealthTrend(metric: "reliability", values: reliabilityValues, direction: reliabilityDirection))
        }

        return trends
    }

    private func analyzeTrendDirection(values: [Double]) -> SystemHealthTrend.TrendDirection {
        guard values.count >= 5 else { return .stable }

        let recent = Array(values.suffix(3))
        let older = Array(values.prefix(3))

        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)

        let threshold = 2.0 // 2% change threshold

        if recentAvg > olderAvg + threshold {
            return .improving
        } else if recentAvg < olderAvg - threshold {
            return .declining
        } else {
            return .stable
        }
    }

    // MARK: - Issue Detection

    private func detectTelemetryHealthIssues() -> [TelemetryHealthIssue] {
        var issues: [TelemetryHealthIssue] = []

        // Check API performance
        if let apiMetrics = aggregatedMetrics["api_call_duration"],
           apiMetrics.average > performanceTargets.apiResponseTimeMs * 2 {
            issues.append(TelemetryHealthIssue(
                severity: .high,
                category: .performance,
                title: "Slow API Response Times",
                description: "Average API response time is \(String(format: "%.1f", apiMetrics.average))ms, significantly above target",
                recommendation: "Check network connectivity and OpenStack service health"
            ))
        }

        // Check success rates
        if let successMetrics = aggregatedMetrics["api_call_success_rate"],
           successMetrics.average < 0.95 {
            issues.append(TelemetryHealthIssue(
                severity: .medium,
                category: .reliability,
                title: "Low API Success Rate",
                description: "API success rate is \(String(format: "%.1f", successMetrics.average * 100))%",
                recommendation: "Review error logs and check OpenStack service status"
            ))
        }

        // Check memory usage
        if let memoryMetrics = aggregatedMetrics["memory_usage"],
           memoryMetrics.average > performanceTargets.maxMemoryUsageMB {
            issues.append(TelemetryHealthIssue(
                severity: .medium,
                category: .resource,
                title: "High Memory Usage",
                description: "Memory usage is \(String(format: "%.1f", memoryMetrics.average))MB",
                recommendation: "Clear caches or restart the application"
            ))
        }

        return issues
    }

    // MARK: - Batch Processing

    private func processMetricsBatch() {
        let batch = metricsBuffer
        metricsBuffer.removeAll()

        // Update recent metrics for UI
        recentMetrics.append(contentsOf: batch.suffix(20))
        if recentMetrics.count > 100 {
            recentMetrics.removeFirst(recentMetrics.count - 100)
        }

        // Aggregate metrics for health calculations
        for metric in batch {
            if aggregatedMetrics[metric.name] == nil {
                aggregatedMetrics[metric.name] = MetricAggregation()
            }
            aggregatedMetrics[metric.name]?.add(value: metric.value, timestamp: metric.timestamp)
        }

        // Clean old metric data
        cleanupOldMetrics()
    }

    private func cleanupOldMetrics() {
        let cutoffTime = Date().addingTimeInterval(-metricRetentionHours * 3600)

        for key in aggregatedMetrics.keys {
            aggregatedMetrics[key]?.cleanup(before: cutoffTime)
        }
    }

    // MARK: - Control Methods

    /// Enable/disable telemetry collection
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            metricsBuffer.removeAll()
        }
    }

    /// Get health history for dashboard charts
    public func getHealthHistory() -> [SystemHealth] {
        return healthHistory
    }

    /// Get aggregated metrics for analysis
    public func getAggregatedMetrics() -> [String: MetricAggregation] {
        return aggregatedMetrics
    }

    /// Reset all telemetry data
    public func reset() {
        metricsBuffer.removeAll()
        recentMetrics.removeAll()
        healthHistory.removeAll()
        aggregatedMetrics.removeAll()

        currentHealth = SystemHealth(
            performanceScore: 100.0,
            reliabilityScore: 100.0,
            efficiencyScore: 100.0
        )
    }
}

// MARK: - Supporting Types

/// Aggregated metric data for efficient health calculations
public class MetricAggregation {
    private var values: [(Double, Date)] = []

    public var count: Int { values.count }
    public var average: Double {
        guard !values.isEmpty else { return 0.0 }
        return values.map(\.0).reduce(0, +) / Double(values.count)
    }
    public var minimum: Double { values.map(\.0).min() ?? 0.0 }
    public var maximum: Double { values.map(\.0).max() ?? 0.0 }

    func add(value: Double, timestamp: Date) {
        values.append((value, timestamp))

        // Keep only recent values for efficiency
        if values.count > 1000 {
            values.removeFirst(values.count - 1000)
        }
    }

    func cleanup(before cutoff: Date) {
        values.removeAll { $0.1 < cutoff }
    }
}

/// Performance targets for health scoring
private struct PerformanceTargets {
    let apiResponseTimeMs: Double = 500.0    // Target API response time
    let maxMemoryUsageMB: Double = 100.0     // Target max memory usage
    let minCacheHitRate: Double = 0.8        // Target cache hit rate
    let minSuccessRate: Double = 0.95        // Target API success rate
}

/// Anomaly detection system for predictive monitoring
private class AnomalyDetector {
    private var baseline: [String: Double] = [:]

    func analyze(health: SystemHealth, metrics: [String: MetricAggregation]) {
        // Simple anomaly detection based on deviation from baseline
        // In a full implementation, this would use more sophisticated algorithms

        updateBaseline(health: health)
    }

    private func updateBaseline(health: SystemHealth) {
        baseline["performance"] = (baseline["performance"] ?? 100.0) * 0.9 + health.performanceScore * 0.1
        baseline["reliability"] = (baseline["reliability"] ?? 100.0) * 0.9 + health.reliabilityScore * 0.1
        baseline["efficiency"] = (baseline["efficiency"] ?? 100.0) * 0.9 + health.efficiencyScore * 0.1
    }
}