import Foundation
import SwiftNCurses

// Virtualizes list rendering for improved performance with large datasets
struct ListVirtualizer {

    // Configuration for virtualization
    struct Config {
        let bufferSize: Int        // Extra items to render above/below viewport
        let itemHeight: Int32      // Height of each list item (usually 1)
        let enablePreloading: Bool // Whether to preload items for smooth scrolling

        static let `default` = Config(
            bufferSize: 5,          // Render 5 extra items above and below viewport
            itemHeight: 1,          // Most list items are 1 row high
            enablePreloading: true  // Enable smooth scrolling
        )

        // Configuration for large datasets
        static let large = Config(
            bufferSize: 10,         // Larger buffer for big datasets
            itemHeight: 1,
            enablePreloading: true
        )

        // Configuration for very large datasets (>1000 items)
        static let massive = Config(
            bufferSize: 3,          // Smaller buffer to reduce memory usage
            itemHeight: 1,
            enablePreloading: false // Disable preloading for max performance
        )
    }

    // Result of virtualization calculation
    struct ViewportInfo {
        let visibleStartIndex: Int
        let visibleEndIndex: Int
        let bufferStartIndex: Int
        let bufferEndIndex: Int
        let totalVisibleItems: Int
        let shouldRenderScrollIndicator: Bool
    }

    private let config: Config

    init(config: Config = .default) {
        self.config = config
    }

    // Calculate what items should be rendered for optimal performance
    func calculateViewport<T>(
        totalItems: [T],
        scrollOffset: Int,
        viewportHeight: Int32,
        startRow: Int32
    ) -> ViewportInfo {

        let totalCount = totalItems.count
        let viewportItemCount = Int(viewportHeight - 3) // Account for headers/borders

        // Empty list handling
        guard totalCount > 0 else {
            return ViewportInfo(
                visibleStartIndex: 0,
                visibleEndIndex: 0,
                bufferStartIndex: 0,
                bufferEndIndex: 0,
                totalVisibleItems: 0,
                shouldRenderScrollIndicator: false
            )
        }

        // Calculate visible range
        let visibleStart = max(0, min(scrollOffset, totalCount - viewportItemCount))
        let visibleEnd = min(totalCount, visibleStart + viewportItemCount)

        // Calculate buffer range for smooth scrolling
        let bufferStart = max(0, visibleStart - config.bufferSize)
        let bufferEnd = min(totalCount, visibleEnd + config.bufferSize)

        let shouldShowScrollIndicator = totalCount > viewportItemCount

        let result = ViewportInfo(
            visibleStartIndex: visibleStart,
            visibleEndIndex: visibleEnd,
            bufferStartIndex: bufferStart,
            bufferEndIndex: bufferEnd,
            totalVisibleItems: visibleEnd - visibleStart,
            shouldRenderScrollIndicator: shouldShowScrollIndicator
        )

        // Log performance info for large datasets
        if totalCount > 100 {
            Logger.shared.logDebug("ListVirtualizer - Viewport: \(visibleStart)-\(visibleEnd) of \(totalCount) items (buffer: \(bufferStart)-\(bufferEnd))")
        }

        return result
    }

    // Get optimal configuration based on dataset size
    static func optimalConfig(for itemCount: Int) -> Config {
        switch itemCount {
        case 0..<50:
            return .default
        case 50..<500:
            return .default
        case 500..<1000:
            return .large
        default:
            return .massive
        }
    }

    // Render virtualized list with performance optimization
    @MainActor
    static func renderVirtualizedList<T: Sendable>(
        screen: OpaquePointer?,
        items: [T],
        scrollOffset: Int,
        selectedIndex: Int,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        renderItem: @Sendable (T, Int, Bool, Int32, Int32, Int32) async -> Void
    ) async {

        let config = optimalConfig(for: items.count)
        let virtualizer = ListVirtualizer(config: config)

        let viewport = virtualizer.calculateViewport(
            totalItems: items,
            scrollOffset: scrollOffset,
            viewportHeight: height,
            startRow: startRow
        )

        // Only render items in the buffer range for performance
        let renderStart = viewport.bufferStartIndex
        let renderEnd = viewport.bufferEndIndex

        let currentRow = startRow + 2 // Account for title and headers

        for i in renderStart..<renderEnd {
            // Skip items outside visible area (they're in buffer)
            let rowIndex = i - viewport.visibleStartIndex
            let isVisible = i >= viewport.visibleStartIndex && i < viewport.visibleEndIndex

            if isVisible {
                let isSelected = i == selectedIndex

                // Use the row position adjusted for viewport
                let adjustedRow = currentRow + Int32(rowIndex)

                // Only render if row is within screen bounds
                if adjustedRow >= startRow + 2 && adjustedRow < startRow + height - 2 {
                    await renderItem(items[i], i, isSelected, adjustedRow, startCol, width)
                }
            }
        }

        // Render scroll indicator if needed
        if viewport.shouldRenderScrollIndicator {
            await renderScrollIndicator(
                screen: screen,
                scrollOffset: scrollOffset,
                totalItems: items.count,
                visibleItems: viewport.totalVisibleItems,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height
            )
        }
    }

    // Render scroll indicator with performance info
    @MainActor
    private static func renderScrollIndicator(
        screen: OpaquePointer?,
        scrollOffset: Int,
        totalItems: Int,
        visibleItems: Int,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        let indicatorRow = startRow + height - 1
        let indicatorCol = startCol + width - 25

        let surface = SwiftNCurses.surface(from: screen)

        let currentEnd = min(scrollOffset + visibleItems, totalItems)
        let scrollInfo = "[\(scrollOffset + 1)-\(currentEnd)/\(totalItems)]"
        let scrollBounds = Rect(x: indicatorCol, y: indicatorRow, width: Int32(scrollInfo.count), height: 1)
        await SwiftNCurses.render(Text(scrollInfo).info(), on: surface, in: scrollBounds)

        // Add performance indicator for large datasets
        if totalItems > 500 {
            let virtualBounds = Rect(x: indicatorCol - 8, y: indicatorRow, width: 7, height: 1)
            await SwiftNCurses.render(Text("VIRTUAL").info(), on: surface, in: virtualBounds)
        }
    }

    // Calculate if we should use virtualization
    static func shouldVirtualize(itemCount: Int) -> Bool {
        return itemCount > 50 // Virtualize for datasets larger than 50 items
    }

    // Performance metrics
    static func getPerformanceImpact(itemCount: Int, viewportHeight: Int32) -> [String: Any] {
        let config = optimalConfig(for: itemCount)
        let virtualizer = ListVirtualizer(config: config)

        let viewport = virtualizer.calculateViewport(
            totalItems: Array(0..<itemCount),
            scrollOffset: 0,
            viewportHeight: viewportHeight,
            startRow: 2
        )

        let renderRatio = Double(viewport.bufferEndIndex - viewport.bufferStartIndex) / Double(itemCount)

        return [
            "total_items": itemCount,
            "rendered_items": viewport.bufferEndIndex - viewport.bufferStartIndex,
            "render_ratio": String(format: "%.1f%%", renderRatio * 100),
            "virtualization_enabled": shouldVirtualize(itemCount: itemCount),
            "buffer_size": config.bufferSize
        ]
    }
}