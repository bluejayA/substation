// Sources/Substation/Modules/SecurityGroups/SecurityGroupsDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Neutron Security Groups
///
/// This provider handles all data fetching operations for security groups,
/// replacing the centralized fetchSecurityGroups() method in DataManager.
@MainActor
final class SecurityGroupsDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: SecurityGroupsModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    /// Pagination manager for large datasets
    private var paginationManager: PaginationManager<SecurityGroup>?

    // MARK: - DataProvider Protocol

    let resourceType: String = "securitygroups"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedSecurityGroups.count ?? 0
    }

    var supportsPagination: Bool {
        return true
    }

    // MARK: - Initialization

    /// Initialize the SecurityGroupsDataProvider
    ///
    /// - Parameters:
    ///   - module: The parent SecurityGroupsModule
    ///   - tui: The TUI instance for client and cache access
    init(module: SecurityGroupsModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

    /// Fetch security group data from the OpenStack Neutron API
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
            Logger.shared.logDebug("SecurityGroupsDataProvider - Fetching security groups", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            // Determine timeout based on priority
            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch security groups with appropriate timeout
            let securityGroups: [SecurityGroup]
            if timeoutSeconds > 0 {
                securityGroups = try await withTimeout(seconds: timeoutSeconds) {
                    try await tui.client.listSecurityGroups(forceRefresh: forceRefresh)
                }
            } else {
                securityGroups = try await tui.client.listSecurityGroups(forceRefresh: forceRefresh)
            }

            // Update cache
            tui.cacheManager.cachedSecurityGroups = securityGroups
            lastRefreshTime = Date()

            // Update pagination if enabled
            if let paginationManager = paginationManager {
                await paginationManager.updateFromFilterCache(securityGroups)
            }

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("SecurityGroupsDataProvider - Fetched \(securityGroups.count) security groups", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: securityGroups.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("SecurityGroupsDataProvider - Fetch timed out", context: [
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
            Logger.shared.logError("SecurityGroupsDataProvider - Failed to fetch security groups: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    /// Clear the cached security group data
    func clearCache() async {
        tui?.cacheManager.cachedSecurityGroups.removeAll()
        lastRefreshTime = nil
        paginationManager = nil
        Logger.shared.logDebug("SecurityGroupsDataProvider - Cache cleared")
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
            self.paginationManager = PaginationManager<SecurityGroup>.forSecurityGroups(
                data: tui.cacheManager.cachedSecurityGroups,
                config: config
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
            Logger.shared.logDebug("SecurityGroupsDataProvider - Security group access may require admin privileges (HTTP 403)")
        case .httpError(404, _):
            Logger.shared.logDebug("SecurityGroupsDataProvider - Neutron service may not be available (HTTP 404)")
        default:
            Logger.shared.logError("SecurityGroupsDataProvider - OpenStack error: \(error)")
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
extension SecurityGroupsDataProvider: BatchDataProvider {
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
        // For security groups, we typically fetch all at once from the API
        // But we can simulate batch processing for UI updates
        let result = await fetchData(priority: priority, forceRefresh: true)

        // Report completion
        progressHandler(1.0)

        return result
    }
}

/// Extension for detailed fetching
extension SecurityGroupsDataProvider: DetailedDataProvider {
    /// Fetch detailed information for a specific security group
    ///
    /// - Parameters:
    ///   - id: The security group ID
    ///   - includeRelated: Whether to fetch related resources
    /// - Returns: The detailed security group or nil if not found
    func fetchDetailedResource(id: String, includeRelated: Bool) async -> Any? {
        guard let tui = tui else { return nil }

        do {
            let securityGroup = try await tui.client.getSecurityGroup(id: id)

            if includeRelated {
                // Could fetch related resources like rules, ports using this group, etc.
                // For now, just return the security group
                return securityGroup
            }

            return securityGroup
        } catch {
            Logger.shared.logError("SecurityGroupsDataProvider - Failed to fetch detailed security group: \(error)")
            return nil
        }
    }
}
