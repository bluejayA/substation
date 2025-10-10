import Foundation
import OSClient
import SwiftTUI

struct SecurityGroupSelectionView {
    @MainActor
    static func drawSecurityGroupSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        securityGroups: [SecurityGroup],
        selectedSecurityGroupIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String = "Select Security Groups"
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        let tabs = [
            FormSelectorTab<SecurityGroup>(
                title: "Security Groups",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 30) { securityGroup in
                        (securityGroup.name ?? "Unknown").padding(toLength: 30, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "DESCRIPTION", width: 40) { securityGroup in
                        (securityGroup.description ?? "No description").padding(toLength: 40, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: securityGroups,
            selectedItemIds: selectedSecurityGroupIds,
            highlightedIndex: highlightedIndex,
            checkboxMode: .multiSelect,
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
