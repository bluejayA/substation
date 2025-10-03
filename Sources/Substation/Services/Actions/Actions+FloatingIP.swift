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

// MARK: - Floating IP Actions

@MainActor
extension Actions {

    internal func manageFloatingIPServerAssignment(screen: OpaquePointer?) async {
        guard currentView == .floatingIPs else { return }

        let filteredFloatingIPs = FilterUtils.filterFloatingIPs(cachedFloatingIPs, query: searchQuery)
        guard selectedIndex < filteredFloatingIPs.count else {
            statusMessage = "No floating IP selected"
            return
        }

        let floatingIP = filteredFloatingIPs[selectedIndex]
        let floatingIPAddress = floatingIP.floatingIpAddress ?? "Unknown IP"

        // Check if floating IP is already assigned
        if let _ = floatingIP.fixedIpAddress {
            statusMessage = "Floating IP '\(floatingIPAddress)' is already assigned. Detach it first."
            return
        }

        // Switch to floating IP server management view
        selectedResource = floatingIP
        attachmentMode = .attach
        selectedServerId = nil
        tui.changeView(to: .floatingIPServerManagement, resetSelection: false)
        statusMessage = "Select a server to assign floating IP '\(floatingIPAddress)'"
    }

    internal func loadAttachedServerForFloatingIP(_ floatingIP: FloatingIP) async {
        attachedServerId = nil
        // Find server that has this floating IP attached by checking ports
        if let portId = floatingIP.portId {
            // Find the port that the floating IP is attached to
            if let port = cachedPorts.first(where: { $0.id == portId }) {
                // Get the server ID from the port's device_id
                if let serverId = port.deviceId {
                    attachedServerId = serverId
                }
            }
        }
    }
}
