// Sources/Substation/Modules/Routers/Views/RouterSubnetManagementView.swift
import Foundation
import SwiftNCurses
import OSClient

/// View for managing subnet interfaces attached to a router
///
/// This view displays a list of subnets that can be attached to or detached from
/// a router. It supports:
/// - Filtering by attach/detach mode
/// - Subnet selection via SPACE
/// - Applying changes via ENTER
/// - Mode toggling via TAB
@MainActor
struct RouterSubnetManagementView {

    /// Draw the router subnet management interface
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - startRow: Starting row position
    ///   - startCol: Starting column position
    ///   - width: Available width
    ///   - height: Available height
    ///   - router: The router being managed
    ///   - subnets: All available subnets
    ///   - attachedSubnetIds: Set of subnet IDs already attached to the router
    ///   - selectedSubnetId: Currently selected subnet ID for the operation
    ///   - searchQuery: Optional search filter
    ///   - scrollOffset: Current scroll position
    ///   - selectedIndex: Currently highlighted index
    ///   - mode: Current attachment mode (attach/detach)
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        router: Router,
        subnets: [Subnet],
        attachedSubnetIds: Set<String>,
        selectedSubnetId: String?,
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int,
        mode: AttachmentMode
    ) async {
        let routerName = router.name ?? "Unknown"
        let modeText = mode == .attach ? "ATTACH" : "DETACH"
        let title = "Manage Router Subnet Interfaces - \(routerName) - Mode: \(modeText)"

        // Filter subnets based on mode
        let filteredSubnets: [Subnet]
        switch mode {
        case .attach:
            // Show subnets that are NOT currently attached to this router
            filteredSubnets = subnets.filter { !attachedSubnetIds.contains($0.id) }
        case .detach:
            // Show subnets that ARE currently attached to this router
            filteredSubnets = subnets.filter { attachedSubnetIds.contains($0.id) }
        }

        let selectedIds: Set<String> = selectedSubnetId.map { Set([$0]) } ?? []

        // Create the surface and bounds
        let surface = SwiftNCurses.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        // Clear the area first
        surface.clear(rect: bounds)

        // Build the FormSelector component
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
                    FormSelectorColumn(header: "NETWORK", width: 36) { subnet in
                        subnet.networkId.padding(toLength: 36, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: filteredSubnets,
            selectedItemIds: selectedIds,
            highlightedIndex: selectedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxWidth: Int(width),
            maxHeight: Int(height),
            isActive: true
        )

        // Render the selector
        await SwiftNCurses.render(selector.render(), on: surface, in: bounds)
    }
}
