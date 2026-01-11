// Sources/Substation/Modules/Hypervisors/HypervisorsDataProvider.swift
import Foundation
import OSClient

/// Data provider for the Hypervisors module
///
/// Handles data fetching and caching for hypervisor resources.
/// This provider requires administrative privileges to function properly.
@MainActor
final class HypervisorsDataProvider: DataProvider {
    // MARK: - DataProvider Protocol Properties

    /// Resource type identifier
    let resourceType: String = "hypervisors"

    /// Current item count in cache
    var currentItemCount: Int {
        return tui?.cacheManager.cachedHypervisors.count ?? 0
    }

    /// Whether this provider supports pagination
    var supportsPagination: Bool { false }

    // MARK: - Internal Properties

    /// Reference to parent module
    private weak var module: HypervisorsModule?

    /// Reference to TUI system
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    // MARK: - Initialization

    /// Initialize data provider with module and TUI context
    ///
    /// - Parameters:
    ///   - module: Parent HypervisorsModule instance
    ///   - tui: Main TUI system instance
    init(module: HypervisorsModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - DataProvider Protocol Methods

    /// Fetch hypervisor data from OpenStack API
    ///
    /// - Parameters:
    ///   - priority: Data fetch priority for timeout handling
    ///   - forceRefresh: If true, bypass cache and fetch fresh data
    /// - Returns: DataFetchResult with fetch metrics
    func fetchData(priority: DataFetchPriority, forceRefresh: Bool) async -> DataFetchResult {
        guard let tui = tui else {
            return DataFetchResult(
                itemCount: 0,
                duration: 0,
                fromCache: false,
                error: ModuleError.invalidState("TUI reference is nil")
            )
        }

        let startTime = Date()
        let timeoutSeconds = timeoutForPriority(priority)

        do {
            let hypervisors = try await withTimeout(seconds: timeoutSeconds) {
                try await tui.client.nova.listHypervisors(forceRefresh: forceRefresh)
            }

            // Update cache
            tui.cacheManager.cachedHypervisors = hypervisors
            lastRefreshTime = Date()

            let fetchDuration = Date().timeIntervalSince(startTime)

            return DataFetchResult(
                itemCount: hypervisors.count,
                duration: fetchDuration,
                fromCache: false,
                error: nil
            )
        } catch {
            let fetchDuration = Date().timeIntervalSince(startTime)

            return DataFetchResult(
                itemCount: currentItemCount,
                duration: fetchDuration,
                fromCache: true,
                error: error
            )
        }
    }

    /// Clear cached hypervisor data
    func clearCache() async {
        tui?.cacheManager.cachedHypervisors = []
        lastRefreshTime = nil
    }

    // MARK: - Helper Methods

    /// Get timeout for priority level
    ///
    /// - Parameter priority: Data fetch priority
    /// - Returns: Timeout in seconds
    private func timeoutForPriority(_ priority: DataFetchPriority) -> Double {
        switch priority {
        case .critical:
            return 30.0
        case .secondary:
            return 20.0
        case .background:
            return 10.0
        case .onDemand:
            return 30.0
        case .fast:
            return 15.0
        }
    }

    /// Execute async operation with timeout
    ///
    /// - Parameters:
    ///   - seconds: Timeout duration in seconds
    ///   - operation: Async operation to execute
    /// - Returns: Result of the operation
    /// - Throws: TimeoutError or operation errors
    private func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
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
}

/// Error thrown when an operation times out
private struct TimeoutError: Error {}
