import Foundation

// MARK: - List View Component

/// High-level list component that handles headers, scrolling, selection, and virtualization
public struct ListView<Item: Sendable>: Component {
    private let items: [Item]
    private let selectedIndex: Int?
    private let scrollOffset: Int
    private let configuration: ListConfiguration
    private let rowRenderer: @Sendable (Item, Bool, Int) -> any Component

    public struct ListConfiguration: Sendable {
        let showHeaders: Bool
        let showBorder: Bool
        let title: String?
        let headerStyle: TextStyle
        let separatorStyle: TextStyle
        let selectionStyle: TextStyle
        let maxVisibleItems: Int?

        public init(
            showHeaders: Bool = true,
            showBorder: Bool = true,
            title: String? = nil,
            headerStyle: TextStyle = .accent,
            separatorStyle: TextStyle = .secondary,
            selectionStyle: TextStyle = .primary,
            maxVisibleItems: Int? = nil
        ) {
            self.showHeaders = showHeaders
            self.showBorder = showBorder
            self.title = title
            self.headerStyle = headerStyle
            self.separatorStyle = separatorStyle
            self.selectionStyle = selectionStyle
            self.maxVisibleItems = maxVisibleItems
        }

        public static func standard<T>() -> ListView<T>.ListConfiguration {
            return ListView<T>.ListConfiguration()
        }
    }

    public init(
        items: [Item],
        selectedIndex: Int? = nil,
        scrollOffset: Int = 0,
        configuration: ListConfiguration = .standard(),
        @ComponentBuilder rowRenderer: @escaping @Sendable (Item, Bool, Int) -> any Component
    ) {
        self.items = items
        self.selectedIndex = selectedIndex
        self.scrollOffset = scrollOffset
        self.configuration = configuration
        self.rowRenderer = rowRenderer
    }

    public var intrinsicSize: Size {
        let headerHeight: Int32 = configuration.showHeaders ? 3 : 1 // Title + header + separator
        let itemCount = configuration.maxVisibleItems ?? items.count
        let contentHeight = Int32(itemCount)
        let borderHeight: Int32 = configuration.showBorder ? 2 : 0
        let footerHeight: Int32 = needsScrollIndicator ? 2 : 0

        return Size(
            width: 80, // Default width, should be configurable
            height: headerHeight + contentHeight + borderHeight + footerHeight
        )
    }

    private var needsScrollIndicator: Bool {
        guard let maxVisible = configuration.maxVisibleItems else { return false }
        return items.count > maxVisible
    }

    private var visibleItems: [Item] {
        guard let maxVisible = configuration.maxVisibleItems else { return items }
        let startIndex = max(0, min(scrollOffset, items.count - maxVisible))
        let endIndex = min(items.count, startIndex + maxVisible)
        return Array(items[startIndex..<endIndex])
    }

    @MainActor public func render(in context: DrawingContext) async {
        var currentRow: Int32 = 0
        let bounds = context.bounds

        // Title
        if let title = configuration.title {
            await Text(title).styled(configuration.headerStyle)
                .render(in: context.subContext(rect: Rect(
                    origin: Position(row: currentRow, col: 0),
                    size: Size(width: bounds.size.width, height: 1)
                )))
            currentRow += 1
        }

        // Headers
        if configuration.showHeaders {
            await renderHeaders(in: context, at: currentRow)
            currentRow += 2 // Header + separator
        }

        // Content
        let contentHeight = bounds.size.height - currentRow - (needsScrollIndicator ? 2 : 0)
        let contentRect = Rect(
            origin: Position(row: currentRow, col: 0),
            size: Size(width: bounds.size.width, height: contentHeight)
        )

        await renderContent(in: context.subContext(rect: contentRect))
        currentRow += contentHeight

        // Scroll indicator
        if needsScrollIndicator {
            await renderScrollIndicator(in: context, at: currentRow)
        }
    }

    @MainActor private func renderHeaders(in context: DrawingContext, at row: Int32) async {
        // This would be customizable through the configuration
        // For now, just render a generic header
        await Text("Items").styled(configuration.headerStyle)
            .render(in: context.subContext(rect: Rect(
                origin: Position(row: row, col: 2),
                size: Size(width: context.bounds.size.width - 4, height: 1)
            )))

        // Separator
        await Separator(direction: .horizontal, style: configuration.separatorStyle)
            .render(in: context.subContext(rect: Rect(
                origin: Position(row: row + 1, col: 2),
                size: Size(width: context.bounds.size.width - 4, height: 1)
            )))
    }

    @MainActor private func renderContent(in context: DrawingContext) async {
        let startOffset = configuration.maxVisibleItems != nil ? scrollOffset : 0

        for (index, item) in visibleItems.enumerated() {
            let absoluteIndex = startOffset + index
            let isSelected = selectedIndex == absoluteIndex
            let rowComponent = rowRenderer(item, isSelected, absoluteIndex)

            let rowRect = Rect(
                origin: Position(row: Int32(index), col: 0),
                size: Size(width: context.bounds.size.width, height: 1)
            )

            // Apply selection styling
            if isSelected {
                let styledRow = SelectableRow(rowComponent, isSelected: true, style: configuration.selectionStyle)
                await styledRow.render(in: context.subContext(rect: rowRect))
            } else {
                await rowComponent.render(in: context.subContext(rect: rowRect))
            }
        }
    }

    @MainActor private func renderScrollIndicator(in context: DrawingContext, at row: Int32) async {
        guard let maxVisible = configuration.maxVisibleItems else { return }

        let currentPage = scrollOffset / maxVisible + 1
        let totalPages = (items.count - 1) / maxVisible + 1
        let pageInfo = "Page \(currentPage)/\(totalPages)"

        await Text(pageInfo).styled(.info)
            .render(in: context.subContext(rect: Rect(
                origin: Position(row: row, col: 1),
                size: Size(width: Int32(pageInfo.count), height: 1)
            )))

        // Progress bar
        let progress = Double(scrollOffset) / Double(max(1, items.count - maxVisible))
        await ProgressBar(progress: progress, width: 20)
            .render(in: context.subContext(rect: Rect(
                origin: Position(row: row + 1, col: 1),
                size: Size(width: 22, height: 1)
            )))
    }
}

// MARK: - Selectable Row Component

/// Component that handles row selection styling
public struct SelectableRow: Component {
    private let child: any Component
    private let isSelected: Bool
    private let style: TextStyle

    public init(_ child: any Component, isSelected: Bool, style: TextStyle = .primary) {
        self.child = child
        self.isSelected = isSelected
        self.style = style
    }

    public var intrinsicSize: Size {
        return child.intrinsicSize
    }

    @MainActor public func render(in context: DrawingContext) async {
        if isSelected {
            // Fill background for selection
            let selectionStyle = style.reverse()
            await context.surface.fill(rect: context.bounds, character: " ", style: selectionStyle)
        }

        await child.render(in: context)
    }
}

// MARK: - List Item Components

/// Standard list item with icon, text, and optional status
public struct ListItem: Component {
    private let icon: (any Component)?
    private let text: String
    private let status: (any Component)?
    private let style: TextStyle

    public init(icon: (any Component)? = nil,
                text: String,
                status: (any Component)? = nil,
                style: TextStyle = .primary) {
        self.icon = icon
        self.text = text
        self.status = status
        self.style = style
    }

    public var intrinsicSize: Size {
        var width: Int32 = 0

        if let icon = icon {
            width += icon.intrinsicSize.width + 1
        }

        width += Int32(text.count)

        if let status = status {
            width += status.intrinsicSize.width + 1
        }

        return Size(width: width, height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        var currentCol: Int32 = 0

        // Icon
        if let icon = icon {
            await icon.render(in: context.subContext(rect: Rect(
                origin: Position(row: 0, col: currentCol),
                size: icon.intrinsicSize
            )))
            currentCol += icon.intrinsicSize.width + 1
        }

        // Text
        await Text(text).styled(style)
            .render(in: context.subContext(rect: Rect(
                origin: Position(row: 0, col: currentCol),
                size: Size(width: Int32(text.count), height: 1)
            )))
        currentCol += Int32(text.count)

        // Status
        if let status = status {
            currentCol += 1
            await status.render(in: context.subContext(rect: Rect(
                origin: Position(row: 0, col: currentCol),
                size: status.intrinsicSize
            )))
        }
    }
}

// MARK: - Table List Item

/// List item with fixed-width columns for table-like display
public struct TableListItem: Component {
    private let columns: [TableColumn]

    public struct TableColumn: Sendable {
        let content: any Component
        let width: Int32
        let alignment: FormattedText.TextAlignment

        public init(content: any Component, width: Int32, alignment: FormattedText.TextAlignment = .leading) {
            self.content = content
            self.width = width
            self.alignment = alignment
        }

        public init(text: String, width: Int32, style: TextStyle = .primary, alignment: FormattedText.TextAlignment = .leading) {
            self.content = Text(text).styled(style)
            self.width = width
            self.alignment = alignment
        }
    }

    public init(columns: [TableColumn]) {
        self.columns = columns
    }

    public var intrinsicSize: Size {
        let totalWidth = columns.reduce(0) { $0 + $1.width }
        return Size(width: totalWidth, height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        var currentCol: Int32 = 0

        for column in columns {
            let columnRect = Rect(
                origin: Position(row: 0, col: currentCol),
                size: Size(width: column.width, height: 1)
            )

            await column.content.render(in: context.subContext(rect: columnRect))
            currentCol += column.width
        }
    }
}