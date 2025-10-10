import Foundation
import struct OSClient.FloatingIP
import struct OSClient.Port
import OSClient
import SwiftTUI

@MainActor
struct FloatingIPPortManagementView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, floatingIP: FloatingIP, ports: [Port], attachedPortId: String?, selectedPortId: String?, searchQuery: String?, scrollOffset: Int, selectedIndex: Int, mode: AttachmentMode, resourceResolver: ResourceResolver) async {
        // Filter ports based on mode and attachment status
        // A floating IP can only be attached to one port at a time
        let relevantPorts: [Port]
        switch mode {
        case .attach:
            // ATTACH mode: Only show ports if floating IP is NOT attached
            if attachedPortId != nil {
                // Floating IP is already attached - must detach first
                relevantPorts = []
            } else {
                // Floating IP is free - show all available ports
                relevantPorts = ports
            }
        case .detach:
            // DETACH mode: Show ONLY the attached port
            if let attachedId = attachedPortId {
                relevantPorts = ports.filter { $0.id == attachedId }
            } else {
                relevantPorts = []  // No port attached - show empty list
            }
        }

        let floatingIPAddress = floatingIP.floatingIpAddress ?? floatingIP.id
        let modeText = mode == .attach ? "ATTACH" : "DETACH"

        // Build title with attachment status
        var title = "Manage Floating IP Port Attachment - \(floatingIPAddress) - Mode: \(modeText)"
        if let attachedId = attachedPortId, let attachedPort = ports.first(where: { $0.id == attachedId }) {
            let attachedName = attachedPort.name ?? attachedPort.id
            title += " (Currently attached to: \(attachedName))"
        } else if mode == .detach {
            title += " (Unattached)"
        }

        // Mark the attached port in the selection
        var selectedIds: Set<String> = selectedPortId.map { Set([$0]) } ?? []
        if let attachedId = attachedPortId {
            selectedIds.insert(attachedId)
        }

        await PortSelectionView.drawPortSelection(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            ports: relevantPorts,
            selectedPortIds: selectedIds,
            highlightedIndex: selectedIndex,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            title: title
        )
    }
}
