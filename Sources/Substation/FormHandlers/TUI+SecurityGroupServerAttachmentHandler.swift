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

// MARK: - Security Group Server Attachment Input Handler

@MainActor
extension TUI {

    internal func handleSecurityGroupServerAttachmentInput(_ ch: Int32, screen: OpaquePointer?) async {
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

        case Int32(10): // ENTER - attach security group to selected servers
            needsRedraw = true
            await uiHelpers.performBatchSecurityGroupAttachment()

        case Int32(259): // KEY_UP
            if selectedIndex > 0 {
                selectedIndex -= 1
                // Auto-scroll if selection goes above visible area
                if selectedIndex < scrollOffset {
                    scrollOffset = selectedIndex
                }
            }

        case Int32(258): // KEY_DOWN
            if selectedIndex < filteredServers.count - 1 {
                selectedIndex += 1
                // Auto-scroll if selection goes below visible area
                let visibleRows = 20 // Approximate number of visible rows
                if selectedIndex >= scrollOffset + visibleRows {
                    scrollOffset = selectedIndex - visibleRows + 1
                }
            }

        default:
            // Handle search input
            if ch >= 32 && ch < 127 {
                let character = Character(UnicodeScalar(Int(ch))!)
                if searchQuery == nil {
                    searchQuery = String(character)
                } else {
                    searchQuery! += String(character)
                }
                selectedIndex = 0
                scrollOffset = 0
                await self.draw(screen: screen)
            } else if ch == 127 || ch == 8 { // BACKSPACE
                if searchQuery != nil && !searchQuery!.isEmpty {
                    searchQuery!.removeLast()
                    if searchQuery!.isEmpty {
                        searchQuery = nil
                    }
                    selectedIndex = 0
                    scrollOffset = 0
                    await self.draw(screen: screen)
                }
            }
        }
    }
}
