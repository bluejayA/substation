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

// MARK: - Network Interface Management Input Handler

@MainActor
extension TUI {

    internal func handleNetworkInterfaceInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(9): // TAB - Switch between ports and networks mode
            networkInterfaceForm.toggleViewMode()
        case Int32(259): // UP
            let managementItems = networkInterfaceForm.getManagementItems(for: networkInterfaceForm.currentViewMode)
            if !managementItems.isEmpty {
                networkInterfaceForm.selectedResourceIndex = max(0, networkInterfaceForm.selectedResourceIndex - 1)
            }
        case Int32(258): // DOWN
            let managementItems = networkInterfaceForm.getManagementItems(for: networkInterfaceForm.currentViewMode)
            if !managementItems.isEmpty {
                networkInterfaceForm.selectedResourceIndex = min(managementItems.count - 1, networkInterfaceForm.selectedResourceIndex + 1)
            }
        case Int32(32): // SPACE - Toggle resource selection with intelligent attach/detach
            let managementItems = networkInterfaceForm.getManagementItems(for: networkInterfaceForm.currentViewMode)
            if networkInterfaceForm.selectedResourceIndex < managementItems.count {
                let selectedItem = managementItems[networkInterfaceForm.selectedResourceIndex]
                if let port = selectedItem as? Port {
                    networkInterfaceForm.togglePortManagement(port.id)
                } else if let network = selectedItem as? Network {
                    networkInterfaceForm.toggleNetworkManagement(network.id)
                }
            }
        case Int32(10), Int32(13): // ENTER - Apply changes
            needsRedraw = true
            if networkInterfaceForm.hasPendingChanges() {
                await actions.applyNetworkInterfaceChanges(screen: screen)
            }
        default:
            break
        }
    }
}
