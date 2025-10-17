import Foundation

// MARK: - Performance Metrics

/// Calculates and tracks performance metrics for operations
@MainActor
final class PerformanceMetrics {

    /// Metric data for a specific operation type
    struct TypeMetrics: Sendable {
        let operationType: String
        var totalOperations: Int
        var successfulOperations: Int
        var failedOperations: Int
        var cancelledOperations: Int
        var totalDuration: TimeInterval
        var totalBytesTransferred: Int64
        var averageDuration: TimeInterval {
            guard totalOperations > 0 else { return 0 }
            return totalDuration / Double(totalOperations)
        }
        var successRate: Double {
            guard totalOperations > 0 else { return 0 }
            return Double(successfulOperations) / Double(totalOperations)
        }
        var failureRate: Double {
            guard totalOperations > 0 else { return 0 }
            return Double(failedOperations) / Double(totalOperations)
        }
    }

    /// Time-based metrics for trend analysis
    struct TimeSeriesMetrics: Sendable {
        let timeRange: String
        var operationCount: Int
        var successCount: Int
        var failureCount: Int
        var averageDuration: TimeInterval
        var totalBytesTransferred: Int64
    }

    /// Overall performance summary
    struct PerformanceSummary: Sendable {
        var totalOperations: Int
        var successfulOperations: Int
        var failedOperations: Int
        var cancelledOperations: Int
        var queuedOperations: Int
        var runningOperations: Int
        var averageDuration: TimeInterval
        var totalBytesTransferred: Int64
        var averageTransferRate: Double
        var topErrors: [ErrorFrequency]
        var typeMetrics: [TypeMetrics]
        var timeSeriesMetrics: [TimeSeriesMetrics]

        var overallSuccessRate: Double {
            let completed = successfulOperations + failedOperations + cancelledOperations
            guard completed > 0 else { return 0 }
            return Double(successfulOperations) / Double(completed)
        }
    }

    /// Error frequency tracking
    struct ErrorFrequency: Sendable, Identifiable {
        let id = UUID()
        let errorMessage: String
        let count: Int
        let percentage: Double
    }

    /// Calculate comprehensive performance metrics from operations
    func calculate(from operations: [SwiftBackgroundOperation]) -> PerformanceSummary {
        var summary = PerformanceSummary(
            totalOperations: operations.count,
            successfulOperations: 0,
            failedOperations: 0,
            cancelledOperations: 0,
            queuedOperations: 0,
            runningOperations: 0,
            averageDuration: 0,
            totalBytesTransferred: 0,
            averageTransferRate: 0,
            topErrors: [],
            typeMetrics: [],
            timeSeriesMetrics: []
        )

        guard !operations.isEmpty else { return summary }

        // Calculate basic counts and totals
        var totalDuration: TimeInterval = 0
        var completedOpsCount = 0
        var totalTransferRate: Double = 0
        var transferRateCount = 0
        var errorCounts: [String: Int] = [:]

        for operation in operations {
            // Status counts
            switch operation.status {
            case .completed:
                summary.successfulOperations += 1
                completedOpsCount += 1
            case .failed:
                summary.failedOperations += 1
                completedOpsCount += 1
                if let error = operation.error {
                    errorCounts[error, default: 0] += 1
                }
            case .cancelled:
                summary.cancelledOperations += 1
                completedOpsCount += 1
            case .queued:
                summary.queuedOperations += 1
            case .running:
                summary.runningOperations += 1
            }

            // Duration (only for completed operations)
            if !operation.status.isActive {
                totalDuration += operation.elapsedTime
            }

            // Bytes transferred
            summary.totalBytesTransferred += operation.bytesTransferred

            // Transfer rate (only for running operations with data)
            if operation.status == .running && operation.transferRate > 0 {
                totalTransferRate += operation.transferRate
                transferRateCount += 1
            }
        }

        // Calculate averages
        if completedOpsCount > 0 {
            summary.averageDuration = totalDuration / Double(completedOpsCount)
        }

        if transferRateCount > 0 {
            summary.averageTransferRate = totalTransferRate / Double(transferRateCount)
        }

        // Calculate per-type metrics
        summary.typeMetrics = calculateTypeMetrics(from: operations)

        // Calculate time series metrics
        summary.timeSeriesMetrics = calculateTimeSeriesMetrics(from: operations)

        // Top errors
        summary.topErrors = calculateTopErrors(from: errorCounts, totalErrors: summary.failedOperations)

        return summary
    }

    // MARK: - Type Metrics

    /// Calculate metrics grouped by operation type
    private func calculateTypeMetrics(from operations: [SwiftBackgroundOperation]) -> [TypeMetrics] {
        var metricsDict: [String: TypeMetrics] = [:]

        for operation in operations {
            let typeName = operation.type.displayName

            if metricsDict[typeName] == nil {
                metricsDict[typeName] = TypeMetrics(
                    operationType: typeName,
                    totalOperations: 0,
                    successfulOperations: 0,
                    failedOperations: 0,
                    cancelledOperations: 0,
                    totalDuration: 0,
                    totalBytesTransferred: 0
                )
            }

            metricsDict[typeName]?.totalOperations += 1

            switch operation.status {
            case .completed:
                metricsDict[typeName]?.successfulOperations += 1
            case .failed:
                metricsDict[typeName]?.failedOperations += 1
            case .cancelled:
                metricsDict[typeName]?.cancelledOperations += 1
            default:
                break
            }

            // Only include duration for completed operations
            if !operation.status.isActive {
                metricsDict[typeName]?.totalDuration += operation.elapsedTime
            }

            metricsDict[typeName]?.totalBytesTransferred += operation.bytesTransferred
        }

        return Array(metricsDict.values).sorted { $0.totalOperations > $1.totalOperations }
    }

    // MARK: - Time Series Metrics

    /// Calculate metrics over time periods
    private func calculateTimeSeriesMetrics(from operations: [SwiftBackgroundOperation]) -> [TimeSeriesMetrics] {
        let now = Date()
        let calendar = Calendar.current

        // Define time ranges
        let timeRanges: [(String, Date)] = [
            ("Last Hour", calendar.date(byAdding: .hour, value: -1, to: now)!),
            ("Last 6 Hours", calendar.date(byAdding: .hour, value: -6, to: now)!),
            ("Last 24 Hours", calendar.date(byAdding: .day, value: -1, to: now)!),
            ("Last 7 Days", calendar.date(byAdding: .day, value: -7, to: now)!),
            ("Last 30 Days", calendar.date(byAdding: .day, value: -30, to: now)!)
        ]

        var metrics: [TimeSeriesMetrics] = []

        for (rangeName, startDate) in timeRanges {
            let rangeOps = operations.filter { $0.startTime >= startDate }

            var successCount = 0
            var failureCount = 0
            var totalDuration: TimeInterval = 0
            var completedCount = 0
            var totalBytes: Int64 = 0

            for op in rangeOps {
                if op.status == .completed {
                    successCount += 1
                }
                if op.status == .failed {
                    failureCount += 1
                }

                if !op.status.isActive {
                    totalDuration += op.elapsedTime
                    completedCount += 1
                }

                totalBytes += op.bytesTransferred
            }

            let avgDuration = completedCount > 0 ? totalDuration / Double(completedCount) : 0

            metrics.append(TimeSeriesMetrics(
                timeRange: rangeName,
                operationCount: rangeOps.count,
                successCount: successCount,
                failureCount: failureCount,
                averageDuration: avgDuration,
                totalBytesTransferred: totalBytes
            ))
        }

        return metrics
    }

    // MARK: - Error Analysis

    /// Calculate top errors by frequency
    private func calculateTopErrors(from errorCounts: [String: Int], totalErrors: Int) -> [ErrorFrequency] {
        guard totalErrors > 0 else { return [] }

        return errorCounts.map { error, count in
            ErrorFrequency(
                errorMessage: error,
                count: count,
                percentage: Double(count) / Double(totalErrors) * 100
            )
        }
        .sorted { $0.count > $1.count }
        .prefix(10)
        .map { $0 }
    }

    // MARK: - Resource Utilization

    /// Calculate resource utilization metrics
    func calculateResourceUtilization(from operations: [SwiftBackgroundOperation]) -> ResourceUtilization {
        var containerUsage: [String: Int] = [:]
        var resourceTypeUsage: [String: Int] = [:]

        for operation in operations {
            // Container usage
            if !operation.containerName.isEmpty {
                containerUsage[operation.containerName, default: 0] += 1
            }

            // Resource type usage
            if let resourceType = operation.resourceType {
                resourceTypeUsage[resourceType, default: 0] += 1
            }
        }

        let topContainers = containerUsage.sorted { $0.value > $1.value }.prefix(10).map {
            ResourceUsageItem(name: $0.key, count: $0.value)
        }

        let topResourceTypes = resourceTypeUsage.sorted { $0.value > $1.value }.prefix(10).map {
            ResourceUsageItem(name: $0.key, count: $0.value)
        }

        return ResourceUtilization(
            topContainers: topContainers,
            topResourceTypes: topResourceTypes
        )
    }

    /// Resource utilization summary
    struct ResourceUtilization: Sendable {
        let topContainers: [ResourceUsageItem]
        let topResourceTypes: [ResourceUsageItem]
    }

    /// Resource usage item
    struct ResourceUsageItem: Sendable, Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }

    // MARK: - Formatting Helpers

    /// Format duration as human-readable string
    nonisolated func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    /// Format bytes as human-readable string
    nonisolated func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.2f KB", kb)
        }

        let mb = kb / 1024
        if mb < 1024 {
            return String(format: "%.2f MB", mb)
        }

        let gb = mb / 1024
        return String(format: "%.2f GB", gb)
    }

    /// Format transfer rate
    nonisolated func formatTransferRate(_ rate: Double) -> String {
        if rate < 1 {
            return String(format: "%.2f KB/s", rate * 1024)
        }
        return String(format: "%.2f MB/s", rate)
    }

    /// Format percentage
    nonisolated func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value * 100)
    }
}
