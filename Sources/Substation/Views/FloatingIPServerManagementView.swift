import Foundation
import SwiftTUI
import OSClient

@MainActor
struct FloatingIPServerManagementView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, floatingIP: FloatingIP, servers: [Server], attachedServerId: String?, selectedServerId: String?, searchQuery: String?, scrollOffset: Int, selectedIndex: Int, mode: AttachmentMode, resourceResolver: ResourceResolver) async {
        // Floating IPs have a one-to-one relationship with servers
        // Filter based on mode:
        // - ATTACH: Show all servers EXCEPT the currently attached one
        // - DETACH: Show ONLY the currently attached server (empty if unassigned)
        let relevantServers: [Server]
        switch mode {
        case .attach:
            if let attachedId = attachedServerId {
                relevantServers = servers.filter { $0.id != attachedId }
            } else {
                relevantServers = servers
            }
        case .detach:
            if let attachedId = attachedServerId {
                relevantServers = servers.filter { $0.id == attachedId }
            } else {
                // No server attached - show empty list
                relevantServers = []
            }
        }

        let floatingIPAddress = floatingIP.floatingIpAddress ?? "Unknown"
        let modeText = mode == .attach ? "ATTACH" : "DETACH"

        // Build title with attachment status
        var title = "Manage Floating IP Server Assignment - \(floatingIPAddress) - Mode: \(modeText)"
        if let attachedId = attachedServerId, let attachedServer = servers.first(where: { $0.id == attachedId }) {
            let attachedName = attachedServer.name ?? "Unknown"
            title += " (Currently attached to: \(attachedName))"
        } else if mode == .detach {
            title += " (Unassigned)"
        }

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
            checkboxMode: .basic
        )
    }
}