// Sources/Substation/Modules/Images/ImagesDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Glance Images
///
/// This provider handles all data fetching operations for images,
/// replacing the centralized fetchImages() method in DataManager.
@MainActor
final class ImagesDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: ImagesModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    // MARK: - DataProvider Protocol

    let resourceType: String = "images"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedImages.count ?? 0
    }

    // MARK: - Initialization

    /// Initialize the ImagesDataProvider
    ///
    /// - Parameters:
    ///   - module: The parent ImagesModule
    ///   - tui: The TUI instance for client and cache access
    init(module: ImagesModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

    /// Fetch images data from the API
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
            Logger.shared.logDebug("ImagesDataProvider - Fetching images", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            // Determine timeout based on priority
            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch images with appropriate timeout
            // Note: listImages does not support forceRefresh parameter
            let images: [Image]
            if timeoutSeconds > 0 {
                images = try await withTimeout(seconds: timeoutSeconds) {
                    try await tui.client.listImages()
                }
            } else {
                images = try await tui.client.listImages()
            }

            // Update cache
            tui.cacheManager.cachedImages = images
            lastRefreshTime = Date()

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("ImagesDataProvider - Fetched \(images.count) images", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: images.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("ImagesDataProvider - Fetch timed out", context: [
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
            Logger.shared.logError("ImagesDataProvider - Failed to fetch images: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    /// Clear cached image data
    func clearCache() async {
        tui?.cacheManager.cachedImages.removeAll()
        lastRefreshTime = nil
        Logger.shared.logDebug("ImagesDataProvider - Cache cleared")
    }

    // MARK: - Private Methods

    /// Get timeout duration based on fetch priority
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
            Logger.shared.logDebug("ImagesDataProvider - Image access may require admin privileges (HTTP 403)")
        case .httpError(404, _):
            Logger.shared.logDebug("ImagesDataProvider - Glance service may not be available (HTTP 404)")
        default:
            Logger.shared.logError("ImagesDataProvider - OpenStack error: \(error)")
        }
    }

    /// Execute an operation with a timeout
    ///
    /// - Parameters:
    ///   - seconds: Timeout duration in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: TimeoutError if operation exceeds timeout, or any error from operation
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
