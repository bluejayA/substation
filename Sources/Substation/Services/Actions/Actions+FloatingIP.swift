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
            // Floating IP is attached - set mode to detach
            selectedResource = floatingIP
            attachmentMode = .detach
            await loadAttachedServerForFloatingIP(floatingIP)
            tui.changeView(to: .floatingIPServerManagement, resetSelection: false)
            statusMessage = "Floating IP '\(floatingIPAddress)' is attached. Select to detach or press TAB to switch to attach mode."
        } else {
            // Floating IP is not attached - set mode to attach
            selectedResource = floatingIP
            attachmentMode = .attach
            selectedServerId = nil
            attachedServerId = nil  // Clear attached server ID for unattached floating IPs
            tui.changeView(to: .floatingIPServerManagement, resetSelection: false)
            statusMessage = "Select a server to attach floating IP '\(floatingIPAddress)'"
        }
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

    internal func manageFloatingIPPortAssignment(screen: OpaquePointer?) async {
        guard currentView == .floatingIPs else { return }

        let filteredFloatingIPs = FilterUtils.filterFloatingIPs(cachedFloatingIPs, query: searchQuery)
        guard selectedIndex < filteredFloatingIPs.count else {
            statusMessage = "No floating IP selected"
            return
        }

        let floatingIP = filteredFloatingIPs[selectedIndex]
        let floatingIPAddress = floatingIP.floatingIpAddress ?? floatingIP.id

        // Check if floating IP is already attached to a port
        if let portId = floatingIP.portId, !portId.isEmpty {
            // Floating IP is attached - set mode to detach
            attachmentMode = .detach
            tui.attachedPortId = portId
            tui.changeView(to: .floatingIPPortManagement, resetSelection: true)
            selectedResource = floatingIP  // Set AFTER changeView to prevent it being cleared
            statusMessage = "Floating IP '\(floatingIPAddress)' is attached. Select to detach or press TAB to switch to attach mode."
        } else {
            // Floating IP is not attached - set mode to attach
            attachmentMode = .attach
            tui.selectedPortId = nil
            tui.attachedPortId = nil
            tui.changeView(to: .floatingIPPortManagement, resetSelection: true)
            selectedResource = floatingIP  // Set AFTER changeView to prevent it being cleared
            statusMessage = "Select a port to attach floating IP '\(floatingIPAddress)'"
        }
    }
}
