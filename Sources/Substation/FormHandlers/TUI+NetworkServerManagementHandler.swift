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

// MARK: - Network Server Management Input Handler

@MainActor
extension TUI {

    /// Dynamic navigation context based on filtered and mode-specific servers
    var networkServerManagementNavigationContext: NavigationContext {
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

        return .management(itemCount: relevantServers.count)
    }

    internal func handleNetworkServerManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard currentView == .networkServerManagement else { return }

        // Get relevant servers for current mode
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

        let relevantServers: [Server]
        switch attachmentMode {
        case .attach:
            relevantServers = filteredServers.filter { !attachedServerIds.contains($0.id) }
        case .detach:
            relevantServers = filteredServers.filter { attachedServerIds.contains($0.id) }
        }

        // Delegate to FormInputHandler for management-style input handling
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
                await self.uiHelpers.performEnhancedNetworkManagement()
            },
            additionalHandling: { ch in
                await self.handleNetworkServerManagementSpecificInput(ch, screen: screen, relevantServers: relevantServers)
            }
        )
    }

    /// Handle view-specific input (TAB for mode switching)
    private func handleNetworkServerManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?, relevantServers: [Server]) async -> Bool {
        switch ch {
        case Int32(9): // TAB - Switch between attach and detach modes
            attachmentMode = (attachmentMode == .attach) ? .detach : .attach
            selectedServers.removeAll()
            selectedIndex = 0
            scrollOffset = 0
            statusMessage = "Switched to \(attachmentMode == .attach ? "ATTACH" : "DETACH") mode"
            await self.draw(screen: screen)
            return true

        default:
            return false
        }
    }
}
