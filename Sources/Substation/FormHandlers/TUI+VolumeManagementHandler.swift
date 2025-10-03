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

// MARK: - Volume Management Input Handler

@MainActor
extension TUI {

    internal func handleVolumeManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(9): // TAB - Switch operation mode
            let operations = VolumeManagementForm.VolumeOperation.allCases
            if let currentIndex = operations.firstIndex(of: volumeManagementForm.selectedOperation) {
                let nextIndex = (currentIndex + 1) % operations.count
                volumeManagementForm.selectedOperation = operations[nextIndex]
                volumeManagementForm.selectedResourceIndex = 0 // Reset selection
            }
        case Int32(259): // UP
            let displayServers = volumeManagementForm.getCurrentDisplayItems()
            if !displayServers.isEmpty {
                volumeManagementForm.selectedResourceIndex = max(0, volumeManagementForm.selectedResourceIndex - 1)
            }
        case Int32(258): // DOWN
            let displayServers = volumeManagementForm.getCurrentDisplayItems()
            if !displayServers.isEmpty {
                volumeManagementForm.selectedResourceIndex = min(displayServers.count - 1, volumeManagementForm.selectedResourceIndex + 1)
            }
        case Int32(32): // SPACE - Toggle server selection (attach mode only)
            if volumeManagementForm.selectedOperation == .attach {
                let displayServers = volumeManagementForm.getCurrentDisplayItems()
                if volumeManagementForm.selectedResourceIndex < displayServers.count {
                    let selectedServer = displayServers[volumeManagementForm.selectedResourceIndex]
                    volumeManagementForm.toggleServer(selectedServer.id)
                }
            }
        case Int32(10), Int32(13): // ENTER - Apply changes or perform action
            needsRedraw = true
            switch volumeManagementForm.selectedOperation {
            case .attach:
                if volumeManagementForm.hasPendingChanges() {
                    await actions.applyVolumeAttachment(screen: screen)
                }
            case .view:
                // No action in view mode, or could switch to attach mode
                break
            }
        default:
            break
        }
    }
}
