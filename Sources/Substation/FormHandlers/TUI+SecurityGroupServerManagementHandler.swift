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

// MARK: - Security Group Server Management Input Handler

@MainActor
extension TUI {

    internal func handleSecurityGroupServerManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard currentView == .securityGroupServerManagement else { return }

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

        // Filter servers based on current mode
        let relevantServers: [Server]
        switch attachmentMode {
        case .attach:
            relevantServers = filteredServers.filter { !attachedServerIds.contains($0.id) }
        case .detach:
            relevantServers = filteredServers.filter { attachedServerIds.contains($0.id) }
        }

        let _ = await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: relevantServers.count,
            onToggle: {
                guard self.selectedIndex < relevantServers.count else { return }
                let server = relevantServers[self.selectedIndex]
                if self.selectedServers.contains(server.id) {
                    self.selectedServers.remove(server.id)
                    self.statusMessage = "Deselected server '\(server.name ?? "Unknown")'"
                } else {
                    self.selectedServers.insert(server.id)
                    self.statusMessage = "Selected server '\(server.name ?? "Unknown")'"
                }
            },
            onEnter: {
                self.needsRedraw = true
                await self.uiHelpers.performEnhancedSecurityGroupManagement()
            },
            additionalHandling: { ch in
                // Handle TAB for mode switching
                if ch == Int32(9) {
                    self.attachmentMode = (self.attachmentMode == .attach) ? .detach : .attach
                    self.selectedServers.removeAll()
                    self.selectedIndex = 0
                    self.scrollOffset = 0
                    self.statusMessage = "Switched to \(self.attachmentMode == .attach ? "ATTACH" : "DETACH") mode"
                    return true
                }
                return false
            }
        )
    }
}
