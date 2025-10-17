import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import SwiftTUI

// MARK: - Performance Metrics View

/// View for displaying operation performance metrics and analytics
struct PerformanceMetricsView {

    /// Draw performance metrics view
    /// - Parameters:
    ///   - screen: The ncurses screen pointer
    ///   - startRow: Starting row position
    ///   - startCol: Starting column position
    ///   - width: View width
    ///   - height: View height
    ///   - summary: Performance summary data
    ///   - scrollOffset: Current scroll offset
    @MainActor
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        summary: PerformanceMetrics.PerformanceSummary,
        scrollOffset: Int
    ) async {
        guard let screen = screen else { return }

        // Defensive bounds checking
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let metricsCalculator = PerformanceMetrics()

        // Build sections
        let sections = buildSections(summary: summary, metricsCalculator: metricsCalculator)

        let detailView = DetailView(
            title: "Performance Metrics",
            sections: sections,
            helpText: "UP/DOWN: Scroll | ESC: Return to operations",
            scrollOffset: scrollOffset
        )

        await detailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height
        )
    }

    // MARK: - Section Builders

    /// Build all sections for the performance metrics view
    private static func buildSections(
        summary: PerformanceMetrics.PerformanceSummary,
        metricsCalculator: PerformanceMetrics
    ) -> [DetailSection] {
        var sections: [DetailSection] = []

        // Overall Summary
        if let overallSection = buildOverallSection(summary: summary, metricsCalculator: metricsCalculator) {
            sections.append(overallSection)
        }

        // Operation Type Breakdown
        if let typeSection = buildTypeMetricsSection(summary: summary, metricsCalculator: metricsCalculator) {
            sections.append(typeSection)
        }

        // Time Series Analysis
        if let timeSeriesSection = buildTimeSeriesSection(summary: summary, metricsCalculator: metricsCalculator) {
            sections.append(timeSeriesSection)
        }

        // Error Analysis
        if let errorSection = buildErrorSection(summary: summary) {
            sections.append(errorSection)
        }

        return sections
    }

    /// Build overall summary section
    private static func buildOverallSection(
        summary: PerformanceMetrics.PerformanceSummary,
        metricsCalculator: PerformanceMetrics
    ) -> DetailSection? {
        var items: [DetailItem] = []

        items.append(.field(
            label: "Total Operations",
            value: String(summary.totalOperations),
            style: .primary
        ))

        items.append(.field(
            label: "Successful",
            value: "\(summary.successfulOperations) (\(metricsCalculator.formatPercentage(summary.overallSuccessRate)))",
            style: .success
        ))

        items.append(.field(
            label: "Failed",
            value: String(summary.failedOperations),
            style: summary.failedOperations > 0 ? .error : .secondary
        ))

        items.append(.field(
            label: "Cancelled",
            value: String(summary.cancelledOperations),
            style: .secondary
        ))

        items.append(.spacer)

        items.append(.field(
            label: "Currently Running",
            value: String(summary.runningOperations),
            style: .info
        ))

        items.append(.field(
            label: "Queued",
            value: String(summary.queuedOperations),
            style: .accent
        ))

        items.append(.spacer)

        items.append(.field(
            label: "Average Duration",
            value: metricsCalculator.formatDuration(summary.averageDuration),
            style: .secondary
        ))

        items.append(.field(
            label: "Total Data Transferred",
            value: metricsCalculator.formatBytes(summary.totalBytesTransferred),
            style: .secondary
        ))

        if summary.averageTransferRate > 0 {
            items.append(.field(
                label: "Average Transfer Rate",
                value: metricsCalculator.formatTransferRate(summary.averageTransferRate),
                style: .secondary
            ))
        }

        return DetailSection(title: "Overall Summary", items: items, titleStyle: .accent)
    }

    /// Build operation type metrics section
    private static func buildTypeMetricsSection(
        summary: PerformanceMetrics.PerformanceSummary,
        metricsCalculator: PerformanceMetrics
    ) -> DetailSection? {
        guard !summary.typeMetrics.isEmpty else { return nil }

        var items: [DetailItem] = []

        for typeMetric in summary.typeMetrics {
            items.append(.field(
                label: typeMetric.operationType,
                value: "",
                style: .primary
            ))

            items.append(.field(
                label: "  Total",
                value: String(typeMetric.totalOperations),
                style: .secondary
            ))

            items.append(.field(
                label: "  Success Rate",
                value: metricsCalculator.formatPercentage(typeMetric.successRate),
                style: typeMetric.successRate > 0.9 ? .success : (typeMetric.successRate > 0.7 ? .secondary : .error)
            ))

            items.append(.field(
                label: "  Avg Duration",
                value: metricsCalculator.formatDuration(typeMetric.averageDuration),
                style: .secondary
            ))

            if typeMetric.totalBytesTransferred > 0 {
                items.append(.field(
                    label: "  Data Transferred",
                    value: metricsCalculator.formatBytes(typeMetric.totalBytesTransferred),
                    style: .secondary
                ))
            }

            items.append(.spacer)
        }

        return DetailSection(title: "Performance by Operation Type", items: items, titleStyle: .accent)
    }

    /// Build time series analysis section
    private static func buildTimeSeriesSection(
        summary: PerformanceMetrics.PerformanceSummary,
        metricsCalculator: PerformanceMetrics
    ) -> DetailSection? {
        guard !summary.timeSeriesMetrics.isEmpty else { return nil }

        var items: [DetailItem] = []

        for tsMetric in summary.timeSeriesMetrics {
            guard tsMetric.operationCount > 0 else { continue }

            items.append(.field(
                label: tsMetric.timeRange,
                value: "",
                style: .primary
            ))

            items.append(.field(
                label: "  Operations",
                value: String(tsMetric.operationCount),
                style: .secondary
            ))

            let successRate = tsMetric.operationCount > 0 ? Double(tsMetric.successCount) / Double(tsMetric.operationCount) : 0
            items.append(.field(
                label: "  Success",
                value: "\(tsMetric.successCount) (\(metricsCalculator.formatPercentage(successRate)))",
                style: .success
            ))

            if tsMetric.failureCount > 0 {
                items.append(.field(
                    label: "  Failed",
                    value: String(tsMetric.failureCount),
                    style: .error
                ))
            }

            items.append(.field(
                label: "  Avg Duration",
                value: metricsCalculator.formatDuration(tsMetric.averageDuration),
                style: .secondary
            ))

            if tsMetric.totalBytesTransferred > 0 {
                items.append(.field(
                    label: "  Data Transferred",
                    value: metricsCalculator.formatBytes(tsMetric.totalBytesTransferred),
                    style: .secondary
                ))
            }

            items.append(.spacer)
        }

        return DetailSection(title: "Trends Over Time", items: items, titleStyle: .accent)
    }

    /// Build error analysis section
    private static func buildErrorSection(
        summary: PerformanceMetrics.PerformanceSummary
    ) -> DetailSection? {
        guard !summary.topErrors.isEmpty else { return nil }

        var items: [DetailItem] = []

        items.append(.field(
            label: "Top Errors",
            value: "(\(summary.failedOperations) total failures)",
            style: .error
        ))

        items.append(.spacer)

        for (index, error) in summary.topErrors.prefix(5).enumerated() {
            let errorPreview = String(error.errorMessage.prefix(60))
            items.append(.field(
                label: "\(index + 1).",
                value: errorPreview,
                style: .error
            ))

            items.append(.field(
                label: "   ",
                value: "Count: \(error.count) (\(String(format: "%.1f", error.percentage))%)",
                style: .secondary
            ))

            items.append(.spacer)
        }

        return DetailSection(title: "Error Analysis", items: items, titleStyle: .accent)
    }
}
