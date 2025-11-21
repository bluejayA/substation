import Foundation
import SwiftNCurses
import OSClient

@MainActor
struct NetworkServerManagementView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, network: Network, servers: [Server], attachedServerIds: Set<String>, selectedServers: Set<String>, searchQuery: String?, scrollOffset: Int, selectedIndex: Int, mode: AttachmentMode, resourceResolver: ResourceResolver) async {
        // Filter servers based on current mode
        let relevantServers: [Server]
        switch mode {
        case .attach:
            relevantServers = servers.filter { !attachedServerIds.contains($0.id) }
        case .detach:
            relevantServers = servers.filter { attachedServerIds.contains($0.id) }
        }

        let networkName = network.name ?? "Unknown"
        let modeText = mode == .attach ? "ATTACH" : "DETACH"
        let title = "Manage Network Server Attachments - \(networkName) - Mode: \(modeText)"

        await ServerSelectionView.drawServerSelection(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            servers: relevantServers,
            selectedServerIds: selectedServers,
            highlightedIndex: selectedIndex,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery ?? "",
            title: title,
            checkboxMode: .multiSelect
        )
    }
}