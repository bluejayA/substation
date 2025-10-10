import Foundation
import SwiftTUI
import OSClient

struct SourceTypeSelectionView {
    @MainActor
    static func drawSourceTypeSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        sourceTypes: [SourceTypeOption],
        selectedSourceTypeIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String = "Select Source Type"
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        let tabs = [
            FormSelectorTab<SourceTypeOption>(
                title: "Source Types",
                columns: [
                    FormSelectorColumn(header: "TYPE", width: 50) { option in
                        option.name.padding(toLength: 50, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: sourceTypes,
            selectedItemIds: selectedSourceTypeIds,
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxWidth: Int(width),
            maxHeight: Int(height),
            isActive: true
        )

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(selector.render(), on: surface, in: bounds)
    }
}
