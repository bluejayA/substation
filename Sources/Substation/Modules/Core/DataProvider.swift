// Sources/Substation/Modules/Core/DataProvider.swift
import Foundation
import OSClient

/// Priority levels for data fetching operations
enum DataFetchPriority: String, Sendable {
    case critical = "critical"      // Must complete for basic UI functionality
    case secondary = "secondary"    // Important but not blocking
    case background = "background"  // Can be deferred or cached
    case onDemand = "on-demand"    // User-initiated refresh
    case fast = "fast"             // Quick refresh of core resources
}

/// Result of a data fetch operation
struct DataFetchResult: Sendable {
    let itemCount: Int
    let duration: TimeInterval
    let fromCache: Bool
    let error: (any Error)?

    init(itemCount: Int, duration: TimeInterval, fromCache: Bool = false, error: (any Error)? = nil) {
        self.itemCount = itemCount
        self.duration = duration
        self.fromCache = fromCache
        self.error = error
    }
}

/// Protocol for modules that provide data fetching capabilities
///
/// Modules implementing this protocol can register themselves to handle
/// data fetching for their resource types, replacing the centralized
/// DataManager fetch methods.
@MainActor
protocol DataProvider {
    /// Resource type identifier (e.g., "servers", "networks", "volumes")
    var resourceType: String { get }

    /// Fetch data for this resource type
    /// - Parameters:
    ///   - priority: The fetch priority determining timeout and caching behavior
    ///   - forceRefresh: Whether to bypass caches and fetch fresh data
    /// - Returns: Result of the fetch operation
    func fetchData(priority: DataFetchPriority, forceRefresh: Bool) async -> DataFetchResult

    /// Refresh data for a specific resource by ID
    /// - Parameters:
    ///   - resourceId: The ID of the resource to refresh
    ///   - priority: The fetch priority
    /// - Returns: Result of the fetch operation
    func refreshResource(id: String, priority: DataFetchPriority) async -> DataFetchResult

    /// Clear cached data for this resource type
    func clearCache() async

    /// Get the last refresh time for this resource type
    var lastRefreshTime: Date? { get }

    /// Check if data needs refresh based on staleness
    /// - Parameter threshold: Time interval in seconds
    /// - Returns: True if data is older than threshold
    func needsRefresh(threshold: TimeInterval) -> Bool

    /// Get current item count for this resource type
    var currentItemCount: Int { get }

    /// Pagination support - optional
    var supportsPagination: Bool { get }

    /// Get paginated items if pagination is supported
    func getPaginatedItems(page: Int, pageSize: Int) async -> [Any]?
}

/// Default implementations for DataProvider
extension DataProvider {
    /// Default implementation checks last refresh time against threshold
    func needsRefresh(threshold: TimeInterval) -> Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) > threshold
    }

    /// Default implementation returns false for pagination support
    var supportsPagination: Bool { return false }

    /// Default implementation returns nil for paginated items
    func getPaginatedItems(page: Int, pageSize: Int) async -> [Any]? {
        return nil
    }

    /// Default implementation for single resource refresh (calls fetchData)
    func refreshResource(id: String, priority: DataFetchPriority) async -> DataFetchResult {
        // By default, refresh all data (modules can override for optimized single-resource refresh)
        return await fetchData(priority: priority, forceRefresh: true)
    }
}

/// Extension for batch operations on data providers
@MainActor
protocol BatchDataProvider: DataProvider {
    /// Fetch data in batches for large datasets
    /// - Parameters:
    ///   - batchSize: Number of items per batch
    ///   - priority: The fetch priority
    ///   - progressHandler: Called after each batch with progress (0.0 to 1.0)
    /// - Returns: Combined result of all batches
    func fetchDataInBatches(
        batchSize: Int,
        priority: DataFetchPriority,
        progressHandler: @escaping (Double) -> Void
    ) async -> DataFetchResult
}

/// Extension for data providers that support filtering
@MainActor
protocol FilterableDataProvider: DataProvider {
    associatedtype FilterType

    /// Fetch filtered data
    /// - Parameters:
    ///   - filter: The filter to apply
    ///   - priority: The fetch priority
    /// - Returns: Result of the filtered fetch
    func fetchFilteredData(filter: FilterType, priority: DataFetchPriority) async -> DataFetchResult
}

/// Extension for data providers that support detailed fetching
@MainActor
protocol DetailedDataProvider: DataProvider {
    /// Fetch detailed information for a specific resource
    /// - Parameters:
    ///   - id: The resource ID
    ///   - includeRelated: Whether to fetch related resources
    /// - Returns: The detailed resource or nil if not found
    func fetchDetailedResource(id: String, includeRelated: Bool) async -> Any?
}