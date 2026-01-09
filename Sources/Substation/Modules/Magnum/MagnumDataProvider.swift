// Sources/Substation/Modules/Magnum/MagnumDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Magnum Container Infrastructure
///
/// This provider handles all data fetching operations for clusters,
/// cluster templates, and nodegroups.
@MainActor
final class MagnumDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: MagnumModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    // MARK: - DataProvider Protocol

    let resourceType: String = "clusters"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedClusters.count ?? 0
    }

    // MARK: - Initialization

    /// Initialize the MagnumDataProvider
    ///
    /// - Parameters:
    ///   - module: The parent MagnumModule
    ///   - tui: The TUI instance for client and cache access
    init(module: MagnumModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

    /// Fetch Magnum data from the API
    ///
    /// - Parameters:
    ///   - priority: The fetch priority determining timeout and caching behavior
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
            Logger.shared.logDebug("MagnumDataProvider - Fetching Magnum resources", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch clusters and templates in parallel
            async let clustersTask = fetchClusters(tui: tui, timeout: timeoutSeconds)
            async let templatesTask = fetchClusterTemplates(tui: tui, timeout: timeoutSeconds)

            let (clusters, templates) = try await (clustersTask, templatesTask)

            // Update cache
            tui.cacheManager.cachedClusters = clusters
            tui.cacheManager.cachedClusterTemplates = templates
            lastRefreshTime = Date()

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("MagnumDataProvider - Fetched \(clusters.count) clusters, \(templates.count) templates", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: clusters.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("MagnumDataProvider - Fetch timed out", context: [
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
            Logger.shared.logError("MagnumDataProvider - Failed to fetch data: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    /// Fetch nodegroups for a specific cluster
    ///
    /// - Parameters:
    ///   - clusterId: The cluster UUID to fetch nodegroups for
    /// - Returns: Array of nodegroups
    func fetchNodegroups(clusterId: String) async throws -> [Nodegroup] {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        let magnumService = await tui.client.magnum
        let nodegroups = try await magnumService.listNodegroups(clusterId: clusterId)

        // Update cache
        tui.cacheManager.cachedNodegroups = nodegroups

        return nodegroups
    }

    /// Clear cached Magnum data
    func clearCache() async {
        tui?.cacheManager.cachedClusters.removeAll()
        tui?.cacheManager.cachedClusterTemplates.removeAll()
        tui?.cacheManager.cachedNodegroups.removeAll()
        lastRefreshTime = nil
        Logger.shared.logDebug("MagnumDataProvider - Cache cleared")
    }

    // MARK: - Private Methods

    /// Fetch clusters with timeout
    private func fetchClusters(tui: TUI, timeout: TimeInterval) async throws -> [Cluster] {
        if timeout > 0 {
            return try await withTimeout(seconds: timeout) {
                let magnumService = await tui.client.magnum
                return try await magnumService.listClusters()
            }
        } else {
            let magnumService = await tui.client.magnum
            return try await magnumService.listClusters()
        }
    }

    /// Fetch cluster templates with timeout
    private func fetchClusterTemplates(tui: TUI, timeout: TimeInterval) async throws -> [ClusterTemplate] {
        if timeout > 0 {
            return try await withTimeout(seconds: timeout) {
                let magnumService = await tui.client.magnum
                return try await magnumService.listClusterTemplates()
            }
        } else {
            let magnumService = await tui.client.magnum
            return try await magnumService.listClusterTemplates()
        }
    }

    /// Get timeout duration based on fetch priority
    private func timeoutForPriority(_ priority: DataFetchPriority) -> TimeInterval {
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

    /// Handle OpenStack-specific errors with appropriate logging
    private func handleOpenStackError(_ error: OpenStackError) {
        switch error {
        case .httpError(403, _):
            Logger.shared.logDebug("MagnumDataProvider - Magnum access may require specific privileges (HTTP 403)")
        case .httpError(404, _):
            Logger.shared.logDebug("MagnumDataProvider - Magnum service may not be available (HTTP 404)")
        default:
            Logger.shared.logError("MagnumDataProvider - OpenStack error: \(error)")
        }
    }

    /// Execute an operation with a timeout
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

    /// Error thrown when an operation times out
    struct TimeoutError: Error {}
}
