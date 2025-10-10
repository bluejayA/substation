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

    var securityGroupServerAttachmentNavigationContext: NavigationContext {
        let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
        return .list(maxIndex: max(0, filteredServers.count - 1))
    }

    internal func handleSecurityGroupServerAttachmentInput(_ ch: Int32, screen: OpaquePointer?) async {
        let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)

        // Try common navigation first
        if await handleCommonNavigation(ch, screen: screen, context: securityGroupServerAttachmentNavigationContext) {
            return
        }

        // Handle view-specific input
        await handleSecurityGroupServerAttachmentSpecificInput(ch, screen: screen, filteredServers: filteredServers)
    }

    private func handleSecurityGroupServerAttachmentSpecificInput(_ ch: Int32, screen: OpaquePointer?, filteredServers: [Server]) async {
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

        default:
            break
        }
    }
}
