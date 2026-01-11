// Sources/Substation/Modules/Swift/SwiftDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Swift Containers
///
/// This provider handles all data fetching operations for Swift containers,
/// replacing the centralized fetchContainers() method in DataManager.
/// Gracefully handles service unavailability as Swift may not be installed.
@MainActor
final class SwiftDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: SwiftModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    /// Pagination manager for large datasets
    private var paginationManager: PaginationManager<SwiftContainer>?

    /// Flag to track if service is unavailable
    private var serviceUnavailable: Bool = false

    // MARK: - DataProvider Protocol

    let resourceType: String = "swift"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedSwiftContainers.count ?? 0
    }

    var supportsPagination: Bool {
        return true
    }

    // MARK: - Initialization

    /// Initialize the SwiftDataProvider
    ///
    /// - Parameters:
    ///   - module: The parent SwiftModule
    ///   - tui: The TUI instance for client and cache access
    init(module: SwiftModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

    /// Fetch container data from the OpenStack Swift API
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
            Logger.shared.logDebug("SwiftDataProvider - Skipping fetch, service previously unavailable")
            return DataFetchResult(
                itemCount: currentItemCount,
                duration: 0,
                fromCache: true
            )
        }

        // Stale-while-revalidate for container list
        let cacheMaxAge: TimeInterval = 30
        if !forceRefresh && !tui.cacheManager.cachedSwiftContainers.isEmpty {
            let isFresh = tui.cacheManager.isSwiftContainersCacheFresh(maxAge: cacheMaxAge)

            if isFresh {
                // Cache is fresh - use it directly
                Logger.shared.logDebug("SwiftDataProvider - Using fresh cached containers (\(currentItemCount) items)")
                return DataFetchResult(
                    itemCount: currentItemCount,
                    duration: 0,
                    fromCache: true
                )
            } else {
                // Cache is stale - show it but revalidate in background
                Logger.shared.logDebug("SwiftDataProvider - Showing stale cache (\(currentItemCount) items), revalidating in background")

                // Launch background revalidation
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    await self.revalidateContainerListCache()
                }

                return DataFetchResult(
                    itemCount: currentItemCount,
                    duration: 0,
                    fromCache: true
                )
            }
        }

        let startTime = Date()

        do {
            Logger.shared.logDebug("SwiftDataProvider - Fetching containers", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            // Determine timeout based on priority
            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch containers with appropriate timeout
            // Note: Swift API may not have forceRefresh parameter
            let containers: [SwiftContainer]
            if timeoutSeconds > 0 {
                containers = try await withTimeout(seconds: timeoutSeconds) {
                    try await tui.client.swift.listContainers()
                }
            } else {
                containers = try await tui.client.swift.listContainers()
            }

            // Update cache
            tui.cacheManager.cachedSwiftContainers = containers
            lastRefreshTime = Date()
            serviceUnavailable = false

            // Update pagination if enabled
            if let paginationManager = paginationManager {
                await paginationManager.updateFromFilterCache(containers)
            }

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("SwiftDataProvider - Fetched \(containers.count) containers", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: containers.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("SwiftDataProvider - Fetch timed out", context: [
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
            Logger.shared.logError("SwiftDataProvider - Failed to fetch containers: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    /// Clear the cached container data
    func clearCache() async {
        tui?.cacheManager.cachedSwiftContainers.removeAll()
        lastRefreshTime = nil
        paginationManager = nil
        serviceUnavailable = false
        Logger.shared.logDebug("SwiftDataProvider - Cache cleared")
    }

    /// Revalidate container list cache in background
    ///
    /// Fetches fresh data from server and updates cache without blocking UI.
    private func revalidateContainerListCache() async {
        guard let tui = tui else { return }

        Logger.shared.logDebug("SwiftDataProvider - Revalidating container list cache")

        do {
            let startTime = Date()
            let containers = try await tui.client.swift.listContainers()

            // Update cache
            tui.cacheManager.cachedSwiftContainers = containers
            lastRefreshTime = Date()
            serviceUnavailable = false

            // Update pagination if enabled
            if let paginationManager = paginationManager {
                await paginationManager.updateFromFilterCache(containers)
            }

            let duration = Date().timeIntervalSince(startTime)
            let oldCount = currentItemCount

            if oldCount != containers.count {
                Logger.shared.logInfo("SwiftDataProvider - Revalidation detected change: \(oldCount) -> \(containers.count) containers in \(String(format: "%.2f", duration))s")
                // Only show status if user is viewing containers
                if tui.viewCoordinator.currentView == .swift {
                    tui.statusMessage = "Updated: \(containers.count) containers"
                    tui.markNeedsRedraw()
                }
            } else {
                Logger.shared.logDebug("SwiftDataProvider - Revalidation completed, no changes (\(containers.count) containers) in \(String(format: "%.2f", duration))s")
            }

        } catch {
            Logger.shared.logDebug("SwiftDataProvider - Revalidation failed: \(error.localizedDescription)")
        }
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
            self.paginationManager = PaginationManager<SwiftContainer>(
                config: config,
                data: tui.cacheManager.cachedSwiftContainers
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
            Logger.shared.logDebug("SwiftDataProvider - Container access may require admin privileges (HTTP 403)")
        case .httpError(404, _):
            Logger.shared.logDebug("SwiftDataProvider - Swift service may not be installed (HTTP 404)")
            serviceUnavailable = true
        case .endpointNotFound:
            Logger.shared.logDebug("SwiftDataProvider - Swift endpoint not found in service catalog")
            serviceUnavailable = true
        default:
            Logger.shared.logError("SwiftDataProvider - OpenStack error: \(error)")
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
extension SwiftDataProvider: BatchDataProvider {
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
        // For containers, we typically fetch all at once from the API
        // But we can simulate batch processing for UI updates
        let result = await fetchData(priority: priority, forceRefresh: true)

        // Report completion
        progressHandler(1.0)

        return result
    }
}

/// Extension for detailed fetching
extension SwiftDataProvider: DetailedDataProvider {
    /// Fetch detailed information for a specific container
    ///
    /// - Parameters:
    ///   - id: The container name (used as ID)
    ///   - includeRelated: Whether to fetch related resources
    /// - Returns: The container metadata or nil if not found
    func fetchDetailedResource(id: String, includeRelated: Bool) async -> Any? {
        guard let tui = tui else { return nil }

        do {
            let metadata = try await tui.client.swift.getContainerMetadata(containerName: id)

            if includeRelated {
                // Could fetch related resources like objects list, ACLs, etc.
                // For now, just return the metadata
                return metadata
            }

            return metadata
        } catch {
            Logger.shared.logError("SwiftDataProvider - Failed to fetch detailed container: \(error)")
            return nil
        }
    }
}
