import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

// MARK: - Allowed Address Pair Management Input Handling
//
// Simple interaction model:
// 1. User presses SHIFT-E on a port
// 2. Shows list of all available ports
// 3. SPACE toggles port selection for allowed address pairs
// 4. ENTER applies changes
// 5. ESC cancels and returns to ports view
//
// No other hotkeys or modes

@MainActor
extension TUI {

    internal func handleAllowedAddressPairManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard currentView == .portAllowedAddressPairManagement else { return }
        guard let form = allowedAddressPairForm else { return }

        let portCount = cachedPorts.count

        // Synchronize selectedIndex with form's highlightedPortIndex
        selectedIndex = form.highlightedPortIndex

        let _ = await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: portCount,
            onToggle: {
                // SPACE - Toggle port for allowed address pairs
                if var updatedForm = self.allowedAddressPairForm {
                    updatedForm.highlightedPortIndex = self.selectedIndex
                    updatedForm.togglePortSelection()

                    if let port = updatedForm.getHighlightedPort() {
                        let portName = port.name ?? port.id
                        let status = updatedForm.getPortSelectionStatus(port.id)
                        switch status {
                        case .available:
                            self.statusMessage = "'\(portName)' - removed from selection"
                        case .currentlyUsed:
                            self.statusMessage = "'\(portName)' - currently used (unchanged)"
                        case .pendingAddition:
                            self.statusMessage = "'\(portName)' - will be added"
                        case .pendingRemoval:
                            self.statusMessage = "'\(portName)' - will be removed"
                        }
                    }

                    self.allowedAddressPairForm = updatedForm
                }
            },
            onEnter: {
                // ENTER - Apply pending changes
                if let currentForm = self.allowedAddressPairForm {
                    if currentForm.hasPendingChanges() {
                        Task { await self.actions.applyAllowedAddressPairChanges(screen: screen) }
                    } else {
                        self.statusMessage = "No changes to apply - use SPACE to toggle ports, ESC to cancel"
                    }
                }
            },
            additionalHandling: { _ in
                // No additional hotkeys
                return false
            }
        )

        // Sync back to form
        if var updatedForm = allowedAddressPairForm {
            updatedForm.highlightedPortIndex = selectedIndex
            allowedAddressPairForm = updatedForm
        }
    }
}
