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

// MARK: - Server Lifecycle Actions

@MainActor
extension Actions {

    internal func restartServer(screen: OpaquePointer?) async {
        guard currentView == .servers else { return }

        let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
        guard selectedIndex < filteredServers.count else {
            statusMessage = "No server selected"
            return
        }

        let server = filteredServers[selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Build server details for confirmation
        var serverDetails: [String] = []
        serverDetails.append("Name: \(serverName)")
        if let status = server.status {
            serverDetails.append("Status: \(status)")
        }
        if let flavor = server.flavor, let flavorName = cachedFlavors.first(where: { $0.id == flavor.id })?.name {
            serverDetails.append("Flavor: \(flavorName)")
        }
        if let ip = resourceResolver.getServerIP(server) {
            serverDetails.append("IP: \(ip)")
        }

        // Confirm restart
        guard await ViewUtils.confirmOperation(
            title: "Confirm Server Restart",
            message: "Restart the following server?",
            details: serverDetails,
            screen: screen,
            screenRows: screenRows,
            screenCols: screenCols
        ) else {
            statusMessage = "Server restart cancelled"
            await tui.draw(screen: screen)
            return
        }

        // Show restart in progress
        statusMessage = "Restarting server '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            try await client.rebootServer(id: server.id, type: "SOFT")

            statusMessage = "Server '\(serverName)' restart initiated successfully"

            // Refresh data to get updated server status
            await dataManager.refreshAllData()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to restart server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
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
        } catch {
            statusMessage = "Failed to restart server '\(serverName)': \(error.localizedDescription)"
        }
    }

    internal func startServer(screen: OpaquePointer?) async {
        guard currentView == .servers else { return }

        let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
        guard selectedIndex < filteredServers.count else {
            statusMessage = "No server selected"
            return
        }

        let server = filteredServers[selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Build server details for confirmation
        var serverDetails: [String] = []
        serverDetails.append("Name: \(serverName)")
        if let status = server.status {
            serverDetails.append("Status: \(status)")
        }
        if let flavor = server.flavor, let flavorName = cachedFlavors.first(where: { $0.id == flavor.id })?.name {
            serverDetails.append("Flavor: \(flavorName)")
        }
        if let ip = resourceResolver.getServerIP(server) {
            serverDetails.append("IP: \(ip)")
        }

        // Confirm start
        guard await ViewUtils.confirmOperation(
            title: "Confirm Server Start",
            message: "Start the following server?",
            details: serverDetails,
            screen: screen,
            screenRows: screenRows,
            screenCols: screenCols
        ) else {
            statusMessage = "Server start cancelled"
            await tui.draw(screen: screen)
            return
        }

        statusMessage = "Starting server '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            try await client.startServer(id: server.id)
            statusMessage = "Server '\(serverName)' start initiated successfully"

            // Refresh server data to update status
            await dataManager.refreshAllData()
        } catch let error as OpenStackError {
            let baseMsg = "Failed to start server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 409 {
                    statusMessage = "\(baseMsg): Server cannot be started (current state conflict)"
                } else if code == 404 {
                    statusMessage = "\(baseMsg): Server not found"
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
                statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to start server '\(serverName)': \(error.localizedDescription)"
        }
    }

    internal func stopServer(screen: OpaquePointer?) async {
        guard currentView == .servers else { return }

        let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
        guard selectedIndex < filteredServers.count else {
            statusMessage = "No server selected"
            return
        }

        let server = filteredServers[selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Build server details for confirmation
        var serverDetails: [String] = []
        serverDetails.append("Name: \(serverName)")
        if let status = server.status {
            serverDetails.append("Status: \(status)")
        }
        if let flavor = server.flavor, let flavorName = cachedFlavors.first(where: { $0.id == flavor.id })?.name {
            serverDetails.append("Flavor: \(flavorName)")
        }
        if let ip = resourceResolver.getServerIP(server) {
            serverDetails.append("IP: \(ip)")
        }

        // Confirm stop
        guard await ViewUtils.confirmOperation(
            title: "Confirm Server Stop",
            message: "Stop the following server?",
            details: serverDetails,
            screen: screen,
            screenRows: screenRows,
            screenCols: screenCols
        ) else {
            statusMessage = "Server stop cancelled"
            await tui.draw(screen: screen)
            return
        }

        statusMessage = "Stopping server '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            try await client.stopServer(id: server.id)
            statusMessage = "Server '\(serverName)' stop initiated successfully"

            // Refresh server data to update status
            await dataManager.refreshAllData()
        } catch let error as OpenStackError {
            let baseMsg = "Failed to stop server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 409 {
                    statusMessage = "\(baseMsg): Server cannot be stopped (current state conflict)"
                } else if code == 404 {
                    statusMessage = "\(baseMsg): Server not found"
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
                statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to stop server '\(serverName)': \(error.localizedDescription)"
        }
    }
}
