import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Network Server Attachment Input Handler

@MainActor
extension TUI {

    internal func handleNetworkServerAttachmentInput(_ ch: Int32, screen: OpaquePointer?) async {
        let filteredServers = FilterUtils.filterServers(cacheManager.cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)

        switch ch {
        case 32: // SPACE - toggle server selection
            guard viewCoordinator.selectedIndex < filteredServers.count else { return }
            let server = filteredServers[viewCoordinator.selectedIndex]

            if selectionManager.selectedServers.contains(server.id) {
                selectionManager.selectedServers.remove(server.id)
                statusMessage = "Deselected server '\(server.name ?? "Unknown")'"
            } else {
                selectionManager.selectedServers.insert(server.id)
                statusMessage = "Selected server '\(server.name ?? "Unknown")'"
            }

        case Int32(10): // ENTER - attach network to selected servers
            renderCoordinator.needsRedraw = true
            if let module = ModuleRegistry.shared.module(for: "networks") as? NetworksModule {
                await module.performBatchNetworkAttachment()
            }

        case Int32(259), Int32(258): // UP/DOWN - Navigate list
            if ch == Int32(259) {
                if viewCoordinator.selectedIndex > 0 {
                    viewCoordinator.selectedIndex -= 1
                    // Auto-scroll if selection goes above visible area
                    if viewCoordinator.selectedIndex < viewCoordinator.scrollOffset {
                        viewCoordinator.scrollOffset = viewCoordinator.selectedIndex
                    }
                }
            } else {
                if viewCoordinator.selectedIndex < filteredServers.count - 1 {
                    viewCoordinator.selectedIndex += 1
                    // Auto-scroll if selection goes below visible area
                    let visibleRows = 20 // Approximate number of visible rows
                    if viewCoordinator.selectedIndex >= viewCoordinator.scrollOffset + visibleRows {
                        viewCoordinator.scrollOffset = viewCoordinator.selectedIndex - visibleRows + 1
                    }
                }
            }

        default:
            break
        }
    }
}
