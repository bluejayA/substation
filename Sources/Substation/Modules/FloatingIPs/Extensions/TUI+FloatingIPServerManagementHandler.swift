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

    internal func handleFloatingIPServerManagementInput(_ ch: Int32, screen: OpaquePointer?) async -> Bool {
        // Guard removed - ViewRegistry ensures this handler is only called for the correct view

        // Apply search filter if needed
        let filteredServers: [Server]
        if let query = searchQuery, !query.isEmpty {
            filteredServers = cacheManager.cachedServers.filter { server in
                (server.name?.localizedCaseInsensitiveContains(query) ?? false) ||
                (server.status?.rawValue.localizedCaseInsensitiveContains(query) ?? false) ||
                (server.addresses?.values.flatMap { $0 }.first?.addr.localizedCaseInsensitiveContains(query) ?? false)
            }
        } else {
            filteredServers = cacheManager.cachedServers
        }

        // Floating IPs have a one-to-one relationship with servers
        // Filter based on mode:
        // - ATTACH: Show all servers EXCEPT the currently attached one
        // - DETACH: Show ONLY the currently attached server (empty if unassigned)
        let relevantServers: [Server]
        switch selectionManager.attachmentMode {
        case .attach:
            if let attachedId = selectionManager.attachedServerId {
                relevantServers = filteredServers.filter { $0.id != attachedId }
            } else {
                relevantServers = filteredServers
            }
        case .detach:
            if let attachedId = selectionManager.attachedServerId {
                relevantServers = filteredServers.filter { $0.id == attachedId }
            } else {
                // No server attached - show empty list
                relevantServers = []
            }
        }

        return await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: relevantServers.count,
            onToggle: {
                guard self.viewCoordinator.selectedIndex < relevantServers.count else { return }
                let server = relevantServers[self.viewCoordinator.selectedIndex]
                if self.selectionManager.selectedServerId == server.id {
                    self.selectionManager.selectedServerId = nil
                    self.statusMessage = "Deselected server '\(server.name ?? "Unknown")'"
                } else {
                    self.selectionManager.selectedServerId = server.id
                    self.statusMessage = "Selected server '\(server.name ?? "Unknown")'"
                }
                self.renderCoordinator.needsRedraw = true
                await self.draw(screen: screen)
            },
            onEnter: {
                self.renderCoordinator.needsRedraw = true
                guard let module = ModuleRegistry.shared.module(for: "floatingips") as? FloatingIPsModule else {
                    Logger.shared.logError("Failed to get FloatingIPsModule from registry", context: [:])
                    self.statusMessage = "Error: Floating IPs module not available"
                    return
                }
                await module.performFloatingIPServerManagement()
            },
            additionalHandling: { ch in
                // Handle TAB for mode switching
                if ch == Int32(9) {
                    self.selectionManager.attachmentMode = (self.selectionManager.attachmentMode == .attach) ? .detach : .attach
                    self.selectionManager.selectedServerId = nil
                    self.viewCoordinator.selectedIndex = 0
                    self.viewCoordinator.scrollOffset = 0
                    self.statusMessage = "Switched to \(self.selectionManager.attachmentMode == .attach ? "ASSIGN" : "UNASSIGN") mode"
                    self.renderCoordinator.needsRedraw = true
                    await self.draw(screen: screen)
                    return true
                }
                return false
            }
        )
    }
}
