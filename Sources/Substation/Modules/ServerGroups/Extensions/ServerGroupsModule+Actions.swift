// Sources/Substation/Modules/ServerGroups/ServerGroupsModule+Actions.swift
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

extension ServerGroupsModule {
    /// Register all server group actions with the ActionRegistry
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard let tui = tui else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register delete server group action
        actions.append(ModuleActionRegistration(
            identifier: "servergroup.delete",
            title: "Delete Server Group",
            keybinding: "d",
            viewModes: [.serverGroups],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteServerGroup(screen: screen)
            },
            description: "Delete the selected server group",
            requiresConfirmation: true,
            category: .general
        ))

        // Register create server group action
        actions.append(ModuleActionRegistration(
            identifier: "servergroup.create",
            title: "Create Server Group",
            keybinding: "c",
            viewModes: [.serverGroups],
            handler: { [weak tui] screen in
                guard let tui = tui else { return }
                tui.changeView(to: .serverGroupCreate)
                tui.serverGroupCreateForm = ServerGroupCreateForm()
                tui.serverGroupCreateFormState = FormBuilderState(fields: tui.serverGroupCreateForm.buildFields(
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                ))
            },
            description: "Create a new server group",
            requiresConfirmation: false,
            category: .general
        ))

        return actions
    }
}

// MARK: - Server Group Action Implementations

extension ServerGroupsModule {
    /// Delete the selected server group
    ///
    /// Prompts for confirmation before deleting the server group from OpenStack.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteServerGroup(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .serverGroups else { return }

        let filteredServerGroups = FilterUtils.filterServerGroups(tui.cacheManager.cachedServerGroups, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredServerGroups.count else {
            tui.statusMessage = "No server group selected"
            return
        }

        let serverGroup = filteredServerGroups[tui.viewCoordinator.selectedIndex]
        let serverGroupName = serverGroup.name ?? "Unnamed server group"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(serverGroupName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Server group deletion cancelled"
            return
        }

        // Show deletion in progress
        tui.statusMessage = "Deleting server group '\(serverGroupName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            try await tui.client.deleteServerGroup(id: serverGroup.id)

            // Remove from cached server groups
            if let index = tui.cacheManager.cachedServerGroups.firstIndex(where: { $0.id == serverGroup.id }) {
                tui.cacheManager.cachedServerGroups.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredServerGroups.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Server group '\(serverGroupName)' deleted successfully"
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete server group '\(serverGroupName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 409 {
                    tui.statusMessage = "\(baseMsg): Server group is in use and cannot be deleted"
                } else if code == 404 {
                    tui.statusMessage = "\(baseMsg): Server group not found"
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
            tui.statusMessage = "Failed to delete server group '\(serverGroupName)': \(error.localizedDescription)"
        }
    }

    /// Submit server group creation from the server group create form
    ///
    /// Validates the form data and creates a new server group in OpenStack.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func submitServerGroupCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Validate the form
        let validationErrors = tui.serverGroupCreateForm.validate()
        if !validationErrors.isEmpty {
            tui.statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let name = tui.serverGroupCreateForm.getTrimmedServerGroupName()
        let policy = tui.serverGroupCreateForm.selectedPolicy.rawValue

        // Show creation in progress
        tui.statusMessage = "Creating server group '\(name)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            _ = try await tui.client.createServerGroup(name: name, policy: policy)

            tui.statusMessage = "Server group '\(name)' created successfully"

            // Refresh server group cache and return to list
            let _ = await DataProviderRegistry.shared.fetchData(for: "servergroups", priority: .onDemand, forceRefresh: true)
            tui.changeView(to: .serverGroups, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create server group '\(name)'"
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
            tui.statusMessage = "Failed to create server group '\(name)': \(error.localizedDescription)"
        }
    }
}
