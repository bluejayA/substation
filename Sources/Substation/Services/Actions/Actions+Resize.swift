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

// MARK: - Server Resize Actions

@MainActor
extension Actions {

    internal func applyServerResize(screen: OpaquePointer?) async {
        guard let server = serverResizeForm.selectedServer else {
            statusMessage = "No server selected"
            return
        }

        let serverName = server.name ?? "Unnamed Server"

        // Check if we're in confirm/revert mode
        if serverResizeForm.mode == .confirmOrRevert {
            // Handle resize confirmation or revert
            let action = serverResizeForm.selectedAction
            let actionName = (action == .confirmResize) ? "confirm" : "revert"

            // Confirm action
            let confirmTitle = action == .confirmResize ? "Confirm Resize" : "Revert Resize"
            let confirmMessage = action == .confirmResize ?
                "Confirm resize for '\(serverName)'?" :
                "Revert resize for '\(serverName)'?"
            guard await ViewUtils.confirmOperation(
                title: confirmTitle,
                message: confirmMessage,
                screen: screen,
                screenRows: screenRows,
                screenCols: screenCols
            ) else {
                statusMessage = "Resize \(actionName) cancelled"
                return
            }

            statusMessage = "\(actionName == "confirm" ? "Confirming" : "Reverting") resize for server '\(serverName)'..."
            await tui.draw(screen: screen)

            do {
                if action == .confirmResize {
                    try await client.confirmResize(id: server.id)
                    statusMessage = "Server '\(serverName)' resize confirmed successfully"
                } else {
                    try await client.revertResize(id: server.id)
                    statusMessage = "Server '\(serverName)' resize reverted successfully"
                }

                // Reset form and return to servers view
                serverResizeForm.reset()
                currentView = .servers

                // Refresh server data
                await dataManager.refreshAllData()
            } catch let error as OpenStackError {
                let baseMsg = "Failed to \(actionName) resize for server '\(serverName)'"
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
                    if code == 409 {
                        statusMessage = "\(baseMsg): Invalid server state"
                    } else if code == 404 {
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
                statusMessage = "Failed to \(actionName) resize for server '\(serverName)': \(error.localizedDescription)"
            }
        } else {
            // Normal flavor selection mode
            guard let selectedFlavor = serverResizeForm.getSelectedFlavor() else {
                statusMessage = "No flavor selected for resize"
                return
            }

            // Build resize details for confirmation
            var resizeDetails: [String] = []
            resizeDetails.append("Server: \(serverName)")
            if let currentFlavor = serverResizeForm.currentFlavor {
                let currentName = currentFlavor.name ?? "Unknown"
                let newName = selectedFlavor.name ?? "Unknown"
                resizeDetails.append("Flavor: \(currentName) -> \(newName)")

                // Show resource changes
                let ramChange = selectedFlavor.ram - currentFlavor.ram
                let vcpuChange = selectedFlavor.vcpus - currentFlavor.vcpus
                if ramChange != 0 {
                    let ramSign = ramChange > 0 ? "+" : ""
                    resizeDetails.append("RAM: \(currentFlavor.ram)MB -> \(selectedFlavor.ram)MB (\(ramSign)\(ramChange)MB)")
                }
                if vcpuChange != 0 {
                    let vcpuSign = vcpuChange > 0 ? "+" : ""
                    resizeDetails.append("vCPUs: \(currentFlavor.vcpus) -> \(selectedFlavor.vcpus) (\(vcpuSign)\(vcpuChange))")
                }
            } else {
                resizeDetails.append("New Flavor: \(selectedFlavor.name ?? "Unknown")")
            }

            // Confirm resize
            guard await ViewUtils.confirmOperation(
                title: "Confirm Server Resize",
                message: "Resize the following server?",
                details: resizeDetails,
                screen: screen,
                screenRows: screenRows,
                screenCols: screenCols
            ) else {
                statusMessage = "Server resize cancelled"
                await tui.draw(screen: screen)
                return
            }

            statusMessage = "Resizing server '\(serverName)' to '\(selectedFlavor.name ?? "Unknown")'..."
            await tui.draw(screen: screen)

            do {
                try await client.resizeServer(id: server.id, flavorRef: selectedFlavor.id)
                statusMessage = "Server '\(serverName)' resize initiated successfully. Returning to server list..."

                // Reset form and return to servers view
                serverResizeForm.reset()
                currentView = .servers

                // Refresh server data
                await dataManager.refreshAllData()
            } catch let error as OpenStackError {
                let baseMsg = "Failed to resize server '\(serverName)'"
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
                    if code == 409 {
                        statusMessage = "\(baseMsg): Cannot resize - check server state"
                    } else if code == 404 {
                        statusMessage = "\(baseMsg): Server or flavor not found"
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
                statusMessage = "Failed to resize server '\(serverName)': \(error.localizedDescription)"
            }
        }
    }

    internal func resizeServer(screen: OpaquePointer?) async {
        guard currentView == .servers else { return }

        let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
        guard selectedIndex < filteredServers.count else {
            statusMessage = "No server selected"
            return
        }

        let server = filteredServers[selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Prepare server resize form
        serverResizeForm.reset()
        serverResizeForm.selectedServer = server
        serverResizeForm.availableFlavors = cachedFlavors
        // Find the current flavor in cached flavors by trying multiple fields
        serverResizeForm.currentFlavor = server.flavor.flatMap { flavorInfo in
            // Try matching by ID first
            if let matched = cachedFlavors.first(where: { $0.id == flavorInfo.id }) {
                return matched
            }
            // Try matching by original_name
            if let originalName = flavorInfo.originalName, let matched = cachedFlavors.first(where: { $0.name == originalName }) {
                return matched
            }
            // Try matching by name
            if let name = flavorInfo.name, let matched = cachedFlavors.first(where: { $0.name == name }) {
                return matched
            }
            return nil
        }

        // Check if server is in VERIFY_RESIZE state (resize pending confirmation)
        if let status = server.status, status == .verify {
            serverResizeForm.mode = .confirmOrRevert
            serverResizeForm.selectedAction = .confirmResize
            statusMessage = "Server '\(serverName)' is awaiting resize confirmation"
        } else if let status = server.status, !["ACTIVE", "SHUTOFF"].contains(status.rawValue) {
            // Server is not in a resizable state
            statusMessage = "Server '\(serverName)' must be ACTIVE or SHUTOFF to resize (current: \(status))"
            return
        } else {
            // Normal resize mode
            serverResizeForm.mode = .selectFlavor
            serverResizeForm.selectedFlavorIndex = 0
        }

        // Change to resize view
        tui.changeView(to: .serverResize, resetSelection: false)
    }
}
