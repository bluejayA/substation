import Foundation
import OSClient
import SwiftTUI

struct SubnetSelectionView {
    @MainActor
    static func drawSubnetSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        subnets: [Subnet],
        selectedSubnetIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String = "Select Subnet"
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        let tabs = [
            FormSelectorTab<Subnet>(
                title: "Subnets",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 30) { subnet in
                        (subnet.name ?? "Unknown").padding(toLength: 30, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "CIDR", width: 20) { subnet in
                        subnet.cidr.padding(toLength: 20, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "IP VERSION", width: 12) { subnet in
                        let ipVersion = "IPv\(subnet.ipVersion)"
                        return ipVersion.padding(toLength: 12, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "GATEWAY", width: 20) { subnet in
                        (subnet.gatewayIp ?? "None").padding(toLength: 20, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: subnets,
            selectedItemIds: selectedSubnetIds,
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
