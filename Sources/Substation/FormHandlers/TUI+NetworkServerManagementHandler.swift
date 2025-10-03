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

// MARK: - Network Server Management Input Handler

@MainActor
extension TUI {

    internal func handleNetworkServerManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard currentView == .networkServerManagement else { return }

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

        switch ch {
        case Int32(9): // TAB - toggle attachment mode
            attachmentMode = (attachmentMode == .attach) ? .detach : .attach
            selectedServers.removeAll()
            selectedIndex = 0
            scrollOffset = 0
            statusMessage = "Switched to \(attachmentMode == .attach ? "ATTACH" : "DETACH") mode"
        case Int32(32): // SPACE - toggle server selection
            guard selectedIndex < relevantServers.count else { return }
            let server = relevantServers[selectedIndex]
            if selectedServers.contains(server.id) {
                selectedServers.remove(server.id)
                statusMessage = "Deselected server '\(server.name ?? "Unknown")'"
            } else {
                selectedServers.insert(server.id)
                statusMessage = "Selected server '\(server.name ?? "Unknown")'"
            }
        case Int32(10): // ENTER - apply changes
            needsRedraw = true
            await uiHelpers.performEnhancedNetworkManagement()
        case Int32(259): // KEY_UP
            if selectedIndex > 0 {
                selectedIndex -= 1
                if selectedIndex < scrollOffset {
                    scrollOffset = selectedIndex
                }
            }
        case Int32(258): // KEY_DOWN
            if selectedIndex < relevantServers.count - 1 {
                selectedIndex += 1
                let visibleRows = 20
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
