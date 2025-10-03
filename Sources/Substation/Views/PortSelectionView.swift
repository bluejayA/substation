import OSClient
import SwiftTUI

struct PortSelectionView {
    @MainActor
    static func drawPortSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        ports: [Port],
        selectedPortIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String = "Select Port"
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        let tabs = [
            FormSelectorTab<Port>(
                title: "Ports",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 30) { port in
                        (port.name ?? "Unknown").padding(toLength: 30, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "STATUS", width: 15) { port in
                        (port.status ?? "unknown").padding(toLength: 15, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "MAC ADDRESS", width: 20) { port in
                        (port.macAddress ?? "N/A").padding(toLength: 20, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: ports,
            selectedItemIds: selectedPortIds,
            highlightedIndex: highlightedIndex,
            multiSelect: false,
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
