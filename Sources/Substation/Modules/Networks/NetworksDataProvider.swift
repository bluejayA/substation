// Sources/Substation/Modules/Networks/NetworksDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Neutron Networks
///
/// This provider handles all data fetching operations for networks,
/// replacing the centralized fetchNetworks() method in DataManager.
@MainActor
final class NetworksDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: NetworksModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    // MARK: - DataProvider Protocol

    let resourceType: String = "networks"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedNetworks.count ?? 0
    }

    var supportsPagination: Bool {
        return false
    }

    // MARK: - Initialization

    /// Initialize the networks data provider
    ///
    /// - Parameters:
    ///   - module: The NetworksModule instance
    ///   - tui: The main TUI instance
    init(module: NetworksModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

    /// Fetch networks from the OpenStack API
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
            Logger.shared.logDebug("NetworksDataProvider - Fetching networks", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            // Determine timeout based on priority
            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch networks with appropriate timeout
            let networks: [Network]
            if timeoutSeconds > 0 {
                networks = try await withTimeout(seconds: timeoutSeconds) {
                    try await tui.client.listNetworks(forceRefresh: forceRefresh)
                }
            } else {
                networks = try await tui.client.listNetworks(forceRefresh: forceRefresh)
            }

            // Update cache
            tui.cacheManager.cachedNetworks = networks
            lastRefreshTime = Date()

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("NetworksDataProvider - Fetched \(networks.count) networks", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: networks.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("NetworksDataProvider - Fetch timed out", context: [
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
            Logger.shared.logError("NetworksDataProvider - Failed to fetch networks: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    /// Clear the networks cache
    func clearCache() async {
        tui?.cacheManager.cachedNetworks.removeAll()
        lastRefreshTime = nil
        Logger.shared.logDebug("NetworksDataProvider - Cache cleared")
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
            Logger.shared.logDebug("NetworksDataProvider - Network access may require admin privileges (HTTP 403)")
        case .httpError(404, _):
            Logger.shared.logDebug("NetworksDataProvider - Neutron service may not be available (HTTP 404)")
        default:
            Logger.shared.logError("NetworksDataProvider - OpenStack error: \(error)")
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
