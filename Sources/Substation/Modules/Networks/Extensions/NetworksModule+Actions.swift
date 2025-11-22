// Sources/Substation/Modules/Networks/NetworksModule+Actions.swift
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

extension NetworksModule {
    /// Register all network actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Network server management (attach/detach servers)
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register network to server management action
        actions.append(ModuleActionRegistration(
            identifier: "network.manage_servers",
            title: "Manage Server Attachments",
            keybinding: "a",
            viewModes: [.networks],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.manageNetworkToServers(screen: screen)
            },
            description: "Attach or detach servers to/from this network",
            requiresConfirmation: false,
            category: .network
        ))

        return actions
    }
}

// MARK: - Network Action Implementations

extension NetworksModule {
    /// Manage network to server attachments
    ///
    /// Opens the server management view to attach or detach servers from a network.
    /// Loads all currently attached servers and allows selection of servers to
    /// attach or detach.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func manageNetworkToServers(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .networks else { return }

        let filteredNetworks = FilterUtils.filterNetworks(
            tui.cacheManager.cachedNetworks,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredNetworks.count else {
            tui.statusMessage = "No network selected"
            return
        }

        let selectedNetwork = filteredNetworks[tui.viewCoordinator.selectedIndex]

        // Store the selected network for reference
        tui.viewCoordinator.selectedResource = selectedNetwork

        // Load attached servers for this network
        await loadAttachedServersForNetwork(selectedNetwork)

        // Clear previous selections
        tui.selectionManager.selectedServers.removeAll()

        // Reset to attach mode
        tui.selectionManager.attachmentMode = .attach

        // Navigate to network server management view
        tui.changeView(to: .networkServerManagement, resetSelection: false)
        tui.statusMessage = "Managing network '\(selectedNetwork.name ?? "Unknown")' server attachments"
    }

    /// Load servers that are currently attached to a network
    ///
    /// Finds all servers that have the specified network attached by checking
    /// server addresses for network name or ID matches.
    ///
    /// - Parameter network: The network to check for attached servers
    private func loadAttachedServersForNetwork(_ network: Network) async {
        guard let tui = tui else { return }

        tui.selectionManager.attachedServerIds.removeAll()

        // Find servers that have this network attached
        // Check for both network name and ID since addresses can be keyed by either
        for server in tui.cacheManager.cachedServers {
            if let addresses = server.addresses {
                let hasNetwork = addresses.keys.contains(network.id) ||
                                (network.name != nil && addresses.keys.contains(network.name!))
                if hasNetwork {
                    tui.selectionManager.attachedServerIds.insert(server.id)
                }
            }
        }
    }

    // MARK: - Network CRUD Operations

    /// Delete the currently selected network
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func deleteNetwork(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .networks else { return }

        let filteredNetworks = FilterUtils.filterNetworks(tui.cacheManager.cachedNetworks, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredNetworks.count else {
            tui.statusMessage = "No network selected"
            return
        }

        let network = filteredNetworks[tui.viewCoordinator.selectedIndex]
        let networkName = network.name

        guard await ViewUtils.confirmDelete(networkName ?? "Unknown Network", screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Network deletion cancelled"
            return
        }

        tui.statusMessage = "Deleting network '\(networkName ?? "Unknown")'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            try await tui.client.deleteNetwork(id: network.id)

            if let index = tui.cacheManager.cachedNetworks.firstIndex(where: { $0.id == network.id }) {
                tui.cacheManager.cachedNetworks.remove(at: index)
            }

            let newMaxIndex = max(0, filteredNetworks.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Network '\(networkName ?? "Unknown")' deleted successfully"
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete network '\(networkName ?? "Unknown")'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 409 {
                    tui.statusMessage = "\(baseMsg): Network is in use and cannot be deleted"
                } else if code == 404 {
                    tui.statusMessage = "\(baseMsg): Network not found"
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
            tui.statusMessage = "Failed to delete network '\(networkName ?? "Unknown")': \(error.localizedDescription)"
        }
    }

    /// Submit network creation from the network create form
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func submitNetworkCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let validationErrors = tui.networkCreateForm.validateForm()
        if !validationErrors.isEmpty {
            tui.statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let networkName = tui.networkCreateForm.getTrimmedName()

        tui.statusMessage = "Creating network '\(networkName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            let description = tui.networkCreateForm.getTrimmedDescription()

            _ = try await tui.client.createNetwork(
                name: networkName,
                description: description.isEmpty ? nil : description
            )

            tui.statusMessage = "Network '\(networkName)' created successfully"

            tui.networkCreateForm = NetworkCreateForm()
            tui.networkCreateFormState = FormBuilderState(fields: [])

            // Trigger accelerated refresh to show state transitions
            tui.refreshAfterOperation()
            tui.changeView(to: .networks, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create network '\(networkName)'"
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
            tui.statusMessage = "Failed to create network '\(networkName)': \(error.localizedDescription)"
        }
    }
}
