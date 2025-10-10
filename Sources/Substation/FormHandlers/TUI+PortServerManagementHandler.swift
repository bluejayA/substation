import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

// MARK: - Port Server Management Input Handling

@MainActor
extension TUI {

    internal func handlePortServerManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard currentView == .portServerManagement else { return }

        // Filter servers based on mode and attachment status
        // A port can only be attached to one server at a time
        let baseServers: [Server]
        switch attachmentMode {
        case .attach:
            // ATTACH mode: Only show servers if port is NOT attached
            if attachedServerId != nil {
                // Port is already attached - must detach first
                baseServers = []
            } else {
                // Port is free - show all available servers
                baseServers = cachedServers
            }
        case .detach:
            // DETACH mode: Show ONLY the attached server
            if let attachedId = attachedServerId {
                baseServers = cachedServers.filter { $0.id == attachedId }
            } else {
                baseServers = []  // No server attached - show empty list
            }
        }

        // Apply search filter on top of mode filtering
        let relevantServers: [Server]
        if let query = searchQuery, !query.isEmpty {
            relevantServers = baseServers.filter { server in
                (server.name?.localizedCaseInsensitiveContains(query) ?? false) ||
                (server.status?.rawValue.localizedCaseInsensitiveContains(query) ?? false) ||
                (server.addresses?.values.flatMap { $0 }.first?.addr.localizedCaseInsensitiveContains(query) ?? false)
            }
        } else {
            relevantServers = baseServers
        }

        let _ = await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: relevantServers.count,
            onToggle: {
                guard self.selectedIndex < relevantServers.count else { return }
                let server = relevantServers[self.selectedIndex]
                if self.selectedServerId == server.id {
                    self.selectedServerId = nil
                    self.statusMessage = "Deselected server '\(server.name ?? "Unknown")'"
                } else {
                    self.selectedServerId = server.id
                    self.statusMessage = "Selected server '\(server.name ?? "Unknown")' - Press ENTER to \(self.attachmentMode == .attach ? "attach" : "detach")"
                }
                await self.draw(screen: screen)
            },
            onEnter: {
                guard self.selectedServerId != nil else {
                    self.statusMessage = "Please select a server first"
                    return
                }
                guard let port = self.selectedResource as? Port else {
                    self.statusMessage = "Port information not available"
                    return
                }
                guard self.selectedIndex < relevantServers.count else { return }
                let server = relevantServers[self.selectedIndex]

                // Filtering ensures only valid operations are possible
                switch self.attachmentMode {
                case .attach:
                    await self.attachPortToServer(port: port, server: server, screen: screen)
                case .detach:
                    await self.detachPortFromServer(port: port, server: server, screen: screen)
                }
            },
            additionalHandling: { ch in
                // Handle TAB for mode switching
                if ch == Int32(9) {
                    self.attachmentMode = (self.attachmentMode == .attach) ? .detach : .attach
                    self.selectedServerId = nil
                    self.selectedIndex = 0
                    self.scrollOffset = 0
                    self.statusMessage = "Switched to \(self.attachmentMode == .attach ? "ATTACH" : "DETACH") mode"
                    return true
                }
                return false
            }
        )
    }

    // MARK: - Port Attach/Detach Operations

    private func attachPortToServer(port: Port, server: Server, screen: OpaquePointer?) async {
        let portName = port.name ?? port.id
        let serverName = server.name ?? "Unknown"

        statusMessage = "Attaching port '\(portName)' to server '\(serverName)'..."

        do {
            try await client.attachPort(serverID: server.id, portID: port.id)
            statusMessage = "Successfully attached port '\(portName)' to server '\(serverName)'"

            Logger.shared.logUserAction("port_attached", details: [
                "portId": port.id,
                "serverId": server.id
            ])

            // Refresh data and return to ports view
            await dataManager.refreshAllData()
            changeView(to: .ports, resetSelection: false)
        } catch {
            statusMessage = "Failed to attach port: \(error.localizedDescription)"
            Logger.shared.logError("Failed to attach port '\(portName)' to server '\(serverName)': \(error)")
        }
    }

    private func detachPortFromServer(port: Port, server: Server, screen: OpaquePointer?) async {
        let portName = port.name ?? port.id
        let serverName = server.name ?? "Unknown"

        // Confirm detach operation
        let confirmed = await ConfirmationModal.show(
            title: "Detach Port",
            message: "Detach port '\(portName)' from server '\(serverName)'?",
            details: ["This will disconnect the server from this network port"],
            screen: screen,
            screenRows: screenRows,
            screenCols: screenCols
        )

        guard confirmed else {
            statusMessage = "Detach cancelled"
            return
        }

        statusMessage = "Detaching port '\(portName)' from server '\(serverName)'..."

        do {
            try await client.detachPort(serverID: server.id, portID: port.id)
            statusMessage = "Successfully detached port '\(portName)' from server '\(serverName)'"

            Logger.shared.logUserAction("port_detached", details: [
                "portId": port.id,
                "serverId": server.id
            ])

            // Refresh data and return to ports view
            await dataManager.refreshAllData()
            changeView(to: .ports, resetSelection: false)
        } catch {
            statusMessage = "Failed to detach port: \(error.localizedDescription)"
            Logger.shared.logError("Failed to detach port '\(portName)' from server '\(serverName)': \(error)")
        }
    }
}
