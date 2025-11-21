import OSClient
import SwiftNCurses

struct ServerSelectionView {
    @MainActor
    static func drawServerSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        servers: [Server],
        selectedServerIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String = "Select Servers",
        checkboxMode: FormSelectorCheckboxMode = .multiSelect
    ) async {
        let surface = SwiftNCurses.surface(from: screen)

        let tabs = [
            FormSelectorTab<Server>(
                title: "Servers",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 30) { server in
                        (server.name ?? "Unknown").padding(toLength: 30, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "STATUS", width: 15) { server in
                        (server.status?.rawValue ?? "unknown").padding(toLength: 15, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "IP ADDRESS", width: 18) { server in
                        let ip = server.addresses?.values.flatMap { $0 }.first?.addr ?? "N/A"
                        return ip.padding(toLength: 18, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: servers,
            selectedItemIds: selectedServerIds,
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
