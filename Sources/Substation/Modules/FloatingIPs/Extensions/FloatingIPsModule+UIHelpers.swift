// Sources/Substation/Modules/FloatingIPs/Extensions/FloatingIPsModule+UIHelpers.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Floating IP UI Helper Operations

extension FloatingIPsModule {
    /// Perform floating IP server management (assign/unassign)
    ///
    /// This function handles the assignment or unassignment of a floating IP
    /// to/from a server. It validates the current selection state and performs
    /// the appropriate API call based on the attachment mode.
    ///
    /// The function:
    /// - Validates that a server and floating IP are selected
    /// - Finds the appropriate port for server attachment
    /// - Calls the OpenStack API to update the floating IP
    /// - Updates the UI state and refreshes data on success
    /// - Logs errors with detailed context for debugging
    ///
    /// - Important: This function expects both selectedServerId and selectedResource
    ///   to be set before being called.
    internal func performFloatingIPServerManagement() async {
        guard let tui = tui else { return }

        guard let selectedId = tui.selectionManager.selectedServerId else {
            tui.statusMessage = "No server selected for floating IP \(tui.selectionManager.attachmentMode == .attach ? "assignment" : "unassignment")"
            return
        }
        guard let selectedFloatingIP = tui.viewCoordinator.selectedResource as? FloatingIP else {
            tui.statusMessage = "No floating IP selected for \(tui.selectionManager.attachmentMode == .attach ? "assignment" : "unassignment")"
            return
        }
        guard let selectedServer = tui.cacheManager.cachedServers.first(where: { $0.id == selectedId }) else {
            tui.statusMessage = "Selected server not found"
            return
        }

        let floatingIPAddress = selectedFloatingIP.floatingIpAddress ?? "Unknown"
        let serverName = selectedServer.name ?? "Unknown"
        let action = tui.selectionManager.attachmentMode == .attach ? "assigning" : "unassigning"
        tui.statusMessage = "\(action.capitalized) floating IP '\(floatingIPAddress)' \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") server '\(serverName)'..."

        // Force immediate UI update to show status message
        tui.forceRedraw()

        do {
            if tui.selectionManager.attachmentMode == .attach {
                // Find the first port for this server to attach the floating IP
                guard let targetPort = tui.cacheManager.cachedPorts.first(where: { $0.deviceId == selectedServer.id }) else {
                    tui.statusMessage = "No ports found for server '\(serverName)'"
                    tui.forceRedraw()
                    return
                }
                _ = try await tui.client.updateFloatingIP(id: selectedFloatingIP.id, portID: targetPort.id)
                tui.statusMessage = "Successfully assigned floating IP '\(floatingIPAddress)' to server '\(serverName)'"
            } else {
                _ = try await tui.client.updateFloatingIP(id: selectedFloatingIP.id, portID: nil)
                tui.statusMessage = "Successfully unassigned floating IP '\(floatingIPAddress)' from server '\(serverName)'"
            }

            tui.selectionManager.selectedServerId = nil
            tui.changeView(to: .floatingIPs, resetSelection: false)
            tui.refreshAfterOperation()
        } catch {
            tui.statusMessage = "Failed to \(tui.selectionManager.attachmentMode == .attach ? "assign" : "unassign") floating IP: \(error.localizedDescription)"
            tui.forceRedraw()
            Logger.shared.logError("Failed to \(tui.selectionManager.attachmentMode == .attach ? "assign" : "unassign") floating IP", error: error, context: [
                "serverId": selectedId,
                "serverName": serverName,
                "floatingIPId": selectedFloatingIP.id,
                "floatingIPAddress": floatingIPAddress
            ])
        }
    }
}
