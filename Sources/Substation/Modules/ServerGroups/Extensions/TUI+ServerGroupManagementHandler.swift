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

// MARK: - Server Group Management Input Handler

/// Extension providing server group management input handling for TUI
///
/// This extension handles keyboard input for the server group management view,
/// supporting navigation through available servers and returning to the main
/// server groups list.
///
/// Supported keys:
/// - UP/DOWN: Navigate through servers
/// - ENTER: Return to server groups list
/// - ESC: Return to server groups list
@MainActor
extension TUI {

    /// Navigation context for server group management
    ///
    /// Provides bounds for keyboard navigation within the server list.
    var serverGroupManagementNavigationContext: NavigationContext {
        let serverCount = serverGroupManagementForm.availableServers.count
        return .list(maxIndex: max(0, serverCount - 1))
    }

    /// Handle keyboard input for server group management view
    ///
    /// Processes navigation and action keys for the server group management interface.
    /// Delegates common navigation to the shared handler, then processes view-specific
    /// actions like ENTER and ESC for returning to the server groups list.
    ///
    /// - Parameters:
    ///   - ch: The key code pressed
    ///   - screen: NCurses screen pointer for rendering
    internal func handleServerGroupManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Try common navigation first
        if await handleCommonNavigation(ch, screen: screen, context: serverGroupManagementNavigationContext) {
            return
        }

        // Handle view-specific input
        await handleServerGroupManagementSpecificInput(ch, screen: screen)
    }

    /// Handle view-specific input for server group management
    ///
    /// - Parameters:
    ///   - ch: The key code pressed
    ///   - screen: NCurses screen pointer for rendering
    private func handleServerGroupManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(10), Int32(13): // ENTER - Return to server groups view
            renderCoordinator.needsRedraw = true
            viewCoordinator.currentView = .serverGroups
            await self.draw(screen: screen)
        case Int32(27): // ESC - Go back to server groups list
            viewCoordinator.currentView = .serverGroups
            await self.draw(screen: screen)
        default:
            break
        }
    }
}
