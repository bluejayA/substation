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

// MARK: - Server Group Management Input Handler

@MainActor
extension TUI {

    var serverGroupManagementNavigationContext: NavigationContext {
        let serverCount = serverGroupManagementForm.availableServers.count
        return .list(maxIndex: max(0, serverCount - 1))
    }

    internal func handleServerGroupManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Try common navigation first
        if await handleCommonNavigation(ch, screen: screen, context: serverGroupManagementNavigationContext) {
            return
        }

        // Handle view-specific input
        await handleServerGroupManagementSpecificInput(ch, screen: screen)
    }

    private func handleServerGroupManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(10), Int32(13): // ENTER - Return to server groups view
            needsRedraw = true
            currentView = .serverGroups
            await self.draw(screen: screen)
        case Int32(27): // ESC - Go back to server groups list
            currentView = .serverGroups
            await self.draw(screen: screen)
        default:
            break
        }
    }
}
