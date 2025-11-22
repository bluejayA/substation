import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.FloatingIP
import struct OSClient.Port
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Floating IP Port Management Input Handler

@MainActor
extension TUI {

    /// Handles input for the Floating IP port management view
    ///
    /// This handler manages the port attachment/detachment interface for floating IPs.
    /// It uses the FormInputHandler pattern for list-based management views with
    /// toggle selection and mode switching between attach and detach operations.
    ///
    /// - Parameters:
    ///   - ch: The input character code from ncurses
    ///   - screen: The ncurses screen pointer for rendering
    internal func handleFloatingIPPortManagementInput(_ ch: Int32, screen: OpaquePointer?) async -> Bool {
        // Guard removed - ViewRegistry ensures this handler is only called for the correct view

        // Filter ports based on mode and attachment status
        // A floating IP can only be attached to one port at a time
        let basePorts: [Port]
        switch selectionManager.attachmentMode {
        case .attach:
            // ATTACH mode: Only show ports if floating IP is NOT attached
            if selectionManager.attachedPortId != nil {
                // Floating IP is already attached - must detach first
                basePorts = []
            } else {
                // Floating IP is free - show all available ports
                basePorts = cacheManager.cachedPorts
            }
        case .detach:
            // DETACH mode: Show ONLY the attached port
            if let attachedId = selectionManager.attachedPortId {
                basePorts = cacheManager.cachedPorts.filter { $0.id == attachedId }
            } else {
                basePorts = []  // No port attached - show empty list
            }
        }

        // Apply search filter on top of mode filtering
        let relevantPorts: [Port]
        if let query = searchQuery, !query.isEmpty {
            relevantPorts = basePorts.filter { port in
                (port.name?.localizedCaseInsensitiveContains(query) ?? false) ||
                port.id.localizedCaseInsensitiveContains(query) ||
                port.networkId.localizedCaseInsensitiveContains(query) ||
                (port.deviceId?.localizedCaseInsensitiveContains(query) ?? false)
            }
        } else {
            relevantPorts = basePorts
        }

        return await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: relevantPorts.count,
            onToggle: {
                guard self.viewCoordinator.selectedIndex < relevantPorts.count else { return }
                let port = relevantPorts[self.viewCoordinator.selectedIndex]
                if self.selectionManager.selectedPortId == port.id {
                    self.selectionManager.selectedPortId = nil
                    self.statusMessage = "Deselected port '\(port.name ?? port.id)'"
                } else {
                    self.selectionManager.selectedPortId = port.id
                    self.statusMessage = "Selected port '\(port.name ?? port.id)' - Press ENTER to \(self.selectionManager.attachmentMode == .attach ? "attach" : "detach")"
                }
                self.renderCoordinator.needsRedraw = true
                await self.draw(screen: screen)
            },
            onEnter: {
                guard self.selectionManager.selectedPortId != nil else {
                    self.statusMessage = "Please select a port first"
                    return
                }
                guard let floatingIP = self.viewCoordinator.selectedResource as? FloatingIP else {
                    self.statusMessage = "Floating IP information not available"
                    return
                }
                guard self.viewCoordinator.selectedIndex < relevantPorts.count else { return }
                let port = relevantPorts[self.viewCoordinator.selectedIndex]

                // Filtering ensures only valid operations are possible
                switch self.selectionManager.attachmentMode {
                case .attach:
                    await self.attachFloatingIPToPort(floatingIP: floatingIP, port: port, screen: screen)
                case .detach:
                    await self.detachFloatingIPFromPort(floatingIP: floatingIP, port: port, screen: screen)
                }
            },
            additionalHandling: { ch in
                // Handle TAB for mode switching
                if ch == Int32(9) {
                    self.selectionManager.attachmentMode = (self.selectionManager.attachmentMode == .attach) ? .detach : .attach
                    self.selectionManager.selectedPortId = nil
                    self.viewCoordinator.selectedIndex = 0
                    self.viewCoordinator.scrollOffset = 0
                    self.statusMessage = "Switched to \(self.selectionManager.attachmentMode == .attach ? "ATTACH" : "DETACH") mode"
                    self.renderCoordinator.needsRedraw = true
                    await self.draw(screen: screen)
                    return true
                }
                return false
            }
        )
    }

    // MARK: - Floating IP Attach/Detach Operations

    private func attachFloatingIPToPort(floatingIP: FloatingIP, port: Port, screen: OpaquePointer?) async {
        let floatingIPAddress = floatingIP.floatingIpAddress ?? floatingIP.id
        let portName = port.name ?? port.id

        statusMessage = "Attaching floating IP '\(floatingIPAddress)' to port '\(portName)'..."

        do {
            _ = try await client.neutron.updateFloatingIP(id: floatingIP.id, portID: port.id, fixedIP: nil)
            statusMessage = "Successfully attached floating IP '\(floatingIPAddress)' to port '\(portName)'"

            Logger.shared.logUserAction("floatingip_attached_to_port", details: [
                "floatingIPId": floatingIP.id,
                "portId": port.id
            ])

            // Trigger accelerated refresh to show state transitions
            refreshAfterOperation()

            // Refresh data and return to floating IPs view
            await dataManager.refreshAllData()
            changeView(to: .floatingIPs, resetSelection: false)
        } catch {
            statusMessage = "Failed to attach floating IP: \(error.localizedDescription)"
            Logger.shared.logError("Failed to attach floating IP '\(floatingIPAddress)' to port '\(portName)': \(error)")
        }
    }

    private func detachFloatingIPFromPort(floatingIP: FloatingIP, port: Port, screen: OpaquePointer?) async {
        let floatingIPAddress = floatingIP.floatingIpAddress ?? floatingIP.id
        let portName = port.name ?? port.id

        // Confirm detach operation
        let confirmed = await ConfirmationModal.show(
            title: "Detach Floating IP",
            message: "Detach floating IP '\(floatingIPAddress)' from port '\(portName)'?",
            details: ["This will disconnect the floating IP from this port"],
            screen: screen,
            screenRows: screenRows,
            screenCols: screenCols
        )

        guard confirmed else {
            statusMessage = "Detach cancelled"
            return
        }

        statusMessage = "Detaching floating IP '\(floatingIPAddress)' from port '\(portName)'..."

        do {
            _ = try await client.neutron.updateFloatingIP(id: floatingIP.id, portID: nil, fixedIP: nil)
            statusMessage = "Successfully detached floating IP '\(floatingIPAddress)' from port '\(portName)'"

            Logger.shared.logUserAction("floatingip_detached_from_port", details: [
                "floatingIPId": floatingIP.id,
                "portId": port.id
            ])

            // Trigger accelerated refresh to show state transitions
            refreshAfterOperation()

            // Refresh data and return to floating IPs view
            await dataManager.refreshAllData()
            changeView(to: .floatingIPs, resetSelection: false)
        } catch {
            statusMessage = "Failed to detach floating IP: \(error.localizedDescription)"
            Logger.shared.logError("Failed to detach floating IP '\(floatingIPAddress)' from port '\(portName)': \(error)")
        }
    }
}
