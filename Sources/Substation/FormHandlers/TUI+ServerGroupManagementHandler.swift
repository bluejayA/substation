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

    internal func handleServerGroupManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(259): // UP arrow - Previous server
            serverGroupManagementForm.moveToPreviousServer()
            await self.draw(screen: screen)
        case Int32(258): // DOWN arrow - Next server
            serverGroupManagementForm.moveToNextServer()
            await self.draw(screen: screen)
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
