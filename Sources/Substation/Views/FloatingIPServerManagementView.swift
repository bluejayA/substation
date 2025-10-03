import Foundation
import SwiftTUI
import OSClient

@MainActor
struct FloatingIPServerManagementView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, floatingIP: FloatingIP, servers: [Server], attachedServerId: String?, selectedServerId: String?, searchQuery: String?, scrollOffset: Int, selectedIndex: Int, mode: AttachmentMode, resourceResolver: ResourceResolver) async {
        // Filter servers based on current mode
        let relevantServers: [Server]
        switch mode {
        case .attach:
            relevantServers = servers.filter { server in
                attachedServerId != server.id
            }
        case .detach:
            if let attachedId = attachedServerId {
                relevantServers = servers.filter { $0.id == attachedId }
            } else {
                relevantServers = []
            }
        }

        let floatingIPAddress = floatingIP.floatingIpAddress ?? "Unknown"
        let modeText = mode == .attach ? "ATTACH" : "DETACH"
        let title = "Manage Floating IP Server Assignment - \(floatingIPAddress) - Mode: \(modeText)"

        let selectedIds: Set<String> = selectedServerId.map { Set([$0]) } ?? []

        await ServerSelectionView.drawServerSelection(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            servers: relevantServers,
            selectedServerIds: selectedIds,
            highlightedIndex: selectedIndex,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            title: title,
            multiSelect: false
        )
    }
}