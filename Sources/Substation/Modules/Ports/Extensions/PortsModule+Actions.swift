// Sources/Substation/Modules/Ports/PortsModule+Actions.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import struct OSClient.Port
import SwiftNCurses
import MemoryKit

// MARK: - Action Registration

extension PortsModule {
    /// Register all port actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Port server assignment management (attach/detach port to server)
    /// - Allowed address pair management
    /// - Apply allowed address pair changes
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register port server assignment action
        actions.append(ModuleActionRegistration(
            identifier: "port.manage_server",
            title: "Manage Server Assignment",
            keybinding: "a",
            viewModes: [.ports],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.managePortServerAssignment(screen: screen)
            },
            description: "Attach or detach port to/from a server",
            requiresConfirmation: false,
            category: .network
        ))

        // Register allowed address pair management action
        actions.append(ModuleActionRegistration(
            identifier: "port.manage_allowed_address_pairs",
            title: "Manage Allowed Address Pairs",
            keybinding: "p",
            viewModes: [.ports],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.managePortAllowedAddressPairs(screen: screen)
            },
            description: "Add port as allowed address pair to other ports",
            requiresConfirmation: false,
            category: .network
        ))

        // Register apply allowed address pair changes action
        actions.append(ModuleActionRegistration(
            identifier: "port.apply_allowed_address_pair_changes",
            title: "Apply Changes",
            keybinding: Character(UnicodeScalar(10)), // Enter key
            viewModes: [.portAllowedAddressPairManagement],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.applyAllowedAddressPairChanges(screen: screen)
            },
            description: "Apply pending allowed address pair changes",
            requiresConfirmation: false,
            category: .network
        ))

        // Register delete port action
        actions.append(ModuleActionRegistration(
            identifier: "port.delete",
            title: "Delete Port",
            keybinding: "d",
            viewModes: [.ports],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deletePort(screen: screen)
            },
            description: "Delete the selected port",
            requiresConfirmation: true,
            category: .network
        ))

        // Register create port action
        actions.append(ModuleActionRegistration(
            identifier: "port.create",
            title: "Create Port",
            keybinding: "c",
            viewModes: [.ports],
            handler: { [weak tui] screen in
                guard let tui = tui else { return }
                tui.changeView(to: .portCreate)
                tui.portCreateForm = PortCreateForm()
                tui.portCreateFormState = FormBuilderState(fields: tui.portCreateForm.buildFields(
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: []),
                    networks: tui.cacheManager.cachedNetworks,
                    securityGroups: tui.cacheManager.cachedSecurityGroups,
                    qosPolicies: tui.cacheManager.cachedQoSPolicies
                ))
            },
            description: "Create a new port",
            requiresConfirmation: false,
            category: .network
        ))

        Logger.shared.logInfo("PortsModule registered \(actions.count) actions", context: [
            "actionCount": actions.count
        ])

        return actions
    }
}

// MARK: - Port Action Implementations

extension PortsModule {
    /// Manage port to server assignment
    ///
    /// Opens the server management view to attach or detach a port
    /// from a server. Automatically detects current state and sets mode.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func managePortServerAssignment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .ports else { return }

        let filteredPorts = FilterUtils.filterPorts(
            tui.cacheManager.cachedPorts,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredPorts.count else {
            tui.statusMessage = "No port selected"
            return
        }

        let port = filteredPorts[tui.viewCoordinator.selectedIndex]
        let portName = port.name ?? port.id

        // Check if port is already attached to a server
        if let deviceId = port.deviceId, !deviceId.isEmpty {
            // Port is attached - set mode to detach
            tui.selectionManager.attachmentMode = .detach
            tui.selectionManager.attachedServerId = deviceId
            tui.changeView(to: .portServerManagement, resetSelection: true)
            tui.viewCoordinator.selectedResource = port
            tui.statusMessage = "Port '\(portName)' is attached. Select to detach or press TAB to switch to attach mode."
        } else {
            // Port is not attached - set mode to attach
            tui.selectionManager.attachmentMode = .attach
            tui.selectionManager.selectedServerId = nil
            tui.selectionManager.attachedServerId = nil
            tui.changeView(to: .portServerManagement, resetSelection: true)
            tui.viewCoordinator.selectedResource = port
            tui.statusMessage = "Select a server to attach port '\(portName)'"
        }
    }

    /// Manage allowed address pairs for a port
    ///
    /// Opens the allowed address pair management view to add the selected
    /// port's IP address as an allowed address pair to other ports.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func managePortAllowedAddressPairs(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .ports else { return }

        let filteredPorts = FilterUtils.filterPorts(
            tui.cacheManager.cachedPorts,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredPorts.count else {
            tui.statusMessage = "No port selected"
            return
        }

        let sourcePort = filteredPorts[tui.viewCoordinator.selectedIndex]
        let portName = sourcePort.name ?? sourcePort.id
        let portIP = sourcePort.fixedIps?.first?.ipAddress ?? "N/A"

        // Populate resource name cache synchronously for display
        for server in tui.cacheManager.cachedServers {
            if let serverName = server.name {
                tui.resourceNameCache.setServerName(server.id, name: serverName)
            }
        }
        for network in tui.cacheManager.cachedNetworks {
            if let networkName = network.name {
                tui.resourceNameCache.setNetworkName(network.id, name: networkName)
            }
        }

        // Initialize the form with the source port and all available target ports
        tui.allowedAddressPairForm = AllowedAddressPairManagementForm(
            sourcePort: sourcePort,
            availablePorts: tui.cacheManager.cachedPorts
        )

        // Switch to the management view
        tui.changeView(to: .portAllowedAddressPairManagement, resetSelection: false)
        tui.statusMessage = "Add port '\(portName)' (\(portIP)) as allowed address pair to other ports"

        Logger.shared.logUserAction("manage_port_allowed_address_pairs", details: [
            "sourcePortId": sourcePort.id,
            "sourcePortName": portName,
            "sourcePortIP": portIP
        ])
    }

    /// Apply pending allowed address pair changes
    ///
    /// Applies all pending additions and removals of the source port's IP
    /// address to/from target ports' allowed address pairs.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func applyAllowedAddressPairChanges(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .portAllowedAddressPairManagement else { return }
        guard let form = tui.allowedAddressPairForm else { return }
        guard form.mode == .selectPorts else { return }

        guard form.hasPendingChanges() else {
            tui.statusMessage = "No changes pending"
            return
        }

        let sourcePortIP = form.getSourcePortIPAddress()
        let portsToAdd = form.getTargetPortsToAdd()
        let portsToRemove = form.getTargetPortsToRemove()

        Logger.shared.logInfo("Applying allowed address pair changes", context: [
            "sourcePortId": form.sourcePort.id,
            "sourcePortIP": sourcePortIP,
            "portsToAddCount": portsToAdd.count,
            "portsToRemoveCount": portsToRemove.count
        ])

        var changeSummary: [String] = []
        if portsToAdd.count > 0 {
            changeSummary.append("adding to \(portsToAdd.count) port(s)")
        }
        if portsToRemove.count > 0 {
            changeSummary.append("removing from \(portsToRemove.count) port(s)")
        }
        tui.statusMessage = "Applying changes: \(changeSummary.joined(separator: ", "))..."

        var successCount = 0
        var failureCount = 0

        // Add source port to target ports
        for targetPort in portsToAdd {
            do {
                let updatedPairs = form.getAllowedAddressPairsForPort(targetPort.id, adding: true)
                let request = UpdatePortRequest(allowedAddressPairs: updatedPairs)
                let updatedPort = try await tui.client.neutron.updatePort(id: targetPort.id, request: request)

                // Update cached port
                if let index = tui.cacheManager.cachedPorts.firstIndex(where: { $0.id == updatedPort.id }) {
                    tui.cacheManager.cachedPorts[index] = updatedPort
                }
                successCount += 1
            } catch {
                Logger.shared.logError("Failed to add allowed address pair to port", context: [
                    "targetPortId": targetPort.id,
                    "error": error.localizedDescription
                ])
                failureCount += 1
            }
        }

        // Remove source port from target ports
        for targetPort in portsToRemove {
            do {
                let updatedPairs = form.getAllowedAddressPairsForPort(targetPort.id, adding: false)
                let request = UpdatePortRequest(allowedAddressPairs: updatedPairs)
                let updatedPort = try await tui.client.neutron.updatePort(id: targetPort.id, request: request)

                // Update cached port
                if let index = tui.cacheManager.cachedPorts.firstIndex(where: { $0.id == updatedPort.id }) {
                    tui.cacheManager.cachedPorts[index] = updatedPort
                }
                successCount += 1
            } catch {
                Logger.shared.logError("Failed to remove allowed address pair from port", context: [
                    "targetPortId": targetPort.id,
                    "error": error.localizedDescription
                ])
                failureCount += 1
            }
        }

        if failureCount == 0 {
            tui.statusMessage = "Successfully updated \(successCount) port(s) with allowed address pair '\(sourcePortIP)'"
        } else {
            tui.statusMessage = "Updated \(successCount) port(s), failed \(failureCount) port(s)"
        }

        Logger.shared.logInfo("Completed allowed address pair changes", context: [
            "sourcePortId": form.sourcePort.id,
            "successCount": successCount,
            "failureCount": failureCount
        ])

        // Trigger accelerated refresh to show state transitions
        tui.refreshAfterOperation()

        // Return to ports list
        tui.changeView(to: .ports, resetSelection: false)
    }

    // MARK: - Port CRUD Operations

    /// Delete the selected port
    ///
    /// Prompts for confirmation before deleting the port from OpenStack.
    /// Updates the UI and refreshes the port cache after successful deletion.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deletePort(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .ports else { return }

        let filteredPorts = FilterUtils.filterPorts(tui.cacheManager.cachedPorts, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredPorts.count else {
            tui.statusMessage = "No port selected"
            return
        }

        let port = filteredPorts[tui.viewCoordinator.selectedIndex]
        let portName = port.name ?? "Unnamed port"

        // Check if port is attached to a device
        if let deviceId = port.deviceId, !deviceId.isEmpty {
            tui.statusMessage = "Cannot delete port '\(portName)': Port is attached to device \(deviceId)"
            return
        }

        // Confirm deletion
        guard await ViewUtils.confirmDelete(portName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Port deletion cancelled"
            return
        }

        // Show deletion in progress
        tui.statusMessage = "Deleting port '\(portName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            try await tui.client.deletePort(id: port.id)

            // Remove from cached ports
            if let index = tui.cacheManager.cachedPorts.firstIndex(where: { $0.id == port.id }) {
                tui.cacheManager.cachedPorts.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredPorts.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Port '\(portName)' deleted successfully"

            // Refresh data to get updated port list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete port '\(portName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 409 {
                    tui.statusMessage = "\(baseMsg): Port is in use and cannot be deleted"
                } else if code == 404 {
                    tui.statusMessage = "\(baseMsg): Port not found"
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
            tui.statusMessage = "Failed to delete port '\(portName)': \(error.localizedDescription)"
        }
    }

    /// Submit port creation from the port create form
    ///
    /// Validates the form data and creates a new port in OpenStack.
    /// Updates the UI and refreshes the port cache after successful creation.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func submitPortCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Validate the form
        let validationErrors = tui.portCreateForm.validate(networks: tui.cacheManager.cachedNetworks, securityGroups: tui.cacheManager.cachedSecurityGroups)
        if !validationErrors.isEmpty {
            tui.statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let portName = tui.portCreateForm.getTrimmedName()
        let description = tui.portCreateForm.getTrimmedDescription()

        // Get selected network
        guard tui.portCreateForm.selectedNetworkIndex >= 0,
              tui.portCreateForm.selectedNetworkIndex < tui.cacheManager.cachedNetworks.count else {
            tui.statusMessage = "Please select a network for the port"
            return
        }

        let selectedNetwork = tui.cacheManager.cachedNetworks[tui.portCreateForm.selectedNetworkIndex]

        // Show creation in progress
        tui.statusMessage = "Creating port '\(portName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            // Prepare security groups if port security is enabled
            var securityGroupIds: [String]? = nil
            if tui.portCreateForm.portSecurityEnabled && !tui.portCreateForm.selectedSecurityGroupIndices.isEmpty {
                securityGroupIds = tui.portCreateForm.getSelectedSecurityGroupIds(securityGroups: tui.cacheManager.cachedSecurityGroups)
            }

            // Prepare QoS policy if enabled
            var qosPolicyId: String? = nil
            if tui.portCreateForm.qosPolicyEnabled && !tui.cacheManager.cachedQoSPolicies.isEmpty && tui.portCreateForm.selectedQosPolicyIndex < tui.cacheManager.cachedQoSPolicies.count {
                qosPolicyId = tui.cacheManager.cachedQoSPolicies[tui.portCreateForm.selectedQosPolicyIndex].id
            }

            // Create the port
            _ = try await tui.client.createPort(
                name: portName,
                description: description.isEmpty ? nil : description,
                networkID: selectedNetwork.id,
                subnetID: nil,
                securityGroups: securityGroupIds,
                qosPolicyID: qosPolicyId
            )

            tui.statusMessage = "Port '\(portName)' created successfully"

            // Trigger accelerated refresh to show state transitions
            tui.refreshAfterOperation()

            // Refresh port cache and return to list
            let _ = await DataProviderRegistry.shared.fetchData(for: "ports", priority: .onDemand, forceRefresh: true)
            tui.changeView(to: .ports, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create port '\(portName)'"
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
            tui.statusMessage = "Failed to create port '\(portName)': \(error.localizedDescription)"
        }
    }
}
