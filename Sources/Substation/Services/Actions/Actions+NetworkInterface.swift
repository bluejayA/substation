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

// MARK: - Network Interface Actions

@MainActor
extension Actions {

    internal func manageNetworkInterfaces(screen: OpaquePointer?) async {
        guard currentView == .servers else { return }

        let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
        guard selectedIndex < filteredServers.count else {
            statusMessage = "No server selected"
            return
        }

        let server = filteredServers[selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Prepare network interface management form
        networkInterfaceForm.reset()
        networkInterfaceForm.selectedServer = server
        networkInterfaceForm.availablePorts = cachedPorts.filter { port in
            port.deviceId == nil || port.deviceId?.isEmpty == true
        }
        networkInterfaceForm.availableNetworks = cachedNetworks

        // Load server's current network interfaces
        statusMessage = "Loading network interfaces for '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            networkInterfaceForm.serverInterfaces = try await client.getServerInterfaces(serverID: server.id)
            statusMessage = "Managing network interfaces for '\(serverName)'"
            tui.changeView(to: .serverNetworkInterfaces, resetSelection: false)
        } catch let error as OTError {
            let baseMsg = "Failed to load network interfaces for '\(serverName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response"
            case .networkError(_):
                statusMessage = "\(baseMsg): Network error"
            case .decodingError(_):
                statusMessage = "\(baseMsg): Response decoding error"
            case .encodingError(_):
                statusMessage = "\(baseMsg): Request encoding error"
            case .configurationError(_):
                statusMessage = "\(baseMsg): Configuration error"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .httpError(let code, _):
                if code == 404 {
                    statusMessage = "\(baseMsg): Server not found"
                } else {
                    statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field: \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to load network interfaces for '\(serverName)': \(error.localizedDescription)"
        }
    }

    internal func manageNetworkToServers(screen: OpaquePointer?) async {
        guard currentView == .networks else { return }
        let filteredNetworks = ResourceFilters.filterNetworks(cachedNetworks, query: searchQuery)
        guard selectedIndex < filteredNetworks.count else {
            statusMessage = "No network selected"
            return
        }
        let selectedNetwork = filteredNetworks[selectedIndex]
        // Store the selected network for reference
        selectedResource = selectedNetwork
        // Load attached servers for this network
        await loadAttachedServersForNetwork(selectedNetwork)
        // Clear previous selections
        selectedServers.removeAll()
        // Reset to attach mode
        attachmentMode = .attach
        // Navigate to network server management view
        tui.changeView(to: .networkServerManagement, resetSelection: false)
        statusMessage = "Managing network '\(selectedNetwork.name ?? "Unknown")' server attachments"
    }

    internal func loadAttachedServersForNetwork(_ network: Network) async {
        attachedServerIds.removeAll()
        // Find servers that have this network attached
        for server in cachedServers {
            if let addresses = server.addresses, addresses.keys.contains(network.name ?? network.id) {
                attachedServerIds.insert(server.id)
            }
        }
    }

    internal func applyNetworkInterfaceChanges(screen: OpaquePointer?) async {
        guard let server = networkInterfaceForm.selectedServer else {
            statusMessage = "No server selected"
            return
        }

        let serverName = server.name ?? "Unnamed Server"
        var changeCount = 0
        var errorCount = 0

        // Apply port attachments
        for portID in networkInterfaceForm.pendingPortAttachments {
            if let port = networkInterfaceForm.availablePorts.first(where: { $0.id == portID }) {
                let portName = port.name ?? port.id
                statusMessage = "Attaching port '\(portName)' to \(serverName)..."
                await tui.draw(screen: screen)

                do {
                    try await client.attachPort(serverID: server.id, portID: port.id)
                    changeCount += 1
                } catch let error as OTError {
                    errorCount += 1
                    let baseMsg = "Failed to attach port '\(portName)'"
                    switch error {
                    case .authenticationFailed:
                        statusMessage = "\(baseMsg): Authentication failed"
                    case .endpointNotFound:
                        statusMessage = "\(baseMsg): Endpoint not found"
                    case .unexpectedResponse:
                        statusMessage = "\(baseMsg): Unexpected response"
                    case .httpError(let code, _):
                        if code == 409 {
                            statusMessage = "\(baseMsg): Already attached"
                        } else if code == 404 {
                            statusMessage = "\(baseMsg): Port not found"
                        } else {
                            statusMessage = "\(baseMsg): HTTP error \(code)"
                        }
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
                    }
                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    errorCount += 1
                    statusMessage = "Failed to attach port '\(portName)': \(error.localizedDescription)"
                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        // Apply network attachments
        for networkID in networkInterfaceForm.pendingNetworkAttachments {
            if let network = networkInterfaceForm.availableNetworks.first(where: { $0.id == networkID }) {
                statusMessage = "Attaching network '\(network.name ?? "Unknown")' to \(serverName)..."
                await tui.draw(screen: screen)

                do {
                    try await client.attachNetwork(serverID: server.id, networkID: network.id)
                    changeCount += 1
                } catch let error as OTError {
                    errorCount += 1
                    let baseMsg = "Failed to attach network '\(network.name ?? "Unknown")'"
                    switch error {
                    case .authenticationFailed:
                        statusMessage = "\(baseMsg): Authentication failed"
                    case .endpointNotFound:
                        statusMessage = "\(baseMsg): Endpoint not found"
                    case .unexpectedResponse:
                        statusMessage = "\(baseMsg): Unexpected response"
                    case .httpError(let code, _):
                        if code == 409 {
                            statusMessage = "\(baseMsg): Already attached or conflict"
                        } else if code == 404 {
                            statusMessage = "\(baseMsg): Network not found"
                        } else {
                            statusMessage = "\(baseMsg): HTTP error \(code)"
                        }
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
                    }
                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    errorCount += 1
                    statusMessage = "Failed to attach network '\(network.name ?? "Unknown")': \(error.localizedDescription)"
                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        // Apply port detachments
        for portID in networkInterfaceForm.pendingPortDetachments {
            if let port = networkInterfaceForm.availablePorts.first(where: { $0.id == portID }) {
                let portName = port.name ?? port.id
                statusMessage = "Detaching port '\(portName)' from \(serverName)..."
                await tui.draw(screen: screen)

                do {
                    try await client.detachPort(serverID: server.id, portID: port.id)
                    changeCount += 1
                } catch let error as OTError {
                    errorCount += 1
                    let baseMsg = "Failed to detach port '\(portName)'"
                    switch error {
                    case .authenticationFailed:
                        statusMessage = "\(baseMsg): Authentication failed"
                    case .endpointNotFound:
                        statusMessage = "\(baseMsg): Endpoint not found"
                    case .unexpectedResponse:
                        statusMessage = "\(baseMsg): Unexpected response"
                    case .httpError(let code, _):
                        if code == 409 {
                            statusMessage = "\(baseMsg): Cannot detach (conflict)"
                        } else if code == 404 {
                            statusMessage = "\(baseMsg): Port not found"
                        } else {
                            statusMessage = "\(baseMsg): HTTP error \(code)"
                        }
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
                    }
                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    errorCount += 1
                    statusMessage = "Failed to detach port '\(portName)': \(error.localizedDescription)"
                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        // Apply network detachments
        for networkID in networkInterfaceForm.pendingNetworkDetachments {
            if let network = networkInterfaceForm.availableNetworks.first(where: { $0.id == networkID }) {
                statusMessage = "Detaching network '\(network.name ?? "Unknown")' from \(serverName)..."
                await tui.draw(screen: screen)

                do {
                    // Detach network by detaching all server ports on this network
                    let portsToDetach = networkInterfaceForm.serverInterfaces.compactMap { interface in
                        networkInterfaceForm.availablePorts.first { port in
                            port.id == interface.portId && port.networkId == network.id
                        }
                    }

                    var portDetachCount = 0
                    for port in portsToDetach {
                        try await client.detachPort(serverID: server.id, portID: port.id)
                        portDetachCount += 1
                    }

                    if portDetachCount > 0 {
                        changeCount += 1
                    }
                } catch let error as OTError {
                    errorCount += 1
                    let baseMsg = "Failed to detach network '\(network.name ?? "Unknown")'"
                    switch error {
                    case .authenticationFailed:
                        statusMessage = "\(baseMsg): Authentication failed"
                    case .endpointNotFound:
                        statusMessage = "\(baseMsg): Endpoint not found"
                    case .unexpectedResponse:
                        statusMessage = "\(baseMsg): Unexpected response"
                    case .httpError(let code, _):
                        if code == 409 {
                            statusMessage = "\(baseMsg): Cannot detach (conflict)"
                        } else if code == 404 {
                            statusMessage = "\(baseMsg): Network not found"
                        } else {
                            statusMessage = "\(baseMsg): HTTP error \(code)"
                        }
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
                    }
                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    errorCount += 1
                    statusMessage = "Failed to detach network '\(network.name ?? "Unknown")': \(error.localizedDescription)"
                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        // Summary and refresh
        if changeCount > 0 {
            var message = "Applied \(changeCount) network interface changes"
            if errorCount > 0 {
                message += " (with \(errorCount) errors)"
            }
            statusMessage = message

            // Clear pending changes
            networkInterfaceForm.pendingPortAttachments.removeAll()
            networkInterfaceForm.pendingPortDetachments.removeAll()
            networkInterfaceForm.pendingNetworkAttachments.removeAll()
            networkInterfaceForm.pendingNetworkDetachments.removeAll()

            // Refresh network interfaces
            do {
                networkInterfaceForm.serverInterfaces = try await client.getServerInterfaces(serverID: server.id)
            } catch {
                statusMessage = message + " - Warning: Failed to refresh network interfaces"
            }
        } else if errorCount > 0 {
            statusMessage = "All \(errorCount) network interface operations failed"
        } else {
            statusMessage = "No changes to apply"
        }

        // Reset form and return to servers view after operation
        networkInterfaceForm.reset()
        Logger.shared.logNavigation(".serverNetworkInterfaces", to: ".servers", details: ["action": "network_interface_changes_applied"])
        tui.changeView(to: .servers, resetSelection: false, preserveStatus: true)
    }
}
