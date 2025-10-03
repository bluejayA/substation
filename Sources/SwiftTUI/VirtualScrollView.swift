import Foundation
import CNCurses
import MemoryKit

// MARK: - Virtual Scrolling Component

/// High-performance virtual scrolling component for large datasets
public struct VirtualScrollView<Item: Sendable, ItemView: Component>: Component {
    private let items: [Item]
    private let itemHeight: Int32
    private let renderItem: @Sendable (Item, Bool) -> ItemView
    private let scrollOffset: Int
    private let selectedIndex: Int?

    public init(
        items: [Item],
        itemHeight: Int32 = 1,
        scrollOffset: Int = 0,
        selectedIndex: Int? = nil,
        renderItem: @escaping @Sendable (Item, Bool) -> ItemView
    ) {
        self.items = items
        self.itemHeight = itemHeight
        self.scrollOffset = scrollOffset
        self.selectedIndex = selectedIndex
        self.renderItem = renderItem
    }

    public var intrinsicSize: Size {
        return Size(width: 80, height: Int32(items.count) * itemHeight)
    }

    @MainActor
    public func render(in context: DrawingContext) async {
        let rect = context.bounds
        let surface = context.surface
        guard !items.isEmpty else {
            // Render empty state
            let emptyText = Text("No items to display").secondary()
            await emptyText.render(in: context)
            return
        }

        let visibleItemCount = Int(rect.size.height / itemHeight)
        let startIndex = max(0, scrollOffset)
        let endIndex = min(items.count, startIndex + visibleItemCount)

        // Log performance for large lists
        if items.count > 100 {
            SwiftTUILoggerConfig.shared.logger.logDebug("SwiftTUI: VirtualScrollView rendering", context: [
                "totalItems": items.count,
                "visibleItems": endIndex - startIndex,
                "scrollOffset": scrollOffset
            ])
        }

        // Clear the area first
        await surface.fill(rect: rect, character: " ", style: .primary)

        // Render visible items
        for i in startIndex..<endIndex {
            let item = items[i]
            let isSelected = selectedIndex == i
            _ = Rect(
                x: rect.origin.col,
                y: rect.origin.row + Int32(i - startIndex) * itemHeight,
                width: rect.size.width,
                height: itemHeight
            )

            let itemView = renderItem(item, isSelected)
            let itemContext = context.subContext(rect: Rect(
                origin: Position(
                    row: Int32(i - startIndex) * itemHeight,
                    col: 0
                ),
                size: Size(width: rect.size.width, height: itemHeight)
            ))
            await itemView.render(in: itemContext)
        }
    }
}

// MARK: - Virtual List Controller

/// Controller for managing virtual scrolling state and behavior
@MainActor
public final class VirtualListController: @unchecked Sendable {

    // MARK: - MemoryKit Integration

    private let memoryManager: SwiftTUIMemoryManager
    private let listId: String
    public var scrollOffset: Int = 0 {
        didSet { notifyObservers() }
    }
    public var selectedIndex: Int = 0 {
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

    private let itemHeight: Int32
    private let viewportHeight: Int32
    private var itemCount: Int = 0

    public init(itemHeight: Int32 = 1, viewportHeight: Int32) {
        self.itemHeight = itemHeight
        self.viewportHeight = viewportHeight
        self.listId = "virtuallist_\(UUID().uuidString)"
        self.memoryManager = SwiftTUILoggerConfig.shared.createMemoryManager()
    }

    /// Update the total number of items
    public func updateItemCount(_ count: Int) {
        itemCount = count
        // Ensure selection and scroll are within bounds
        validateSelection()
        validateScroll()

        // Cache the updated state
        Task {
            await cacheCurrentState()
        }
    }

    /// Move selection up
    public func moveSelectionUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
            ensureSelectionVisible()
            Task {
                await cacheCurrentState()
            }
        }
    }

    /// Move selection down
    public func moveSelectionDown() {
        if selectedIndex < itemCount - 1 {
            selectedIndex += 1
            ensureSelectionVisible()
            Task {
                await cacheCurrentState()
            }
        }
    }

    /// Move selection to specific index
    public func moveSelection(to index: Int) {
        selectedIndex = max(0, min(index, itemCount - 1))
        ensureSelectionVisible()
        Task {
            await cacheCurrentState()
        }
    }

    /// Scroll up by one page
    public func scrollPageUp() {
        let pageSize = Int(viewportHeight / itemHeight)
        scrollOffset = max(0, scrollOffset - pageSize)
        selectedIndex = max(0, selectedIndex - pageSize)
        Task {
            await cacheCurrentState()
        }
    }

    /// Scroll down by one page
    public func scrollPageDown() {
        let pageSize = Int(viewportHeight / itemHeight)
        let maxScroll = max(0, itemCount - Int(viewportHeight / itemHeight))
        scrollOffset = min(maxScroll, scrollOffset + pageSize)
        selectedIndex = min(itemCount - 1, selectedIndex + pageSize)
        Task {
            await cacheCurrentState()
        }
    }

    /// Scroll to top
    public func scrollToTop() {
        scrollOffset = 0
        selectedIndex = 0
        Task {
            await cacheCurrentState()
        }
    }

    /// Scroll to bottom
    public func scrollToBottom() {
        let visibleItems = Int(viewportHeight / itemHeight)
        scrollOffset = max(0, itemCount - visibleItems)
        selectedIndex = max(0, itemCount - 1)
        Task {
            await cacheCurrentState()
        }
    }

    /// Get current visible range
    public func getVisibleRange() -> Range<Int> {
        let visibleItems = Int(viewportHeight / itemHeight)
        let start = max(0, scrollOffset)
        let end = min(itemCount, start + visibleItems)
        return start..<end
    }

    /// Get pagination info
    public func getPaginationInfo() -> PaginationInfo {
        let visibleItems = Int(viewportHeight / itemHeight)
        let totalPages = max(1, (itemCount + visibleItems - 1) / visibleItems)
        let currentPage = max(1, (scrollOffset / visibleItems) + 1)

        return PaginationInfo(
            currentPage: currentPage,
            totalPages: totalPages,
            visibleItems: visibleItems,
            totalItems: itemCount,
            selectedIndex: selectedIndex
        )
    }

    // MARK: - Private Methods

    private func ensureSelectionVisible() {
        let visibleItems = Int(viewportHeight / itemHeight)

        if selectedIndex < scrollOffset {
            // Selection is above visible area
            scrollOffset = selectedIndex
        } else if selectedIndex >= scrollOffset + visibleItems {
            // Selection is below visible area
            scrollOffset = selectedIndex - visibleItems + 1
        }

        validateScroll()
    }

    private func validateSelection() {
        selectedIndex = max(0, min(selectedIndex, itemCount - 1))
    }

    private func validateScroll() {
        let visibleItems = Int(viewportHeight / itemHeight)
        let maxScroll = max(0, itemCount - visibleItems)
        scrollOffset = max(0, min(scrollOffset, maxScroll))
    }

    // MARK: - MemoryKit Cache Operations

    /// Cache current state for performance optimization
    private func cacheCurrentState() async {
        let visibleRange = getVisibleRange()
        let rangeData = RangeData(startIndex: visibleRange.lowerBound, endIndex: visibleRange.upperBound)
        let state = VirtualListState(
            listId: listId,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            itemCount: itemCount,
            visibleRange: rangeData
        )
        await memoryManager.cacheVirtualListState(state, forKey: listId)
    }

    /// Restore state from cache if available
    public func restoreStateFromCache() async {
        if let cachedState = await memoryManager.getCachedVirtualListState(forKey: listId) {
            scrollOffset = cachedState.scrollOffset
            selectedIndex = cachedState.selectedIndex
            itemCount = cachedState.itemCount
            validateSelection()
            validateScroll()
            notifyObservers()
        }
    }

    /// Clear cached state
    public func clearCachedState() async {
        await memoryManager.clearCache(type: .virtualLists)
    }
}

// MARK: - Pagination Information

public struct PaginationInfo: Sendable {
    public let currentPage: Int
    public let totalPages: Int
    public let visibleItems: Int
    public let totalItems: Int
    public let selectedIndex: Int

    public var description: String {
        return "Page \(currentPage)/\(totalPages) (\(selectedIndex + 1)/\(totalItems))"
    }

    public var shortDescription: String {
        return "\(selectedIndex + 1)/\(totalItems)"
    }
}

// MARK: - Scroll Indicators

/// Component for rendering scroll indicators
public struct ScrollIndicator: Component {
    private let paginationInfo: PaginationInfo
    private let showPageInfo: Bool
    private let showProgressBar: Bool

    public init(
        paginationInfo: PaginationInfo,
        showPageInfo: Bool = true,
        showProgressBar: Bool = true
    ) {
        self.paginationInfo = paginationInfo
        self.showPageInfo = showPageInfo
        self.showProgressBar = showProgressBar
    }

    public var intrinsicSize: Size {
        return Size(width: 40, height: showProgressBar ? 2 : 1)
    }

    @MainActor
    public func render(in context: DrawingContext) async {
        let rect = context.bounds
        let surface = context.surface
        // Clear area
        await surface.fill(rect: rect, character: " ", style: .secondary)

        if showPageInfo {
            let pageText = Text(paginationInfo.description).accent()
            _ = Rect(
                x: rect.origin.col,
                y: rect.origin.row,
                width: min(rect.size.width, Int32(paginationInfo.description.count)),
                height: 1
            )
            let pageContext = context.subContext(rect: Rect(
                origin: Position(row: 0, col: 0),
                size: Size(width: min(rect.size.width, Int32(paginationInfo.description.count)), height: 1)
            ))
            await pageText.render(in: pageContext)
        }

        if showProgressBar && rect.size.height > 1 {
            _ = Rect(
                x: rect.origin.col,
                y: rect.origin.row + (showPageInfo ? 1 : 0),
                width: rect.size.width,
                height: 1
            )
            let progressContext = context.subContext(rect: Rect(
                origin: Position(row: showPageInfo ? 1 : 0, col: 0),
                size: Size(width: rect.size.width, height: 1)
            ))
            await renderProgressBar(in: progressContext)
        }
    }

    @MainActor
    private func renderProgressBar(in context: DrawingContext) async {
        let rect = context.bounds
        let surface = context.surface
        guard paginationInfo.totalItems > 0 else { return }

        let progress = Double(paginationInfo.selectedIndex) / Double(paginationInfo.totalItems - 1)
        let barWidth = Int(rect.size.width)
        let filledWidth = Int(Double(barWidth) * progress)

        for x in 0..<barWidth {
            let char: Character = x < filledWidth ? "=" : "-"
            let style: TextStyle = x < filledWidth ? .accent : .secondary

            let charRect = Rect(x: rect.origin.col + Int32(x), y: rect.origin.row, width: 1, height: 1)
            let charText = Text(String(char)).styled(style)
            await charText.render(on: surface, in: charRect)
        }
    }
}

// MARK: - List Search Integration

/// Search functionality for virtual lists
public final class ListSearchController: @unchecked Sendable {

    // MARK: - MemoryKit Integration

    private let memoryManager: SwiftTUIMemoryManager
    private let searchId: String
    public var searchQuery: String = "" {
        didSet {
            updateSearchResults()
            notifyObservers()
        }
    }
    public var searchResults: [Int] = [] {
        didSet { notifyObservers() }
    }
    public var currentResultIndex: Int = -1 {
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

    private var allItems: [Any] = []
    private var searchableText: (Any) -> String = { _ in "" }

    public init() {
        self.searchId = "search_\(UUID().uuidString)"
        self.memoryManager = SwiftTUILoggerConfig.shared.createMemoryManager()
    }

    /// Configure search
    public func configure<T>(
        items: [T],
        searchableText: @escaping (T) -> String
    ) {
        self.allItems = items
        self.searchableText = { item in
            guard let typedItem = item as? T else { return "" }
            return searchableText(typedItem)
        }
        updateSearchResults()
    }

    /// Update search query
    public func updateQuery(_ query: String) {
        searchQuery = query
        updateSearchResults()

        // Cache search state
        Task {
            await cacheSearchState()
        }
    }

    /// Move to next search result
    public func nextResult() -> Int? {
        guard !searchResults.isEmpty else { return nil }

        currentResultIndex = (currentResultIndex + 1) % searchResults.count
        return searchResults[currentResultIndex]
    }

    /// Move to previous search result
    public func previousResult() -> Int? {
        guard !searchResults.isEmpty else { return nil }

        currentResultIndex = currentResultIndex <= 0 ?
            searchResults.count - 1 : currentResultIndex - 1
        return searchResults[currentResultIndex]
    }

    /// Clear search
    public func clearSearch() {
        searchQuery = ""
        searchResults = []
        currentResultIndex = -1

        // Clear cached search state
        Task {
            await clearCachedSearchState()
        }
    }

    /// Get search status
    public func getSearchStatus() -> SearchStatus {
        return SearchStatus(
            query: searchQuery,
            resultCount: searchResults.count,
            currentIndex: currentResultIndex,
            hasResults: !searchResults.isEmpty
        )
    }

    // MARK: - Private Methods

    private func updateSearchResults() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            currentResultIndex = -1
            return
        }

        let query = searchQuery.lowercased()
        searchResults = allItems.enumerated().compactMap { index, item in
            let text = searchableText(item).lowercased()
            return text.contains(query) ? index : nil
        }

        currentResultIndex = searchResults.isEmpty ? -1 : 0

        // Cache updated search results
        Task {
            await cacheSearchState()
        }
    }

    // MARK: - MemoryKit Cache Operations

    /// Cache current search state
    private func cacheSearchState() async {
        let searchState = SearchState(
            searchId: searchId,
            query: searchQuery,
            results: searchResults,
            currentIndex: currentResultIndex,
            hasResults: !searchResults.isEmpty
        )
        await memoryManager.cacheSearchState(searchState, forKey: searchId)
    }

    /// Clear cached search state
    private func clearCachedSearchState() async {
        await memoryManager.clearSearchCache(forKey: searchId)
    }

    /// Restore search state from cache
    public func restoreSearchStateFromCache() async {
        if let cachedState = await memoryManager.getCachedSearchState(forKey: searchId) {
            searchQuery = cachedState.query
            searchResults = cachedState.results
            currentResultIndex = cachedState.currentIndex
            notifyObservers()
        }
    }
}

public struct SearchStatus {
    public let query: String
    public let resultCount: Int
    public let currentIndex: Int
    public let hasResults: Bool

    public var description: String {
        guard hasResults else {
            return query.isEmpty ? "" : "No matches for '\(query)'"
        }

        return "\(currentIndex + 1)/\(resultCount) matches for '\(query)'"
    }
}

// MARK: - Search State for Caching

public struct SearchState: Sendable, Codable {
    public let searchId: String
    public let query: String
    public let results: [Int]
    public let currentIndex: Int
    public let hasResults: Bool
    public let timestamp: Date

    public init(searchId: String, query: String, results: [Int], currentIndex: Int, hasResults: Bool) {
        self.searchId = searchId
        self.query = query
        self.results = results
        self.currentIndex = currentIndex
        self.hasResults = hasResults
        self.timestamp = Date()
    }
}

// MARK: - Performance Optimized List View

/// High-performance list view combining virtual scrolling with search
public struct OptimizedListView<Item: Sendable>: Component {
    private let items: [Item]
    private let controller: VirtualListController
    private let searchController: ListSearchController?
    private let renderItem: @Sendable (Item, Bool, Bool) -> any Component
    private let getItemText: @Sendable (Item) -> String

    public init(
        items: [Item],
        controller: VirtualListController,
        searchController: ListSearchController? = nil,
        getItemText: @escaping @Sendable (Item) -> String,
        renderItem: @escaping @Sendable (Item, Bool, Bool) -> any Component
    ) {
        self.items = items
        self.controller = controller
        self.searchController = searchController
        self.getItemText = getItemText
        self.renderItem = renderItem
    }

    public var intrinsicSize: Size {
        return Size(width: 80, height: Int32(items.count))
    }

    @MainActor
    public func render(in context: DrawingContext) async {
        let rect = context.bounds
        let surface = context.surface
        // Update controllers at render time
        controller.updateItemCount(items.count)
        searchController?.configure(items: items, searchableText: getItemText)

        let paginationInfo = controller.getPaginationInfo()
        let searchStatus = searchController?.getSearchStatus()

        // Calculate layout
        let headerHeight: Int32 = (searchStatus?.hasResults == true) ? 1 : 0
        let footerHeight: Int32 = 2 // For pagination and scroll bar
        let listHeight = rect.size.height - headerHeight - footerHeight

        // Render search status
        if let searchStatus = searchStatus, searchStatus.hasResults {
            let searchRect = Rect(x: rect.origin.col, y: rect.origin.row, width: rect.size.width, height: 1)
            let searchText = Text(searchStatus.description).warning()
            await searchText.render(on: surface, in: searchRect)
        }

        // Render virtual list
        let listRect = Rect(
            x: rect.origin.col,
            y: rect.origin.row + headerHeight,
            width: rect.size.width,
            height: listHeight
        )

        await renderVirtualList(on: surface, in: listRect, paginationInfo: paginationInfo)

        // Render pagination and scroll indicator
        let footerRect = Rect(
            x: rect.origin.col,
            y: rect.origin.row + headerHeight + listHeight,
            width: rect.size.width,
            height: footerHeight
        )

        let scrollIndicator = ScrollIndicator(paginationInfo: paginationInfo)
        await scrollIndicator.render(on: surface, in: footerRect)
    }

    @MainActor
    private func renderVirtualList(
        on surface: any Surface,
        in rect: Rect,
        paginationInfo: PaginationInfo
    ) async {
        let visibleRange = controller.getVisibleRange()

        for (displayIndex, itemIndex) in visibleRange.enumerated() {
            guard itemIndex < items.count else { break }

            let item = items[itemIndex]
            let isSelected = itemIndex == controller.selectedIndex
            let isSearchResult = searchController?.searchResults.contains(itemIndex) ?? false

            let itemRect = Rect(
                x: rect.origin.col,
                y: rect.origin.row + Int32(displayIndex),
                width: rect.size.width,
                height: 1
            )

            let itemView = renderItem(item, isSelected, isSearchResult)
            await itemView.render(on: surface, in: itemRect)
        }
    }
}