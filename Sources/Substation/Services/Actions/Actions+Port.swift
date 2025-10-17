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

// MARK: - Port Actions

@MainActor
extension Actions {

    internal func managePortServerAssignment(screen: OpaquePointer?) async {
        guard currentView == .ports else { return }

        let filteredPorts = FilterUtils.filterPorts(cachedPorts, query: searchQuery)
        guard selectedIndex < filteredPorts.count else {
            statusMessage = "No port selected"
            return
        }

        let port = filteredPorts[selectedIndex]
        let portName = port.name ?? port.id

        // Check if port is already attached to a server
        if let deviceId = port.deviceId, !deviceId.isEmpty {
            // Port is attached - set mode to detach
            attachmentMode = .detach
            attachedServerId = deviceId
            tui.changeView(to: .portServerManagement, resetSelection: true)
            selectedResource = port  // Set AFTER changeView to prevent it being cleared
            statusMessage = "Port '\(portName)' is attached. Select to detach or press TAB to switch to attach mode."
        } else {
            // Port is not attached - set mode to attach
            attachmentMode = .attach
            selectedServerId = nil
            attachedServerId = nil
            tui.changeView(to: .portServerManagement, resetSelection: true)
            selectedResource = port  // Set AFTER changeView to prevent it being cleared
            statusMessage = "Select a server to attach port '\(portName)'"
        }
    }
}
