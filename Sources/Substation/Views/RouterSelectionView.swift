import Foundation
import SwiftNCurses
import OSClient

@MainActor
struct RouterSelectionView {

    static func drawRouterSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        routers: [Router],
        selectedRouterIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String,
        checkboxMode: FormSelectorCheckboxMode = .basic
    ) async {
        let surface = SwiftNCurses.surface(from: screen)

        let tabs = [
            FormSelectorTab<Router>(
                title: "Routers",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 25) { router in
                        (router.name ?? "Unknown").padding(toLength: 25, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "STATUS", width: 15) { router in
                        (router.status ?? "unknown").padding(toLength: 15, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "ADMIN STATE", width: 12) { router in
                        (router.adminStateUp == true ? "UP" : "DOWN").padding(toLength: 12, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: routers,
            selectedItemIds: selectedRouterIds,
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
