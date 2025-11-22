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

// MARK: - Volume Management Input Handler
//
// This handler manages input for the volume attachment management view.
// It uses the core navigation systems via formInputHandler.handleManagementInput
// for consistent behavior across all management views.

@MainActor
extension TUI {

    /// Navigation context for volume management view
    ///
    /// Provides the navigation context based on the current display items count.
    /// This ensures proper navigation bounds for the management view.
    var volumeManagementNavigationContext: NavigationContext {
        let itemCount = volumeManagementForm.getCurrentDisplayItems().count
        return .management(itemCount: itemCount)
    }

    /// Handle input for volume management view using the core navigation systems
    ///
    /// This method delegates navigation to the centralized formInputHandler
    /// to ensure consistent behavior across all management views in the application.
    ///
    /// - Parameters:
    ///   - ch: The input character code
    ///   - screen: The ncurses screen pointer
    internal func handleVolumeManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard viewCoordinator.currentView == .volumeManagement else { return }

        let displayServers = volumeManagementForm.getCurrentDisplayItems()

        let _ = await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: displayServers.count,
            onToggle: {
                // SPACE - Toggle server selection (only in attach mode)
                if self.volumeManagementForm.selectedOperation == .attach {
                    if self.viewCoordinator.selectedIndex < displayServers.count {
                        let selectedServer = displayServers[self.viewCoordinator.selectedIndex]
                        self.volumeManagementForm.toggleServer(selectedServer.id)
                        self.renderCoordinator.needsRedraw = true
                    }
                }
            },
            onEnter: {
                // ENTER - Apply changes
                self.renderCoordinator.needsRedraw = true
                switch self.volumeManagementForm.selectedOperation {
                case .attach:
                    if self.volumeManagementForm.hasPendingChanges() {
                        if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                            await module.applyVolumeAttachment(screen: screen)
                        }
                    }
                case .view:
                    break
                }
            },
            additionalHandling: { ch in
                // TAB - Switch between operations (attach/view)
                if ch == Int32(9) {
                    let operations = VolumeManagementForm.VolumeOperation.allCases
                    if let currentIndex = operations.firstIndex(of: self.volumeManagementForm.selectedOperation) {
                        let nextIndex = (currentIndex + 1) % operations.count
                        self.volumeManagementForm.selectedOperation = operations[nextIndex]
                        // Reset selection when switching modes
                        self.viewCoordinator.selectedIndex = 0
                        self.viewCoordinator.scrollOffset = 0
                    }
                    self.renderCoordinator.needsRedraw = true
                    return true
                }
                return false
            }
        )
    }
}
