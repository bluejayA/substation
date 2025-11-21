// Sources/Substation/Modules/Servers/ServersModule+Actions.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Action Registration

extension ServersModule {
    /// Register all server actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Server lifecycle management (start, stop, reboot)
    /// - Console and log viewing
    /// - Server resize operations
    /// - Snapshot creation
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register start server action
        actions.append(ModuleActionRegistration(
            identifier: "server.start",
            title: "Start Server",
            keybinding: "s",
            viewModes: [.servers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.startServer(screen: screen)
            },
            description: "Start the selected server",
            requiresConfirmation: true,
            category: .lifecycle
        ))

        // Register stop server action
        actions.append(ModuleActionRegistration(
            identifier: "server.stop",
            title: "Stop Server",
            keybinding: "S",
            viewModes: [.servers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.stopServer(screen: screen)
            },
            description: "Stop the selected server",
            requiresConfirmation: true,
            category: .lifecycle
        ))

        // Register reboot server action
        actions.append(ModuleActionRegistration(
            identifier: "server.reboot",
            title: "Reboot Server",
            keybinding: "r",
            viewModes: [.servers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.restartServer(screen: screen)
            },
            description: "Soft reboot the selected server",
            requiresConfirmation: true,
            category: .lifecycle
        ))

        // Register view server logs action
        actions.append(ModuleActionRegistration(
            identifier: "server.logs",
            title: "View Console Logs",
            keybinding: "l",
            viewModes: [.servers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.viewServerLogs(screen: screen)
            },
            description: "View console output logs for the selected server",
            requiresConfirmation: false,
            category: .management
        ))

        // Register view server console action
        actions.append(ModuleActionRegistration(
            identifier: "server.console",
            title: "Open Console",
            keybinding: "c",
            viewModes: [.servers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.viewServerConsole(screen: screen)
            },
            description: "Open remote console (noVNC) for the selected server",
            requiresConfirmation: false,
            category: .management
        ))

        // Register resize server action
        actions.append(ModuleActionRegistration(
            identifier: "server.resize",
            title: "Resize Server",
            keybinding: "R",
            viewModes: [.servers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.resizeServer(screen: screen)
            },
            description: "Change the flavor (size) of the selected server",
            requiresConfirmation: false,
            category: .management
        ))

        // Register snapshot creation action
        actions.append(ModuleActionRegistration(
            identifier: "server.snapshot",
            title: "Create Snapshot",
            keybinding: "n",
            viewModes: [.servers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.openSnapshotManagement(screen: screen)
            },
            description: "Create a snapshot image of the selected server",
            requiresConfirmation: false,
            category: .storage
        ))

        return actions
    }
}

// MARK: - Server Lifecycle Action Implementations

extension ServersModule {
    /// Restart (soft reboot) the selected server
    ///
    /// Performs a soft reboot on the currently selected server after
    /// displaying a confirmation dialog with server details.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func restartServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(
            tui.cacheManager.cachedServers,
            query: tui.searchQuery,
            getServerIP: tui.resourceResolver.getServerIP
        )
        guard tui.viewCoordinator.selectedIndex < filteredServers.count else {
            tui.statusMessage = "No server selected"
            return
        }

        let server = filteredServers[tui.viewCoordinator.selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Build server details for confirmation
        var serverDetails: [String] = []
        serverDetails.append("Name: \(serverName)")
        if let status = server.status {
            serverDetails.append("Status: \(status)")
        }
        if let flavor = server.flavor, let flavorName = tui.cacheManager.cachedFlavors.first(where: { $0.id == flavor.id })?.name {
            serverDetails.append("Flavor: \(flavorName)")
        }
        if let ip = tui.resourceResolver.getServerIP(server) {
            serverDetails.append("IP: \(ip)")
        }

        // Confirm restart
        guard await ViewUtils.confirmOperation(
            title: "Confirm Server Restart",
            message: "Restart the following server?",
            details: serverDetails,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Server restart cancelled"
            await tui.draw(screen: screen)
            return
        }

        // Show restart in progress
        tui.statusMessage = "Restarting server '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            try await tui.client.rebootServer(id: server.id, type: "SOFT")

            tui.statusMessage = "Server '\(serverName)' restart initiated successfully"

            // Refresh data to get updated server status
            await tui.dataManager.refreshAllData()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to restart server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, let message):
                if let message = message {
                    tui.statusMessage = "\(baseMsg): \(message)"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                tui.statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                tui.statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                tui.statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                tui.statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                tui.statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                tui.statusMessage = "\(baseMsg): Missing required field: \(field)"
            case .invalidResponse:
                tui.statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                tui.statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            tui.statusMessage = "Failed to restart server '\(serverName)': \(error.localizedDescription)"
        }
    }

    /// Start the selected server
    ///
    /// Initiates a start operation on the currently selected server after
    /// displaying a confirmation dialog with server details.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func startServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(
            tui.cacheManager.cachedServers,
            query: tui.searchQuery,
            getServerIP: tui.resourceResolver.getServerIP
        )
        guard tui.viewCoordinator.selectedIndex < filteredServers.count else {
            tui.statusMessage = "No server selected"
            return
        }

        let server = filteredServers[tui.viewCoordinator.selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Build server details for confirmation
        var serverDetails: [String] = []
        serverDetails.append("Name: \(serverName)")
        if let status = server.status {
            serverDetails.append("Status: \(status)")
        }
        if let flavor = server.flavor, let flavorName = tui.cacheManager.cachedFlavors.first(where: { $0.id == flavor.id })?.name {
            serverDetails.append("Flavor: \(flavorName)")
        }
        if let ip = tui.resourceResolver.getServerIP(server) {
            serverDetails.append("IP: \(ip)")
        }

        // Confirm start
        guard await ViewUtils.confirmOperation(
            title: "Confirm Server Start",
            message: "Start the following server?",
            details: serverDetails,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Server start cancelled"
            await tui.draw(screen: screen)
            return
        }

        tui.statusMessage = "Starting server '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            try await tui.client.startServer(id: server.id)
            tui.statusMessage = "Server '\(serverName)' start initiated successfully"

            // Refresh server data to update status
            await tui.dataManager.refreshAllData()
        } catch let error as OpenStackError {
            let baseMsg = "Failed to start server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 409 {
                    tui.statusMessage = "\(baseMsg): Server cannot be started (current state conflict)"
                } else if code == 404 {
                    tui.statusMessage = "\(baseMsg): Server not found"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                tui.statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                tui.statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                tui.statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                tui.statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                tui.statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                tui.statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                tui.statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                tui.statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            tui.statusMessage = "Failed to start server '\(serverName)': \(error.localizedDescription)"
        }
    }

    /// Stop the selected server
    ///
    /// Initiates a stop operation on the currently selected server after
    /// displaying a confirmation dialog with server details.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func stopServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(
            tui.cacheManager.cachedServers,
            query: tui.searchQuery,
            getServerIP: tui.resourceResolver.getServerIP
        )
        guard tui.viewCoordinator.selectedIndex < filteredServers.count else {
            tui.statusMessage = "No server selected"
            return
        }

        let server = filteredServers[tui.viewCoordinator.selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Build server details for confirmation
        var serverDetails: [String] = []
        serverDetails.append("Name: \(serverName)")
        if let status = server.status {
            serverDetails.append("Status: \(status)")
        }
        if let flavor = server.flavor, let flavorName = tui.cacheManager.cachedFlavors.first(where: { $0.id == flavor.id })?.name {
            serverDetails.append("Flavor: \(flavorName)")
        }
        if let ip = tui.resourceResolver.getServerIP(server) {
            serverDetails.append("IP: \(ip)")
        }

        // Confirm stop
        guard await ViewUtils.confirmOperation(
            title: "Confirm Server Stop",
            message: "Stop the following server?",
            details: serverDetails,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Server stop cancelled"
            await tui.draw(screen: screen)
            return
        }

        tui.statusMessage = "Stopping server '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            try await tui.client.stopServer(id: server.id)
            tui.statusMessage = "Server '\(serverName)' stop initiated successfully"

            // Refresh server data to update status
            await tui.dataManager.refreshAllData()
        } catch let error as OpenStackError {
            let baseMsg = "Failed to stop server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 409 {
                    tui.statusMessage = "\(baseMsg): Server cannot be stopped (current state conflict)"
                } else if code == 404 {
                    tui.statusMessage = "\(baseMsg): Server not found"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                tui.statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                tui.statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                tui.statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                tui.statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                tui.statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                tui.statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                tui.statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                tui.statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            tui.statusMessage = "Failed to stop server '\(serverName)': \(error.localizedDescription)"
        }
    }
}

// MARK: - Server Console Log Action Implementations

extension ServersModule {
    /// View console logs for the selected server
    ///
    /// Fetches and displays the console output logs for the currently
    /// selected server in a dialog window.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func viewServerLogs(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(
            tui.cacheManager.cachedServers,
            query: tui.searchQuery,
            getServerIP: tui.resourceResolver.getServerIP
        )
        guard tui.viewCoordinator.selectedIndex < filteredServers.count else {
            tui.statusMessage = "No server selected"
            return
        }

        let server = filteredServers[tui.viewCoordinator.selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        tui.statusMessage = "Fetching console logs for '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            let consoleOutput = try await tui.client.getConsoleOutput(serverID: server.id)
            await tui.uiHelpers.showConsoleOutputDialog(serverName: serverName, output: consoleOutput, screen: screen)
            // Redraw the main interface after closing the console dialog
            tui.statusMessage = "Console logs closed"
            await tui.draw(screen: screen)
        } catch let error as OpenStackError {
            let baseMsg = "Failed to get console output for '\(serverName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 400 {
                    tui.statusMessage = "\(baseMsg): Bad request (server may not support console output)"
                } else if code == 404 {
                    tui.statusMessage = "\(baseMsg): Server not found"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                tui.statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                tui.statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                tui.statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                tui.statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                tui.statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                tui.statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                tui.statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                tui.statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            tui.statusMessage = "Failed to get console output for '\(serverName)': \(error.localizedDescription)"
        }
    }

    /// View remote console for the selected server
    ///
    /// Fetches the remote console URL (noVNC) for the currently selected
    /// server and transitions to the console view.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func viewServerConsole(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(
            tui.cacheManager.cachedServers,
            query: tui.searchQuery,
            getServerIP: tui.resourceResolver.getServerIP
        )
        guard tui.viewCoordinator.selectedIndex < filteredServers.count else {
            tui.statusMessage = "No server selected"
            return
        }

        let server = filteredServers[tui.viewCoordinator.selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        tui.statusMessage = "Fetching console URL for '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            let console = try await tui.client.getRemoteConsole(serverID: server.id)
            // Store the server name and console, then change to console view
            tui.viewCoordinator.previousSelectedResourceName = serverName
            tui.viewCoordinator.selectedResource = console
            tui.changeView(to: .serverConsole, resetSelection: false)
            tui.statusMessage = "Viewing console for '\(serverName)'"
        } catch let error as OpenStackError {
            let baseMsg = "Failed to get console URL for '\(serverName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 400 {
                    tui.statusMessage = "\(baseMsg): Bad request (server may not support remote console)"
                } else if code == 404 {
                    tui.statusMessage = "\(baseMsg): Server not found"
                } else if code == 409 {
                    tui.statusMessage = "\(baseMsg): Server state conflict (may not be running)"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                tui.statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                tui.statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                tui.statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                tui.statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                tui.statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                tui.statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                tui.statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                tui.statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            tui.statusMessage = "Failed to get console URL for '\(serverName)': \(error.localizedDescription)"
        }
    }
}

// MARK: - Server Resize Action Implementations

extension ServersModule {
    /// Open the resize management view for the selected server
    ///
    /// Prepares the server resize form with the current server's flavor
    /// information and transitions to the resize view. Handles servers
    /// in VERIFY_RESIZE state that need confirmation or revert.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func resizeServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(
            tui.cacheManager.cachedServers,
            query: tui.searchQuery,
            getServerIP: tui.resourceResolver.getServerIP
        )
        guard tui.viewCoordinator.selectedIndex < filteredServers.count else {
            tui.statusMessage = "No server selected"
            return
        }

        let server = filteredServers[tui.viewCoordinator.selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Prepare server resize form
        tui.serverResizeForm.reset()
        tui.serverResizeForm.selectedServer = server
        tui.serverResizeForm.availableFlavors = tui.cacheManager.cachedFlavors
        // Find the current flavor in cached flavors by trying multiple fields
        tui.serverResizeForm.currentFlavor = server.flavor.flatMap { flavorInfo in
            // Try matching by ID first
            if let matched = tui.cacheManager.cachedFlavors.first(where: { $0.id == flavorInfo.id }) {
                return matched
            }
            // Try matching by original_name
            if let originalName = flavorInfo.originalName, let matched = tui.cacheManager.cachedFlavors.first(where: { $0.name == originalName }) {
                return matched
            }
            // Try matching by name
            if let name = flavorInfo.name, let matched = tui.cacheManager.cachedFlavors.first(where: { $0.name == name }) {
                return matched
            }
            return nil
        }

        // Check if server is in VERIFY_RESIZE state (resize pending confirmation)
        if let status = server.status, status == .verify {
            tui.serverResizeForm.mode = .confirmOrRevert
            tui.serverResizeForm.selectedAction = .confirmResize
            tui.statusMessage = "Server '\(serverName)' is awaiting resize confirmation"
        } else if let status = server.status, !["ACTIVE", "SHUTOFF"].contains(status.rawValue) {
            // Server is not in a resizable state
            tui.statusMessage = "Server '\(serverName)' must be ACTIVE or SHUTOFF to resize (current: \(status))"
            return
        } else {
            // Normal resize mode
            tui.serverResizeForm.mode = .selectFlavor
            tui.serverResizeForm.selectedFlavorIndex = 0
        }

        // Change to resize view
        tui.changeView(to: .serverResize, resetSelection: false)
    }

    /// Apply the server resize operation
    ///
    /// Executes the resize operation based on the current form mode:
    /// - selectFlavor: Initiates resize to the selected flavor
    /// - confirmOrRevert: Confirms or reverts a pending resize
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func applyServerResize(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        guard let server = tui.serverResizeForm.selectedServer else {
            tui.statusMessage = "No server selected"
            return
        }

        let serverName = server.name ?? "Unnamed Server"

        // Check if we're in confirm/revert mode
        if tui.serverResizeForm.mode == .confirmOrRevert {
            // Handle resize confirmation or revert
            let action = tui.serverResizeForm.selectedAction
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
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            ) else {
                tui.statusMessage = "Resize \(actionName) cancelled"
                return
            }

            tui.statusMessage = "\(actionName == "confirm" ? "Confirming" : "Reverting") resize for server '\(serverName)'..."
            await tui.draw(screen: screen)

            do {
                if action == .confirmResize {
                    try await tui.client.confirmResize(id: server.id)
                    tui.statusMessage = "Server '\(serverName)' resize confirmed successfully"
                } else {
                    try await tui.client.revertResize(id: server.id)
                    tui.statusMessage = "Server '\(serverName)' resize reverted successfully"
                }

                // Reset form and return to servers view
                tui.serverResizeForm.reset()
                tui.viewCoordinator.currentView = .servers

                // Refresh server data
                await tui.dataManager.refreshAllData()
            } catch let error as OpenStackError {
                let baseMsg = "Failed to \(actionName) resize for server '\(serverName)'"
                switch error {
                case .authenticationFailed:
                    tui.statusMessage = "\(baseMsg): Authentication failed"
                case .endpointNotFound:
                    tui.statusMessage = "\(baseMsg): Endpoint not found"
                case .unexpectedResponse:
                    tui.statusMessage = "\(baseMsg): Unexpected response"
                case .networkError(_):
                    tui.statusMessage = "\(baseMsg): Network error"
                case .decodingError(_):
                    tui.statusMessage = "\(baseMsg): Response decoding error"
                case .encodingError(_):
                    tui.statusMessage = "\(baseMsg): Request encoding error"
                case .configurationError(_):
                    tui.statusMessage = "\(baseMsg): Configuration error"
                case .performanceEnhancementsNotAvailable:
                    tui.statusMessage = "\(baseMsg): Performance enhancements not available"
                case .httpError(let code, _):
                    if code == 409 {
                        tui.statusMessage = "\(baseMsg): Invalid server state"
                    } else if code == 404 {
                        tui.statusMessage = "\(baseMsg): Server not found"
                    } else {
                        tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                    }
                case .missingRequiredField(let field):
                    tui.statusMessage = "\(baseMsg): Missing required field: \(field)"
                case .invalidResponse:
                    tui.statusMessage = "\(baseMsg): Invalid response from server"
                case .invalidURL:
                    tui.statusMessage = "\(baseMsg): Invalid URL configuration"
                }
            } catch {
                tui.statusMessage = "Failed to \(actionName) resize for server '\(serverName)': \(error.localizedDescription)"
            }
        } else {
            // Normal flavor selection mode
            guard let selectedFlavor = tui.serverResizeForm.getSelectedFlavor() else {
                tui.statusMessage = "No flavor selected for resize"
                return
            }

            // Build resize details for confirmation
            var resizeDetails: [String] = []
            resizeDetails.append("Server: \(serverName)")
            if let currentFlavor = tui.serverResizeForm.currentFlavor {
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
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            ) else {
                tui.statusMessage = "Server resize cancelled"
                await tui.draw(screen: screen)
                return
            }

            tui.statusMessage = "Resizing server '\(serverName)' to '\(selectedFlavor.name ?? "Unknown")'..."
            await tui.draw(screen: screen)

            do {
                try await tui.client.resizeServer(id: server.id, flavorRef: selectedFlavor.id)
                tui.statusMessage = "Server '\(serverName)' resize initiated successfully. Returning to server list..."

                // Reset form and return to servers view
                tui.serverResizeForm.reset()
                tui.viewCoordinator.currentView = .servers

                // Refresh server data
                await tui.dataManager.refreshAllData()
            } catch let error as OpenStackError {
                let baseMsg = "Failed to resize server '\(serverName)'"
                switch error {
                case .authenticationFailed:
                    tui.statusMessage = "\(baseMsg): Authentication failed"
                case .endpointNotFound:
                    tui.statusMessage = "\(baseMsg): Endpoint not found"
                case .unexpectedResponse:
                    tui.statusMessage = "\(baseMsg): Unexpected response"
                case .networkError(_):
                    tui.statusMessage = "\(baseMsg): Network error"
                case .decodingError(_):
                    tui.statusMessage = "\(baseMsg): Response decoding error"
                case .encodingError(_):
                    tui.statusMessage = "\(baseMsg): Request encoding error"
                case .configurationError(_):
                    tui.statusMessage = "\(baseMsg): Configuration error"
                case .performanceEnhancementsNotAvailable:
                    tui.statusMessage = "\(baseMsg): Performance enhancements not available"
                case .httpError(let code, _):
                    if code == 409 {
                        tui.statusMessage = "\(baseMsg): Cannot resize - check server state"
                    } else if code == 404 {
                        tui.statusMessage = "\(baseMsg): Server or flavor not found"
                    } else {
                        tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                    }
                case .missingRequiredField(let field):
                    tui.statusMessage = "\(baseMsg): Missing required field: \(field)"
                case .invalidResponse:
                    tui.statusMessage = "\(baseMsg): Invalid response from server"
                case .invalidURL:
                    tui.statusMessage = "\(baseMsg): Invalid URL configuration"
                }
            } catch {
                tui.statusMessage = "Failed to resize server '\(serverName)': \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Server Snapshot Action Implementations

extension ServersModule {
    /// Open the snapshot management view for the selected server
    ///
    /// Prepares the snapshot management form with the selected server
    /// and transitions to the snapshot creation view.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func openSnapshotManagement(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(
            tui.cacheManager.cachedServers,
            query: tui.searchQuery,
            getServerIP: tui.resourceResolver.getServerIP
        )
        guard tui.viewCoordinator.selectedIndex < filteredServers.count else {
            tui.statusMessage = "No server selected"
            return
        }

        let server = filteredServers[tui.viewCoordinator.selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Reset and prepare the snapshot form
        tui.snapshotManagementForm.reset()
        tui.snapshotManagementForm.selectedServer = server
        tui.snapshotManagementForm.snapshotName = "\(serverName)-snapshot"

        // Change to snapshot management view
        tui.changeView(to: .serverSnapshotManagement, resetSelection: false)
        tui.statusMessage = "Creating snapshot for server '\(serverName)'"
    }

    /// Execute the server snapshot creation
    ///
    /// Creates a snapshot image of the server using the configured
    /// snapshot name and metadata from the form.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func executeSnapshotCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        guard let server = tui.snapshotManagementForm.selectedServer else {
            tui.snapshotManagementForm.errorMessage = "No server selected"
            tui.statusMessage = "Snapshot creation failed: No server selected"
            return
        }

        let snapshotName = tui.snapshotManagementForm.snapshotName.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverName = server.name ?? "Unknown Server"

        // Set loading state and update status line
        tui.snapshotManagementForm.isLoading = true
        tui.snapshotManagementForm.errorMessage = nil
        tui.statusMessage = "Creating snapshot '\(snapshotName)' for server '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            let metadata = tui.snapshotManagementForm.generateSnapshotMetadata()

            let imageID = try await tui.client.createServerSnapshot(
                serverID: server.id,
                name: snapshotName,
                metadata: metadata
            )

            // Success - update form state and status line
            tui.snapshotManagementForm.isLoading = false
            tui.snapshotManagementForm.successMessage = "Snapshot '\(snapshotName)' created successfully (ID: \(imageID))"
            tui.statusMessage = "[SUCCESS] Snapshot '\(snapshotName)' created successfully for '\(serverName)' (ID: \(imageID))"

            // Show success message briefly
            await tui.draw(screen: screen)
            usleep(2_000_000) // Show success message for 2 seconds

            // Refresh image cache to include the new snapshot
            let _ = await DataProviderRegistry.shared.fetchData(for: "images", priority: .onDemand, forceRefresh: true)

            // Restore success status message after refresh (which may overwrite it)
            tui.statusMessage = "[SUCCESS] Snapshot '\(snapshotName)' created successfully for '\(serverName)' (ID: \(imageID))"

            // Reset form and return to servers view after successful creation
            tui.snapshotManagementForm.reset()
            Logger.shared.logNavigation(".serverSnapshotManagement", to: ".servers", details: ["action": "snapshot_created_success"])
            tui.changeView(to: .servers, resetSelection: false, preserveStatus: true)

        } catch let error as OpenStackError {
            tui.snapshotManagementForm.isLoading = false
            let baseMsg = "Failed to create snapshot '\(snapshotName)'"
            let statusMsg: String
            switch error {
            case .authenticationFailed:
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Authentication failed"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Authentication failed"
            case .endpointNotFound:
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Endpoint not found"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Endpoint not found"
            case .unexpectedResponse:
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Unexpected response"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Unexpected response"
            case .networkError(let underlyingError):
                let errorDetail = underlyingError.localizedDescription
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Network error - \(errorDetail)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Network error - \(errorDetail)"
            case .decodingError(let underlyingError):
                let errorDetail = underlyingError.localizedDescription
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Response decoding error - \(errorDetail)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Response decoding error - \(errorDetail)"
            case .encodingError(let underlyingError):
                let errorDetail = underlyingError.localizedDescription
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Request encoding error - \(errorDetail)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Request encoding error - \(errorDetail)"
            case .configurationError(let message):
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Configuration error - \(message)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Performance enhancements not available"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Performance enhancements not available"
            case .httpError(let code, let message):
                let detail = message.map { " - \($0)" } ?? ""
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): HTTP error \(code)\(detail)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': HTTP error \(code)\(detail)"
            case .missingRequiredField(let field):
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Missing required field \(field)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Missing required field \(field)"
            case .invalidResponse:
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Invalid response"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Invalid response"
            case .invalidURL:
                tui.snapshotManagementForm.errorMessage = "\(baseMsg): Invalid URL"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Invalid URL"
            }
            tui.statusMessage = statusMsg

            // Show error message briefly then return to servers view
            await tui.draw(screen: screen)
            usleep(3_000_000) // Show error message for 3 seconds
            Logger.shared.logError("snapshot_creation_failed", error: error, context: ["serverID": server.id])

            // Reset form and return to servers view
            tui.snapshotManagementForm.reset()
            Logger.shared.logNavigation(".serverSnapshotManagement", to: ".servers", details: ["action": "snapshot_creation_failed"])
            tui.changeView(to: .servers, resetSelection: false, preserveStatus: true)

        } catch {
            tui.snapshotManagementForm.isLoading = false
            tui.snapshotManagementForm.errorMessage = "Failed to create snapshot '\(snapshotName)': \(error.localizedDescription)"
            tui.statusMessage = "[ERROR] Failed to create snapshot '\(snapshotName)' for '\(serverName)': \(error.localizedDescription)"

            // Show error message briefly then return to servers view
            await tui.draw(screen: screen)
            usleep(3_000_000) // Show error message for 3 seconds
            Logger.shared.logError("snapshot_creation_failed", error: error, context: ["serverID": server.id])

            // Reset form and return to servers view
            tui.snapshotManagementForm.reset()
            Logger.shared.logNavigation(".serverSnapshotManagement", to: ".servers", details: ["action": "snapshot_creation_failed"])
            tui.changeView(to: .servers, resetSelection: false, preserveStatus: true)
        }
    }
}

// MARK: - Network Interface Action Implementations

extension ServersModule {
    /// Apply network interface changes to a server
    ///
    /// Processes pending network additions and removals for a server.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func applyNetworkInterfaceChanges(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        guard let server = tui.networkInterfaceForm.selectedServer else {
            tui.statusMessage = "No server selected"
            return
        }

        let serverName = server.name ?? "Unnamed Server"
        var changeCount = 0
        var errors: [String] = []

        // Apply network additions (attach networks)
        for networkId in tui.networkInterfaceForm.pendingNetworkAttachments {
            if let network = tui.cacheManager.cachedNetworks.first(where: { $0.id == networkId }) {
                tui.statusMessage = "Attaching network '\(network.name ?? "Unknown")'..."
                do {
                    _ = try await tui.client.nova.attachNetworkToServer(
                        serverId: server.id,
                        networkId: networkId
                    )
                    changeCount += 1
                } catch {
                    errors.append("Failed to attach network '\(network.name ?? networkId)': \(error.localizedDescription)")
                }
            }
        }

        // Apply port additions (attach ports)
        for portId in tui.networkInterfaceForm.pendingPortAttachments {
            if let port = tui.cacheManager.cachedPorts.first(where: { $0.id == portId }) {
                tui.statusMessage = "Attaching port '\(port.name ?? port.id)'..."
                do {
                    try await tui.client.attachPort(
                        serverID: server.id,
                        portID: portId
                    )
                    changeCount += 1
                } catch {
                    errors.append("Failed to attach port '\(port.name ?? portId)': \(error.localizedDescription)")
                }
            }
        }

        // Apply interface removals (detach)
        for portId in tui.networkInterfaceForm.pendingPortDetachments {
            tui.statusMessage = "Detaching interface..."
            do {
                try await tui.client.detachPort(serverID: server.id, portID: portId)
                changeCount += 1
            } catch {
                errors.append("Failed to detach interface: \(error.localizedDescription)")
            }
        }

        // Update status and refresh
        if changeCount > 0 {
            var message = "Applied \(changeCount) network interface changes to '\(serverName)'"
            if !errors.isEmpty {
                message += " (with \(errors.count) errors)"
            }
            tui.statusMessage = message

            // Clear pending changes
            tui.networkInterfaceForm.pendingNetworkAttachments.removeAll()
            tui.networkInterfaceForm.pendingPortAttachments.removeAll()
            tui.networkInterfaceForm.pendingPortDetachments.removeAll()

            // Refresh server data
            let _ = await DataProviderRegistry.shared.fetchData(for: "servers", priority: .onDemand, forceRefresh: true)
        } else if !errors.isEmpty {
            tui.statusMessage = "All network interface operations failed"
        } else {
            tui.statusMessage = "No changes to apply"
        }
    }

    // MARK: - Server CRUD Operations

    /// Create a new server from the server create form
    ///
    /// Supports both image and volume boot sources, with optional bulk creation
    internal func createServer() async {
        guard let tui = tui else { return }

        // Validation
        guard !tui.serverCreateForm.serverName.isEmpty else {
            tui.statusMessage = "Server name is required"
            return
        }

        // Parse and validate maxServers
        guard let maxServersCount = Int(tui.serverCreateForm.maxServers.trimmingCharacters(in: .whitespacesAndNewlines)), maxServersCount >= 1 else {
            tui.statusMessage = "Max servers must be a valid number >= 1"
            return
        }

        // Validate boot source requirements
        var selectedBootSourceId: String = ""
        switch tui.serverCreateForm.bootSource {
        case .image:
            guard let selectedImageId = tui.serverCreateForm.selectedImageID else {
                tui.statusMessage = "Please select an image"
                return
            }
            selectedBootSourceId = selectedImageId
        case .volume:
            guard let selectedVolumeId = tui.serverCreateForm.selectedVolumeID else {
                tui.statusMessage = "Please select a bootable volume"
                return
            }
            selectedBootSourceId = selectedVolumeId
        }

        guard let selectedFlavorId = tui.serverCreateForm.selectedFlavorID else {
            tui.statusMessage = "Please select a flavor"
            return
        }

        guard let selectedFlavor = tui.cacheManager.cachedFlavors.first(where: { $0.id == selectedFlavorId }) else {
            tui.statusMessage = "Selected flavor not found"
            return
        }

        // Get selected network, key pair, and server group (optional)
        let selectedNetworkId = tui.serverCreateForm.selectedNetworks.first
        let selectedKeyPairName = tui.serverCreateForm.selectedKeyPairName
        let selectedServerGroupID = tui.serverCreateForm.selectedServerGroupID

        // Use the base server name
        let serverName = tui.serverCreateForm.serverName

        // Capture form values before going async
        let bootSource = tui.serverCreateForm.bootSource
        let selectedSecurityGroupNames = tui.serverCreateForm.selectedSecurityGroups
        let cachedVolumes = tui.cacheManager.cachedVolumes

        // Create operation tracker for bulk server creation (if more than 1)
        let operation: SwiftBackgroundOperation?
        if maxServersCount > 1 {
            let op = SwiftBackgroundOperation(
                type: .bulkCreate,
                resourceType: "Servers",
                itemsTotal: maxServersCount
            )
            tui.swiftBackgroundOps.addOperation(op)
            op.status = .queued
            operation = op
        } else {
            operation = nil
        }

        tui.statusMessage = maxServersCount > 1 ? "Starting creation of \(maxServersCount) servers..." : "Creating server..."

        // Return to servers view immediately
        tui.changeView(to: .servers, resetSelection: false)

        // Run creation in background task
        Task { @MainActor in
            if let op = operation {
                op.status = .running
            }

            do {
                let newServer: Server

                switch bootSource {
                case .image:
                    let networks: [NetworkRequest]? = if let networkId = selectedNetworkId {
                        [NetworkRequest(uuid: networkId, port: nil, fixedIp: nil)]
                    } else {
                        nil
                    }

                    let securityGroups: [SecurityGroupRef]? = if !selectedSecurityGroupNames.isEmpty {
                        selectedSecurityGroupNames.map { SecurityGroupRef(name: $0) }
                    } else {
                        nil
                    }

                    let request = CreateServerRequest(
                        name: serverName,
                        imageRef: selectedBootSourceId,
                        flavorRef: selectedFlavor.id,
                        metadata: nil,
                        personality: nil,
                        securityGroups: securityGroups,
                        userData: nil,
                        availabilityZone: nil,
                        networks: networks,
                        keyName: selectedKeyPairName,
                        adminPass: nil,
                        minCount: maxServersCount,
                        maxCount: maxServersCount,
                        returnReservationId: nil,
                        serverGroup: selectedServerGroupID,
                        blockDeviceMapping: nil
                    )
                    newServer = try await tui.client.createServer(request: request)

                case .volume:
                    guard let selectedVolume = cachedVolumes.first(where: { $0.id == selectedBootSourceId }) else {
                        tui.statusMessage = "Selected volume not found"
                        return
                    }

                    let blockDeviceMapping = [
                        BlockDeviceMapping(
                            sourceType: "volume",
                            destinationType: "volume",
                            bootIndex: 0,
                            uuid: selectedVolume.id,
                            volumeSize: nil as Int?,
                            deleteOnTermination: false
                        )
                    ]

                    let networks: [NetworkRequest]? = if let networkId = selectedNetworkId {
                        [NetworkRequest(uuid: networkId, port: nil, fixedIp: nil)]
                    } else {
                        nil
                    }

                    let securityGroups: [SecurityGroupRef]? = if !selectedSecurityGroupNames.isEmpty {
                        selectedSecurityGroupNames.map { SecurityGroupRef(name: $0) }
                    } else {
                        nil
                    }

                    let request = CreateServerRequest(
                        name: serverName,
                        imageRef: nil,
                        flavorRef: selectedFlavor.id,
                        metadata: nil,
                        personality: nil,
                        securityGroups: securityGroups,
                        userData: nil,
                        availabilityZone: nil,
                        networks: networks,
                        keyName: selectedKeyPairName,
                        adminPass: nil,
                        minCount: maxServersCount,
                        maxCount: maxServersCount,
                        returnReservationId: nil,
                        serverGroup: selectedServerGroupID,
                        blockDeviceMapping: blockDeviceMapping
                    )
                    newServer = try await tui.client.createServer(request: request)
                }

                tui.cacheManager.cachedServers.append(newServer)
                let successMessage = maxServersCount > 1
                    ? "Started creation of \(maxServersCount) servers with name pattern '\(serverName)-N'"
                    : "Server '\(serverName)' created successfully"
                tui.statusMessage = successMessage

                if let operation = operation {
                    operation.itemsCompleted = maxServersCount
                    operation.markCompleted()
                    operation.progress = 1.0
                }

                tui.refreshAfterOperation()

            } catch let error as OpenStackError {
                let baseMsg = "Failed to create server"
                switch error {
                case .authenticationFailed:
                    tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
                case .endpointNotFound:
                    tui.statusMessage = "\(baseMsg): Compute service endpoint not found - check cloud config"
                case .unexpectedResponse:
                    tui.statusMessage = "\(baseMsg): Unexpected response - server may be overloaded"
                case .httpError(let code, _):
                    tui.statusMessage = "\(baseMsg): HTTP \(code) - check image/flavor/network availability"
                case .networkError(let error):
                    tui.statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                case .decodingError(let error):
                    tui.statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                case .encodingError(let error):
                    tui.statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                case .configurationError(let message):
                    tui.statusMessage = "\(baseMsg): Configuration error - \(message)"
                case .performanceEnhancementsNotAvailable:
                    tui.statusMessage = "\(baseMsg): Performance enhancements not available"
                case .missingRequiredField(let field):
                    tui.statusMessage = "\(baseMsg): Missing required field - \(field)"
                case .invalidResponse:
                    tui.statusMessage = "\(baseMsg): Invalid response from server"
                case .invalidURL:
                    tui.statusMessage = "\(baseMsg): Invalid URL configuration"
                }
                if let operation = operation {
                    operation.markFailed(error: tui.statusMessage ?? "Unknown error")
                }
            } catch {
                tui.statusMessage = "Failed to create server: \(error.localizedDescription)"
                if let operation = operation {
                    operation.markFailed(error: tui.statusMessage ?? "Unknown error")
                }
            }
        }
    }

    /// Delete the currently selected server
    ///
    /// - Parameter screen: The ncurses screen pointer for confirmation dialog
    internal func deleteServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(
            tui.cacheManager.cachedServers,
            query: tui.searchQuery,
            getServerIP: tui.resourceResolver.getServerIP
        )
        guard tui.viewCoordinator.selectedIndex < filteredServers.count else {
            tui.statusMessage = "No server selected"
            return
        }

        let server = filteredServers[tui.viewCoordinator.selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(serverName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Server deletion cancelled"
            return
        }

        tui.statusMessage = "Deleting server '\(serverName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            try await tui.client.deleteServer(id: server.id)

            if let index = tui.cacheManager.cachedServers.firstIndex(where: { $0.id == server.id }) {
                tui.cacheManager.cachedServers.remove(at: index)
            }

            let newMaxIndex = max(0, filteredServers.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Server '\(serverName)' deleted successfully"
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, let message):
                if let message = message {
                    tui.statusMessage = "\(baseMsg): \(message)"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                tui.statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                tui.statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                tui.statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                tui.statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                tui.statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                tui.statusMessage = "\(baseMsg): Missing required field: \(field)"
            case .invalidResponse:
                tui.statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                tui.statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            tui.statusMessage = "Failed to delete server '\(serverName)': \(error.localizedDescription)"
        }
    }

    /// Create a snapshot from a server
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func createServerSnapshot(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        var server: Server?

        if tui.viewCoordinator.currentView == .servers {
            // From servers list view
            let filteredServers = FilterUtils.filterServers(
                tui.cacheManager.cachedServers,
                query: tui.searchQuery,
                getServerIP: tui.resourceResolver.getServerIP
            )
            guard tui.viewCoordinator.selectedIndex < filteredServers.count else {
                tui.statusMessage = "No server selected"
                return
            }
            server = filteredServers[tui.viewCoordinator.selectedIndex]
        } else if tui.viewCoordinator.currentView == .serverDetail {
            // From server detail view - use the currently selected resource
            server = tui.viewCoordinator.selectedResource as? Server
        }

        guard let selectedServer = server else {
            tui.statusMessage = "No server selected for snapshot creation"
            return
        }

        // Initialize the snapshot management form and switch to the new view
        tui.snapshotManagementForm.reset()
        tui.snapshotManagementForm.selectedServer = selectedServer
        tui.snapshotManagementForm.generateDefaultSnapshotName()

        // Switch to the snapshot management view
        tui.changeView(to: .serverSnapshotManagement, resetSelection: false)
    }
}
