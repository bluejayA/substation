// Sources/Substation/Modules/Servers/ServersDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Nova Servers
///
/// This provider handles all data fetching operations for servers,
/// replacing the centralized fetchServers() method in DataManager.
@MainActor
final class ServersDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: ServersModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    /// Pagination manager for large datasets
    private var paginationManager: PaginationManager<Server>?

    // MARK: - DataProvider Protocol

    let resourceType: String = "servers"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedServers.count ?? 0
    }

    var supportsPagination: Bool {
        return true
    }

    // MARK: - Initialization

    init(module: ServersModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

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
            Logger.shared.logDebug("ServersDataProvider - Fetching servers", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            // Determine timeout based on priority
            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch servers with appropriate timeout
            let servers: [Server]
            if timeoutSeconds > 0 {
                servers = try await withTimeout(seconds: timeoutSeconds) {
                    try await tui.client.listServers(forceRefresh: forceRefresh)
                }
            } else {
                servers = try await tui.client.listServers(forceRefresh: forceRefresh)
            }

            // Update cache
            tui.cacheManager.cachedServers = servers
            lastRefreshTime = Date()

            // Update pagination if enabled
            if let paginationManager = paginationManager {
                await paginationManager.updateFromFilterCache(servers)
            }

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("ServersDataProvider - Fetched \(servers.count) servers", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: servers.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("ServersDataProvider - Fetch timed out", context: [
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
            Logger.shared.logError("ServersDataProvider - Failed to fetch servers: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    func refreshResource(id: String, priority: DataFetchPriority) async -> DataFetchResult {
        guard let tui = tui else {
            return DataFetchResult(
                itemCount: 0,
                duration: 0,
                error: ModuleError.invalidState("TUI reference is nil")
            )
        }

        let startTime = Date()

        do {
            // Fetch single server details
            let server = try await tui.client.getServer(id: id)

            // Update in cache
            if let index = tui.cacheManager.cachedServers.firstIndex(where: { $0.id == id }) {
                tui.cacheManager.cachedServers[index] = server
            } else {
                tui.cacheManager.cachedServers.append(server)
            }

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logDebug("ServersDataProvider - Refreshed server \(id)", context: [
                "duration": String(format: "%.2f", duration)
            ])

            return DataFetchResult(
                itemCount: 1,
                duration: duration,
                fromCache: false
            )

        } catch {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logError("ServersDataProvider - Failed to refresh server \(id): \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    func clearCache() async {
        tui?.cacheManager.cachedServers.removeAll()
        lastRefreshTime = nil
        paginationManager = nil
        Logger.shared.logDebug("ServersDataProvider - Cache cleared")
    }

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
            self.paginationManager = PaginationManager<Server>.forServers(
                data: tui.cacheManager.cachedServers,
                config: config
            )
            await self.paginationManager?.initialLoad()
        }

        return paginationManager?.visibleItems
    }

    // MARK: - Private Methods

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

    private func handleOpenStackError(_ error: OpenStackError) {
        switch error {
        case .httpError(403, _):
            Logger.shared.logDebug("ServersDataProvider - Server access may require admin privileges (HTTP 403)")
        case .httpError(404, _):
            Logger.shared.logDebug("ServersDataProvider - Nova service may not be available (HTTP 404)")
        default:
            Logger.shared.logError("ServersDataProvider - OpenStack error: \(error)")
        }
    }

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

    struct TimeoutError: Error {}
}

/// Extension for batch operations
extension ServersDataProvider: BatchDataProvider {
    func fetchDataInBatches(
        batchSize: Int,
        priority: DataFetchPriority,
        progressHandler: @escaping (Double) -> Void
    ) async -> DataFetchResult {
        // For servers, we typically fetch all at once from the API
        // But we can simulate batch processing for UI updates
        let result = await fetchData(priority: priority, forceRefresh: true)

        // Report completion
        progressHandler(1.0)

        return result
    }
}

/// Extension for detailed fetching
extension ServersDataProvider: DetailedDataProvider {
    func fetchDetailedResource(id: String, includeRelated: Bool) async -> Any? {
        guard let tui = tui else { return nil }

        do {
            let server = try await tui.client.getServer(id: id)

            if includeRelated {
                // Could fetch related resources like attached volumes, networks, etc.
                // For now, just return the server
                return server
            }

            return server
        } catch {
            Logger.shared.logError("ServersDataProvider - Failed to fetch detailed server: \(error)")
            return nil
        }
    }
}