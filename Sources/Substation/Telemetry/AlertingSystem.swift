import Foundation
import SwiftNCurses
import CrossPlatformTimer

// MARK: - Alerting System Types

/// Smart alerting and notification system with optimization recommendations
@MainActor
public final class AlertingSystem: Sendable {

    // MARK: - Alert Types

    public enum AlertType: String, CaseIterable, Sendable {
        case performance = "performance"
        case reliability = "reliability"
        case resource = "resource"
        case optimization = "optimization"
        case predictive = "predictive"
        case security = "security"
    }

    public enum AlertPriority: Int, CaseIterable, Comparable, Sendable {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3

        public static func < (lhs: AlertPriority, rhs: AlertPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Alert Structure

    public struct Alert: Identifiable, Sendable {
        public let id: String
        public let type: AlertType
        public let priority: AlertPriority
        public let title: String
        public let message: String
        public let recommendation: String?
        public let actionable: Bool
        public let timestamp: Date
        public let expiresAt: Date?
        public let context: [String: String]

        public init(type: AlertType, priority: AlertPriority, title: String, message: String,
                   recommendation: String? = nil, actionable: Bool = false,
                   ttl: TimeInterval? = nil, context: [String: String] = [:]) {
            self.id = UUID().uuidString.prefix(8).uppercased()
            self.type = type
            self.priority = priority
            self.title = title
            self.message = message
            self.recommendation = recommendation
            self.actionable = actionable
            self.timestamp = Date()
            self.expiresAt = ttl.map { Date().addingTimeInterval($0) }
            self.context = context
        }
    }

    // MARK: - Properties

    public private(set) var activeAlerts: [Alert] = []
    public private(set) var alertHistory: [Alert] = []
    public private(set) var optimizationSuggestions: [OptimizationSuggestion] = []

    private let telemetryManager: TelemetryManager
    private let metricsCollector: MetricsCollector
    private var alertRules: [AlertRule] = []
    private var alertingTimer: AnyObject?
    private var lastAlertCheck = Date()

    // Configuration
    private let maxActiveAlerts = 10
    private let alertCheckInterval: TimeInterval = 10.0
    private let alertHistoryRetention: TimeInterval = 3600 * 24 // 24 hours

    // MARK: - Initialization

    public init(telemetryManager: TelemetryManager, metricsCollector: MetricsCollector) {
        self.telemetryManager = telemetryManager
        self.metricsCollector = metricsCollector

        setupDefaultAlertRules()
        startAlertingSystem()
    }

    deinit {
        // Timer cleanup handled by the system
        // alertingTimer?.invalidate() - removed due to sendability constraints
    }

    // MARK: - Alert Management

    /// Add a new alert to the system
    public func addAlert(_ alert: Alert) {
        // Check for duplicate alerts
        if activeAlerts.contains(where: { $0.title == alert.title && $0.type == alert.type }) {
            return
        }

        activeAlerts.append(alert)
        alertHistory.append(alert)

        // Sort by priority
        activeAlerts.sort { $0.priority > $1.priority }

        // Maintain limits
        if activeAlerts.count > maxActiveAlerts {
            _ = activeAlerts.removeLast()
            // Log that we had to drop a lower priority alert
        }

        // Clean history
        cleanupAlertHistory()
    }

    /// Remove an alert by ID
    public func dismissAlert(_ alertId: String) {
        activeAlerts.removeAll { $0.id == alertId }
    }

    /// Clear all alerts of a specific type
    public func clearAlerts(ofType type: AlertType) {
        activeAlerts.removeAll { $0.type == type }
    }

    /// Clear all alerts
    public func clearAllAlerts() {
        activeAlerts.removeAll()
    }

    // MARK: - Automatic Alert Generation

    private func startAlertingSystem() {
        alertingTimer = createCompatibleTimer(interval: alertCheckInterval, repeats: true, action: { [weak self] in
            Task { @MainActor in
                self?.checkAlertConditions()
                self?.cleanupExpiredAlerts()
                self?.generateOptimizationSuggestions()
            }
        })
    }

    private func checkAlertConditions() {
        let currentHealth = telemetryManager.currentHealth
        let aggregatedMetrics = telemetryManager.getAggregatedMetrics()

        // Check each alert rule
        for i in alertRules.indices {
            if alertRules[i].shouldTrigger(health: currentHealth, metrics: aggregatedMetrics) {
                let alert = alertRules[i].createAlert(currentHealth, aggregatedMetrics)
                addAlert(alert)
            }
        }

        // Check for predictive issues
        checkPredictiveAlerts(health: currentHealth, metrics: aggregatedMetrics)

        lastAlertCheck = Date()
    }

    private func checkPredictiveAlerts(health: SystemHealth, metrics: [String: MetricAggregation]) {
        // Analyze trends to predict future issues
        for trend in health.trends {
            if trend.direction == .declining {
                let alert = createPredictiveAlert(for: trend)
                addAlert(alert)
            }
        }

        // Check for resource exhaustion predictions
        checkResourceExhaustionPredictions(metrics: metrics)
    }

    private func checkResourceExhaustionPredictions(metrics: [String: MetricAggregation]) {
        // Memory usage trend analysis
        if let memoryMetrics = metrics["memory_usage"] {
            let currentUsage = memoryMetrics.average
            let growthRate = calculateGrowthRate(for: "memory_usage")

            if growthRate > 0 && currentUsage > 70 {
                let timeToExhaustion = (100 - currentUsage) / growthRate * 60 // minutes
                if timeToExhaustion < 30 { // Less than 30 minutes
                    let alert = Alert(
                        type: .predictive,
                        priority: .high,
                        title: "Memory Exhaustion Predicted",
                        message: "Current memory usage trend suggests exhaustion in \(Int(timeToExhaustion)) minutes",
                        recommendation: "Consider restarting the application or clearing caches",
                        actionable: true,
                        context: ["memory_usage": String(format: "%.1f", currentUsage)]
                    )
                    addAlert(alert)
                }
            }
        }
    }

    private func calculateGrowthRate(for metricName: String) -> Double {
        // Simplified growth rate calculation
        // In a real implementation, this would use more sophisticated time series analysis
        return 0.1 // Placeholder
    }

    private func createPredictiveAlert(for trend: SystemHealthTrend) -> Alert {
        let metric = trend.metric
        let direction = trend.direction

        return Alert(
            type: .predictive,
            priority: .medium,
            title: "Declining \(metric.capitalized) Trend Detected",
            message: "The \(metric) metric has been consistently declining over recent measurements",
            recommendation: getRecommendationFor(metric: metric, trend: direction),
            actionable: true,
            ttl: 1800, // 30 minutes
            context: ["metric": metric, "trend": direction.rawValue]
        )
    }

    // MARK: - Optimization Suggestions

    private func generateOptimizationSuggestions() {
        var suggestions: [OptimizationSuggestion] = []

        _ = metricsCollector.getTelemetrySessionMetrics()
        let featureUsage = metricsCollector.getFeatureUsageStats()
        let aggregatedMetrics = telemetryManager.getAggregatedMetrics()

        // Cache optimization suggestions
        suggestions.append(contentsOf: generateCacheOptimizations(metrics: aggregatedMetrics))

        // Performance optimization suggestions
        suggestions.append(contentsOf: generatePerformanceOptimizations(metrics: aggregatedMetrics))

        // User workflow optimization suggestions
        suggestions.append(contentsOf: generateWorkflowOptimizations(featureUsage: featureUsage))

        // Resource optimization suggestions
        suggestions.append(contentsOf: generateResourceOptimizations(metrics: aggregatedMetrics))

        optimizationSuggestions = suggestions
    }

    private func generateCacheOptimizations(metrics: [String: MetricAggregation]) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        if let cacheHitRate = metrics["cache_hit_rate"]?.average, cacheHitRate < 60 {
            suggestions.append(OptimizationSuggestion(
                category: .caching,
                priority: .medium,
                title: "Low Cache Hit Rate",
                description: "Current cache hit rate is \(String(format: "%.1f", cacheHitRate))%",
                recommendation: "Consider increasing cache size or adjusting cache TTL values",
                estimatedImprovement: "Could improve response times by 20-40%",
                actionable: true
            ))
        }

        if let cacheSize = metrics["cache_size"]?.average, cacheSize > 800 {
            suggestions.append(OptimizationSuggestion(
                category: .caching,
                priority: .low,
                title: "Large Cache Size",
                description: "Cache is holding \(Int(cacheSize)) items",
                recommendation: "Consider implementing cache eviction strategies",
                estimatedImprovement: "Could reduce memory usage by 10-20%",
                actionable: false
            ))
        }

        return suggestions
    }

    private func generatePerformanceOptimizations(metrics: [String: MetricAggregation]) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        if let apiDuration = metrics["api_call_duration"]?.average, apiDuration > 1000 {
            suggestions.append(OptimizationSuggestion(
                category: .performance,
                priority: .high,
                title: "Slow API Response Times",
                description: "Average API response time is \(String(format: "%.1f", apiDuration))ms",
                recommendation: "Consider enabling request batching or checking network connectivity",
                estimatedImprovement: "Could improve overall responsiveness by 30-50%",
                actionable: true
            ))
        }

        if let uiRenderTime = metrics["ui_render_time"]?.average, uiRenderTime > 100 {
            suggestions.append(OptimizationSuggestion(
                category: .performance,
                priority: .medium,
                title: "Slow UI Rendering",
                description: "UI rendering is taking \(String(format: "%.1f", uiRenderTime))ms on average",
                recommendation: "Consider enabling list virtualization for large datasets",
                estimatedImprovement: "Could improve UI responsiveness by 20-30%",
                actionable: true
            ))
        }

        return suggestions
    }

    private func generateWorkflowOptimizations(featureUsage: [String: Int]) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        // Find most used features
        let sortedFeatures = featureUsage.sorted { $0.value > $1.value }
        let topFeatures = Array(sortedFeatures.prefix(3))

        if topFeatures.count >= 2 {
            suggestions.append(OptimizationSuggestion(
                category: .workflow,
                priority: .low,
                title: "Frequent Feature Usage Detected",
                description: "You frequently use: \(topFeatures.map { $0.key }.joined(separator: ", "))",
                recommendation: "Consider creating custom shortcuts or workflows for these operations",
                estimatedImprovement: "Could save 15-30% of interaction time",
                actionable: false
            ))
        }

        return suggestions
    }

    private func generateResourceOptimizations(metrics: [String: MetricAggregation]) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        if let memoryUsage = metrics["memory_usage"]?.average, memoryUsage > 80 {
            suggestions.append(OptimizationSuggestion(
                category: .resource,
                priority: .medium,
                title: "High Memory Usage",
                description: "Application is using \(String(format: "%.1f", memoryUsage))MB of memory",
                recommendation: "Consider clearing caches or restarting the application periodically",
                estimatedImprovement: "Could free up 20-40MB of memory",
                actionable: true
            ))
        }

        return suggestions
    }

    // MARK: - Alert Rules System

    private func setupDefaultAlertRules() {
        // Performance alert rules
        alertRules.append(AlertRule(
            name: "slow_api_response",
            condition: { health, metrics in
                guard let apiMetrics = metrics["api_call_duration"] else { return false }
                return apiMetrics.average > 2000 // 2 seconds
            },
            createAlert: { health, metrics in
                let avgDuration = metrics["api_call_duration"]?.average ?? 0
                return Alert(
                    type: .performance,
                    priority: .high,
                    title: "Very Slow API Responses",
                    message: "API responses are averaging \(String(format: "%.1f", avgDuration))ms",
                    recommendation: "Check network connectivity and OpenStack service health",
                    actionable: true,
                    ttl: 300,
                    context: ["avg_duration": String(avgDuration)]
                )
            }
        ))

        // Reliability alert rules
        alertRules.append(AlertRule(
            name: "low_success_rate",
            condition: { health, metrics in
                guard let successMetrics = metrics["api_call_success_rate"] else { return false }
                return successMetrics.average < 0.9
            },
            createAlert: { health, metrics in
                let successRate = metrics["api_call_success_rate"]?.average ?? 0
                return Alert(
                    type: .reliability,
                    priority: .high,
                    title: "Low API Success Rate",
                    message: "API success rate has dropped to \(String(format: "%.1f", successRate * 100))%",
                    recommendation: "Check error logs and OpenStack service status",
                    actionable: true,
                    ttl: 600,
                    context: ["success_rate": String(successRate)]
                )
            }
        ))

        // Resource alert rules
        alertRules.append(AlertRule(
            name: "high_memory_usage",
            condition: { health, metrics in
                guard let memoryMetrics = metrics["memory_usage"] else { return false }
                return memoryMetrics.average > 100
            },
            createAlert: { health, metrics in
                let memoryUsage = metrics["memory_usage"]?.average ?? 0
                return Alert(
                    type: .resource,
                    priority: .medium,
                    title: "High Memory Usage",
                    message: "Application is using \(String(format: "%.1f", memoryUsage))MB of memory",
                    recommendation: "Consider clearing caches or restarting",
                    actionable: true,
                    ttl: 900,
                    context: ["memory_usage": String(memoryUsage)]
                )
            }
        ))
    }

    // MARK: - Cleanup and Maintenance

    private func cleanupExpiredAlerts() {
        let now = Date()
        activeAlerts.removeAll { alert in
            if let expiresAt = alert.expiresAt {
                return now > expiresAt
            }
            return false
        }
    }

    private func cleanupAlertHistory() {
        let cutoff = Date().addingTimeInterval(-alertHistoryRetention)
        alertHistory.removeAll { $0.timestamp < cutoff }

        // Keep maximum of 100 entries
        if alertHistory.count > 100 {
            alertHistory.removeFirst(alertHistory.count - 100)
        }
    }

    // MARK: - Utility Methods

    private func getRecommendationFor(metric: String, trend: SystemHealthTrend.TrendDirection) -> String {
        switch metric {
        case "performance":
            return "Monitor API response times and consider optimizing frequently used operations"
        case "reliability":
            return "Review error logs and check OpenStack service connectivity"
        case "efficiency":
            return "Analyze cache performance and resource utilization patterns"
        default:
            return "Review system performance metrics and consider optimization opportunities"
        }
    }

    // MARK: - Query Methods

    /// Get alerts by type
    public func getAlerts(ofType type: AlertType) -> [Alert] {
        return activeAlerts.filter { $0.type == type }
    }

    /// Get alerts by priority
    public func getAlerts(withPriority priority: AlertPriority) -> [Alert] {
        return activeAlerts.filter { $0.priority == priority }
    }

    /// Get actionable alerts
    public func getActionableAlerts() -> [Alert] {
        return activeAlerts.filter { $0.actionable }
    }

    /// Get alert statistics
    public func getAlertStatistics() -> AlertStatistics {
        return AlertStatistics(
            totalActive: activeAlerts.count,
            criticalCount: activeAlerts.filter { $0.priority == .critical }.count,
            highCount: activeAlerts.filter { $0.priority == .high }.count,
            mediumCount: activeAlerts.filter { $0.priority == .medium }.count,
            lowCount: activeAlerts.filter { $0.priority == .low }.count,
            actionableCount: activeAlerts.filter { $0.actionable }.count,
            totalHistorical: alertHistory.count
        )
    }
}

// MARK: - Supporting Types

/// Alert rule for automatic alert generation
private struct AlertRule {
    let name: String
    let condition: (SystemHealth, [String: MetricAggregation]) -> Bool
    let createAlert: (SystemHealth, [String: MetricAggregation]) -> AlertingSystem.Alert
    private var lastTriggered: Date?

    init(name: String,
         condition: @escaping (SystemHealth, [String: MetricAggregation]) -> Bool,
         createAlert: @escaping (SystemHealth, [String: MetricAggregation]) -> AlertingSystem.Alert) {
        self.name = name
        self.condition = condition
        self.createAlert = createAlert
    }

    mutating func shouldTrigger(health: SystemHealth, metrics: [String: MetricAggregation]) -> Bool {
        // Don't trigger too frequently (at most once per 5 minutes)
        if let last = lastTriggered, Date().timeIntervalSince(last) < 300 {
            return false
        }

        if condition(health, metrics) {
            lastTriggered = Date()
            return true
        }

        return false
    }
}

/// Optimization suggestion structure
public struct OptimizationSuggestion: Identifiable {
    public let id = UUID()
    public let category: OptimizationCategory
    public let priority: AlertingSystem.AlertPriority
    public let title: String
    public let description: String
    public let recommendation: String
    public let estimatedImprovement: String
    public let actionable: Bool

    public enum OptimizationCategory: String, CaseIterable {
        case performance = "performance"
        case caching = "caching"
        case resource = "resource"
        case workflow = "workflow"
        case configuration = "configuration"
    }
}

/// Alert statistics summary
public struct AlertStatistics {
    public let totalActive: Int
    public let criticalCount: Int
    public let highCount: Int
    public let mediumCount: Int
    public let lowCount: Int
    public let actionableCount: Int
    public let totalHistorical: Int

    public var highestPriority: AlertingSystem.AlertPriority? {
        if criticalCount > 0 { return .critical }
        if highCount > 0 { return .high }
        if mediumCount > 0 { return .medium }
        if lowCount > 0 { return .low }
        return nil
    }
}