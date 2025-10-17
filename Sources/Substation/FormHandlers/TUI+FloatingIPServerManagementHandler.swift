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

// MARK: - Floating IP Server Management Input Handler

@MainActor
extension TUI {

    internal func handleFloatingIPServerManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard currentView == .floatingIPServerManagement else { return }

        // Apply search filter if needed
        let filteredServers: [Server]
        if let query = searchQuery, !query.isEmpty {
            filteredServers = cachedServers.filter { server in
                (server.name?.localizedCaseInsensitiveContains(query) ?? false) ||
                (server.status?.rawValue.localizedCaseInsensitiveContains(query) ?? false) ||
                (server.addresses?.values.flatMap { $0 }.first?.addr.localizedCaseInsensitiveContains(query) ?? false)
            }
        } else {
            filteredServers = cachedServers
        }

        // Floating IPs have a one-to-one relationship with servers
        // Filter based on mode:
        // - ATTACH: Show all servers EXCEPT the currently attached one
        // - DETACH: Show ONLY the currently attached server (empty if unassigned)
        let relevantServers: [Server]
        switch attachmentMode {
        case .attach:
            if let attachedId = attachedServerId {
                relevantServers = filteredServers.filter { $0.id != attachedId }
            } else {
                relevantServers = filteredServers
            }
        case .detach:
            if let attachedId = attachedServerId {
                relevantServers = filteredServers.filter { $0.id == attachedId }
            } else {
                // No server attached - show empty list
                relevantServers = []
            }
        }

        let _ = await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: relevantServers.count,
            onToggle: {
                guard self.selectedIndex < relevantServers.count else { return }
                let server = relevantServers[self.selectedIndex]
                if self.selectedServerId == server.id {
                    self.selectedServerId = nil
                    self.statusMessage = "Deselected server '\(server.name ?? "Unknown")'"
                } else {
                    self.selectedServerId = server.id
                    self.statusMessage = "Selected server '\(server.name ?? "Unknown")'"
                }
            },
            onEnter: {
                self.needsRedraw = true
                await self.uiHelpers.performFloatingIPServerManagement()
            },
            additionalHandling: { ch in
                // Handle TAB for mode switching
                if ch == Int32(9) {
                    self.attachmentMode = (self.attachmentMode == .attach) ? .detach : .attach
                    self.selectedServerId = nil
                    self.selectedIndex = 0
                    self.scrollOffset = 0
                    self.statusMessage = "Switched to \(self.attachmentMode == .attach ? "ASSIGN" : "UNASSIGN") mode"
                    return true
                }
                return false
            }
        )
    }
}
