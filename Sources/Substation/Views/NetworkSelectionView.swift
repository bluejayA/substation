import Foundation
import OSClient
import SwiftNCurses

struct NetworkSelectionView {
    @MainActor
    static func drawNetworkSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        networks: [Network],
        selectedNetworkIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String = "Select Network",
        checkboxMode: FormSelectorCheckboxMode = .basic
    ) async {
        let surface = SwiftNCurses.surface(from: screen)

        let tabs = [
            FormSelectorTab<Network>(
                title: "Networks",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 30) { network in
                        (network.name ?? "Unknown").padding(toLength: 30, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "STATUS", width: 15) { network in
                        (network.status ?? "unknown").padding(toLength: 15, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "EXTERNAL", width: 8) { network in
                        (network.external == true ? "Yes" : "No").padding(toLength: 8, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: networks,
            selectedItemIds: selectedNetworkIds,
            highlightedIndex: highlightedIndex,
            checkboxMode: checkboxMode,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxWidth: Int(width),
            maxHeight: Int(height),
            isActive: true
        )

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftNCurses.render(selector.render(), on: surface, in: bounds)
    }
}
