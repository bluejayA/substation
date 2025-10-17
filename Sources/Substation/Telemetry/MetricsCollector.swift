import Foundation
import SwiftNCurses
import CrossPlatformTimer

// MARK: - Metrics Collection Framework

/// High-performance metrics collector with minimal overhead
@MainActor
public final class MetricsCollector: Sendable {

    // MARK: - Collection Categories

    public enum MetricCategory: String, CaseIterable {
        case performance = "performance"
        case userBehavior = "user_behavior"
        case resourceUsage = "resource_usage"
        case openStackHealth = "openstack_health"
        case caching = "caching"
        case networking = "networking"
    }

    // MARK: - Properties

    private let telemetryManager: TelemetryManager
    private var collectionTimers: [String: AnyObject] = [:]
    private var sessionMetrics: TelemetrySessionMetrics
    private var resourceMetrics: ResourceMetrics

    // Performance tracking
    private var operationStartTimes: [String: Date] = [:]
    private var featureUsageCount: [String: Int] = [:]
    private var errorCounts: [String: Int] = [:]

    // MARK: - Initialization

    public init(telemetryManager: TelemetryManager) {
        self.telemetryManager = telemetryManager
        self.sessionMetrics = TelemetrySessionMetrics()
        self.resourceMetrics = ResourceMetrics()

        startAutomaticCollection()
    }

    // Timers will be automatically invalidated when the object is deallocated

    // MARK: - Performance Metrics

    /// Start timing an operation
    public func startOperation(_ operationId: String) {
        operationStartTimes[operationId] = Date()
    }

    /// End timing an operation and record metrics
    public func endOperation(_ operationId: String, success: Bool = true, context: [String: String] = [:]) {
        guard let startTime = operationStartTimes.removeValue(forKey: operationId) else { return }

        let duration = Date().timeIntervalSince(startTime)
        var finalContext = context
        finalContext["operation"] = operationId
        finalContext["success"] = String(success)

        telemetryManager.recordMetric(
            name: "operation_duration",
            value: duration * 1000,
            unit: "ms",
            context: finalContext
        )

        // Track operation success rates
        telemetryManager.recordMetric(
            name: "operation_success_rate",
            value: success ? 1.0 : 0.0,
            context: finalContext
        )
    }

    /// Record UI rendering performance
    public func recordUIPerformance(viewName: String, renderTime: TimeInterval, itemCount: Int? = nil) {
        var context = ["view": viewName]
        if let count = itemCount {
            context["item_count"] = String(count)
        }

        telemetryManager.recordMetric(
            name: "ui_render_time",
            value: renderTime * 1000,
            unit: "ms",
            context: context
        )
    }

    /// Record pagination performance
    public func recordPaginationMetrics(totalItems: Int, pageSize: Int, loadTime: TimeInterval) {
        let context = [
            "total_items": String(totalItems),
            "page_size": String(pageSize)
        ]

        telemetryManager.recordMetric(name: "pagination_load_time", value: loadTime * 1000, unit: "ms", context: context)
        telemetryManager.recordMetric(name: "pagination_efficiency", value: Double(pageSize) / loadTime, unit: "items/sec", context: context)
    }

    // MARK: - User Behavior Tracking

    /// Track feature usage
    public func recordFeatureUsage(_ featureName: String, context: [String: String] = [:]) {
        featureUsageCount[featureName, default: 0] += 1

        var finalContext = context
        finalContext["feature"] = featureName
        finalContext["usage_count"] = String(featureUsageCount[featureName] ?? 0)

        telemetryManager.recordMetric(
            name: "feature_usage",
            value: 1.0,
            context: finalContext
        )
    }

    /// Track view transitions
    public func recordViewTransition(from: String, to: String, duration: TimeInterval? = nil) {
        let context = ["from_view": from, "to_view": to]

        telemetryManager.recordMetric(
            name: "view_transition",
            value: 1.0,
            context: context
        )

        if let duration = duration {
            telemetryManager.recordMetric(
                name: "view_transition_time",
                value: duration * 1000,
                unit: "ms",
                context: context
            )
        }
    }

    /// Track user workflow patterns
    public func recordWorkflowStep(workflow: String, step: String, stepIndex: Int, success: Bool = true) {
        let context = [
            "workflow": workflow,
            "step": step,
            "step_index": String(stepIndex),
            "success": String(success)
        ]

        telemetryManager.recordMetric(
            name: "workflow_step",
            value: success ? 1.0 : 0.0,
            context: context
        )
    }

    /// Track error occurrences
    public func recordError(_ error: any Error, category: String, context: [String: String] = [:]) {
        let errorKey = "\(category).\(type(of: error))"
        errorCounts[errorKey, default: 0] += 1

        var finalContext = context
        finalContext["error_category"] = category
        finalContext["error_type"] = String(describing: type(of: error))
        finalContext["error_count"] = String(errorCounts[errorKey] ?? 0)

        telemetryManager.recordMetric(
            name: "error_occurrence",
            value: 1.0,
            context: finalContext
        )
    }

    // MARK: - OpenStack Health Metrics

    /// Record OpenStack service performance
    public func recordOpenStackService(service: String, endpoint: String, responseTime: TimeInterval, success: Bool, statusCode: Int? = nil) {
        var context = [
            "service": service,
            "endpoint": endpoint,
            "success": String(success)
        ]
        if let code = statusCode {
            context["status_code"] = String(code)
        }

        telemetryManager.recordMetric(
            name: "openstack_service_response_time",
            value: responseTime * 1000,
            unit: "ms",
            context: context
        )

        telemetryManager.recordMetric(
            name: "openstack_service_availability",
            value: success ? 1.0 : 0.0,
            context: context
        )
    }

    /// Record OpenStack quota usage
    public func recordQuotaUsage(resource: String, used: Int, total: Int, project: String? = nil) {
        let utilizationRate = total > 0 ? Double(used) / Double(total) : 0.0

        var context = ["resource": resource]
        if let project = project {
            context["project"] = project
        }

        telemetryManager.recordMetric(
            name: "quota_utilization",
            value: utilizationRate * 100,
            unit: "%",
            context: context
        )

        telemetryManager.recordMetric(
            name: "quota_usage_absolute",
            value: Double(used),
            unit: "units",
            context: context
        )
    }

    /// Record resource efficiency metrics
    public func recordResourceEfficiency(resourceType: String, activeCount: Int, totalCount: Int) {
        let efficiency = totalCount > 0 ? Double(activeCount) / Double(totalCount) : 0.0

        let context = ["resource_type": resourceType]

        telemetryManager.recordMetric(
            name: "resource_efficiency",
            value: efficiency * 100,
            unit: "%",
            context: context
        )
    }

    // MARK: - Cache Performance

    /// Record detailed cache metrics
    public func recordCachePerformance(cacheName: String, operation: String, hit: Bool, duration: TimeInterval? = nil) {
        var context = ["cache_name": cacheName, "operation": operation]

        telemetryManager.recordMetric(
            name: "cache_hit_rate",
            value: hit ? 1.0 : 0.0,
            context: context
        )

        if let duration = duration {
            context["hit_type"] = hit ? "hit" : "miss"
            telemetryManager.recordMetric(
                name: "cache_operation_time",
                value: duration * 1000,
                unit: "ms",
                context: context
            )
        }
    }

    /// Record cache optimization impact
    public func recordCacheOptimizationImpact(cacheName: String, beforeLatency: TimeInterval, afterLatency: TimeInterval) {
        let improvement = ((beforeLatency - afterLatency) / beforeLatency) * 100
        let context = ["cache_name": cacheName]

        telemetryManager.recordMetric(
            name: "cache_optimization_improvement",
            value: improvement,
            unit: "%",
            context: context
        )
    }

    // MARK: - Network Performance

    /// Record network latency and throughput
    public func recordNetworkMetrics(endpoint: String, latency: TimeInterval, bytesTransferred: Int, success: Bool) {
        let context = [
            "endpoint": endpoint,
            "success": String(success)
        ]

        telemetryManager.recordMetric(
            name: "network_latency",
            value: latency * 1000,
            unit: "ms",
            context: context
        )

        if bytesTransferred > 0 && latency > 0 {
            let throughput = Double(bytesTransferred) / latency
            telemetryManager.recordMetric(
                name: "network_throughput",
                value: throughput,
                unit: "bytes/sec",
                context: context
            )
        }
    }

    // MARK: - Batch Operation Metrics

    /// Record batch operation performance
    public func recordBatchOperation(operationType: String, itemCount: Int, duration: TimeInterval, successCount: Int) {
        let context = ["operation_type": operationType]
        let successRate = itemCount > 0 ? Double(successCount) / Double(itemCount) : 0.0
        let throughput = duration > 0 ? Double(itemCount) / duration : 0.0

        telemetryManager.recordMetric(name: "batch_operation_duration", value: duration * 1000, unit: "ms", context: context)
        telemetryManager.recordMetric(name: "batch_operation_success_rate", value: successRate * 100, unit: "%", context: context)
        telemetryManager.recordMetric(name: "batch_operation_throughput", value: throughput, unit: "items/sec", context: context)
        telemetryManager.recordMetric(name: "batch_operation_size", value: Double(itemCount), unit: "items", context: context)
    }

    // MARK: - Automatic Collection

    private func startAutomaticCollection() {
        // Collect system resource usage every 30 seconds
        startTimer("resource_collection", interval: 30.0) {
            Task { @MainActor in
                await self.collectResourceMetrics()
            }
        }

        // Collect session metrics every 60 seconds
        startTimer("session_collection", interval: 60.0) {
            Task { @MainActor in
                await self.collectTelemetrySessionMetrics()
            }
        }
    }

    private func startTimer(_ name: String, interval: TimeInterval, action: @escaping @Sendable () -> Void) {
        let timer = createCompatibleTimer(interval: interval, repeats: true, action: {
            Task { @MainActor in
                action()
            }
        })
        collectionTimers[name] = timer
    }

    private func collectResourceMetrics() async {
        // Collect memory usage
        let memoryUsage = getMemoryUsage()
        telemetryManager.recordResourceUsage(memory: memoryUsage)

        // Update session metrics
        sessionMetrics.updateActiveTime()
        resourceMetrics.update()
    }

    private func collectTelemetrySessionMetrics() async {
        let metrics = sessionMetrics.getMetrics()

        telemetryManager.recordMetric(name: "session_duration", value: metrics.totalDuration, unit: "seconds")
        telemetryManager.recordMetric(name: "session_active_time", value: metrics.activeTime, unit: "seconds")
        telemetryManager.recordMetric(name: "session_feature_count", value: Double(featureUsageCount.count), unit: "features")
    }

    nonisolated private func getMemoryUsage() -> Double {
        // Simple memory usage estimation - placeholder for demonstration
        // In a production system, this would use proper system APIs with concurrency safety
        // For now, return a mock value to avoid concurrency issues with mach_task_self_
        return 64.0 // Mock 64MB usage
    }

    // MARK: - Control Methods

    /// Stop all automatic collection
    public func stopAllTimers() {
        for timer in collectionTimers.values {
            invalidateTimer(timer)
        }
        collectionTimers.removeAll()
    }

    /// Get current session metrics
    public func getTelemetrySessionMetrics() -> TelemetrySessionMetrics.Snapshot {
        return sessionMetrics.getMetrics()
    }

    /// Get feature usage statistics
    public func getFeatureUsageStats() -> [String: Int] {
        return featureUsageCount
    }

    /// Get error statistics
    public func getErrorStats() -> [String: Int] {
        return errorCounts
    }

    /// Reset all collected metrics
    public func resetMetrics() {
        operationStartTimes.removeAll()
        featureUsageCount.removeAll()
        errorCounts.removeAll()
        sessionMetrics = TelemetrySessionMetrics()
        resourceMetrics = ResourceMetrics()
    }
}

// MARK: - Supporting Types

/// Session-level metrics tracking
public class TelemetrySessionMetrics {
    private let sessionStart = Date()
    private var lastActivityTime = Date()
    private var totalActiveTime: TimeInterval = 0
    private var lastActiveTimeUpdate = Date()

    public struct Snapshot {
        public let totalDuration: TimeInterval
        public let activeTime: TimeInterval
        public let sessionStart: Date
        public let lastActivity: Date
    }

    func updateActiveTime() {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastActiveTimeUpdate)

        // Only count as active time if less than 5 minutes since last activity
        if timeSinceLastUpdate < 300 {
            totalActiveTime += timeSinceLastUpdate
        }

        lastActiveTimeUpdate = now
        lastActivityTime = now
    }

    func getMetrics() -> Snapshot {
        let now = Date()
        return Snapshot(
            totalDuration: now.timeIntervalSince(sessionStart),
            activeTime: totalActiveTime,
            sessionStart: sessionStart,
            lastActivity: lastActivityTime
        )
    }
}

/// System resource metrics tracking
public class ResourceMetrics {
    private var previousMemoryUsage: Double = 0
    private var memoryTrend: TrendDirection = .stable

    public enum TrendDirection {
        case increasing, decreasing, stable
    }

    func update() {
        // Update memory trend analysis
        let currentMemory = getCurrentMemoryUsage()
        if currentMemory > previousMemoryUsage * 1.1 {
            memoryTrend = .increasing
        } else if currentMemory < previousMemoryUsage * 0.9 {
            memoryTrend = .decreasing
        } else {
            memoryTrend = .stable
        }

        previousMemoryUsage = currentMemory
    }

    private func getCurrentMemoryUsage() -> Double {
        // This would be implemented with actual system calls
        return 50.0 // Placeholder
    }

    public func getMemoryTrend() -> TrendDirection {
        return memoryTrend
    }
}