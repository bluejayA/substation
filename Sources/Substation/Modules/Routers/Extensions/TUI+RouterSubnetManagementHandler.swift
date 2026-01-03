// Sources/Substation/Modules/Routers/Extensions/TUI+RouterSubnetManagementHandler.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses

// MARK: - Router Subnet Management Input Handler

/// Extension providing router subnet management input handling for TUI
///
/// This extension handles keyboard input for the router subnet management view,
/// supporting navigation, selection, and attachment/detachment operations.
///
/// Supported keys:
/// - UP/DOWN: Navigate through subnets
/// - TAB: Toggle between attach/detach mode
/// - SPACE: Toggle subnet selection
/// - ENTER: Apply changes
/// - ESC: Return to router list
@MainActor
extension TUI {

    /// Navigation context for router subnet management
    ///
    /// Provides bounds for keyboard navigation within the filtered subnet list
    /// based on the current attachment mode.
    var routerSubnetManagementNavigationContext: NavigationContext {
        let filteredSubnets: [Subnet]
        if let query = searchQuery, !query.isEmpty {
            filteredSubnets = cacheManager.cachedSubnets.filter { subnet in
                (subnet.name?.localizedCaseInsensitiveContains(query) ?? false) ||
                subnet.cidr.localizedCaseInsensitiveContains(query)
            }
        } else {
            filteredSubnets = cacheManager.cachedSubnets
        }

        let relevantSubnets: [Subnet]
        switch selectionManager.attachmentMode {
        case .attach:
            relevantSubnets = filteredSubnets.filter { !selectionManager.attachedSubnetIds.contains($0.id) }
        case .detach:
            relevantSubnets = filteredSubnets.filter { selectionManager.attachedSubnetIds.contains($0.id) }
        }

        return .list(maxIndex: max(0, relevantSubnets.count - 1))
    }

    /// Handle keyboard input for router subnet management view
    ///
    /// Processes navigation and action keys for the router subnet management interface.
    /// Supports filtering, mode toggling, subnet selection, and applying changes.
    ///
    /// - Parameters:
    ///   - ch: The key code pressed
    ///   - screen: NCurses screen pointer for rendering
    internal func handleRouterSubnetManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard viewCoordinator.currentView == .routerSubnetManagement else { return }

        // Apply search filter if needed
        let filteredSubnets: [Subnet]
        if let query = searchQuery, !query.isEmpty {
            filteredSubnets = cacheManager.cachedSubnets.filter { subnet in
                (subnet.name?.localizedCaseInsensitiveContains(query) ?? false) ||
                subnet.cidr.localizedCaseInsensitiveContains(query)
            }
        } else {
            filteredSubnets = cacheManager.cachedSubnets
        }

        // Filter subnets based on attachment mode
        let relevantSubnets: [Subnet]
        switch selectionManager.attachmentMode {
        case .attach:
            // Show subnets that are NOT currently attached to this router
            relevantSubnets = filteredSubnets.filter { !selectionManager.attachedSubnetIds.contains($0.id) }
        case .detach:
            // Show subnets that ARE currently attached to this router
            relevantSubnets = filteredSubnets.filter { selectionManager.attachedSubnetIds.contains($0.id) }
        }

        // Try common navigation first
        if await handleCommonNavigation(ch, screen: screen, context: routerSubnetManagementNavigationContext) {
            return
        }

        // Handle view-specific input
        await handleRouterSubnetManagementSpecificInput(ch, screen: screen, relevantSubnets: relevantSubnets)
    }

    /// Handle view-specific input for router subnet management
    ///
    /// - Parameters:
    ///   - ch: The key code pressed
    ///   - screen: NCurses screen pointer for rendering
    ///   - relevantSubnets: Filtered list of subnets based on current mode
    private func handleRouterSubnetManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?, relevantSubnets: [Subnet]) async {
        switch ch {
        case Int32(9): // TAB - toggle attachment mode
            selectionManager.attachmentMode = (selectionManager.attachmentMode == .attach) ? .detach : .attach
            selectionManager.selectedSubnetId = nil
            viewCoordinator.selectedIndex = 0
            viewCoordinator.scrollOffset = 0
            statusMessage = "Switched to \(selectionManager.attachmentMode == .attach ? "ATTACH" : "DETACH") mode"
        case Int32(32): // SPACE - toggle subnet selection
            guard viewCoordinator.selectedIndex < relevantSubnets.count else { return }
            let subnet = relevantSubnets[viewCoordinator.selectedIndex]
            if selectionManager.selectedSubnetId == subnet.id {
                selectionManager.selectedSubnetId = nil
                statusMessage = "Deselected subnet '\(subnet.name ?? subnet.cidr)'"
            } else {
                selectionManager.selectedSubnetId = subnet.id
                statusMessage = "Selected subnet '\(subnet.name ?? subnet.cidr)'"
            }
        case Int32(10): // ENTER - apply changes
            renderCoordinator.needsRedraw = true
            guard let module = ModuleRegistry.shared.module(for: "routers") as? RoutersModule else {
                Logger.shared.logError("Failed to get RoutersModule from registry", context: [:])
                statusMessage = "Error: Routers module not available"
                return
            }
            await module.performRouterSubnetManagement(screen: screen)
        case Int32(27): // ESC - back to router list
            _ = await handleRouterSubnetManagementEscape()
        default:
            break
        }
    }

    /// Handle ESC key press for router subnet management
    ///
    /// Uses centralized navigation handling to return to the previous view.
    ///
    /// - Returns: Boolean indicating if navigation was handled
    private func handleRouterSubnetManagementEscape() async -> Bool {
        // Use centralized ESC handling
        return await NavigationInputHandler.handleEscapeKey(tui: self)
    }
}
