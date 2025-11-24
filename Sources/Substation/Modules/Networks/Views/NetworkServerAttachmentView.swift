import Foundation
import SwiftNCurses
import OSClient

@MainActor
struct NetworkServerAttachmentView {

    /// Draws the network server attachment view for selecting servers to attach a network to
    /// - Parameters:
    ///   - screen: The ncurses screen pointer
    ///   - startRow: The starting row position for drawing
    ///   - startCol: The starting column position for drawing
    ///   - width: The width of the drawable area
    ///   - height: The height of the drawable area
    ///   - servers: Array of available servers to select from
    ///   - selectedServers: Set of currently selected server IDs
    ///   - searchQuery: Optional search filter for server names
    ///   - scrollOffset: Current scroll position in the list
    ///   - selectedIndex: Index of the currently highlighted server
    @MainActor
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
            title: "Attach Network to Servers",
            checkboxMode: .multiSelect
        )
    }
}