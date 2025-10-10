import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

@MainActor
struct PortServerManagementView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, port: Port, servers: [Server], attachedServerId: String?, selectedServerId: String?, searchQuery: String?, scrollOffset: Int, selectedIndex: Int, mode: AttachmentMode, resourceResolver: ResourceResolver) async {
        // Filter servers based on mode and attachment status
        // A port can only be attached to one server at a time
        let relevantServers: [Server]
        switch mode {
        case .attach:
            // ATTACH mode: Only show servers if port is NOT attached
            if attachedServerId != nil {
                // Port is already attached - must detach first
                relevantServers = []
            } else {
                // Port is free - show all available servers
                relevantServers = servers
            }
        case .detach:
            // DETACH mode: Show ONLY the attached server
            if let attachedId = attachedServerId {
                relevantServers = servers.filter { $0.id == attachedId }
            } else {
                relevantServers = []  // No server attached - show empty list
            }
        }

        let portName = port.name ?? port.id
        let modeText = mode == .attach ? "ATTACH" : "DETACH"

        // Build title with attachment status
        var title = "Manage Port Server Attachment - \(portName) - Mode: \(modeText)"
        if let attachedId = attachedServerId, let attachedServer = servers.first(where: { $0.id == attachedId }) {
            let attachedName = attachedServer.name ?? "Unknown"
            title += " (Currently attached to: \(attachedName))"
        } else if mode == .detach {
            title += " (Unattached)"
        }

        // Mark the attached server in the selection
        var selectedIds: Set<String> = selectedServerId.map { Set([$0]) } ?? []
        if let attachedId = attachedServerId {
            selectedIds.insert(attachedId)
        }

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
