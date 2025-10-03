import Foundation

public actor MetricsCollector {
    private var metrics: [MetricType: [Metric]] = [:]
    private let maxMetricsPerType: Int = 10000

    public init() {}

    public func record(_ metric: Metric) async {
        if metrics[metric.type] == nil {
            metrics[metric.type] = []
        }

        metrics[metric.type]?.append(metric)

        if let count = metrics[metric.type]?.count, count > maxMetricsPerType {
            let half = maxMetricsPerType / 2
            metrics[metric.type] = Array(metrics[metric.type]?.suffix(half) ?? [])
        }
    }

    public func getMetrics(
        type: MetricType? = nil,
        from: Date? = nil,
        to: Date? = nil
    ) -> [Metric] {
        var result: [Metric] = []

        let typesToQuery = type != nil ? [type!] : Array(metrics.keys)

        for metricType in typesToQuery {
            guard let typeMetrics = metrics[metricType] else { continue }

            let filteredMetrics = typeMetrics.filter { metric in
                if let from = from, metric.timestamp < from { return false }
                if let to = to, metric.timestamp > to { return false }
                return true
            }

            result.append(contentsOf: filteredMetrics)
        }

        return result.sorted { $0.timestamp < $1.timestamp }
    }

    public func getAverageValue(
        for type: MetricType,
        from: Date? = nil,
        to: Date? = nil
    ) -> Double? {
        let filteredMetrics = getMetrics(type: type, from: from, to: to)
        guard !filteredMetrics.isEmpty else { return nil }

        let sum = filteredMetrics.reduce(0) { $0 + $1.value }
        return sum / Double(filteredMetrics.count)
    }
}