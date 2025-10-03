import Foundation

// Use the Alert type from EnterpriseModels, not CircuitBreakerAlert

/// Shared telemetry actor singleton for cross-system telemetry data
public class SharedTelemetryActor {
    public static let shared = TelemetryActor()
}

public actor TelemetryActor {
    private let metricsCollector: MetricsCollector
    private let healthMonitor: SystemHealthMonitor

    public init() {
        self.metricsCollector = MetricsCollector()
        self.healthMonitor = SystemHealthMonitor(metricsCollector: self.metricsCollector)
    }

    public func recordMetric(_ metric: Metric) async {
        await metricsCollector.record(metric)
    }

    public func getHealthScore() async -> HealthScore {
        return await healthMonitor.getCurrentHealthScore()
    }

    public func getActiveAlerts() async -> [Alert] {
        return await healthMonitor.getActiveAlerts()
    }

    public func getMetrics(
        type: MetricType? = nil,
        from: Date? = nil,
        to: Date? = nil
    ) async -> [Metric] {
        return await metricsCollector.getMetrics(type: type, from: from, to: to)
    }
}