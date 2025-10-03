import Foundation
import SwiftTUI
import OSClient

@MainActor
struct SubnetRouterManagementView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, subnet: Subnet, routers: [Router], attachedRouterIds: Set<String>, selectedRouterId: String?, searchQuery: String?, scrollOffset: Int, selectedIndex: Int, mode: AttachmentMode, resourceResolver: ResourceResolver) async {
        let subnetName = subnet.name ?? "Unknown"
        let modeText = mode == .attach ? "ATTACH" : "DETACH"
        let title = "Manage Subnet Router Attachment - \(subnetName) (\(subnet.cidr)) - Mode: \(modeText)"

        // Filter routers based on mode
        let filteredRouters: [Router]
        switch mode {
        case .attach:
            // Show routers that are NOT currently attached to this subnet
            filteredRouters = routers.filter { !attachedRouterIds.contains($0.id) }
        case .detach:
            // Show routers that ARE currently attached to this subnet
            filteredRouters = routers.filter { attachedRouterIds.contains($0.id) }
        }

        let selectedIds: Set<String> = selectedRouterId.map { Set([$0]) } ?? []

        await RouterSelectionView.drawRouterSelection(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            routers: filteredRouters,
            selectedRouterIds: selectedIds,
            highlightedIndex: selectedIndex,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery ?? "",
            title: title,
            multiSelect: false
        )
    }
}