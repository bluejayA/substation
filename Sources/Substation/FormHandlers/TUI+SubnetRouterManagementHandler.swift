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

    var subnetRouterManagementNavigationContext: NavigationContext {
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

        let relevantRouters: [Router]
        switch attachmentMode {
        case .attach:
            relevantRouters = filteredRouters.filter { !attachedRouterIds.contains($0.id) }
        case .detach:
            relevantRouters = filteredRouters.filter { attachedRouterIds.contains($0.id) }
        }

        return .list(maxIndex: max(0, relevantRouters.count - 1))
    }

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

        // Try common navigation first
        if await handleCommonNavigation(ch, screen: screen, context: subnetRouterManagementNavigationContext) {
            return
        }

        // Handle view-specific input
        await handleSubnetRouterManagementSpecificInput(ch, screen: screen, relevantRouters: relevantRouters)
    }

    private func handleSubnetRouterManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?, relevantRouters: [Router]) async {
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
        case Int32(27): // ESC - back to subnet list
            _ = await handleSubnetRouterManagementEscape()
        default:
            break
        }
    }

    private func handleSubnetRouterManagementEscape() async -> Bool {
        // Use centralized ESC handling
        return await NavigationInputHandler.handleEscapeKey(tui: self)
    }
}
