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

// MARK: - Subnet Router Management Input Handler

@MainActor
extension TUI {

    internal func handleSubnetRouterManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard currentView == .subnetRouterManagement else { return }

        // Apply search filter if needed
        let filteredRouters: [Router]
        if let query = searchQuery, !query.isEmpty {
            filteredRouters = cachedRouters.filter { router in
                (router.name?.localizedCaseInsensitiveContains(query) ?? false) ||
                (router.description?.localizedCaseInsensitiveContains(query) ?? false) ||
                (router.status?.localizedCaseInsensitiveContains(query) ?? false)
            }
        } else {
            filteredRouters = cachedRouters
        }

        // Filter routers based on attachment mode
        let relevantRouters: [Router]
        switch attachmentMode {
        case .attach:
            // Show routers that are NOT currently attached to this subnet
            relevantRouters = filteredRouters.filter { !attachedRouterIds.contains($0.id) }
        case .detach:
            // Show routers that ARE currently attached to this subnet
            relevantRouters = filteredRouters.filter { attachedRouterIds.contains($0.id) }
        }

        switch ch {
        case Int32(9): // TAB - toggle attachment mode
            attachmentMode = (attachmentMode == .attach) ? .detach : .attach
            selectedRouterId = nil
            selectedIndex = 0
            scrollOffset = 0
            statusMessage = "Switched to \(attachmentMode == .attach ? "ATTACH" : "DETACH") mode"
        case Int32(32): // SPACE - toggle router selection
            guard selectedIndex < relevantRouters.count else { return }
            let router = relevantRouters[selectedIndex]
            if selectedRouterId == router.id {
                selectedRouterId = nil
                statusMessage = "Deselected router '\(router.name ?? "Unknown")'"
            } else {
                selectedRouterId = router.id
                statusMessage = "Selected router '\(router.name ?? "Unknown")'"
            }
        case Int32(10): // ENTER - apply changes
            needsRedraw = true
            await uiHelpers.performSubnetRouterManagement()
        case Int32(259): // KEY_UP
            if selectedIndex > 0 {
                selectedIndex -= 1
                if selectedIndex < scrollOffset {
                    scrollOffset = selectedIndex
                }
            }
        case Int32(258): // KEY_DOWN
            if selectedIndex < relevantRouters.count - 1 {
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
