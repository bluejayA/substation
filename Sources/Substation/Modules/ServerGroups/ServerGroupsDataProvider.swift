// Sources/Substation/Modules/ServerGroups/ServerGroupsDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Nova Server Groups
///
/// This provider handles all data fetching operations for server groups,
/// replacing the centralized fetchServerGroups() method in DataManager.
/// Server groups are used for affinity/anti-affinity scheduling policies.
@MainActor
final class ServerGroupsDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: ServerGroupsModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    // MARK: - DataProvider Protocol

    let resourceType: String = "servergroups"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedServerGroups.count ?? 0
    }

    var supportsPagination: Bool {
        return false
    }

    // MARK: - Initialization

    /// Initialize the server groups data provider
    ///
    /// - Parameters:
    ///   - module: The ServerGroupsModule instance
    ///   - tui: The main TUI instance
    init(module: ServerGroupsModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

    /// Fetch server groups from the OpenStack API
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
            Logger.shared.logDebug("ServerGroupsDataProvider - Fetching server groups", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            // Determine timeout based on priority
            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch server groups with appropriate timeout
            let serverGroups: [ServerGroup]
            if timeoutSeconds > 0 {
                serverGroups = try await withTimeout(seconds: timeoutSeconds) {
                    try await tui.client.listServerGroups(forceRefresh: forceRefresh)
                }
            } else {
                serverGroups = try await tui.client.listServerGroups(forceRefresh: forceRefresh)
            }

            // Update cache
            tui.cacheManager.cachedServerGroups = serverGroups
            lastRefreshTime = Date()

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("ServerGroupsDataProvider - Fetched \(serverGroups.count) server groups", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: serverGroups.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("ServerGroupsDataProvider - Fetch timed out", context: [
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
            Logger.shared.logError("ServerGroupsDataProvider - Failed to fetch server groups: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    /// Clear the server groups cache
    func clearCache() async {
        tui?.cacheManager.cachedServerGroups.removeAll()
        lastRefreshTime = nil
        Logger.shared.logDebug("ServerGroupsDataProvider - Cache cleared")
    }

    // MARK: - Private Methods

    /// Get timeout interval based on priority
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
            Logger.shared.logDebug("ServerGroupsDataProvider - Server group access may require admin privileges (HTTP 403)")
        case .httpError(404, _):
            // Server groups feature may not be available in all OpenStack deployments
            Logger.shared.logDebug("ServerGroupsDataProvider - Server groups feature may not be available in this OpenStack deployment (HTTP 404)")
        default:
            Logger.shared.logError("ServerGroupsDataProvider - OpenStack error: \(error)")
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

    /// Error type for timeout operations
    struct TimeoutError: Error {}
}
