// Sources/Substation/Modules/FloatingIPs/FloatingIPsModule+Actions.swift
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

extension FloatingIPsModule {
    /// Register all floating IP actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Server assignment management
    /// - Port assignment management
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register server assignment action
        actions.append(ModuleActionRegistration(
            identifier: "floatingip.manage_server",
            title: "Manage Server Assignment",
            keybinding: "a",
            viewModes: [.floatingIPs],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.manageFloatingIPServerAssignment(screen: screen)
            },
            description: "Assign or unassign floating IP to/from a server",
            requiresConfirmation: false,
            category: .network
        ))

        // Register port assignment action
        actions.append(ModuleActionRegistration(
            identifier: "floatingip.manage_port",
            title: "Manage Port Assignment",
            keybinding: "p",
            viewModes: [.floatingIPs],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.manageFloatingIPPortAssignment(screen: screen)
            },
            description: "Assign or unassign floating IP to/from a port",
            requiresConfirmation: false,
            category: .network
        ))

        // Register delete floating IP action
        actions.append(ModuleActionRegistration(
            identifier: "floatingip.delete",
            title: "Delete Floating IP",
            keybinding: "d",
            viewModes: [.floatingIPs],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteFloatingIP(screen: screen)
            },
            description: "Delete the selected floating IP",
            requiresConfirmation: true,
            category: .network
        ))

        // Register create floating IP action
        actions.append(ModuleActionRegistration(
            identifier: "floatingip.create",
            title: "Create Floating IP",
            keybinding: "c",
            viewModes: [.floatingIPs],
            handler: { [weak tui] screen in
                guard let tui = tui else { return }
                tui.changeView(to: .floatingIPCreate)
                tui.floatingIPCreateForm = FloatingIPCreateForm()
                tui.floatingIPCreateFormState = FormBuilderState(fields: tui.floatingIPCreateForm.buildFields(
                    externalNetworks: tui.dataManager.externalNetworks,
                    subnets: tui.cacheManager.cachedSubnets,
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                ))
            },
            description: "Create a new floating IP",
            requiresConfirmation: false,
            category: .network
        ))

        return actions
    }
}

// MARK: - Floating IP Action Implementations

extension FloatingIPsModule {
    /// Manage floating IP to server assignment
    ///
    /// Opens the server management view to attach or detach a floating IP
    /// from a server. Automatically detects current state and sets mode.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func manageFloatingIPServerAssignment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .floatingIPs else { return }

        let filteredFloatingIPs = FilterUtils.filterFloatingIPs(
            tui.cacheManager.cachedFloatingIPs,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredFloatingIPs.count else {
            tui.statusMessage = "No floating IP selected"
            return
        }

        let floatingIP = filteredFloatingIPs[tui.viewCoordinator.selectedIndex]
        let floatingIPAddress = floatingIP.floatingIpAddress ?? "Unknown IP"

        // Check if floating IP is already assigned
        if floatingIP.fixedIpAddress != nil {
            // Floating IP is attached - set mode to detach
            tui.viewCoordinator.selectedResource = floatingIP
            tui.selectionManager.attachmentMode = .detach
            await loadAttachedServerForFloatingIP(floatingIP)
            tui.changeView(to: .floatingIPServerManagement, resetSelection: false)
            tui.statusMessage = "Floating IP '\(floatingIPAddress)' is attached. Select to detach or press TAB to switch to attach mode."
        } else {
            // Floating IP is not attached - set mode to attach
            tui.viewCoordinator.selectedResource = floatingIP
            tui.selectionManager.attachmentMode = .attach
            tui.selectionManager.selectedServerId = nil
            tui.selectionManager.attachedServerId = nil
            tui.changeView(to: .floatingIPServerManagement, resetSelection: false)
            tui.statusMessage = "Select a server to attach floating IP '\(floatingIPAddress)'"
        }
    }

    /// Load the server that currently has the floating IP attached
    ///
    /// - Parameter floatingIP: The floating IP to check
    private func loadAttachedServerForFloatingIP(_ floatingIP: FloatingIP) async {
        guard let tui = tui else { return }

        tui.selectionManager.attachedServerId = nil
        // Find server that has this floating IP attached by checking ports
        if let portId = floatingIP.portId {
            // Find the port that the floating IP is attached to
            if let port = tui.cacheManager.cachedPorts.first(where: { $0.id == portId }) {
                // Get the server ID from the port's device_id
                if let serverId = port.deviceId {
                    tui.selectionManager.attachedServerId = serverId
                }
            }
        }
    }

    /// Manage floating IP to port assignment
    ///
    /// Opens the port management view to attach or detach a floating IP
    /// from a port. Automatically detects current state and sets mode.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func manageFloatingIPPortAssignment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .floatingIPs else { return }

        let filteredFloatingIPs = FilterUtils.filterFloatingIPs(
            tui.cacheManager.cachedFloatingIPs,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredFloatingIPs.count else {
            tui.statusMessage = "No floating IP selected"
            return
        }

        let floatingIP = filteredFloatingIPs[tui.viewCoordinator.selectedIndex]
        let floatingIPAddress = floatingIP.floatingIpAddress ?? floatingIP.id

        // Check if floating IP is already attached to a port
        if let portId = floatingIP.portId, !portId.isEmpty {
            // Floating IP is attached - set mode to detach
            tui.selectionManager.attachmentMode = .detach
            tui.selectionManager.attachedPortId = portId
            tui.changeView(to: .floatingIPPortManagement, resetSelection: true)
            tui.viewCoordinator.selectedResource = floatingIP
            tui.statusMessage = "Floating IP '\(floatingIPAddress)' is attached. Select to detach or press TAB to switch to attach mode."
        } else {
            // Floating IP is not attached - set mode to attach
            tui.selectionManager.attachmentMode = .attach
            tui.selectionManager.selectedPortId = nil
            tui.selectionManager.attachedPortId = nil
            tui.changeView(to: .floatingIPPortManagement, resetSelection: true)
            tui.viewCoordinator.selectedResource = floatingIP
            tui.statusMessage = "Select a port to attach floating IP '\(floatingIPAddress)'"
        }
    }

    // MARK: - Floating IP CRUD Operations

    /// Delete the selected floating IP
    ///
    /// Prompts for confirmation before deleting the floating IP from OpenStack.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteFloatingIP(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .floatingIPs else { return }

        let filteredFloatingIPs = FilterUtils.filterFloatingIPs(tui.cacheManager.cachedFloatingIPs, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredFloatingIPs.count else {
            tui.statusMessage = "No floating IP selected"
            return
        }

        let floatingIP = filteredFloatingIPs[tui.viewCoordinator.selectedIndex]

        // Confirm deletion
        guard await ViewUtils.confirmDelete("delete floating IP \(floatingIP.floatingIpAddress ?? "Unknown")", screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Floating IP deletion cancelled"
            return
        }

        tui.statusMessage = "Deleting floating IP..."
        await tui.draw(screen: screen)

        do {
            try await tui.client.deleteFloatingIP(id: floatingIP.id)

            // Remove from cached floating IPs
            if let index = tui.cacheManager.cachedFloatingIPs.firstIndex(where: { $0.id == floatingIP.id }) {
                tui.cacheManager.cachedFloatingIPs.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredFloatingIPs.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Floating IP deleted successfully"
            tui.refreshAfterOperation()
        } catch {
            tui.statusMessage = "Failed to delete floating IP: \(error.localizedDescription)"
        }
    }

    /// Submit floating IP creation from the floating IP create form
    ///
    /// Validates the form data and creates a new floating IP in OpenStack.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func submitFloatingIPCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Validate the form
        let externalNetworks = tui.cacheManager.cachedNetworks.filter { $0.external == true }
        let validationErrors = tui.floatingIPCreateForm.validateForm()
        if !validationErrors.isEmpty {
            tui.statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        // Get selected external network
        guard let externalNetworkId = tui.floatingIPCreateForm.getSelectedExternalNetworkId(externalNetworks: externalNetworks) else {
            tui.statusMessage = "Please select an external network for the floating IP"
            return
        }

        // Get optional subnet and QoS policy
        let selectedSubnetId = tui.floatingIPCreateForm.getSelectedSubnetId(externalNetworks: externalNetworks, subnets: tui.cacheManager.cachedSubnets)
        let description = tui.floatingIPCreateForm.getTrimmedDescription()
        let trimmedDescription = description.isEmpty ? nil : description

        // Show creation in progress
        tui.statusMessage = "Creating floating IP..."
        tui.renderCoordinator.needsRedraw = true

        do {
            // Create the floating IP with all selected parameters
            _ = try await tui.client.createFloatingIP(
                networkID: externalNetworkId,
                portID: nil,
                subnetID: selectedSubnetId,
                description: trimmedDescription
            )

            tui.statusMessage = "Floating IP created successfully"

            // Refresh floating IP cache and return to list
            await tui.dataManager.refreshAllData()
            tui.refreshManager.lastRefresh = Date()
            tui.changeView(to: .floatingIPs, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create floating IP"
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
            tui.statusMessage = "Failed to create floating IP: \(error.localizedDescription)"
        }
    }
}
