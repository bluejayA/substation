// Sources/Substation/Modules/Core/ResourcePool.swift
import Foundation

/// A pooled resource entry with usage tracking
struct PooledResource<T> {
    /// The pooled resource value
    let value: T
    /// Last time this resource was accessed
    var lastAccessed: Date
    /// Number of times accessed
    var accessCount: Int
}

/// Statistics for resource pool operations
struct ResourcePoolStatistics: Sendable {
    /// Number of resources currently pooled
    let pooledCount: Int
    /// Total number of acquisitions
    let totalAcquisitions: Int
    /// Number of cache hits
    let cacheHits: Int
    /// Number of cache misses (new allocations)
    let cacheMisses: Int
    /// Cache hit rate percentage
    let hitRate: Double
    /// Total estimated memory in bytes
    let estimatedMemoryBytes: Int
}

/// Thread-safe resource pool for commonly used objects
///
/// This pool provides:
/// - Shared read-only resources between modules
/// - Pooled formatters to reduce allocation overhead
/// - Usage tracking for optimization
///
/// Example usage:
/// ```swift
/// let pool = ResourcePool.shared
/// let formatter = pool.acquireDateFormatter(.iso8601)
/// let number = pool.acquireNumberFormatter(.decimal)
/// ```
@MainActor
final class ResourcePool {
    /// Shared singleton instance
    static let shared = ResourcePool()

    // MARK: - Date Formatters

    /// Pooled date formatters by format type
    private var dateFormatters: [DateFormatterType: PooledResource<DateFormatter>] = [:]

    // MARK: - Number Formatters

    /// Pooled number formatters by format type
    private var numberFormatters: [NumberFormatterType: PooledResource<NumberFormatter>] = [:]

    // MARK: - Byte Count Formatters

    /// Pooled byte count formatter
    private var byteCountFormatter: PooledResource<ByteCountFormatter>?

    // MARK: - Shared Data

    /// Shared read-only configuration data
    private var sharedConfigs: [String: Any] = [:]

    /// Shared string constants
    private var stringPool: [String: String] = [:]

    // MARK: - Statistics

    /// Total acquisition count
    private var totalAcquisitions: Int = 0

    /// Cache hit count
    private var cacheHits: Int = 0

    /// Cache miss count
    private var cacheMisses: Int = 0

    // MARK: - Initialization

    private init() {
        // Pre-populate commonly used formatters
        initializeCommonFormatters()
        Logger.shared.logInfo("[ResourcePool] Initialized")
    }

    // MARK: - Date Formatter Types

    /// Supported date formatter types
    enum DateFormatterType: String, CaseIterable {
        case iso8601 = "iso8601"
        case standard = "standard"
        case compact = "compact"
        case logging = "logging"
        case shortDateTime = "shortDateTime"
        case mediumDateTime = "mediumDateTime"
        case dateOnly = "dateOnly"
        case timeOnly = "timeOnly"
    }

    // MARK: - Number Formatter Types

    /// Supported number formatter types
    enum NumberFormatterType: String, CaseIterable {
        case decimal = "decimal"
        case percent = "percent"
        case currency = "currency"
        case scientific = "scientific"
        case none = "none"
    }

    // MARK: - Public API - Date Formatters

    /// Acquire a date formatter from the pool
    ///
    /// - Parameter type: The formatter type to acquire
    /// - Returns: A DateFormatter instance
    func acquireDateFormatter(_ type: DateFormatterType) -> DateFormatter {
        totalAcquisitions += 1

        if var pooled = dateFormatters[type] {
            cacheHits += 1
            pooled.lastAccessed = Date()
            pooled.accessCount += 1
            dateFormatters[type] = pooled
            return pooled.value
        }

        cacheMisses += 1
        let formatter = createDateFormatter(for: type)
        dateFormatters[type] = PooledResource(
            value: formatter,
            lastAccessed: Date(),
            accessCount: 1
        )
        return formatter
    }

    /// Format a date using a pooled formatter
    ///
    /// - Parameters:
    ///   - date: The date to format
    ///   - type: The formatter type
    /// - Returns: Formatted date string
    func formatDate(_ date: Date, type: DateFormatterType) -> String {
        return acquireDateFormatter(type).string(from: date)
    }

    // MARK: - Public API - Number Formatters

    /// Acquire a number formatter from the pool
    ///
    /// - Parameter type: The formatter type to acquire
    /// - Returns: A NumberFormatter instance
    func acquireNumberFormatter(_ type: NumberFormatterType) -> NumberFormatter {
        totalAcquisitions += 1

        if var pooled = numberFormatters[type] {
            cacheHits += 1
            pooled.lastAccessed = Date()
            pooled.accessCount += 1
            numberFormatters[type] = pooled
            return pooled.value
        }

        cacheMisses += 1
        let formatter = createNumberFormatter(for: type)
        numberFormatters[type] = PooledResource(
            value: formatter,
            lastAccessed: Date(),
            accessCount: 1
        )
        return formatter
    }

    /// Format a number using a pooled formatter
    ///
    /// - Parameters:
    ///   - number: The number to format
    ///   - type: The formatter type
    /// - Returns: Formatted number string
    func formatNumber(_ number: Double, type: NumberFormatterType) -> String {
        return acquireNumberFormatter(type).string(from: NSNumber(value: number)) ?? "\(number)"
    }

    /// Format an integer using a pooled formatter
    ///
    /// - Parameters:
    ///   - number: The integer to format
    ///   - type: The formatter type
    /// - Returns: Formatted number string
    func formatNumber(_ number: Int, type: NumberFormatterType) -> String {
        return acquireNumberFormatter(type).string(from: NSNumber(value: number)) ?? "\(number)"
    }

    // MARK: - Public API - Byte Count Formatter

    /// Acquire the byte count formatter
    ///
    /// - Returns: A ByteCountFormatter instance
    func acquireByteCountFormatter() -> ByteCountFormatter {
        totalAcquisitions += 1

        if var pooled = byteCountFormatter {
            cacheHits += 1
            pooled.lastAccessed = Date()
            pooled.accessCount += 1
            byteCountFormatter = pooled
            return pooled.value
        }

        cacheMisses += 1
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        byteCountFormatter = PooledResource(
            value: formatter,
            lastAccessed: Date(),
            accessCount: 1
        )
        return formatter
    }

    /// Format bytes using the pooled formatter
    ///
    /// - Parameter bytes: The byte count to format
    /// - Returns: Formatted byte string (e.g., "1.5 GB")
    func formatBytes(_ bytes: Int64) -> String {
        return acquireByteCountFormatter().string(fromByteCount: bytes)
    }

    /// Format bytes from integer using the pooled formatter
    ///
    /// - Parameter bytes: The byte count to format
    /// - Returns: Formatted byte string
    func formatBytes(_ bytes: Int) -> String {
        return formatBytes(Int64(bytes))
    }

    // MARK: - Public API - Shared Data

    /// Store shared configuration data
    ///
    /// - Parameters:
    ///   - value: The configuration value
    ///   - key: The configuration key
    func setSharedConfig(_ value: Any, for key: String) {
        sharedConfigs[key] = value
        Logger.shared.logDebug("[ResourcePool] Stored shared config: \(key)")
    }

    /// Get shared configuration data
    ///
    /// - Parameter key: The configuration key
    /// - Returns: The configuration value or nil
    func getSharedConfig(for key: String) -> Any? {
        return sharedConfigs[key]
    }

    /// Get typed shared configuration data
    ///
    /// - Parameters:
    ///   - key: The configuration key
    ///   - type: The expected type
    /// - Returns: The configuration value cast to the expected type or nil
    func getSharedConfig<T>(for key: String, as type: T.Type) -> T? {
        return sharedConfigs[key] as? T
    }

    // MARK: - Public API - String Pool

    /// Get or create a pooled string
    ///
    /// This reduces memory for frequently used strings by interning them.
    ///
    /// - Parameter string: The string to pool
    /// - Returns: The pooled string reference
    func intern(_ string: String) -> String {
        if let pooled = stringPool[string] {
            return pooled
        }
        stringPool[string] = string
        return string
    }

    /// Clear the string pool
    func clearStringPool() {
        stringPool.removeAll()
        Logger.shared.logDebug("[ResourcePool] Cleared string pool")
    }

    // MARK: - Statistics

    /// Get pool statistics
    ///
    /// - Returns: Statistics about pool usage
    func getStatistics() -> ResourcePoolStatistics {
        let pooledCount = dateFormatters.count + numberFormatters.count + (byteCountFormatter != nil ? 1 : 0)

        let hitRate: Double
        if totalAcquisitions > 0 {
            hitRate = (Double(cacheHits) / Double(totalAcquisitions)) * 100.0
        } else {
            hitRate = 0.0
        }

        // Estimate memory usage
        // Formatters are relatively heavy objects
        let formatterBytes = pooledCount * 4096
        let stringPoolBytes = stringPool.values.reduce(0) { $0 + $1.utf8.count }
        let configBytes = sharedConfigs.count * 256

        return ResourcePoolStatistics(
            pooledCount: pooledCount,
            totalAcquisitions: totalAcquisitions,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            hitRate: hitRate,
            estimatedMemoryBytes: formatterBytes + stringPoolBytes + configBytes
        )
    }

    /// Reset statistics counters
    func resetStatistics() {
        totalAcquisitions = 0
        cacheHits = 0
        cacheMisses = 0
        Logger.shared.logDebug("[ResourcePool] Reset statistics")
    }

    /// Clear all pooled resources
    func clear() {
        dateFormatters.removeAll()
        numberFormatters.removeAll()
        byteCountFormatter = nil
        sharedConfigs.removeAll()
        stringPool.removeAll()
        resetStatistics()
        Logger.shared.logInfo("[ResourcePool] Cleared all resources")
    }

    // MARK: - Private Methods

    /// Initialize commonly used formatters
    private func initializeCommonFormatters() {
        // Pre-warm the pool with commonly used formatters
        _ = acquireDateFormatter(.standard)
        _ = acquireDateFormatter(.compact)
        _ = acquireNumberFormatter(.decimal)
        _ = acquireByteCountFormatter()

        // Reset stats after pre-warming
        resetStatistics()
    }

    /// Create a date formatter for the given type
    private func createDateFormatter(for type: DateFormatterType) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        switch type {
        case .iso8601:
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
        case .standard:
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale.current
        case .compact:
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            formatter.locale = Locale.current
        case .logging:
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            formatter.timeZone = TimeZone.current
            formatter.locale = Locale.current
        case .shortDateTime:
            formatter.dateFormat = "MM/dd/yy HH:mm"
        case .mediumDateTime:
            formatter.dateFormat = "MMM dd, yyyy HH:mm"
        case .dateOnly:
            formatter.dateFormat = "MMM dd, yyyy"
        case .timeOnly:
            formatter.dateFormat = "HH:mm:ss"
        }

        return formatter
    }

    /// Create a number formatter for the given type
    private func createNumberFormatter(for type: NumberFormatterType) -> NumberFormatter {
        let formatter = NumberFormatter()

        switch type {
        case .decimal:
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
        case .percent:
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 1
        case .currency:
            formatter.numberStyle = .currency
        case .scientific:
            formatter.numberStyle = .scientific
            formatter.maximumFractionDigits = 2
        case .none:
            formatter.numberStyle = .none
        }

        return formatter
    }
}
