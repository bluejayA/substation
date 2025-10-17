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

// MARK: - Server Console Log Actions

@MainActor
extension Actions {

    internal func viewServerLogs(screen: OpaquePointer?) async {
        guard currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
        guard selectedIndex < filteredServers.count else {
            statusMessage = "No server selected"
            return
        }

        let server = filteredServers[selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        statusMessage = "Fetching console logs for '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            let consoleOutput = try await client.getConsoleOutput(serverID: server.id)
            await tui.uiHelpers.showConsoleOutputDialog(serverName: serverName, output: consoleOutput, screen: screen)
            // Redraw the main interface after closing the console dialog
            statusMessage = "Console logs closed"
            await tui.draw(screen: screen)
        } catch let error as OpenStackError {
            let baseMsg = "Failed to get console output for '\(serverName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 400 {
                    statusMessage = "\(baseMsg): Bad request (server may not support console output)"
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
            statusMessage = "Failed to get console output for '\(serverName)': \(error.localizedDescription)"
        }
    }

    internal func viewServerConsole(screen: OpaquePointer?) async {
        guard currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
        guard selectedIndex < filteredServers.count else {
            statusMessage = "No server selected"
            return
        }

        let server = filteredServers[selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        statusMessage = "Fetching console URL for '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            let console = try await client.getRemoteConsole(serverID: server.id)
            // Store the server name and console, then change to console view
            tui.previousSelectedResourceName = serverName
            tui.selectedResource = console
            tui.changeView(to: .serverConsole, resetSelection: false)
            statusMessage = "Viewing console for '\(serverName)'"
        } catch let error as OpenStackError {
            let baseMsg = "Failed to get console URL for '\(serverName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 400 {
                    statusMessage = "\(baseMsg): Bad request (server may not support remote console)"
                } else if code == 404 {
                    statusMessage = "\(baseMsg): Server not found"
                } else if code == 409 {
                    statusMessage = "\(baseMsg): Server state conflict (may not be running)"
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
            statusMessage = "Failed to get console URL for '\(serverName)': \(error.localizedDescription)"
        }
    }
}
