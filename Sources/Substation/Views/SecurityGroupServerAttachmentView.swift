import Foundation
import SwiftTUI
import OSClient

@MainActor
struct SecurityGroupServerAttachmentView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, servers: [Server], selectedServers: Set<String>, searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {
        await ServerSelectionView.drawServerSelection(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            servers: servers,
            selectedServerIds: selectedServers,
            highlightedIndex: selectedIndex,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            title: "Attach Security Group to Servers",
            checkboxMode: .multiSelect
        )
    }
}