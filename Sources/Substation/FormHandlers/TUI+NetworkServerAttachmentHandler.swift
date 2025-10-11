import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftTUI
import MemoryKit

// MARK: - Network Server Attachment Input Handler

@MainActor
extension TUI {

    internal func handleNetworkServerAttachmentInput(_ ch: Int32, screen: OpaquePointer?) async {
        let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)

        switch ch {
        case 32: // SPACE - toggle server selection
            guard selectedIndex < filteredServers.count else { return }
            let server = filteredServers[selectedIndex]

            if selectedServers.contains(server.id) {
                selectedServers.remove(server.id)
                statusMessage = "Deselected server '\(server.name ?? "Unknown")'"
            } else {
                selectedServers.insert(server.id)
                statusMessage = "Selected server '\(server.name ?? "Unknown")'"
            }

        case Int32(10): // ENTER - attach network to selected servers
            needsRedraw = true
            await uiHelpers.performBatchNetworkAttachment()

        case Int32(259), Int32(258): // UP/DOWN - Navigate list
            if ch == Int32(259) {
                if selectedIndex > 0 {
                    selectedIndex -= 1
                    // Auto-scroll if selection goes above visible area
                    if selectedIndex < scrollOffset {
                        scrollOffset = selectedIndex
                    }
                }
            } else {
                if selectedIndex < filteredServers.count - 1 {
                    selectedIndex += 1
                    // Auto-scroll if selection goes below visible area
                    let visibleRows = 20 // Approximate number of visible rows
                    if selectedIndex >= scrollOffset + visibleRows {
                        scrollOffset = selectedIndex - visibleRows + 1
                    }
                }
            }

        default:
            break
        }
    }
}
