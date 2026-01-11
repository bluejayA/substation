// Sources/Substation/Modules/Routers/RoutersDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Neutron Routers
///
/// This provider handles all data fetching operations for routers,
/// replacing the centralized fetchRouters() method in DataManager.
@MainActor
final class RoutersDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: RoutersModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    /// Pagination manager for large datasets
    private var paginationManager: PaginationManager<Router>?

    // MARK: - DataProvider Protocol

    let resourceType: String = "routers"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedRouters.count ?? 0
    }

    var supportsPagination: Bool {
        return true
    }

    // MARK: - Initialization

    /// Initialize the RoutersDataProvider
    ///
    /// - Parameters:
    ///   - module: The parent RoutersModule
    ///   - tui: The TUI instance for client and cache access
    init(module: RoutersModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

    /// Fetch router data from the OpenStack Neutron API
    ///
    /// - Parameters:
    ///   - priority: The fetch priority determining timeout behavior
    ///   - forceRefresh: Whether to bypass caches and fetch fresh data
    /// - Returns: Result of the fetch operation
    func fetchData(priority: DataFetchPriority, forceRefresh: Bool) async -> DataFetchResult {
        guard let tui = tui else {
            return DataFetchResult(
                itemCount: 0,
                duration: 0,
                error: ModuleError.invalidState("TUI reference is nil")
            )
        }

        let startTime = Date()

        do {
            Logger.shared.logDebug("RoutersDataProvider - Fetching routers", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            // Determine timeout based on priority
            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch routers with appropriate timeout
            let routers: [Router]
            if timeoutSeconds > 0 {
                routers = try await withTimeout(seconds: timeoutSeconds) {
                    try await tui.client.listRouters(forceRefresh: forceRefresh)
                }
            } else {
                routers = try await tui.client.listRouters(forceRefresh: forceRefresh)
            }

            // Update cache
            tui.cacheManager.cachedRouters = routers
            lastRefreshTime = Date()

            // Update pagination if enabled
            if let paginationManager = paginationManager {
                await paginationManager.updateFromFilterCache(routers)
            }

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("RoutersDataProvider - Fetched \(routers.count) routers", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: routers.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("RoutersDataProvider - Fetch timed out", context: [
                "timeout": timeoutForPriority(priority),
                "duration": String(format: "%.2f", duration)
            ])
            return DataFetchResult(
                itemCount: currentItemCount,
                duration: duration,
                error: error
            )

        } catch let error as OpenStackError {
            let duration = Date().timeIntervalSince(startTime)
            handleOpenStackError(error)
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )

        } catch {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logError("RoutersDataProvider - Failed to fetch routers: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    /// Clear the cached router data
    func clearCache() async {
        tui?.cacheManager.cachedRouters.removeAll()
        lastRefreshTime = nil
        paginationManager = nil
        Logger.shared.logDebug("RoutersDataProvider - Cache cleared")
    }

    /// Get paginated items if pagination is supported
    ///
    /// - Parameters:
    ///   - page: The page number to retrieve
    ///   - pageSize: The number of items per page
    /// - Returns: Array of paginated items or nil
    func getPaginatedItems(page: Int, pageSize: Int) async -> [Any]? {
        if paginationManager == nil {
            // Initialize pagination if not already done
            guard let tui = tui else { return nil }
            // Use appropriate static config based on page size
            let config: PaginationConfig
            if pageSize <= 50 {
                config = .small
            } else if pageSize <= 100 {
                config = .medium
            } else {
                config = .large
            }
            self.paginationManager = PaginationManager<Router>(
                config: config,
                data: tui.cacheManager.cachedRouters
            )
            await self.paginationManager?.initialLoad()
        }

        return paginationManager?.visibleItems
    }

    // MARK: - Private Methods

    /// Get timeout value based on fetch priority
    ///
    /// - Parameter priority: The fetch priority
    /// - Returns: Timeout in seconds
    private func timeoutForPriority(_ priority: DataFetchPriority) -> TimeInterval {
        switch priority {
        case .critical:
            return 30.0  // Generous timeout for critical data
        case .secondary:
            return 20.0
        case .background:
            return 10.0  // Aggressive timeout for background fetches
        case .onDemand:
            return 30.0  // User-initiated, allow more time
        case .fast:
            return 15.0  // Quick refresh
        }
    }

    /// Handle OpenStack-specific errors with appropriate logging
    ///
    /// - Parameter error: The OpenStack error to handle
    private func handleOpenStackError(_ error: OpenStackError) {
        switch error {
        case .httpError(403, _):
            Logger.shared.logDebug("RoutersDataProvider - Router access may require admin privileges (HTTP 403)")
        case .httpError(404, _):
            Logger.shared.logDebug("RoutersDataProvider - Neutron service may not be available (HTTP 404)")
        default:
            Logger.shared.logError("RoutersDataProvider - OpenStack error: \(error)")
        }
    }

    /// Execute an operation with a timeout
    ///
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: TimeoutError if the operation times out
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            group.cancelAll()
            return result
        }
    }

    /// Timeout error type
    struct TimeoutError: Error {}
}

/// Extension for batch operations
extension RoutersDataProvider: BatchDataProvider {
    /// Fetch data in batches for large datasets
    ///
    /// - Parameters:
    ///   - batchSize: Number of items per batch
    ///   - priority: The fetch priority
    ///   - progressHandler: Called after each batch with progress (0.0 to 1.0)
    /// - Returns: Combined result of all batches
    func fetchDataInBatches(
        batchSize: Int,
        priority: DataFetchPriority,
        progressHandler: @escaping (Double) -> Void
    ) async -> DataFetchResult {
        // For routers, we typically fetch all at once from the API
        // But we can simulate batch processing for UI updates
        let result = await fetchData(priority: priority, forceRefresh: true)

        // Report completion
        progressHandler(1.0)

        return result
    }
}

/// Extension for detailed fetching
extension RoutersDataProvider: DetailedDataProvider {
    /// Fetch detailed information for a specific router
    ///
    /// - Parameters:
    ///   - id: The router ID
    ///   - includeRelated: Whether to fetch related resources
    /// - Returns: The detailed router or nil if not found
    func fetchDetailedResource(id: String, includeRelated: Bool) async -> Any? {
        guard let tui = tui else { return nil }

        // Find router in cache
        let routers = tui.cacheManager.cachedRouters
        if let router = routers.first(where: { $0.id == id }) {
            return router
        }

        Logger.shared.logDebug("RoutersDataProvider - Router not found in cache: \(id)")
        return nil
    }
}
