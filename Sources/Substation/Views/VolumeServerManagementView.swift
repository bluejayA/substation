import Foundation
import SwiftTUI
import OSClient

@MainActor
struct VolumeServerManagementView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, volume: Volume, servers: [Server], attachedServerIds: Set<String>, selectedServers: Set<String>, searchQuery: String?, scrollOffset: Int, selectedIndex: Int, mode: AttachmentMode, resourceResolver: ResourceResolver) async {
        let volumeName = volume.name ?? "Unknown"
        let volumeSize = volume.size ?? 0
        let modeText = mode == .attach ? "ATTACH" : "DETACH"
        let title = "Manage Volume Server Attachments - \(volumeName) (\(volumeSize)GB) - Mode: \(modeText)"

        // Filter servers based on mode
        let filteredServers: [Server]
        switch mode {
        case .attach:
            // Show servers that don't have the volume attached
            filteredServers = servers.filter { !attachedServerIds.contains($0.id) }
        case .detach:
            // Show only servers that have the volume attached
            filteredServers = servers.filter { attachedServerIds.contains($0.id) }
        }

        await ServerSelectionView.drawServerSelection(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            servers: filteredServers,
            selectedServerIds: selectedServers,
            highlightedIndex: selectedIndex,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery ?? "",
            title: title,
            multiSelect: true
        )
    }
}