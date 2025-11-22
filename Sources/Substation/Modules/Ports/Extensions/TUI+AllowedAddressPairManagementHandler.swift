import Foundation
import struct OSClient.Port
import OSClient
import SwiftNCurses

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

    /// Handle input for allowed address pair management view
    ///
    /// Supports:
    /// - UP/DOWN: Navigate port list
    /// - SPACE: Toggle port selection for allowed address pairs
    /// - ENTER: Apply pending changes
    /// - ESC: Cancel and return to ports
    ///
    /// - Parameters:
    ///   - ch: The input character code
    ///   - screen: Screen pointer for rendering
    internal func handleAllowedAddressPairManagementInput(_ ch: Int32, screen: OpaquePointer?) async -> Bool {
        // Guard removed - ViewRegistry ensures this handler is only called for the correct view
        guard let form = allowedAddressPairForm else { return false }

        let portCount = cacheManager.cachedPorts.count

        // Synchronize viewCoordinator.selectedIndex with form's highlightedPortIndex
        viewCoordinator.selectedIndex = form.highlightedPortIndex

        let handled = await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: portCount,
            onToggle: {
                // SPACE - Toggle port for allowed address pairs
                if var updatedForm = self.allowedAddressPairForm {
                    updatedForm.highlightedPortIndex = self.viewCoordinator.selectedIndex
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
                        Task {
                            if let module = ModuleRegistry.shared.module(for: "ports") as? PortsModule {
                                await module.applyAllowedAddressPairChanges(screen: screen)
                            }
                        }
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
            updatedForm.highlightedPortIndex = viewCoordinator.selectedIndex
            allowedAddressPairForm = updatedForm
        }

        return handled
    }
}
