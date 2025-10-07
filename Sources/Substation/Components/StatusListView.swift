import Foundation
import SwiftTUI
import OSClient

// MARK: - StatusListColumn

struct StatusListColumn<T> {
    let header: String
    let width: Int
    let getValue: (T) -> String
    let getStyle: ((T) -> TextStyle)?

    init(
        header: String,
        width: Int,
        getValue: @escaping (T) -> String,
        getStyle: ((T) -> TextStyle)? = nil
    ) {
        self.header = header
        self.width = width
        self.getValue = getValue
        self.getStyle = getStyle
    }
}

// MARK: - StatusListView

@MainActor
struct StatusListView<T: Sendable> {
    private let title: String
    private let columns: [StatusListColumn<T>]
    private let getStatusIcon: (T) -> String
    private let filterItems: ([T], String?) -> [T]
    private let getItemID: (T) -> String

    init(
        title: String,
        columns: [StatusListColumn<T>],
        getStatusIcon: @escaping (T) -> String,
        filterItems: @escaping ([T], String?) -> [T],
        getItemID: @escaping (T) -> String = { _ in "" }
    ) {
        self.title = title
        self.columns = columns
        self.getStatusIcon = getStatusIcon
        self.filterItems = filterItems
        self.getItemID = getItemID
    }

    // MARK: - Main Draw Function

    func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        items: [T],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int,
        dataManager: DataManager? = nil,
        virtualScrollManager: VirtualScrollManager<T>? = nil,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        // Defensive bounds checking
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title with multi-select indicator
        var titleText = searchQuery.map { "\(title) (filtered: \($0))" } ?? title
        if multiSelectMode {
            titleText += " [MULTI-SELECT: \(selectedItems.count) selected]"
        }
        components.append(Text(titleText).emphasis().bold().padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        // Header
        let headerText = buildHeaderText()
        components.append(Text(headerText).muted()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)).border())

        // Content - determine rendering approach
        if let virtualScrollManager = virtualScrollManager {
            await renderWithVirtualScrolling(
                components: &components,
                virtualScrollManager: virtualScrollManager,
                selectedIndex: selectedIndex,
                height: height,
                multiSelectMode: multiSelectMode,
                selectedItems: selectedItems
            )
        } else if let dataManager = dataManager, dataManager.isPaginationEnabled(for: title.lowercased()) {
            await renderWithPagination(
                components: &components,
                dataManager: dataManager,
                selectedIndex: selectedIndex,
                height: height,
                resourceKey: title.lowercased(),
                multiSelectMode: multiSelectMode,
                selectedItems: selectedItems
            )
        } else {
            await renderTraditional(
                components: &components,
                items: items,
                searchQuery: searchQuery,
                scrollOffset: scrollOffset,
                selectedIndex: selectedIndex,
                height: height,
                multiSelectMode: multiSelectMode,
                selectedItems: selectedItems
            )
        }

        // Render
        let listComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(listComponent, on: surface, in: bounds)
    }

    // MARK: - Header Building

    private func buildHeaderText() -> String {
        var header = " ST  "
        for column in columns {
            let paddedHeader = String(column.header.prefix(column.width))
                .padding(toLength: column.width, withPad: " ", startingAt: 0)
            header += paddedHeader + " "
        }
        return header
    }

    // MARK: - Rendering Modes

    private func renderWithVirtualScrolling(
        components: inout [any Component],
        virtualScrollManager: VirtualScrollManager<T>,
        selectedIndex: Int,
        height: Int32,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        let maxVisibleItems = max(1, Int(height) - 10)
        let renderableItems = virtualScrollManager.getRenderableItems(
            startRow: 5,
            endRow: 5 + Int32(maxVisibleItems)
        )

        if renderableItems.isEmpty {
            components.append(Text("No items found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            for (item, _, index) in renderableItems {
                let isSelected = index == selectedIndex
                let itemID = getItemID(item)
                let isMultiSelected = multiSelectMode && selectedItems.contains(itemID)
                let itemComponent = createItemComponent(item: item, isSelected: isSelected, isMultiSelected: isMultiSelected, multiSelectMode: multiSelectMode)
                components.append(itemComponent)
            }

            let scrollInfo = virtualScrollManager.getScrollInfo()
            components.append(Text("Virtual: \(scrollInfo)").info()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
        }
    }

    private func renderWithPagination(
        components: inout [any Component],
        dataManager: DataManager,
        selectedIndex: Int,
        height: Int32,
        resourceKey: String,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        let paginatedItems: [T] = await dataManager.getPaginatedItems(for: resourceKey, type: T.self)

        if paginatedItems.isEmpty {
            components.append(Text("No items found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            let maxVisibleItems = max(1, Int(height) - 10)
            let endIndex = min(paginatedItems.count, maxVisibleItems)

            for i in 0..<endIndex {
                let item = paginatedItems[i]
                let isSelected = i == selectedIndex
                let itemID = getItemID(item)
                let isMultiSelected = multiSelectMode && selectedItems.contains(itemID)
                let itemComponent = createItemComponent(item: item, isSelected: isSelected, isMultiSelected: isMultiSelected, multiSelectMode: multiSelectMode)
                components.append(itemComponent)
            }

            if let paginationStatus = dataManager.getPaginationStatus(for: resourceKey) {
                components.append(Text("Paginated: \(paginationStatus)").info()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
            }
        }
    }

    private func renderTraditional(
        components: inout [any Component],
        items: [T],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int,
        height: Int32,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        let filteredItems = filterItems(items, searchQuery)

        if filteredItems.isEmpty {
            components.append(Text("No items found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            let maxVisibleItems = max(1, Int(height) - 10)

            var startIndex = max(0, scrollOffset)
            var endIndex = min(filteredItems.count, startIndex + maxVisibleItems)

            if selectedIndex < startIndex {
                startIndex = selectedIndex
                endIndex = min(filteredItems.count, startIndex + maxVisibleItems)
            } else if selectedIndex >= endIndex {
                endIndex = min(filteredItems.count, selectedIndex + 1)
                startIndex = max(0, endIndex - maxVisibleItems)
            }

            for i in startIndex..<endIndex {
                let item = filteredItems[i]
                let isSelected = i == selectedIndex
                let itemID = getItemID(item)
                let isMultiSelected = multiSelectMode && selectedItems.contains(itemID)
                let itemComponent = createItemComponent(item: item, isSelected: isSelected, isMultiSelected: isMultiSelected, multiSelectMode: multiSelectMode)
                components.append(itemComponent)
            }

            if filteredItems.count > maxVisibleItems {
                let scrollText = "[\(startIndex + 1)-\(endIndex)/\(filteredItems.count)]"
                components.append(Text(scrollText).info()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
            }
        }
    }

    // MARK: - Item Component Creation

    private func createItemComponent(item: T, isSelected: Bool, isMultiSelected: Bool = false, multiSelectMode: Bool = false) -> any Component {
        var children: [any Component] = []

        // In multi-select mode, replace status icon with checkbox
        if multiSelectMode {
            let checkbox = isMultiSelected ? "[X]" : "[ ]"
            children.append(Text(checkbox).styled(isMultiSelected ? .accent : .secondary))
        } else {
            // Status icon when not in multi-select mode
            let statusIcon = getStatusIcon(item)
            children.append(StatusIcon(status: statusIcon))
        }

        // Columns
        for column in columns {
            let value = column.getValue(item)
            let paddedValue = String(value.prefix(column.width))
                .padding(toLength: column.width, withPad: " ", startingAt: 0)

            let style: TextStyle
            if isMultiSelected {
                style = .accent
            } else {
                style = column.getStyle?(item) ?? (isSelected ? .accent : .secondary)
            }
            children.append(Text(" " + paddedValue).styled(style))
        }

        return HStack(spacing: 0, children: children)
            .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
    }
}
