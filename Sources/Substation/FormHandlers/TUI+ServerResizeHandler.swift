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

// MARK: - Server Resize Input Handler

@MainActor
extension TUI {

    internal func handleServerResizeInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Check if we're in confirm/revert mode
        if serverResizeForm.mode == .confirmOrRevert {
            switch ch {
            case Int32(259), Int32(258): // UP or DOWN - Toggle between confirm and revert
                serverResizeForm.toggleAction()
            case Int32(32): // SPACE - Toggle between confirm and revert
                serverResizeForm.toggleAction()
            case Int32(10), Int32(13): // ENTER - Apply confirm or revert
                needsRedraw = true
                await actions.applyServerResize(screen: screen)
            default:
                break
            }
        } else {
            // Normal flavor selection mode
            switch ch {
            case Int32(259): // UP
                let availableFlavors = serverResizeForm.getAvailableFlavors()
                if !availableFlavors.isEmpty {
                    serverResizeForm.selectedFlavorIndex = max(0, serverResizeForm.selectedFlavorIndex - 1)
                }
            case Int32(258): // DOWN
                let availableFlavors = serverResizeForm.getAvailableFlavors()
                if !availableFlavors.isEmpty {
                    serverResizeForm.selectedFlavorIndex = min(availableFlavors.count - 1, serverResizeForm.selectedFlavorIndex + 1)
                }
            case Int32(32): // SPACE - Toggle flavor selection
                let availableFlavors = serverResizeForm.getAvailableFlavors()
                if serverResizeForm.selectedFlavorIndex < availableFlavors.count {
                    let selectedFlavor = availableFlavors[serverResizeForm.selectedFlavorIndex]
                    serverResizeForm.toggleFlavorSelection(selectedFlavor.id)
                }
            case Int32(10), Int32(13): // ENTER - Apply resize
                needsRedraw = true
                if serverResizeForm.hasPendingChanges() {
                    await actions.applyServerResize(screen: screen)
                }
            default:
                break
            }
        }
    }
}
