// Sources/Substation/Modules/Barbican/BarbicanDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Barbican Secrets
///
/// This provider handles all data fetching operations for secrets,
/// replacing the centralized fetchSecrets() method in DataManager.
/// Gracefully handles service unavailability as Barbican may not be installed.
@MainActor
final class BarbicanDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: BarbicanModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    /// Pagination manager for large datasets
    private var paginationManager: PaginationManager<Secret>?

    /// Flag to track if service is unavailable
    private var serviceUnavailable: Bool = false

    // MARK: - DataProvider Protocol

    let resourceType: String = "secrets"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedSecrets.count ?? 0
    }

    var supportsPagination: Bool {
        return true
    }

    // MARK: - Initialization

    /// Initialize the BarbicanDataProvider
    ///
    /// - Parameters:
    ///   - module: The parent BarbicanModule
    ///   - tui: The TUI instance for client and cache access
    init(module: BarbicanModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

    /// Fetch secret data from the OpenStack Barbican API
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

        // If service was previously marked unavailable, skip fetch unless forced
        if serviceUnavailable && !forceRefresh {
            Logger.shared.logDebug("BarbicanDataProvider - Skipping fetch, service previously unavailable")
            return DataFetchResult(
                itemCount: currentItemCount,
                duration: 0,
                fromCache: true
            )
        }

        let startTime = Date()

        do {
            Logger.shared.logDebug("BarbicanDataProvider - Fetching secrets", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            // Determine timeout based on priority
            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch secrets with appropriate timeout
            let secrets: [Secret]
            if timeoutSeconds > 0 {
                secrets = try await withTimeout(seconds: timeoutSeconds) {
                    try await tui.client.barbican.listSecrets()
                }
            } else {
                secrets = try await tui.client.barbican.listSecrets()
            }

            // Update cache
            tui.cacheManager.cachedSecrets = secrets
            lastRefreshTime = Date()
            serviceUnavailable = false

            // Update pagination if enabled
            if let paginationManager = paginationManager {
                await paginationManager.updateFromFilterCache(secrets)
            }

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("BarbicanDataProvider - Fetched \(secrets.count) secrets", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: secrets.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("BarbicanDataProvider - Fetch timed out", context: [
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
            Logger.shared.logError("BarbicanDataProvider - Failed to fetch secrets: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    /// Clear the cached secret data
    func clearCache() async {
        tui?.cacheManager.cachedSecrets.removeAll()
        lastRefreshTime = nil
        paginationManager = nil
        serviceUnavailable = false
        Logger.shared.logDebug("BarbicanDataProvider - Cache cleared")
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
            self.paginationManager = PaginationManager<Secret>(
                config: config,
                data: tui.cacheManager.cachedSecrets
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
            Logger.shared.logDebug("BarbicanDataProvider - Secret access may require admin privileges (HTTP 403)")
        case .httpError(404, _):
            Logger.shared.logDebug("BarbicanDataProvider - Barbican service may not be installed (HTTP 404)")
            serviceUnavailable = true
        case .endpointNotFound:
            Logger.shared.logDebug("BarbicanDataProvider - Barbican endpoint not found in service catalog")
            serviceUnavailable = true
        default:
            Logger.shared.logError("BarbicanDataProvider - OpenStack error: \(error)")
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

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Timeout error type
    struct TimeoutError: Error {}
}

/// Extension for batch operations
extension BarbicanDataProvider: BatchDataProvider {
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
        // For secrets, we typically fetch all at once from the API
        // But we can simulate batch processing for UI updates
        let result = await fetchData(priority: priority, forceRefresh: true)

        // Report completion
        progressHandler(1.0)

        return result
    }
}

/// Extension for detailed fetching
extension BarbicanDataProvider: DetailedDataProvider {
    /// Fetch detailed information for a specific secret
    ///
    /// - Parameters:
    ///   - id: The secret ID
    ///   - includeRelated: Whether to fetch related resources
    /// - Returns: The detailed secret or nil if not found
    func fetchDetailedResource(id: String, includeRelated: Bool) async -> Any? {
        guard let tui = tui else { return nil }

        // Find secret in cache - Barbican API doesn't have a direct get by ID
        let secrets = tui.cacheManager.cachedSecrets
        if let secret = secrets.first(where: { $0.id == id }) {
            return secret
        }

        Logger.shared.logDebug("BarbicanDataProvider - Secret not found in cache: \(id)")
        return nil
    }
}
