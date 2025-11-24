import Foundation
import OSClient
import struct OSClient.Port

// MARK: - Configuration
struct PaginationConfig {
    let pageSize: Int               // Items per page (renamed for clarity)
    let prefetchThreshold: Double   // When to start prefetching (0.0-1.0)
    let maxCachedPages: Int        // Maximum pages to keep in memory
    let viewportSize: Int          // Items visible at once in UI
    let enableBackgroundLoading: Bool
    let enableMemoryAdaptation: Bool // Adapt page size based on memory pressure

    // Standard configurations for different use cases
    static let small = PaginationConfig(
        pageSize: 50, prefetchThreshold: 0.8, maxCachedPages: 4,
        viewportSize: 20, enableBackgroundLoading: true, enableMemoryAdaptation: true
    )

    static let medium = PaginationConfig(
        pageSize: 100, prefetchThreshold: 0.7, maxCachedPages: 3,
        viewportSize: 25, enableBackgroundLoading: true, enableMemoryAdaptation: true
    )

    static let large = PaginationConfig(
        pageSize: 200, prefetchThreshold: 0.6, maxCachedPages: 2,
        viewportSize: 30, enableBackgroundLoading: true, enableMemoryAdaptation: true
    )

    // Memory-constrained configuration for enterprise environments
    static let enterprise = PaginationConfig(
        pageSize: 500, prefetchThreshold: 0.9, maxCachedPages: 2,
        viewportSize: 50, enableBackgroundLoading: true, enableMemoryAdaptation: true
    )

    static let `default` = medium
}

// MARK: - Supporting Data Structures

// Data source protocol for pagination
@MainActor
protocol PaginationDataSource<T> {
    associatedtype T: Sendable

    // Load a specific page of data
    func loadPage(_ pageNumber: Int, pageSize: Int) async throws -> [T]

    // Get total count (may be expensive, cached when possible)
    func getTotalCount() async throws -> Int

    // Generate hash for change detection
    func getDataHash() async -> String

    // Check if data has changed since last check
    func hasDataChanged(since lastHash: String) async -> Bool
}

// Performance metrics tracking
struct PaginationMetrics {
    var totalLoadTime: TimeInterval = 0
    var averageLoadTime: TimeInterval = 0
    var loadCount: Int = 0
    var cacheHitRate: Double = 0
    var memoryUsage: UInt64 = 0

    mutating func recordLoad(time: TimeInterval) {
        totalLoadTime += time
        loadCount += 1
        averageLoadTime = totalLoadTime / Double(loadCount)
    }

    mutating func recordCacheHit() {
        // Implementation for cache hit tracking
    }
}

// Memory-efficient data source wrapper for existing arrays
@MainActor
class ArrayPaginationDataSource<T: Sendable>: PaginationDataSource {
    private let data: [T]
    private let dataHash: String

    init(_ data: [T]) {
        self.data = data
        self.dataHash = Self.generateHash(from: data)
    }

    func loadPage(_ pageNumber: Int, pageSize: Int) async throws -> [T] {
        let startIndex = pageNumber * pageSize
        let endIndex = min(startIndex + pageSize, data.count)

        guard startIndex < data.count else { return [] }

        return Array(data[startIndex..<endIndex])
    }

    func getTotalCount() async throws -> Int {
        return data.count
    }

    func getDataHash() async -> String {
        return dataHash
    }

    func hasDataChanged(since lastHash: String) async -> Bool {
        return dataHash != lastHash
    }

    private static func generateHash(from data: [T]) -> String {
        if data.isEmpty { return "empty" }
        let count = data.count
        // Use memory addresses for hashing since we can't rely on Hashable
        let firstThree = data.prefix(3).map { "\(ObjectIdentifier(type(of: $0)))" }.joined(separator: "-")
        let lastThree = data.suffix(3).map { "\(ObjectIdentifier(type(of: $0)))" }.joined(separator: "-")
        return "\(count):\(firstThree):\(lastThree)"
    }
}

// Enhanced pagination manager with lazy loading and smart prefetching
@MainActor
class PaginationManager<T: Sendable> {

    // MARK: - State Management

    enum LoadingState {
        case idle
        case loading
        case error(String)
        case partial(Int, Int) // loaded, total
    }

    struct PageInfo {
        let pageNumber: Int
        let startIndex: Int
        let endIndex: Int
        let data: [T]
        let loadTime: Date
        var lastAccessed: Date
        let dataHash: String
    }

    // MARK: - Properties

    private var config: PaginationConfig
    private var pages: [Int: PageInfo] = [:]
    private var totalCount: Int = 0
    private var currentPage: Int = 0
    private var viewportOffset: Int = 0  // Current scroll position within page
    private var selectedIndex: Int = 0

    private(set) var loadingState: LoadingState = .idle
    private var prefetchTasks: Set<Task<Void, Never>> = []

    // Data source and caching integration
    private let dataSource: any PaginationDataSource<T>
    private var lastDataHash: String = ""

    // Memory pressure monitoring
    private var memoryPressureLevel: Int = 0 // 0 = normal, 1 = warning, 2 = critical
    private var lastMemoryCheck: Date = Date()

    // Performance tracking
    private var performanceMetrics = PaginationMetrics()

    // MARK: - Initialization

    init(config: PaginationConfig = .default, dataSource: any PaginationDataSource<T>) {
        self.config = config
        self.dataSource = dataSource
    }

    // Convenience initializer for array data
    convenience init(config: PaginationConfig = .default, data: [T]) {
        let arrayDataSource = ArrayPaginationDataSource(data)
        self.init(config: config, dataSource: arrayDataSource)
    }

    // MARK: - Public Interface

    var visibleItems: [T] {
        guard let pageInfo = pages[currentPage] else { return [] }

        let startIndex = viewportOffset
        let endIndex = min(startIndex + config.viewportSize, pageInfo.data.count)

        guard startIndex < pageInfo.data.count else { return [] }
        return Array(pageInfo.data[startIndex..<endIndex])
    }

    var hasNextPage: Bool {
        return currentPage < totalPages - 1
    }

    var hasPreviousPage: Bool {
        return currentPage > 0
    }

    var currentPageNumber: Int {
        return currentPage + 1  // 1-based for UI display
    }

    var totalPages: Int {
        guard totalCount > 0 else { return 1 }
        return (totalCount + config.pageSize - 1) / config.pageSize
    }

    var totalItemCount: Int {
        return totalCount
    }

    var loadingProgress: (loaded: Int, total: Int)? {
        if case .partial(let loaded, let total) = loadingState {
            return (loaded, total)
        }
        return nil
    }

    // MARK: - Navigation Methods

    func scrollUp() async {
        if viewportOffset > 0 {
            viewportOffset -= 1
        } else if hasPreviousPage {
            _ = await previousPage()
            // Set viewport to end of previous page
            if let pageInfo = pages[currentPage] {
                viewportOffset = max(0, pageInfo.data.count - config.viewportSize)
            }
        }
    }

    func scrollDown() async {
        guard let pageInfo = pages[currentPage] else { return }

        if viewportOffset + config.viewportSize < pageInfo.data.count {
            viewportOffset += 1
        } else if hasNextPage {
            _ = await nextPage()
        }
    }

    func nextPage() async -> [T] {
        guard hasNextPage else { return [] }

        let nextPageNumber = currentPage + 1
        await loadPageIfNeeded(nextPageNumber)

        currentPage = nextPageNumber
        viewportOffset = 0

        // Start prefetching next page
        if config.enableBackgroundLoading {
            await prefetchPage(nextPageNumber + 1)
        }

        return visibleItems
    }

    func previousPage() async -> [T] {
        guard hasPreviousPage else { return [] }

        let prevPageNumber = currentPage - 1
        await loadPageIfNeeded(prevPageNumber)

        currentPage = prevPageNumber
        viewportOffset = 0

        // Start prefetching previous page
        if config.enableBackgroundLoading {
            await prefetchPage(prevPageNumber - 1)
        }

        return visibleItems
    }

    func jumpToPage(_ pageNumber: Int) async {
        let targetPage = max(0, min(pageNumber - 1, totalPages - 1))
        await loadPageIfNeeded(targetPage)

        currentPage = targetPage
        viewportOffset = 0

        // Start prefetching adjacent pages
        if config.enableBackgroundLoading {
            Task { [weak self] in
                guard let self else { return }
                await self.prefetchPage(targetPage + 1)
            }
            Task { [weak self] in
                guard let self else { return }
                await self.prefetchPage(targetPage - 1)
            }
        }
    }

    // MARK: - Data Loading

    func initialLoad() async {
        loadingState = .loading

        do {
            // Get total count and data hash
            totalCount = try await dataSource.getTotalCount()
            let newDataHash = await dataSource.getDataHash()

            // Check if data has changed
            if await dataSource.hasDataChanged(since: lastDataHash) {
                Logger.shared.logDebug("PaginationManager - Data changed, clearing cache")
                pages.removeAll()
                performanceMetrics = PaginationMetrics()
            }

            lastDataHash = newDataHash

            // Load first page
            await loadPageIfNeeded(0)
            currentPage = 0
            viewportOffset = 0

            loadingState = .idle

            // Start background prefetching if enabled and dataset is large
            if config.enableBackgroundLoading && totalCount > config.pageSize {
                Task { [weak self] in
                    guard let self else { return }
                    await self.prefetchPage(1)
                }
            }

        } catch {
            loadingState = .error("Failed to load data: \(error.localizedDescription)")
            Logger.shared.logError("PaginationManager - Initial load failed: \(error)")
        }
    }

    func refresh() async {
        Logger.shared.logInfo("PaginationManager - Refreshing data")
        cancelAllPrefetchTasks()
        pages.removeAll()
        lastDataHash = ""
        await initialLoad()
    }

    private func loadPageIfNeeded(_ pageNumber: Int) async {
        guard pageNumber >= 0 && pageNumber < totalPages else { return }

        // Check if page is already loaded and fresh
        if let pageInfo = pages[pageNumber] {
            // Update access time
            pages[pageNumber] = PageInfo(
                pageNumber: pageInfo.pageNumber,
                startIndex: pageInfo.startIndex,
                endIndex: pageInfo.endIndex,
                data: pageInfo.data,
                loadTime: pageInfo.loadTime,
                lastAccessed: Date(),
                dataHash: pageInfo.dataHash
            )
            return
        }

        await loadPage(pageNumber)
    }

    private func loadPage(_ pageNumber: Int) async {
        guard pageNumber >= 0 && pageNumber < totalPages else { return }

        let startTime = Date().timeIntervalSinceReferenceDate
        loadingState = .loading

        do {
            let pageData = try await dataSource.loadPage(pageNumber, pageSize: config.pageSize)

            let startIndex = pageNumber * config.pageSize
            let endIndex = min(startIndex + pageData.count - 1, totalCount - 1)

            let pageInfo = PageInfo(
                pageNumber: pageNumber,
                startIndex: startIndex,
                endIndex: endIndex,
                data: pageData,
                loadTime: Date(),
                lastAccessed: Date(),
                dataHash: lastDataHash
            )

            pages[pageNumber] = pageInfo
            loadingState = .idle

            // Track performance metrics
            let loadTime = Date().timeIntervalSinceReferenceDate - startTime
            performanceMetrics.recordLoad(time: loadTime)

            Logger.shared.logDebug("PaginationManager - Loaded page \(pageNumber): \(pageData.count) items in \(String(format: "%.3f", loadTime))s")

            // Manage memory by removing old pages
            await performMemoryCleanup()

        } catch {
            loadingState = .error("Failed to load page \(pageNumber): \(error.localizedDescription)")
            Logger.shared.logError("PaginationManager - Page load failed: \(error)")
        }
    }

    // MARK: - Prefetching

    private func prefetchPage(_ pageNumber: Int) async {
        guard config.enableBackgroundLoading else { return }
        guard pageNumber >= 0 && pageNumber < totalPages else { return }
        guard pages[pageNumber] == nil else { return }

        Logger.shared.logDebug("PaginationManager - Prefetching page \(pageNumber)")

        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadPage(pageNumber)
        }
        prefetchTasks.insert(task)
    }

    private func checkPrefetchNeeds() async {
        guard config.enableBackgroundLoading else { return }

        let viewportProgress = Double(viewportOffset + config.viewportSize) / Double(config.pageSize)

        // Check if we should prefetch next page
        if viewportProgress >= config.prefetchThreshold {
            let nextPageNumber = currentPage + 1
            if nextPageNumber < totalPages && pages[nextPageNumber] == nil {
                await prefetchPage(nextPageNumber)
            }
        }

        // Check if we should prefetch previous page
        if Double(viewportOffset) / Double(config.pageSize) <= (1.0 - config.prefetchThreshold) {
            let prevPageNumber = currentPage - 1
            if prevPageNumber >= 0 && pages[prevPageNumber] == nil {
                await prefetchPage(prevPageNumber)
            }
        }
    }

    private func cancelAllPrefetchTasks() {
        prefetchTasks.forEach { $0.cancel() }
        prefetchTasks.removeAll()
    }

    // MARK: - Memory Management

    private func performMemoryCleanup(force: Bool = false) async {
        let currentPageCount = pages.count

        // Check memory pressure periodically
        let now = Date()
        if now.timeIntervalSince(lastMemoryCheck) > 10.0 { // Check every 10 seconds
            await updateMemoryPressure()
            lastMemoryCheck = now
        }

        // Determine if cleanup is needed
        let needsCleanup = force ||
                          currentPageCount > config.maxCachedPages ||
                          memoryPressureLevel >= 1

        guard needsCleanup else { return }

        // Protect current page and adjacent pages
        let protectedPages = Set([
            max(0, currentPage - 1),
            currentPage,
            min(totalPages - 1, currentPage + 1)
        ])

        // Sort pages by access time (LRU first)
        let sortedPages = pages.sorted { $0.value.lastAccessed < $1.value.lastAccessed }

        var removedCount = 0
        let targetRemoveCount = force ? pages.count : max(0, currentPageCount - config.maxCachedPages)

        for (pageNumber, _) in sortedPages {
            if removedCount >= targetRemoveCount { break }

            // Don't remove protected pages unless forcing cleanup
            if !force && protectedPages.contains(pageNumber) { continue }

            pages.removeValue(forKey: pageNumber)
            removedCount += 1
        }

        if removedCount > 0 {
            Logger.shared.logDebug("PaginationManager - Memory cleanup: removed \(removedCount) pages, \(pages.count) remaining")
        }
    }

    private func updateMemoryPressure() async {
        // Estimate memory usage
        let estimatedPageMemory = pages.count * config.pageSize * 1000 // Rough estimate per item
        performanceMetrics.memoryUsage = UInt64(estimatedPageMemory)

        // Update pressure level based on usage
        if estimatedPageMemory > 100 * 1024 * 1024 { // 100MB
            memoryPressureLevel = 2 // Critical
        } else if estimatedPageMemory > 50 * 1024 * 1024 { // 50MB
            memoryPressureLevel = 1 // Warning
        } else {
            memoryPressureLevel = 0 // Normal
        }

        // Adapt configuration if needed
        if config.enableMemoryAdaptation && memoryPressureLevel >= 2 {
            await adaptToMemoryPressure()
        }
    }

    private func adaptToMemoryPressure() async {
        Logger.shared.logInfo("PaginationManager - Adapting to memory pressure level \(memoryPressureLevel)")

        // Reduce cache size and trigger aggressive cleanup
        config = PaginationConfig(
            pageSize: max(25, config.pageSize / 2),
            prefetchThreshold: min(0.95, config.prefetchThreshold + 0.2),
            maxCachedPages: max(1, config.maxCachedPages - 1),
            viewportSize: config.viewportSize,
            enableBackgroundLoading: config.enableBackgroundLoading && memoryPressureLevel < 2,
            enableMemoryAdaptation: config.enableMemoryAdaptation
        )

        // Force cleanup with new constraints
        await performMemoryCleanup(force: true)
    }

    // MARK: - Search and Filtering

    func updateWithFilteredData(_ filteredItems: [T]) async {
        Logger.shared.logDebug("PaginationManager - Updating with filtered data: \(filteredItems.count) items")

        // Clear existing pages and reset state
        pages.removeAll()
        totalCount = filteredItems.count
        currentPage = 0
        viewportOffset = 0

        // Create new data source for filtered data
        let filteredDataSource = ArrayPaginationDataSource(filteredItems)
        lastDataHash = await filteredDataSource.getDataHash()

        // Load first page immediately
        if totalCount > 0 {
            do {
                let firstPageData = try await filteredDataSource.loadPage(0, pageSize: config.pageSize)
                let pageInfo = PageInfo(
                    pageNumber: 0,
                    startIndex: 0,
                    endIndex: min(firstPageData.count - 1, totalCount - 1),
                    data: firstPageData,
                    loadTime: Date(),
                    lastAccessed: Date(),
                    dataHash: lastDataHash
                )
                pages[0] = pageInfo
            } catch {
                Logger.shared.logError("PaginationManager - Failed to load filtered data: \(error)")
            }
        }

        loadingState = .idle
    }

    // MARK: - Status and Diagnostics

    func getStatusInfo() -> String {
        let startItem = currentPage * config.pageSize + viewportOffset + 1
        let endItem = min(startItem + config.viewportSize - 1, totalCount)
        return "[\(startItem)-\(endItem)/\(totalCount)] Page \(currentPageNumber)/\(totalPages)"
    }

    func getLoadingStatusInfo() -> String? {
        switch loadingState {
        case .loading:
            return "Loading..."
        case .error(let message):
            return "Error: \(message)"
        case .partial(let loaded, let total):
            return "Loading \(loaded)/\(total)..."
        case .idle:
            return nil
        }
    }

    func getPerformanceInfo() -> [String: Any] {
        return [
            "total_items": totalCount,
            "current_page": currentPageNumber,
            "total_pages": totalPages,
            "cached_pages": pages.count,
            "page_size": config.pageSize,
            "viewport_size": config.viewportSize,
            "avg_load_time_ms": performanceMetrics.averageLoadTime * 1000,
            "total_load_time": performanceMetrics.totalLoadTime,
            "load_count": performanceMetrics.loadCount,
            "estimated_memory_mb": Double(performanceMetrics.memoryUsage) / (1024 * 1024),
            "memory_pressure_level": memoryPressureLevel,
            "prefetch_enabled": config.enableBackgroundLoading,
            "active_prefetch_tasks": prefetchTasks.count
        ]
    }

    deinit {
        for task in prefetchTasks {
            task.cancel()
        }
    }
}

// MARK: - Convenience Extensions

extension PaginationManager {
    // Factory methods for common OpenStack resource types

    static func forServers(data: [Server] = [], config: PaginationConfig = .medium) -> PaginationManager<Server> {
        return PaginationManager<Server>(config: config, data: data)
    }

    static func forNetworks(data: [Network] = [], config: PaginationConfig = .medium) -> PaginationManager<Network> {
        return PaginationManager<Network>(config: config, data: data)
    }

    static func forVolumes(data: [Volume] = [], config: PaginationConfig = .medium) -> PaginationManager<Volume> {
        return PaginationManager<Volume>(config: config, data: data)
    }

    static func forPorts(data: [Port] = [], config: PaginationConfig = .large) -> PaginationManager<Port> {
        // Use large configuration for ports as they can be numerous
        return PaginationManager<Port>(config: config, data: data)
    }

    static func forImages(data: [Image] = [], config: PaginationConfig = .large) -> PaginationManager<Image> {
        // Use large configuration for images as they can be numerous
        return PaginationManager<Image>(config: config, data: data)
    }

    static func forSecurityGroups(data: [SecurityGroup] = [], config: PaginationConfig = .medium) -> PaginationManager<SecurityGroup> {
        return PaginationManager<SecurityGroup>(config: config, data: data)
    }
}

// MARK: - Integration with FilterCache

extension PaginationManager {
    // Update pagination with filtered data from FilterCache
    func updateFromFilterCache(_ filteredData: [T]) async {
        await updateWithFilteredData(filteredData)
    }

    // Check if current page needs refresh based on data changes
    func shouldRefresh(dataHash: String) -> Bool {
        return lastDataHash != dataHash
    }
}