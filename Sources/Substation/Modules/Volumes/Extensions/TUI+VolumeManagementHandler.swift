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

@MainActor
extension TUI {

    internal func handleVolumeManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Step 1: Try common navigation (UP/DOWN/PAGE/HOME/END/ESC)
        let displayServers = volumeManagementForm.getCurrentDisplayItems()
        let maxIndex = max(0, displayServers.count - 1)

        if await handleVolumeManagementCommonNavigation(ch, maxIndex: maxIndex) {
            return
        }

        // Step 2: Handle view-specific keys
        await handleVolumeManagementSpecificInput(ch, screen: screen)
    }

    // MARK: - Common Navigation

    private func handleVolumeManagementCommonNavigation(_ ch: Int32, maxIndex: Int) async -> Bool {
        // Handle UP/DOWN/PAGE/HOME/END using custom navigation for form's selectedResourceIndex
        switch ch {
        case Int32(259): // KEY_UP
            if volumeManagementForm.selectedResourceIndex > 0 {
                volumeManagementForm.selectedResourceIndex -= 1
            }
            return true

        case Int32(258): // KEY_DOWN
            if volumeManagementForm.selectedResourceIndex < maxIndex {
                volumeManagementForm.selectedResourceIndex += 1
            }
            return true

        case Int32(338): // PAGE_DOWN
            let pageSize = 10
            volumeManagementForm.selectedResourceIndex = min(volumeManagementForm.selectedResourceIndex + pageSize, maxIndex)
            return true

        case Int32(339): // PAGE_UP
            let pageSize = 10
            volumeManagementForm.selectedResourceIndex = max(volumeManagementForm.selectedResourceIndex - pageSize, 0)
            return true

        case Int32(262): // HOME
            volumeManagementForm.selectedResourceIndex = 0
            return true

        case Int32(360): // END
            volumeManagementForm.selectedResourceIndex = maxIndex
            return true

        case Int32(27): // ESC
            return await handleVolumeManagementEscape()

        default:
            return false
        }
    }

    // MARK: - View-Specific Input

    private func handleVolumeManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?) async {
        let displayServers = volumeManagementForm.getCurrentDisplayItems()

        switch ch {
        case Int32(9): // TAB - Switch between operations (attach/view)
            let operations = VolumeManagementForm.VolumeOperation.allCases
            if let currentIndex = operations.firstIndex(of: volumeManagementForm.selectedOperation) {
                let nextIndex = (currentIndex + 1) % operations.count
                volumeManagementForm.selectedOperation = operations[nextIndex]
                volumeManagementForm.selectedResourceIndex = 0
            }
            renderCoordinator.needsRedraw = true

        case Int32(32): // SPACE - Toggle server selection (only in attach mode)
            if volumeManagementForm.selectedOperation == .attach {
                if volumeManagementForm.selectedResourceIndex < displayServers.count {
                    let selectedServer = displayServers[volumeManagementForm.selectedResourceIndex]
                    volumeManagementForm.toggleServer(selectedServer.id)
                    renderCoordinator.needsRedraw = true
                }
            }

        case Int32(10), Int32(13): // ENTER - Apply changes
            renderCoordinator.needsRedraw = true
            switch volumeManagementForm.selectedOperation {
            case .attach:
                if volumeManagementForm.hasPendingChanges() {
                    if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                        await module.applyVolumeAttachment(screen: screen)
                    }
                }
            case .view:
                break
            }

        default:
            break
        }
    }

    // MARK: - ESC Handling

    private func handleVolumeManagementEscape() async -> Bool {
        // Return to volumes list
        changeView(to: .volumes, resetSelection: false)
        return true
    }
}
