import Foundation
import CrossPlatformTimer
#if canImport(Combine)
import Combine
#endif

// MARK: - Incremental Data Loading

/// Manages incremental loading of large datasets with intelligent prefetching
@MainActor
public final class IncrementalDataLoader<T: Sendable>: @unchecked Sendable {
    public typealias LoadFunction = (Int, Int) async throws -> (items: [T], hasMore: Bool)

    public var items: [T] = [] {
        didSet { notifyObservers() }
    }
    public var isLoading: Bool = false {
        didSet { notifyObservers() }
    }
    public var hasMoreData: Bool = true {
        didSet { notifyObservers() }
    }
    public var error: (any Error)? {
        didSet { notifyObservers() }
    }

    private var observers: [() -> Void] = []

    public func addObserver(_ observer: @escaping () -> Void) {
        observers.append(observer)
    }

    private func notifyObservers() {
        for observer in observers {
            observer()
        }
    }

    private let pageSize: Int
    private let prefetchThreshold: Int
    private let maxCacheSize: Int
    private let loadFunction: LoadFunction
    private let logger: any OpenStackClientLogger

    private var loadedPages: Set<Int> = []
    private var currentPage: Int = 0
    private var prefetchTask: Task<Void, Never>?

    public init(
        pageSize: Int = 50,
        prefetchThreshold: Int = 10,
        maxCacheSize: Int = 1000,
        logger: any OpenStackClientLogger = ConsoleLogger(),
        loadFunction: @escaping LoadFunction
    ) {
        self.pageSize = pageSize
        self.prefetchThreshold = prefetchThreshold
        self.maxCacheSize = maxCacheSize
        self.loadFunction = loadFunction
        self.logger = logger
    }

    /// Load initial data
    public func loadInitialData() async {
        await reset()
        await loadNextPage()
    }

    /// Load next page of data
    public func loadNextPage() async {
        guard !isLoading && hasMoreData else { return }

        isLoading = true
        error = nil

        do {
            let startIndex = currentPage * pageSize
            let result = try await loadFunction(startIndex, pageSize)

            // Append new items
            items.append(contentsOf: result.items)
            hasMoreData = result.hasMore
            loadedPages.insert(currentPage)
            currentPage += 1

            // Manage cache size
            if items.count > maxCacheSize {
                await trimCache()
            }

            logger.logInfo("Loaded page \(currentPage)", context: [
                "itemCount": result.items.count,
                "totalItems": items.count,
                "hasMore": result.hasMore
            ])

        } catch {
            self.error = error
            logger.logError("Failed to load data page", context: [
                "page": currentPage,
                "error": error.localizedDescription
            ])
        }

        isLoading = false
    }

    /// Prefetch data if user is near the end
    public func checkPrefetch(currentIndex: Int) {
        let remainingItems = items.count - currentIndex
        if remainingItems <= prefetchThreshold && hasMoreData && !isLoading {
            prefetchTask?.cancel()
            prefetchTask = Task {
                await loadNextPage()
            }
        }
    }

    /// Reset loader state
    public func reset() async {
        prefetchTask?.cancel()
        prefetchTask = nil

        items.removeAll()
        loadedPages.removeAll()
        currentPage = 0
        hasMoreData = true
        error = nil
        isLoading = false
    }

    /// Refresh all data
    public func refresh() async {
        await reset()
        await loadInitialData()
    }

    /// Get loading statistics
    public func getLoadingStats() -> LoadingStats {
        return LoadingStats(
            totalItems: items.count,
            loadedPages: loadedPages.count,
            currentPage: currentPage,
            hasMoreData: hasMoreData,
            isLoading: isLoading,
            cacheUsage: Double(items.count) / Double(maxCacheSize)
        )
    }

    // MARK: - Private Methods

    private func trimCache() async {
        let trimCount = items.count - (maxCacheSize * 3 / 4) // Keep 75% of max cache
        if trimCount > 0 {
            items.removeFirst(trimCount)

            // Update loaded pages tracking
            let removedPages = trimCount / pageSize
            loadedPages = Set(loadedPages.compactMap { page in
                page >= removedPages ? page - removedPages : nil
            })
            currentPage = max(0, currentPage - removedPages)

            logger.logInfo("Trimmed cache", context: [
                "removedItems": trimCount,
                "remainingItems": items.count
            ])
        }
    }
}

public struct LoadingStats: Sendable {
    public let totalItems: Int
    public let loadedPages: Int
    public let currentPage: Int
    public let hasMoreData: Bool
    public let isLoading: Bool
    public let cacheUsage: Double

    public var description: String {
        return "Loaded: \(totalItems) items (\(loadedPages) pages), Cache: \(String(format: "%.1f", cacheUsage * 100))%"
    }
}

// MARK: - Streaming Data Manager

/// Manages real-time streaming updates for OpenStack resources
@MainActor
public final class StreamingDataManager<T: Sendable & Identifiable>: @unchecked Sendable {
    public var items: [T] = [] {
        didSet { notifyObservers() }
    }
    public var isStreaming: Bool = false {
        didSet { notifyObservers() }
    }
    public var lastUpdate: Date? {
        didSet { notifyObservers() }
    }

    private var observers: [() -> Void] = []

    public func addObserver(_ observer: @escaping () -> Void) {
        observers.append(observer)
    }

    private func notifyObservers() {
        for observer in observers {
            observer()
        }
    }

    private let maxItems: Int
    private let updateInterval: TimeInterval
    private let streamFunction: () async throws -> [T]
    private let logger: any OpenStackClientLogger

    private var streamingTask: Task<Void, Never>?
    private var itemsById: [T.ID: T] = [:]

    public init(
        maxItems: Int = 5000,
        updateInterval: TimeInterval = 30.0,
        logger: any OpenStackClientLogger = ConsoleLogger(),
        streamFunction: @escaping () async throws -> [T]
    ) {
        self.maxItems = maxItems
        self.updateInterval = updateInterval
        self.streamFunction = streamFunction
        self.logger = logger
    }

    /// Start streaming data updates
    public func startStreaming() {
        guard !isStreaming else { return }

        isStreaming = true
        streamingTask = Task {
            while !Task.isCancelled {
                do {
                    let newItems = try await streamFunction()
                    await updateItems(newItems)

                    try await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                } catch {
                    logger.logError("Streaming update failed", context: [
                        "error": error.localizedDescription
                    ])
                    // Continue streaming despite errors
                    try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                }
            }
        }

        logger.logInfo("Started streaming data updates", context: [
            "updateInterval": updateInterval
        ])
    }

    /// Stop streaming data updates
    public func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false

        logger.logInfo("Stopped streaming data updates", context: [:])
    }

    /// Manually trigger an update
    public func triggerUpdate() async {
        do {
            let newItems = try await streamFunction()
            await updateItems(newItems)
        } catch {
            logger.logError("Manual update failed", context: [
                "error": error.localizedDescription
            ])
        }
    }

    /// Get item by ID
    public func getItem(id: T.ID) -> T? {
        return itemsById[id]
    }

    /// Get streaming statistics
    public func getStreamingStats() -> StreamingStats {
        return StreamingStats(
            itemCount: items.count,
            isStreaming: isStreaming,
            lastUpdate: lastUpdate,
            updateInterval: updateInterval
        )
    }

    // MARK: - Private Methods

    private func updateItems(_ newItems: [T]) async {
        var updatedItems: [T] = []
        var newItemsById: [T.ID: T] = [:]

        // Process new items
        for item in newItems {
            newItemsById[item.id] = item

            if itemsById[item.id] != nil {
                // Update existing item
                updatedItems.append(item)
            } else {
                // New item
                updatedItems.append(item)
            }
        }

        // Keep items that still exist in the new data
        self.items = updatedItems
        self.itemsById = newItemsById
        self.lastUpdate = Date()

        // Trim if necessary
        if items.count > maxItems {
            let trimCount = items.count - maxItems
            let removedItems = Array(items.prefix(trimCount))

            items.removeFirst(trimCount)
            for item in removedItems {
                itemsById.removeValue(forKey: item.id)
            }

            logger.logInfo("Trimmed streaming data", context: [
                "removedItems": trimCount,
                "remainingItems": items.count
            ])
        }

        logger.logInfo("Updated streaming data", context: [
            "newItems": newItems.count,
            "totalItems": items.count
        ])
    }
}

public struct StreamingStats: Sendable {
    public let itemCount: Int
    public let isStreaming: Bool
    public let lastUpdate: Date?
    public let updateInterval: TimeInterval

    public var description: String {
        let status = isStreaming ? "streaming" : "stopped"
        let lastUpdateStr = lastUpdate?.formatted(date: .omitted, time: .shortened) ?? "never"
        return "Status: \(status), Items: \(itemCount), Last update: \(lastUpdateStr)"
    }
}

// MARK: - Hybrid Data Manager

/// Combines incremental loading with real-time streaming
@MainActor
public final class HybridDataManager<T: Sendable & Identifiable>: @unchecked Sendable {
    public var items: [T] = [] {
        didSet { notifyObservers() }
    }
    public var isLoading: Bool = false {
        didSet { notifyObservers() }
    }
    public var isStreaming: Bool = false {
        didSet { notifyObservers() }
    }
    public var loadingStats: LoadingStats? {
        didSet { notifyObservers() }
    }
    public var streamingStats: StreamingStats? {
        didSet { notifyObservers() }
    }

    private var observers: [() -> Void] = []

    public func addObserver(_ observer: @escaping () -> Void) {
        observers.append(observer)
    }

    private func notifyObservers() {
        for observer in observers {
            observer()
        }



    }

    private let incrementalLoader: IncrementalDataLoader<T>
    private let streamingManager: StreamingDataManager<T>
    private let mode: DataMode
    private let logger: any OpenStackClientLogger

    public enum DataMode {
        case incremental    // Load data in pages
        case streaming      // Real-time updates
        case hybrid         // Incremental loading + streaming updates
    }

    public init(
        mode: DataMode = .hybrid,
        pageSize: Int = 50,
        maxItems: Int = 5000,
        updateInterval: TimeInterval = 30.0,
        logger: any OpenStackClientLogger = ConsoleLogger(),
        loadFunction: @escaping IncrementalDataLoader<T>.LoadFunction,
        streamFunction: @escaping () async throws -> [T]
    ) {
        self.mode = mode
        self.logger = logger

        self.incrementalLoader = IncrementalDataLoader(
            pageSize: pageSize,
            maxCacheSize: maxItems,
            logger: logger,
            loadFunction: loadFunction
        )

        self.streamingManager = StreamingDataManager(
            maxItems: maxItems,
            updateInterval: updateInterval,
            logger: logger,
            streamFunction: streamFunction
        )

        setupObservers()
    }

    /// Start data management
    public func start() async {
        switch mode {
        case .incremental:
            await incrementalLoader.loadInitialData()

        case .streaming:
            streamingManager.startStreaming()

        case .hybrid:
            await incrementalLoader.loadInitialData()
            streamingManager.startStreaming()
        }
    }

    /// Stop data management
    public func stop() {
        streamingManager.stopStreaming()
    }

    /// Load more data (for incremental mode)
    public func loadMore() async {
        await incrementalLoader.loadNextPage()
    }

    /// Check if more data should be prefetched
    public func checkPrefetch(currentIndex: Int) {
        incrementalLoader.checkPrefetch(currentIndex: currentIndex)
    }

    /// Refresh all data
    public func refresh() async {
        switch mode {
        case .incremental:
            await incrementalLoader.refresh()

        case .streaming:
            await streamingManager.triggerUpdate()

        case .hybrid:
            await incrementalLoader.refresh()
            await streamingManager.triggerUpdate()
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe incremental loader
        incrementalLoader.addObserver { [weak self] in
            Task { @MainActor in
                self?.items = self?.incrementalLoader.items ?? []
                self?.isLoading = self?.incrementalLoader.isLoading ?? false
            }
        }

        // Observe streaming manager
        streamingManager.addObserver { [weak self] in
            Task { @MainActor in
                self?.isStreaming = self?.streamingManager.isStreaming ?? false
            }
        }

        // Update stats periodically
        let _ = createCompatibleTimer(interval: 5.0, repeats: true, action: { [weak self] in
            Task { @MainActor in
                self?.updateStats()
            }
        })
    }

    private func updateStats() {
        loadingStats = incrementalLoader.getLoadingStats()
        streamingStats = streamingManager.getStreamingStats()
    }
}

// MARK: - Resource-Specific Data Managers

/// Data manager specifically for OpenStack servers
public typealias HybridServerDataManager = HybridDataManager<Server>

/// Data manager specifically for OpenStack networks
public typealias HybridNetworkDataManager = HybridDataManager<Network>

/// Data manager specifically for OpenStack volumes
public typealias HybridVolumeDataManager = HybridDataManager<Volume>

// MARK: - Extensions for OpenStack Resources

// OpenStack resources already have id properties, so they automatically conform to Identifiable
extension Server: Identifiable {}
extension Network: Identifiable {}
extension Volume: Identifiable {}
extension Image: Identifiable {}