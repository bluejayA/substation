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

// MARK: - Security Group Server Management Input Handler

@MainActor
extension TUI {

    /// Handle input for security group server management view
    ///
    /// Processes keyboard input for managing security group attachments to servers.
    /// Supports dual-mode operation (attach/detach), server selection, and batch operations.
    ///
    /// **Mode Switching:**
    /// - TAB toggles between attach and detach modes
    /// - Mode change clears selections and resets position
    ///
    /// **Supported Keys:**
    /// - UP/DOWN: Navigate server list
    /// - SPACE: Toggle server selection
    /// - TAB: Switch between attach/detach modes
    /// - ENTER: Execute batch operation
    /// - ESC: Cancel and return to security groups
    ///
    /// - Parameters:
    ///   - ch: The input character code
    ///   - screen: The ncurses screen pointer for rendering
    internal func handleSecurityGroupServerManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard viewCoordinator.currentView == .securityGroupServerManagement else { return }

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

        // Filter servers based on current mode
        let relevantServers: [Server]
        switch selectionManager.attachmentMode {
        case .attach:
            relevantServers = filteredServers.filter { !selectionManager.attachedServerIds.contains($0.id) }
        case .detach:
            relevantServers = filteredServers.filter { selectionManager.attachedServerIds.contains($0.id) }
        }

        let _ = await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: relevantServers.count,
            onToggle: {
                guard self.viewCoordinator.selectedIndex < relevantServers.count else { return }
                let server = relevantServers[self.viewCoordinator.selectedIndex]
                if self.selectionManager.selectedServers.contains(server.id) {
                    self.selectionManager.selectedServers.remove(server.id)
                    self.statusMessage = "Deselected server '\(server.name ?? "Unknown")'"
                } else {
                    self.selectionManager.selectedServers.insert(server.id)
                    self.statusMessage = "Selected server '\(server.name ?? "Unknown")'"
                }
            },
            onEnter: {
                self.renderCoordinator.needsRedraw = true
                if let module = ModuleRegistry.shared.module(for: "securitygroups") as? SecurityGroupsModule {
                    await module.performEnhancedSecurityGroupManagement()
                }
            },
            additionalHandling: { ch in
                // Handle TAB for mode switching
                if ch == Int32(9) {
                    self.selectionManager.attachmentMode = (self.selectionManager.attachmentMode == .attach) ? .detach : .attach
                    self.selectionManager.selectedServers.removeAll()
                    self.viewCoordinator.selectedIndex = 0
                    self.viewCoordinator.scrollOffset = 0
                    self.statusMessage = "Switched to \(self.selectionManager.attachmentMode == .attach ? "ATTACH" : "DETACH") mode"
                    return true
                }

                // Handle ESC to cancel
                if ch == Int32(27) {
                    self.selectionManager.selectedServers.removeAll()
                    self.selectionManager.attachedServerIds.removeAll()
                    self.changeView(to: .securityGroups, resetSelection: false)
                    self.statusMessage = "Server management cancelled"
                    return true
                }

                return false
            }
        )
    }
}
