// Sources/Substation/Modules/Subnets/SubnetsModule+Actions.swift
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

extension SubnetsModule {
    /// Register all subnet actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Subnet deletion
    /// - Subnet creation
    /// - Router management
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard let tui = tui else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register delete subnet action
        actions.append(ModuleActionRegistration(
            identifier: "subnet.delete",
            title: "Delete Subnet",
            keybinding: "d",
            viewModes: [.subnets],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteSubnet(screen: screen)
            },
            description: "Delete the selected subnet",
            requiresConfirmation: true,
            category: .network
        ))

        // Register create subnet action
        actions.append(ModuleActionRegistration(
            identifier: "subnet.create",
            title: "Create Subnet",
            keybinding: "c",
            viewModes: [.subnets],
            handler: { [weak tui] screen in
                guard let tui = tui else { return }
                tui.changeView(to: .subnetCreate)
                tui.subnetCreateForm = SubnetCreateForm()
                tui.subnetCreateFormState = FormBuilderState(fields: tui.subnetCreateForm.buildFields(
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    cachedNetworks: tui.cacheManager.cachedNetworks,
                    formState: FormBuilderState(fields: [])
                ))
            },
            description: "Create a new subnet",
            requiresConfirmation: false,
            category: .network
        ))

        // Register router management action
        actions.append(ModuleActionRegistration(
            identifier: "subnet.manage_router",
            title: "Manage Router",
            keybinding: "r",
            viewModes: [.subnets],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.manageSubnetRouter(screen: screen)
            },
            description: "Manage router interface for the selected subnet",
            requiresConfirmation: false,
            category: .network
        ))

        Logger.shared.logInfo("SubnetsModule registered \(actions.count) actions", context: [
            "actionCount": actions.count
        ])

        return actions
    }
}

// MARK: - Subnet Action Implementations

extension SubnetsModule {
    /// Delete the selected subnet
    ///
    /// Prompts for confirmation before deleting the subnet from OpenStack.
    /// Updates the UI and refreshes the subnet cache after successful deletion.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteSubnet(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .subnets else { return }

        let filteredSubnets = FilterUtils.filterSubnets(
            tui.cacheManager.cachedSubnets,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredSubnets.count else {
            tui.statusMessage = "No subnet selected"
            return
        }

        let subnet = filteredSubnets[tui.viewCoordinator.selectedIndex]
        let subnetName = subnet.name ?? "Unnamed subnet"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(
            subnetName,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Subnet deletion cancelled"
            return
        }

        // Show deletion in progress
        tui.statusMessage = "Deleting subnet '\(subnetName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            try await tui.client.deleteSubnet(id: subnet.id)

            // Remove from cached subnets
            if let index = tui.cacheManager.cachedSubnets.firstIndex(where: { $0.id == subnet.id }) {
                tui.cacheManager.cachedSubnets.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredSubnets.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Subnet '\(subnetName)' deleted successfully"

            // Refresh data to get updated subnet list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete subnet '\(subnetName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 409 {
                    tui.statusMessage = "\(baseMsg): Subnet is in use and cannot be deleted"
                } else if code == 404 {
                    tui.statusMessage = "\(baseMsg): Subnet not found"
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
            tui.statusMessage = "Failed to delete subnet '\(subnetName)': \(error.localizedDescription)"
        }
    }

    /// Submit subnet creation from the subnet create form
    ///
    /// Validates the form data and creates a new subnet in OpenStack.
    /// Updates the UI and refreshes the subnet cache after successful creation.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func submitSubnetCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Validate the form
        let validationErrors = tui.subnetCreateForm.validate(availableNetworks: tui.cacheManager.cachedNetworks)
        if !validationErrors.isEmpty {
            tui.statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let subnetName = tui.subnetCreateForm.getTrimmedName()

        // Show creation in progress
        tui.statusMessage = "Creating subnet '\(subnetName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            // Collect all form data - use selected network ID
            guard let networkId = tui.subnetCreateForm.selectedNetworkID else {
                tui.statusMessage = "Failed to create subnet: No network selected"
                return
            }

            let ipVersion = tui.subnetCreateForm.getIPVersionInt()
            let cidr = tui.subnetCreateForm.getTrimmedCIDR()
            let enableDhcp = tui.subnetCreateForm.dhcpEnabled

            // Parse DNS nameservers from comma-separated string
            let dnsString = tui.subnetCreateForm.getTrimmedDNS()
            let dnsNameservers: [String]? = if !dnsString.isEmpty {
                dnsString.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else {
                nil
            }

            // Determine gateway IP - nil means auto-assign gateway (default behavior)
            let gatewayIP: String? = nil

            // Use the createSubnet API
            _ = try await tui.client.createSubnet(
                name: subnetName,
                networkID: networkId,
                cidr: cidr,
                ipVersion: ipVersion,
                gatewayIP: gatewayIP,
                dnsNameservers: dnsNameservers,
                enableDhcp: enableDhcp
            )

            tui.statusMessage = "Subnet '\(subnetName)' created successfully"

            // Refresh subnet cache and return to list
            tui.refreshAfterOperation()
            tui.changeView(to: .subnets, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create subnet '\(subnetName)'"
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
            tui.statusMessage = "Failed to create subnet '\(subnetName)': \(error.localizedDescription)"
        }
    }

    /// Manage router interface for a subnet
    ///
    /// Opens the router management view for the selected subnet.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func manageSubnetRouter(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .subnets else { return }

        let filteredSubnets = FilterUtils.filterSubnets(
            tui.cacheManager.cachedSubnets,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredSubnets.count else {
            tui.statusMessage = "No subnet selected"
            return
        }

        let subnet = filteredSubnets[tui.viewCoordinator.selectedIndex]
        tui.viewCoordinator.selectedResource = subnet
        tui.changeView(to: .subnetRouterManagement, resetSelection: false)
        tui.statusMessage = "Managing router for subnet '\(subnet.name ?? "Unknown")'"
    }
}
