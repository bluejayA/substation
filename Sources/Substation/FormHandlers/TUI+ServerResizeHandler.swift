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

// MARK: - Server Resize Input Handler

@MainActor
extension TUI {

    /// Dynamic navigation context based on current mode
    var serverResizeNavigationContext: NavigationContext {
        if serverResizeForm.mode == .confirmOrRevert {
            // Confirm/revert mode has 2 options
            return .list(maxIndex: 1)
        } else {
            // Flavor selection mode
            let availableFlavors = serverResizeForm.getAvailableFlavors()
            return .list(maxIndex: max(0, availableFlavors.count - 1))
        }
    }

    internal func handleServerResizeInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Step 1: Try common navigation (context-aware based on mode)
        if await handleServerResizeNavigation(ch, screen: screen) {
            await self.draw(screen: screen)
            return
        }

        // Step 2: Handle view-specific keys (mode-dependent)
        await handleServerResizeSpecificInput(ch, screen: screen)
    }

    /// Handle common navigation using context-aware navigation
    private func handleServerResizeNavigation(_ ch: Int32, screen: OpaquePointer?) async -> Bool {
        let context = serverResizeNavigationContext
        switch context {
        case .list:
            // Handle navigation based on mode
            if serverResizeForm.mode == .confirmOrRevert {
                // Confirm/revert mode - toggle between options on UP/DOWN
                switch ch {
                case Int32(259), Int32(258): // UP or DOWN
                    serverResizeForm.toggleAction()
                    return true
                default:
                    return false
                }
            } else {
                // Flavor selection mode - use standard list navigation
                let availableFlavors = serverResizeForm.getAvailableFlavors()
                if availableFlavors.isEmpty { return false }

                switch ch {
                case Int32(259): // UP
                    serverResizeForm.selectedFlavorIndex = max(0, serverResizeForm.selectedFlavorIndex - 1)
                    return true
                case Int32(258): // DOWN
                    serverResizeForm.selectedFlavorIndex = min(availableFlavors.count - 1, serverResizeForm.selectedFlavorIndex + 1)
                    return true
                default:
                    return false
                }
            }
        default:
            return false
        }
    }

    /// Handle view-specific input (SPACE and ENTER behavior changes based on mode)
    private func handleServerResizeSpecificInput(_ ch: Int32, screen: OpaquePointer?) async {
        if serverResizeForm.mode == .confirmOrRevert {
            // Confirm/revert mode
            switch ch {
            case Int32(32): // SPACE - Toggle between confirm and revert
                serverResizeForm.toggleAction()
                await self.draw(screen: screen)
            case Int32(10), Int32(13): // ENTER - Apply confirm or revert
                needsRedraw = true
                await actions.applyServerResize(screen: screen)
            default:
                break
            }
        } else {
            // Flavor selection mode
            switch ch {
            case Int32(32): // SPACE - Toggle flavor selection
                let availableFlavors = serverResizeForm.getAvailableFlavors()
                if serverResizeForm.selectedFlavorIndex < availableFlavors.count {
                    let selectedFlavor = availableFlavors[serverResizeForm.selectedFlavorIndex]
                    serverResizeForm.toggleFlavorSelection(selectedFlavor.id)
                }
                await self.draw(screen: screen)
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
