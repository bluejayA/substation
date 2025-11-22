// Sources/Substation/Modules/Core/ModulePerformanceMetrics.swift
import Foundation

/// Individual timing record for an operation
struct TimingRecord: Sendable {
    /// Name of the operation
    let operation: String
    /// Duration in seconds
    let duration: TimeInterval
    /// Timestamp of the operation
    let timestamp: Date
    /// Additional context
    let context: [String: String]
}

/// Cache performance metrics
struct CacheMetrics: Sendable {
    /// Module identifier
    let moduleId: String
    /// Total cache hits
    let hits: Int
    /// Total cache misses
    let misses: Int
    /// Cache size in bytes
    let sizeBytes: Int
    /// Maximum allowed size in bytes
    let maxSizeBytes: Int
    /// Number of entries
    let entryCount: Int

    /// Calculate hit rate percentage
    var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0.0 }
        return (Double(hits) / Double(total)) * 100.0
    }

    /// Calculate cache utilization percentage
    var utilization: Double {
        guard maxSizeBytes > 0 else { return 0.0 }
        return (Double(sizeBytes) / Double(maxSizeBytes)) * 100.0
    }
}

/// Module performance summary
struct ModulePerformanceSummary: Sendable {
    /// Module identifier
    let moduleId: String
    /// Total load time in milliseconds
    let loadTimeMs: Double
    /// Average operation time in milliseconds
    let avgOperationTimeMs: Double
    /// Number of operations performed
    let operationCount: Int
    /// Memory usage in bytes
    let memoryBytes: Int
    /// Cache metrics if available
    let cacheMetrics: CacheMetrics?
    /// Timestamp of summary
    let timestamp: Date
}

/// Aggregate performance report for module system
struct ModulePerformanceReport: Sendable {
    /// Total startup time in milliseconds
    let startupTimeMs: Double
    /// Module load times in milliseconds
    let moduleLoadTimes: [String: Double]
    /// Registry lookup statistics
    let registryLookups: RegistryLookupStats
    /// Cache statistics across all modules
    let cacheStats: AggregateCacheStats
    /// Total memory usage in bytes
    let totalMemoryBytes: Int
    /// Report generation timestamp
    let generatedAt: Date
}

/// Registry lookup statistics
struct RegistryLookupStats: Sendable {
    /// Total view lookups
    let viewLookups: Int
    /// Total form lookups
    let formLookups: Int
    /// Total action lookups
    let actionLookups: Int
    /// Average lookup time in microseconds
    let avgLookupTimeUs: Double
}

/// Aggregate cache statistics
struct AggregateCacheStats: Sendable {
    /// Total cache hits
    let totalHits: Int
    /// Total cache misses
    let totalMisses: Int
    /// Total cache size in bytes
    let totalSizeBytes: Int
    /// Number of modules with caching
    let modulesWithCache: Int
    /// Overall hit rate percentage
    let overallHitRate: Double
}

/// Performance metrics collector and analyzer for the module system
///
/// This class provides:
/// - Module load time tracking
/// - Registry lookup performance
/// - Cache hit/miss metrics per module
/// - Memory usage per module
/// - Diagnostic reporting for health checks
///
/// Example usage:
/// ```swift
/// let metrics = ModulePerformanceMetrics.shared
/// metrics.startTimer("module.load.servers")
/// // ... load module ...
/// metrics.stopTimer("module.load.servers")
/// let report = metrics.generateReport()
/// ```
@MainActor
final class ModulePerformanceMetrics {
    /// Shared singleton instance
    static let shared = ModulePerformanceMetrics()

    // MARK: - Timer Management

    /// Active timers by operation name
    private var activeTimers: [String: Date] = [:]

    /// Completed timing records
    private var timingRecords: [TimingRecord] = []

    /// Maximum number of timing records to keep
    private let maxTimingRecords: Int = 1000

    // MARK: - Module Load Tracking

    /// Module load times in seconds
    private var moduleLoadTimes: [String: TimeInterval] = [:]

    /// Module initialization order
    private var initializationOrder: [String] = []

    /// Total startup time
    private var startupTime: TimeInterval = 0

    // MARK: - Registry Lookup Tracking

    /// View lookup count
    private var viewLookupCount: Int = 0

    /// Form lookup count
    private var formLookupCount: Int = 0

    /// Action lookup count
    private var actionLookupCount: Int = 0

    /// Total lookup time in seconds
    private var totalLookupTime: TimeInterval = 0

    /// Total lookup count
    private var totalLookupCount: Int = 0

    // MARK: - Cache Metrics

    /// Cache metrics per module
    private var cacheMetrics: [String: CacheMetrics] = [:]

    // MARK: - Memory Tracking

    /// Memory usage per module in bytes
    private var moduleMemoryUsage: [String: Int] = [:]

    // MARK: - Initialization

    private init() {
        Logger.shared.logInfo("[ModulePerformanceMetrics] Initialized")
    }

    // MARK: - Timer API

    /// Start a timer for an operation
    ///
    /// - Parameter operation: Unique operation name
    func startTimer(_ operation: String) {
        activeTimers[operation] = Date()
    }

    /// Stop a timer and record the duration
    ///
    /// - Parameters:
    ///   - operation: The operation name
    ///   - context: Optional context dictionary
    /// - Returns: The duration in seconds, or nil if timer wasn't started
    @discardableResult
    func stopTimer(_ operation: String, context: [String: String] = [:]) -> TimeInterval? {
        guard let startTime = activeTimers.removeValue(forKey: operation) else {
            Logger.shared.logWarning("[ModulePerformanceMetrics] Timer not found: \(operation)")
            return nil
        }

        let duration = Date().timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate

        let record = TimingRecord(
            operation: operation,
            duration: duration,
            timestamp: Date(),
            context: context
        )

        timingRecords.append(record)

        // Trim old records if needed
        if timingRecords.count > maxTimingRecords {
            timingRecords.removeFirst(timingRecords.count - maxTimingRecords)
        }

        return duration
    }

    /// Measure an operation and return its result
    ///
    /// - Parameters:
    ///   - operation: Operation name for tracking
    ///   - context: Optional context
    ///   - closure: The operation to measure
    /// - Returns: The result of the operation
    func measure<T>(_ operation: String, context: [String: String] = [:], _ closure: () throws -> T) rethrows -> T {
        startTimer(operation)
        let result = try closure()
        stopTimer(operation, context: context)
        return result
    }

    /// Measure an async operation
    ///
    /// - Parameters:
    ///   - operation: Operation name
    ///   - context: Optional context
    ///   - closure: The async operation to measure
    /// - Returns: The result of the operation
    func measure<T: Sendable>(_ operation: String, context: [String: String] = [:], _ closure: @Sendable () async throws -> T) async rethrows -> T {
        startTimer(operation)
        let result = try await closure()
        stopTimer(operation, context: context)
        return result
    }

    // MARK: - Module Load Tracking

    /// Record module load time
    ///
    /// - Parameters:
    ///   - moduleId: The module identifier
    ///   - duration: Load time in seconds
    func recordModuleLoad(_ moduleId: String, duration: TimeInterval) {
        moduleLoadTimes[moduleId] = duration
        initializationOrder.append(moduleId)

        Logger.shared.logPerformance("module.load.\(moduleId)", duration: duration)
    }

    /// Record total startup time
    ///
    /// - Parameter duration: Total startup time in seconds
    func recordStartupTime(_ duration: TimeInterval) {
        startupTime = duration
        Logger.shared.logPerformance("module.startup.total", duration: duration)
    }

    /// Get module load time
    ///
    /// - Parameter moduleId: The module identifier
    /// - Returns: Load time in seconds or nil
    func getModuleLoadTime(_ moduleId: String) -> TimeInterval? {
        return moduleLoadTimes[moduleId]
    }

    // MARK: - Registry Lookup Tracking

    /// Record a view lookup
    ///
    /// - Parameter duration: Lookup time in seconds
    func recordViewLookup(duration: TimeInterval) {
        viewLookupCount += 1
        totalLookupTime += duration
        totalLookupCount += 1
    }

    /// Record a form lookup
    ///
    /// - Parameter duration: Lookup time in seconds
    func recordFormLookup(duration: TimeInterval) {
        formLookupCount += 1
        totalLookupTime += duration
        totalLookupCount += 1
    }

    /// Record an action lookup
    ///
    /// - Parameter duration: Lookup time in seconds
    func recordActionLookup(duration: TimeInterval) {
        actionLookupCount += 1
        totalLookupTime += duration
        totalLookupCount += 1
    }

    // MARK: - Cache Metrics

    /// Update cache metrics for a module
    ///
    /// - Parameters:
    ///   - moduleId: The module identifier
    ///   - hits: Number of cache hits
    ///   - misses: Number of cache misses
    ///   - sizeBytes: Current cache size
    ///   - maxSizeBytes: Maximum cache size
    ///   - entryCount: Number of cache entries
    func updateCacheMetrics(
        moduleId: String,
        hits: Int,
        misses: Int,
        sizeBytes: Int,
        maxSizeBytes: Int,
        entryCount: Int
    ) {
        cacheMetrics[moduleId] = CacheMetrics(
            moduleId: moduleId,
            hits: hits,
            misses: misses,
            sizeBytes: sizeBytes,
            maxSizeBytes: maxSizeBytes,
            entryCount: entryCount
        )
    }

    /// Increment cache hit for a module
    ///
    /// - Parameter moduleId: The module identifier
    func recordCacheHit(_ moduleId: String) {
        guard let metrics = cacheMetrics[moduleId] else { return }
        cacheMetrics[moduleId] = CacheMetrics(
            moduleId: moduleId,
            hits: metrics.hits + 1,
            misses: metrics.misses,
            sizeBytes: metrics.sizeBytes,
            maxSizeBytes: metrics.maxSizeBytes,
            entryCount: metrics.entryCount
        )
    }

    /// Increment cache miss for a module
    ///
    /// - Parameter moduleId: The module identifier
    func recordCacheMiss(_ moduleId: String) {
        guard let metrics = cacheMetrics[moduleId] else { return }
        cacheMetrics[moduleId] = CacheMetrics(
            moduleId: moduleId,
            hits: metrics.hits,
            misses: metrics.misses + 1,
            sizeBytes: metrics.sizeBytes,
            maxSizeBytes: metrics.maxSizeBytes,
            entryCount: metrics.entryCount
        )
    }

    /// Get cache metrics for a module
    ///
    /// - Parameter moduleId: The module identifier
    /// - Returns: Cache metrics or nil
    func getCacheMetrics(_ moduleId: String) -> CacheMetrics? {
        return cacheMetrics[moduleId]
    }

    // MARK: - Memory Tracking

    /// Update memory usage for a module
    ///
    /// - Parameters:
    ///   - moduleId: The module identifier
    ///   - bytes: Memory usage in bytes
    func updateMemoryUsage(moduleId: String, bytes: Int) {
        moduleMemoryUsage[moduleId] = bytes
    }

    /// Get memory usage for a module
    ///
    /// - Parameter moduleId: The module identifier
    /// - Returns: Memory in bytes or nil
    func getMemoryUsage(_ moduleId: String) -> Int? {
        return moduleMemoryUsage[moduleId]
    }

    /// Get total memory usage across all modules
    ///
    /// - Returns: Total memory in bytes
    func getTotalMemoryUsage() -> Int {
        return moduleMemoryUsage.values.reduce(0, +)
    }

    // MARK: - Performance Summaries

    /// Get performance summary for a module
    ///
    /// - Parameter moduleId: The module identifier
    /// - Returns: Performance summary
    func getModuleSummary(_ moduleId: String) -> ModulePerformanceSummary? {
        guard let loadTime = moduleLoadTimes[moduleId] else { return nil }

        // Calculate average operation time for this module
        let moduleOps = timingRecords.filter { $0.operation.contains(moduleId) }
        let avgOpTime: Double
        if moduleOps.isEmpty {
            avgOpTime = 0
        } else {
            avgOpTime = (moduleOps.map { $0.duration }.reduce(0, +) / Double(moduleOps.count)) * 1000
        }

        return ModulePerformanceSummary(
            moduleId: moduleId,
            loadTimeMs: loadTime * 1000,
            avgOperationTimeMs: avgOpTime,
            operationCount: moduleOps.count,
            memoryBytes: moduleMemoryUsage[moduleId] ?? 0,
            cacheMetrics: cacheMetrics[moduleId],
            timestamp: Date()
        )
    }

    /// Generate a complete performance report
    ///
    /// - Returns: Aggregate performance report
    func generateReport() -> ModulePerformanceReport {
        // Convert load times to milliseconds
        let loadTimesMs = moduleLoadTimes.mapValues { $0 * 1000 }

        // Calculate average lookup time
        let avgLookupUs: Double
        if totalLookupCount > 0 {
            avgLookupUs = (totalLookupTime / Double(totalLookupCount)) * 1_000_000
        } else {
            avgLookupUs = 0
        }

        let registryStats = RegistryLookupStats(
            viewLookups: viewLookupCount,
            formLookups: formLookupCount,
            actionLookups: actionLookupCount,
            avgLookupTimeUs: avgLookupUs
        )

        // Aggregate cache stats
        let totalHits = cacheMetrics.values.map { $0.hits }.reduce(0, +)
        let totalMisses = cacheMetrics.values.map { $0.misses }.reduce(0, +)
        let totalCacheSize = cacheMetrics.values.map { $0.sizeBytes }.reduce(0, +)

        let overallHitRate: Double
        let totalCacheOps = totalHits + totalMisses
        if totalCacheOps > 0 {
            overallHitRate = (Double(totalHits) / Double(totalCacheOps)) * 100.0
        } else {
            overallHitRate = 0
        }

        let cacheStats = AggregateCacheStats(
            totalHits: totalHits,
            totalMisses: totalMisses,
            totalSizeBytes: totalCacheSize,
            modulesWithCache: cacheMetrics.count,
            overallHitRate: overallHitRate
        )

        return ModulePerformanceReport(
            startupTimeMs: startupTime * 1000,
            moduleLoadTimes: loadTimesMs,
            registryLookups: registryStats,
            cacheStats: cacheStats,
            totalMemoryBytes: getTotalMemoryUsage(),
            generatedAt: Date()
        )
    }

    // MARK: - Diagnostics for Health Checks

    /// Get performance metrics formatted for health check
    ///
    /// - Returns: Dictionary of metrics suitable for ModuleHealthStatus
    func getHealthCheckMetrics() -> [String: Any] {
        var metrics: [String: Any] = [:]

        metrics["startup_time_ms"] = startupTime * 1000
        metrics["total_modules"] = moduleLoadTimes.count
        metrics["total_memory_bytes"] = getTotalMemoryUsage()

        // Include slowest modules
        let sortedLoads = moduleLoadTimes.sorted { $0.value > $1.value }
        if let slowest = sortedLoads.first {
            metrics["slowest_module"] = slowest.key
            metrics["slowest_load_ms"] = slowest.value * 1000
        }

        // Cache hit rate
        let totalHits = cacheMetrics.values.map { $0.hits }.reduce(0, +)
        let totalMisses = cacheMetrics.values.map { $0.misses }.reduce(0, +)
        let totalOps = totalHits + totalMisses
        if totalOps > 0 {
            metrics["cache_hit_rate"] = (Double(totalHits) / Double(totalOps)) * 100.0
        }

        // Registry lookups
        metrics["total_lookups"] = totalLookupCount
        if totalLookupCount > 0 {
            metrics["avg_lookup_us"] = (totalLookupTime / Double(totalLookupCount)) * 1_000_000
        }

        return metrics
    }

    /// Log performance summary to the logger
    func logPerformanceSummary() {
        let report = generateReport()

        Logger.shared.logInfo("[ModulePerformanceMetrics] Performance Summary")
        Logger.shared.logInfo("  Startup time: \(String(format: "%.2f", report.startupTimeMs))ms")
        Logger.shared.logInfo("  Modules loaded: \(report.moduleLoadTimes.count)")
        Logger.shared.logInfo("  Total memory: \(formatBytes(report.totalMemoryBytes))")
        Logger.shared.logInfo("  Cache hit rate: \(String(format: "%.1f", report.cacheStats.overallHitRate))%")

        // Log slow modules
        let slowModules = report.moduleLoadTimes.filter { $0.value > 100 }
        if !slowModules.isEmpty {
            Logger.shared.logWarning("[ModulePerformanceMetrics] Slow modules (>100ms):")
            for (module, time) in slowModules.sorted(by: { $0.value > $1.value }) {
                Logger.shared.logWarning("  - \(module): \(String(format: "%.2f", time))ms")
            }
        }
    }

    // MARK: - Reset

    /// Reset all metrics
    func reset() {
        activeTimers.removeAll()
        timingRecords.removeAll()
        moduleLoadTimes.removeAll()
        initializationOrder.removeAll()
        startupTime = 0
        viewLookupCount = 0
        formLookupCount = 0
        actionLookupCount = 0
        totalLookupTime = 0
        totalLookupCount = 0
        cacheMetrics.removeAll()
        moduleMemoryUsage.removeAll()

        Logger.shared.logInfo("[ModulePerformanceMetrics] Reset all metrics")
    }

    // MARK: - Private Helpers

    /// Format bytes for display
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}
