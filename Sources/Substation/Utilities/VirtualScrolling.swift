import Foundation
import OSClient
import SwiftTUI
import struct OSClient.Port

// MARK: - Virtual Scrolling Configuration
struct VirtualScrollConfig {
    let viewportHeight: Int      // Number of visible lines
    let bufferSize: Int          // Extra lines rendered above/below viewport
    let minimumItemHeight: Int   // Minimum height per item (usually 1 for text)
    let maxRenderItems: Int      // Maximum items to render at once
    let scrollSensitivity: Double // Scroll speed multiplier (0.5-2.0)

    static let `default` = VirtualScrollConfig(
        viewportHeight: 20,
        bufferSize: 5,
        minimumItemHeight: 1,
        maxRenderItems: 30,
        scrollSensitivity: 1.0
    )

    static let compact = VirtualScrollConfig(
        viewportHeight: 15,
        bufferSize: 3,
        minimumItemHeight: 1,
        maxRenderItems: 21,
        scrollSensitivity: 1.2
    )

    static let large = VirtualScrollConfig(
        viewportHeight: 30,
        bufferSize: 10,
        minimumItemHeight: 1,
        maxRenderItems: 50,
        scrollSensitivity: 0.8
    )
}

// MARK: - Virtual Item Information
struct VirtualItem<T> {
    let index: Int          // Original index in data
    let data: T             // The actual data item
    let estimatedHeight: Int // Estimated rendering height
    let isVisible: Bool     // Currently in viewport
    let renderOffset: Int   // Y offset for rendering
}

// MARK: - Virtual Viewport State
struct VirtualViewport {
    var scrollOffset: Int = 0        // Current scroll position (items)
    var topIndex: Int = 0            // First visible item index
    var bottomIndex: Int = 0         // Last visible item index
    var visibleItemCount: Int = 0    // Number of items in viewport
    var totalHeight: Int = 0         // Total scrollable height
    var viewportHeight: Int = 0      // Height of visible area
    var needsRedraw: Bool = true     // Flag to trigger redraw

    mutating func updateBounds(totalItems: Int, config: VirtualScrollConfig) {
        totalHeight = totalItems * config.minimumItemHeight
        viewportHeight = config.viewportHeight

        // Ensure scroll offset is within bounds
        let maxScroll = max(0, totalItems - config.viewportHeight)
        scrollOffset = max(0, min(scrollOffset, maxScroll))

        // Calculate visible range
        topIndex = scrollOffset
        bottomIndex = min(totalItems - 1, scrollOffset + config.viewportHeight - 1)
        visibleItemCount = max(0, bottomIndex - topIndex + 1)

        needsRedraw = true
    }
}

// MARK: - Main Virtual Scrolling Manager
@MainActor
class VirtualScrollManager<T: Sendable> {

    // MARK: - Configuration and State
    private let config: VirtualScrollConfig
    private var viewport = VirtualViewport()
    private var items: [T] = []
    private var virtualItems: [VirtualItem<T>] = []

    // Performance tracking
    private var lastRenderTime: Date = Date()
    private var renderCount: Int = 0
    private var averageRenderTime: TimeInterval = 0

    // Scroll momentum for smooth scrolling
    private var scrollVelocity: Double = 0
    private var lastScrollTime: Date = Date()
    private let momentumDecay: Double = 0.85

    // Integration with pagination
    private var paginationManager: PaginationManager<T>?

    // MARK: - Initialization

    init(config: VirtualScrollConfig = .default) {
        self.config = config
        viewport.viewportHeight = config.viewportHeight
    }

    convenience init(config: VirtualScrollConfig = .default, paginationManager: PaginationManager<T>) {
        self.init(config: config)
        self.paginationManager = paginationManager
    }

    // MARK: - Data Management

    func updateData(_ newData: [T]) {
        items = newData
        rebuildVirtualItems()
        viewport.updateBounds(totalItems: items.count, config: config)

        Logger.shared.logDebug("VirtualScrollManager - Updated with \(newData.count) items, viewport: \(viewport.topIndex)-\(viewport.bottomIndex)")
    }

    func appendData(_ additionalData: [T]) {
        items.append(contentsOf: additionalData)
        rebuildVirtualItems()
        viewport.updateBounds(totalItems: items.count, config: config)

        Logger.shared.logDebug("VirtualScrollManager - Appended \(additionalData.count) items, total: \(items.count)")
    }

    private func rebuildVirtualItems() {
        let startTime = Date().timeIntervalSinceReferenceDate

        virtualItems = items.enumerated().map { index, item in
            let isInViewport = index >= viewport.topIndex && index <= viewport.bottomIndex

            return VirtualItem(
                index: index,
                data: item,
                estimatedHeight: config.minimumItemHeight,
                isVisible: isInViewport,
                renderOffset: index * config.minimumItemHeight
            )
        }

        let buildTime = Date().timeIntervalSinceReferenceDate - startTime
        Logger.shared.logDebug("VirtualScrollManager - Rebuilt \(virtualItems.count) virtual items in \(String(format: "%.3f", buildTime))s")
    }

    // MARK: - Viewport and Scrolling

    var visibleItems: [VirtualItem<T>] {
        let startIndex = max(0, viewport.topIndex - config.bufferSize)
        let endIndex = min(virtualItems.count - 1, viewport.bottomIndex + config.bufferSize)

        guard startIndex <= endIndex else { return [] }

        return Array(virtualItems[startIndex...endIndex])
    }

    var currentViewportInfo: VirtualViewport {
        return viewport
    }

    func scrollUp(lines: Int = 1) async {
        let adjustedLines = Int(Double(lines) * config.scrollSensitivity)
        let newOffset = max(0, viewport.scrollOffset - adjustedLines)

        if newOffset != viewport.scrollOffset {
            viewport.scrollOffset = newOffset
            await updateScrollPosition()
        }
    }

    func scrollDown(lines: Int = 1) async {
        let adjustedLines = Int(Double(lines) * config.scrollSensitivity)
        let maxOffset = max(0, items.count - config.viewportHeight)
        let newOffset = min(maxOffset, viewport.scrollOffset + adjustedLines)

        if newOffset != viewport.scrollOffset {
            viewport.scrollOffset = newOffset
            await updateScrollPosition()
        }
    }

    func pageUp() async {
        await scrollUp(lines: config.viewportHeight)
    }

    func pageDown() async {
        await scrollDown(lines: config.viewportHeight)
    }

    func scrollToTop() async {
        if viewport.scrollOffset != 0 {
            viewport.scrollOffset = 0
            await updateScrollPosition()
        }
    }

    func scrollToBottom() async {
        let maxOffset = max(0, items.count - config.viewportHeight)
        if viewport.scrollOffset != maxOffset {
            viewport.scrollOffset = maxOffset
            await updateScrollPosition()
        }
    }

    func scrollToItem(index: Int) async {
        let targetOffset = max(0, min(index, items.count - config.viewportHeight))
        if viewport.scrollOffset != targetOffset {
            viewport.scrollOffset = targetOffset
            await updateScrollPosition()
        }
    }

    private func updateScrollPosition() async {
        viewport.updateBounds(totalItems: items.count, config: config)
        rebuildVirtualItems()

        // Update pagination if available
        if let paginationManager = paginationManager {
            await checkPaginationNeeds(paginationManager: paginationManager)
        }

        updateScrollMomentum()
    }

    private func updateScrollMomentum() {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastScrollTime)
        lastScrollTime = now

        // Apply momentum decay
        if timeDelta < 0.1 { // Within 100ms, maintain momentum
            scrollVelocity *= momentumDecay
        } else {
            scrollVelocity = 0 // Reset momentum after pause
        }
    }

    // MARK: - Pagination Integration

    private func checkPaginationNeeds(paginationManager: PaginationManager<T>) async {
        let totalItems = paginationManager.totalItemCount

        // Check if we need to load next page
        let itemsFromEnd = totalItems - (viewport.bottomIndex + 1)
        if itemsFromEnd < config.bufferSize && paginationManager.hasNextPage {
            Logger.shared.logDebug("VirtualScrollManager - Triggering next page load (items from end: \(itemsFromEnd))")
            let nextPageItems = await paginationManager.nextPage()
            if !nextPageItems.isEmpty {
                appendData(nextPageItems)
            }
        }

        // Check if we need to load previous page
        if viewport.topIndex < config.bufferSize && paginationManager.hasPreviousPage {
            Logger.shared.logDebug("VirtualScrollManager - Triggering previous page load (items from top: \(viewport.topIndex))")
            let prevPageItems = await paginationManager.previousPage()
            if !prevPageItems.isEmpty {
                // Insert at beginning and adjust scroll position
                let oldScrollOffset = viewport.scrollOffset
                items.insert(contentsOf: prevPageItems, at: 0)
                rebuildVirtualItems()
                viewport.scrollOffset = oldScrollOffset + prevPageItems.count
                viewport.updateBounds(totalItems: items.count, config: config)
            }
        }
    }

    // MARK: - Rendering Support

    func getRenderableItems(startRow: Int32, endRow: Int32) -> [(item: T, row: Int32, index: Int)] {
        let startTime = Date().timeIntervalSinceReferenceDate

        var renderableItems: [(item: T, row: Int32, index: Int)] = []
        let visibleVirtualItems = visibleItems

        for virtualItem in visibleVirtualItems {
            let itemRow = Int32(virtualItem.renderOffset - viewport.scrollOffset) + startRow

            // Only include items that fit within the rendering bounds
            if itemRow >= startRow && itemRow <= endRow {
                renderableItems.append((
                    item: virtualItem.data,
                    row: itemRow,
                    index: virtualItem.index
                ))
            }
        }

        let renderTime = Date().timeIntervalSinceReferenceDate - startTime
        trackRenderTime(renderTime)

        Logger.shared.logDebug("VirtualScrollManager - Generated \(renderableItems.count) renderable items in \(String(format: "%.3f", renderTime))s")

        return renderableItems
    }

    private func trackRenderTime(_ time: TimeInterval) {
        renderCount += 1
        averageRenderTime = ((averageRenderTime * Double(renderCount - 1)) + time) / Double(renderCount)

        if renderCount % 100 == 0 { // Log every 100 renders
            Logger.shared.logInfo("VirtualScrollManager - Avg render time over \(renderCount) renders: \(String(format: "%.3f", averageRenderTime * 1000))ms")
        }
    }

    // MARK: - Status and Diagnostics

    func getScrollInfo() -> String {
        let percentage = items.isEmpty ? 0 : Int((Double(viewport.scrollOffset) / Double(max(1, items.count - config.viewportHeight))) * 100)
        return "[\(viewport.topIndex + 1)-\(viewport.bottomIndex + 1)/\(items.count)] \(percentage)%"
    }

    func getPerformanceInfo() -> [String: Any] {
        return [
            "total_items": items.count,
            "visible_items": visibleItems.count,
            "viewport_top": viewport.topIndex,
            "viewport_bottom": viewport.bottomIndex,
            "viewport_height": config.viewportHeight,
            "buffer_size": config.bufferSize,
            "scroll_offset": viewport.scrollOffset,
            "avg_render_time_ms": averageRenderTime * 1000,
            "render_count": renderCount,
            "scroll_velocity": scrollVelocity,
            "needs_redraw": viewport.needsRedraw
        ]
    }

    var needsRedraw: Bool {
        get { viewport.needsRedraw }
        set { viewport.needsRedraw = newValue }
    }

    // MARK: - Memory Management

    func optimizeMemoryUsage() {
        // Remove virtual items that are far from viewport
        let keepRange = max(0, viewport.topIndex - config.bufferSize * 2)...(viewport.bottomIndex + config.bufferSize * 2)

        // This is a conceptual optimization - in practice, we rebuild virtual items as needed
        Logger.shared.logDebug("VirtualScrollManager - Memory optimization: keeping items \(keepRange.lowerBound)-\(keepRange.upperBound)")
    }
}

// MARK: - Convenience Extensions

extension VirtualScrollManager {
    // Factory methods for common resource types

    static func forServers(config: VirtualScrollConfig = .default) -> VirtualScrollManager<Server> {
        return VirtualScrollManager<Server>(config: config)
    }

    static func forNetworks(config: VirtualScrollConfig = .default) -> VirtualScrollManager<Network> {
        return VirtualScrollManager<Network>(config: config)
    }

    static func forVolumes(config: VirtualScrollConfig = .default) -> VirtualScrollManager<Volume> {
        return VirtualScrollManager<Volume>(config: config)
    }

    static func forPorts(config: VirtualScrollConfig = .large) -> VirtualScrollManager<Port> {
        return VirtualScrollManager<Port>(config: config)
    }

    static func forImages(config: VirtualScrollConfig = .large) -> VirtualScrollManager<Image> {
        return VirtualScrollManager<Image>(config: config)
    }
}

// MARK: - Integration with Existing Views

extension VirtualScrollManager {
    // Helper to integrate with existing view rendering patterns
    func renderItemsInBounds(
        startRow: Int32,
        endRow: Int32,
        screen: OpaquePointer?,
        renderFunction: (T, Int32, Int) -> Void
    ) {
        let renderableItems = getRenderableItems(startRow: startRow, endRow: endRow)

        for (item, row, index) in renderableItems {
            renderFunction(item, row, index)
        }

        // Mark as drawn
        needsRedraw = false
    }
}