import Foundation
import SwiftTUI

// MARK: - FormSelector Component

/// A unified selector component for forms that provides:
/// - Multi-tab mode switching
/// - Multi-select capability
/// - Search/filtering
/// - Column-based display with headers
/// - Scrolling with indicators
/// - Detailed view for selected item
///
/// Usage:
/// - TAB: Switch between tabs/modes
/// - SPACE: Toggle selection (multi-select) or select (single-select)
/// - ENTER: Confirm selection
/// - ESC: Cancel/back
/// - UP/DOWN: Navigate items
/// - Search: Type to filter items
struct FormSelector<Item: FormSelectableItem> {
    let label: String
    let tabs: [FormSelectorTab<Item>]
    let selectedTabIndex: Int
    let items: [Item]
    let selectedItemIds: Set<String>
    let highlightedIndex: Int
    let multiSelect: Bool
    let scrollOffset: Int
    let searchQuery: String?
    let maxWidth: Int?
    let maxHeight: Int?
    let isActive: Bool
    let validationError: String?

    init(
        label: String,
        tabs: [FormSelectorTab<Item>],
        selectedTabIndex: Int = 0,
        items: [Item] = [],
        selectedItemIds: Set<String> = [],
        highlightedIndex: Int = 0,
        multiSelect: Bool = false,
        scrollOffset: Int = 0,
        searchQuery: String? = nil,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil,
        isActive: Bool = false,
        validationError: String? = nil
    ) {
        self.label = label
        self.tabs = tabs
        self.selectedTabIndex = selectedTabIndex
        self.items = items
        self.selectedItemIds = selectedItemIds
        self.highlightedIndex = highlightedIndex
        self.multiSelect = multiSelect
        self.scrollOffset = scrollOffset
        self.searchQuery = searchQuery
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.isActive = isActive
        self.validationError = validationError
    }

    /// Render the selector as a component
    func render() -> any Component {
        var components: [any Component] = []

        // Title
        components.append(
            Text(label).primary().bold()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        )

        // Tab/Mode indicator if multiple tabs
        if tabs.count > 1 {
            let currentTab = tabs[selectedTabIndex]
            let tabComponents: [any Component] = [
                Text("Mode: ").info(),
                Text("[\(currentTab.title)]").success().bold(),
                Text(" (TAB to switch)").secondary()
            ]
            components.append(
                HStack(spacing: 0, children: tabComponents)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
            )
        } else if label.lowercased().contains("mode") == true {
            // Description for single tab mode
            components.append(
                Text(" (Press TAB to switch Modes)").info()
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
            )
        }

        // Instructions
        let instructions = multiSelect ?
            "Browse and select items. SPACE: toggle, ENTER: confirm" :
            "Browse and select item. SPACE: select, ENTER: confirm"
        components.append(
            Text(instructions).secondary()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
        )

        // Search indicator if active
        if let query = searchQuery, !query.isEmpty {
            components.append(
                Text("Search: \(query)_").accent()
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
            )
        }

        // Column headers - aligned with column widths
        let currentTab = tabs[selectedTabIndex]
        let formattedHeaders = currentTab.columns.map { column in
            column.header.padding(toLength: column.width, withPad: " ", startingAt: 0)
        }.joined(separator: "  ")
        components.append(
            Text("[ ] \(formattedHeaders)").secondary()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        )

        // Separator
        let separatorWidth = maxWidth ?? 80
        components.append(
            Text(String(repeating: "-", count: separatorWidth)).muted()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        )

        // Items list
        let itemsComponent = renderItems()
        components.append(itemsComponent)

        // Validation error if present
        if let error = validationError {
            components.append(
                Text("  ! \(error)").error()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
            )
        }

        // Bottom instructions
        let bottomInstructions = tabs.count > 1 ?
            "TAB:switch SPACE:select ENTER:confirm ESC:cancel" :
            "SPACE:select ENTER:confirm ESC:cancel"
        components.append(
            Text(bottomInstructions).muted()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        )

        return VStack(spacing: 0, children: components)
    }

    // MARK: - Private Rendering Methods

    private func renderItems() -> any Component {
        // Filter and sort items based on search query
        let filteredItems = filterItems()

        guard !filteredItems.isEmpty else {
            let emptyMessage = searchQuery?.isEmpty ?? true ?
                "No items available" : "No items match your search"
            return Text(emptyMessage).muted()
                .padding(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 0))
        }

        // Determine which item should be highlighted based on the filtered/sorted array
        let highlightedItemId: String? = {
            guard highlightedIndex >= 0 && highlightedIndex < filteredItems.count else {
                return nil
            }
            return filteredItems[highlightedIndex].id
        }()

        // Calculate overhead from FormSelector UI elements
        var overhead = 0
        overhead += 2  // Title (1 top + 1 bottom padding)
        overhead += 1  // Instructions line
        overhead += 1  // Column headers
        overhead += 1  // Separator
        overhead += 1  // Bottom instructions (1 top padding)
        if tabs.count > 1 { overhead += 1 }  // Tab indicator
        if searchQuery != nil && !searchQuery!.isEmpty { overhead += 1 }  // Search indicator
        if validationError != nil { overhead += 1 }  // Validation error

        // Calculate visible range - use all available space minus overhead
        let availableHeight = maxHeight.map { max(1, $0 - overhead) } ?? filteredItems.count
        let contentHeight = availableHeight

        // Ensure scrollOffset is within bounds
        let maxScrollOffset = max(0, filteredItems.count - contentHeight)
        let safeScrollOffset = max(0, min(scrollOffset, maxScrollOffset))
        let remainingItems = filteredItems.count - safeScrollOffset
        let visibleCount = min(contentHeight, remainingItems)

        var itemComponents: [any Component] = []

        for i in 0..<visibleCount {
            let itemIndex = safeScrollOffset + i
            guard itemIndex >= 0 && itemIndex < filteredItems.count else { break }

            let item = filteredItems[itemIndex]
            let isHighlighted = highlightedItemId != nil && item.id == highlightedItemId
            let isSelected = selectedItemIds.contains(item.id)

            let itemComponent = renderItem(item: item, isHighlighted: isHighlighted, isSelected: isSelected)
            itemComponents.append(itemComponent)
        }

        // Add scroll indicator if needed
        if safeScrollOffset > 0 || safeScrollOffset + visibleCount < filteredItems.count {
            let scrollText = "(\(safeScrollOffset + 1)-\(safeScrollOffset + visibleCount) of \(filteredItems.count))"
            itemComponents.append(
                Text(scrollText).muted()
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            )
        }

        return VStack(spacing: 0, children: itemComponents)
    }

    private func renderItem(item: Item, isHighlighted: Bool, isSelected: Bool) -> any Component {
        let currentTab = tabs[selectedTabIndex]

        // Checkbox
        let checkbox = isSelected ? "[X]" : "[ ]"

        // Format columns
        var columnValues: [String] = []
        for column in currentTab.columns {
            let value = column.getValue(item)
            let formatted = value.padding(toLength: column.width, withPad: " ", startingAt: 0)
            columnValues.append(formatted)
        }

        let itemText = "\(checkbox) \(columnValues.joined(separator: "  "))"

        // Apply styling
        let style: TextStyle
        if isHighlighted {
            style = isSelected ? .accent : .secondary
        } else if isSelected {
            style = .accent
        } else {
            style = .info
        }

        let textComponent = Text(itemText).styled(style)
        let styledComponent = isHighlighted ? textComponent.bold() : textComponent
        return styledComponent
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    private func filterItems() -> [Item] {
        // Filter items based on search query, but preserve input order
        if let query = searchQuery, !query.isEmpty {
            return items.filter { item in
                item.matchesSearch(query)
            }
        } else {
            return items
        }
    }
}

// MARK: - FormSelectorTab

/// Represents a tab/mode in the selector
struct FormSelectorTab<Item: FormSelectableItem> {
    let title: String
    let columns: [FormSelectorColumn<Item>]
    let description: String?

    init(title: String, columns: [FormSelectorColumn<Item>], description: String? = nil) {
        self.title = title
        self.columns = columns
        self.description = description
    }
}

// MARK: - FormSelectorColumn

/// Represents a column in the selector display
struct FormSelectorColumn<Item: FormSelectableItem> {
    let header: String
    let width: Int
    let getValue: (Item) -> String

    init(header: String, width: Int, getValue: @escaping (Item) -> String) {
        self.header = header
        self.width = width
        self.getValue = getValue
    }
}

// MARK: - FormSelectableItem Protocol

/// Protocol that items must conform to for use in FormSelector
protocol FormSelectableItem {
    var id: String { get }
    var sortKey: String { get }
    func matchesSearch(_ query: String) -> Bool
}

// MARK: - FormSelector State Management

/// State management for selector interaction
struct FormSelectorState<Item: FormSelectableItem> {
    var items: [Item]
    var selectedItemIds: Set<String>
    var highlightedIndex: Int
    var selectedTabIndex: Int
    var scrollOffset: Int
    var searchQuery: String
    var multiSelect: Bool

    init(items: [Item] = [], multiSelect: Bool = false) {
        self.items = items
        self.selectedItemIds = []
        self.highlightedIndex = 0
        self.selectedTabIndex = 0
        self.scrollOffset = 0
        self.searchQuery = ""
        self.multiSelect = multiSelect
    }

    // MARK: - Navigation

    mutating func moveUp() {
        let displayItems = getFilteredAndSortedItems()
        if highlightedIndex > 0 {
            highlightedIndex -= 1
            adjustScrollOffset(itemCount: displayItems.count)
        }
    }

    mutating func moveDown() {
        let displayItems = getFilteredAndSortedItems()
        if highlightedIndex < displayItems.count - 1 {
            highlightedIndex += 1
            adjustScrollOffset(itemCount: displayItems.count)
        }
    }

    mutating func nextTab(tabCount: Int) {
        selectedTabIndex = (selectedTabIndex + 1) % tabCount
        resetSelection()
    }

    // MARK: - Selection

    mutating func toggleSelection() {
        let displayItems = getFilteredAndSortedItems()
        guard highlightedIndex < displayItems.count else { return }
        let itemId = displayItems[highlightedIndex].id

        if multiSelect {
            // Toggle selection in multi-select mode
            if selectedItemIds.contains(itemId) {
                selectedItemIds.remove(itemId)
            } else {
                selectedItemIds.insert(itemId)
            }
        } else {
            // Single select mode - replace selection
            selectedItemIds = [itemId]
        }
    }

    mutating func clearSelection() {
        selectedItemIds.removeAll()
    }

    // MARK: - Search

    mutating func updateSearchQuery(_ query: String) {
        searchQuery = query
        highlightedIndex = 0
        scrollOffset = 0
    }

    mutating func appendToSearch(_ char: Character) {
        searchQuery.append(char)
        highlightedIndex = 0
        scrollOffset = 0
    }

    mutating func removeLastSearchCharacter() {
        if !searchQuery.isEmpty {
            searchQuery.removeLast()
            highlightedIndex = 0
            scrollOffset = 0
        }
    }

    mutating func clearSearch() {
        searchQuery = ""
        highlightedIndex = 0
        scrollOffset = 0
    }

    // MARK: - Helper Methods

    private mutating func adjustScrollOffset(itemCount: Int) {
        let maxVisibleItems = 10 // Could be configurable

        // Ensure highlightedIndex is within bounds
        if highlightedIndex >= itemCount && itemCount > 0 {
            highlightedIndex = itemCount - 1
        }

        // Adjust scroll to keep highlighted item visible
        if highlightedIndex < scrollOffset {
            scrollOffset = highlightedIndex
        } else if highlightedIndex >= scrollOffset + maxVisibleItems {
            scrollOffset = highlightedIndex - maxVisibleItems + 1
        }

        // Ensure scrollOffset is within bounds
        if scrollOffset < 0 {
            scrollOffset = 0
        }
    }

    private mutating func resetSelection() {
        highlightedIndex = 0
        scrollOffset = 0
        searchQuery = ""
    }

    // MARK: - Query Methods

    var selectedItems: [Item] {
        items.filter { selectedItemIds.contains($0.id) }
    }

    var hasSelection: Bool {
        !selectedItemIds.isEmpty
    }

    func getFilteredItems() -> [Item] {
        guard !searchQuery.isEmpty else { return items }
        return items.filter { $0.matchesSearch(searchQuery) }
    }

    func getFilteredAndSortedItems() -> [Item] {
        // Return filtered items in their original order (no sorting)
        return getFilteredItems()
    }
}
