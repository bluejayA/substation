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

// MARK: - Subnet Router Management Input Handler

/// Extension providing subnet router management input handling for TUI
///
/// This extension handles keyboard input for the subnet router management view,
/// supporting navigation, selection, and attachment/detachment operations.
///
/// Supported keys:
/// - UP/DOWN: Navigate through routers
/// - TAB: Toggle between attach/detach mode
/// - SPACE: Toggle router selection
/// - ENTER: Apply changes
/// - ESC: Return to subnet list
@MainActor
extension TUI {

    /// Navigation context for subnet router management
    ///
    /// Provides bounds for keyboard navigation within the filtered router list
    /// based on the current attachment mode.
    var subnetRouterManagementNavigationContext: NavigationContext {
        let filteredRouters: [Router]
        if let query = searchQuery, !query.isEmpty {
            filteredRouters = cacheManager.cachedRouters.filter { router in
                (router.name?.localizedCaseInsensitiveContains(query) ?? false) ||
                (router.description?.localizedCaseInsensitiveContains(query) ?? false) ||
                (router.status?.localizedCaseInsensitiveContains(query) ?? false)
            }
        } else {
            filteredRouters = cacheManager.cachedRouters
        }

        let relevantRouters: [Router]
        switch selectionManager.attachmentMode {
        case .attach:
            relevantRouters = filteredRouters.filter { !selectionManager.attachedRouterIds.contains($0.id) }
        case .detach:
            relevantRouters = filteredRouters.filter { selectionManager.attachedRouterIds.contains($0.id) }
        }

        return .list(maxIndex: max(0, relevantRouters.count - 1))
    }

    /// Handle keyboard input for subnet router management view
    ///
    /// Processes navigation and action keys for the subnet router management interface.
    /// Supports filtering, mode toggling, router selection, and applying changes.
    ///
    /// - Parameters:
    ///   - ch: The key code pressed
    ///   - screen: NCurses screen pointer for rendering
    internal func handleSubnetRouterManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard viewCoordinator.currentView == .subnetRouterManagement else { return }

        // Apply search filter if needed
        let filteredRouters: [Router]
        if let query = searchQuery, !query.isEmpty {
            filteredRouters = cacheManager.cachedRouters.filter { router in
                (router.name?.localizedCaseInsensitiveContains(query) ?? false) ||
                (router.description?.localizedCaseInsensitiveContains(query) ?? false) ||
                (router.status?.localizedCaseInsensitiveContains(query) ?? false)
            }
        } else {
            filteredRouters = cacheManager.cachedRouters
        }

        // Filter routers based on attachment mode
        let relevantRouters: [Router]
        switch selectionManager.attachmentMode {
        case .attach:
            // Show routers that are NOT currently attached to this subnet
            relevantRouters = filteredRouters.filter { !selectionManager.attachedRouterIds.contains($0.id) }
        case .detach:
            // Show routers that ARE currently attached to this subnet
            relevantRouters = filteredRouters.filter { selectionManager.attachedRouterIds.contains($0.id) }
        }

        // Try common navigation first
        if await handleCommonNavigation(ch, screen: screen, context: subnetRouterManagementNavigationContext) {
            return
        }

        // Handle view-specific input
        await handleSubnetRouterManagementSpecificInput(ch, screen: screen, relevantRouters: relevantRouters)
    }

    /// Handle view-specific input for subnet router management
    ///
    /// - Parameters:
    ///   - ch: The key code pressed
    ///   - screen: NCurses screen pointer for rendering
    ///   - relevantRouters: Filtered list of routers based on current mode
    private func handleSubnetRouterManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?, relevantRouters: [Router]) async {
        switch ch {
        case Int32(9): // TAB - toggle attachment mode
            selectionManager.attachmentMode = (selectionManager.attachmentMode == .attach) ? .detach : .attach
            selectionManager.selectedRouterId = nil
            viewCoordinator.selectedIndex = 0
            viewCoordinator.scrollOffset = 0
            statusMessage = "Switched to \(selectionManager.attachmentMode == .attach ? "ATTACH" : "DETACH") mode"
        case Int32(32): // SPACE - toggle router selection
            guard viewCoordinator.selectedIndex < relevantRouters.count else { return }
            let router = relevantRouters[viewCoordinator.selectedIndex]
            if selectionManager.selectedRouterId == router.id {
                selectionManager.selectedRouterId = nil
                statusMessage = "Deselected router '\(router.name ?? "Unknown")'"
            } else {
                selectionManager.selectedRouterId = router.id
                statusMessage = "Selected router '\(router.name ?? "Unknown")'"
            }
        case Int32(10): // ENTER - apply changes
            renderCoordinator.needsRedraw = true
            if let module = ModuleRegistry.shared.module(for: "subnets") as? SubnetsModule {
                await module.performSubnetRouterManagement()
            }
        case Int32(27): // ESC - back to subnet list
            _ = await handleSubnetRouterManagementEscape()
        default:
            break
        }
    }

    /// Handle ESC key press for subnet router management
    ///
    /// Uses centralized navigation handling to return to the previous view.
    ///
    /// - Returns: Boolean indicating if navigation was handled
    private func handleSubnetRouterManagementEscape() async -> Bool {
        // Use centralized ESC handling
        return await NavigationInputHandler.handleEscapeKey(tui: self)
    }
}
