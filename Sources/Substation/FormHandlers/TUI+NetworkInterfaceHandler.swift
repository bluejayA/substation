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

// MARK: - Network Interface Management Input Handler

@MainActor
extension TUI {

    internal func handleNetworkInterfaceInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Step 1: Try common navigation (UP/DOWN/PAGE/HOME/END/ESC)
        let managementItems = networkInterfaceForm.getManagementItems(for: networkInterfaceForm.currentViewMode)
        let maxIndex = max(0, managementItems.count - 1)

        if await handleNetworkInterfaceCommonNavigation(ch, maxIndex: maxIndex) {
            return
        }

        // Step 2: Handle view-specific keys
        await handleNetworkInterfaceSpecificInput(ch, screen: screen)
    }

    // MARK: - Common Navigation

    private func handleNetworkInterfaceCommonNavigation(_ ch: Int32, maxIndex: Int) async -> Bool {
        // Handle UP/DOWN/PAGE/HOME/END using the centralized navigation handler
        // Note: We use a custom selectedIndex for this form (networkInterfaceForm.selectedResourceIndex)
        // so we need to manually map the navigation

        switch ch {
        case Int32(259): // KEY_UP
            if networkInterfaceForm.selectedResourceIndex > 0 {
                networkInterfaceForm.selectedResourceIndex -= 1
            }
            return true

        case Int32(258): // KEY_DOWN
            if networkInterfaceForm.selectedResourceIndex < maxIndex {
                networkInterfaceForm.selectedResourceIndex += 1
            }
            return true

        case Int32(338): // PAGE_DOWN
            let pageSize = 10
            networkInterfaceForm.selectedResourceIndex = min(networkInterfaceForm.selectedResourceIndex + pageSize, maxIndex)
            return true

        case Int32(339): // PAGE_UP
            let pageSize = 10
            networkInterfaceForm.selectedResourceIndex = max(networkInterfaceForm.selectedResourceIndex - pageSize, 0)
            return true

        case Int32(262): // HOME
            networkInterfaceForm.selectedResourceIndex = 0
            return true

        case Int32(360): // END
            networkInterfaceForm.selectedResourceIndex = maxIndex
            return true

        case Int32(27): // ESC
            return await handleNetworkInterfaceEscape()

        default:
            return false
        }
    }

    // MARK: - View-Specific Input

    private func handleNetworkInterfaceSpecificInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(9): // TAB - Switch between ports and networks mode
            networkInterfaceForm.toggleViewMode()

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

    // MARK: - ESC Handling

    private func handleNetworkInterfaceEscape() async -> Bool {
        // Use centralized ESC handling
        return await NavigationInputHandler.handleEscapeKey(tui: self)
    }
}
