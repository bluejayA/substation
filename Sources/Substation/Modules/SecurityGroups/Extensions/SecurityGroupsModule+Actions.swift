// Sources/Substation/Modules/SecurityGroups/SecurityGroupsModule+Actions.swift
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

extension SecurityGroupsModule {
    /// Register all security group actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Manage server attachments for security groups
    /// - Manage security group rules
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register attach to servers action
        actions.append(ModuleActionRegistration(
            identifier: "securitygroup.manage_servers",
            title: "Manage Server Attachments",
            keybinding: "a",
            viewModes: [.securityGroups],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.manageSecurityGroupToServers(screen: screen)
            },
            description: "Attach or detach security group to/from servers",
            requiresConfirmation: false,
            category: .security
        ))

        // Register manage rules action
        actions.append(ModuleActionRegistration(
            identifier: "securitygroup.manage_rules",
            title: "Manage Rules",
            keybinding: "r",
            viewModes: [.securityGroups],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.manageSecurityGroupRules(screen: screen)
            },
            description: "Create, edit, and delete security group rules",
            requiresConfirmation: false,
            category: .security
        ))

        return actions
    }
}

// MARK: - Security Group Action Implementations

extension SecurityGroupsModule {
    /// Manage security group attachment to servers
    ///
    /// Opens the server management view to attach or detach a security group
    /// from servers. Shows currently attached servers and allows bulk operations.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func manageSecurityGroupToServers(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .securityGroups else { return }

        let filteredGroups = FilterUtils.filterSecurityGroups(
            tui.cacheManager.cachedSecurityGroups,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredGroups.count else {
            tui.statusMessage = "No security group selected"
            return
        }

        let selectedSecurityGroup = filteredGroups[tui.viewCoordinator.selectedIndex]

        // Store the selected security group for reference
        tui.viewCoordinator.selectedResource = selectedSecurityGroup

        // Load attached servers for this security group
        await loadAttachedServersForSecurityGroup(selectedSecurityGroup)

        // Clear previous selections
        tui.selectionManager.selectedServers.removeAll()

        // Reset to attach mode
        tui.selectionManager.attachmentMode = .attach

        // Navigate to security group server management view
        tui.changeView(to: .securityGroupServerManagement, resetSelection: false)

        let groupName = selectedSecurityGroup.name ?? "Unknown"
        tui.statusMessage = "Managing security group '\(groupName)' - \(tui.selectionManager.attachedServerIds.count) server(s) currently attached. Press TAB to toggle mode."
    }

    /// Manage security group rules
    ///
    /// Opens the rule management view to create, edit, and delete
    /// security group rules for the selected security group.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func manageSecurityGroupRules(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .securityGroups else { return }

        let filteredSecurityGroups = FilterUtils.filterSecurityGroups(
            tui.cacheManager.cachedSecurityGroups,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredSecurityGroups.count else {
            tui.statusMessage = "No security group selected"
            return
        }

        let securityGroup = filteredSecurityGroups[tui.viewCoordinator.selectedIndex]

        // Initialize the security group rule management form with all cached security groups
        tui.securityGroupRuleManagementForm = SecurityGroupRuleManagementForm(
            securityGroup: securityGroup,
            availableSecurityGroups: tui.cacheManager.cachedSecurityGroups
        )

        // Navigate to the security group rule management view
        tui.changeView(to: .securityGroupRuleManagement, resetSelection: false)
        tui.statusMessage = "Managing rules for security group '\(securityGroup.name ?? "Unknown")'"
    }

    /// Load servers that have the security group attached
    ///
    /// Checks both server.securityGroups (if available) and port security groups
    /// to find all servers that have the specified security group attached.
    ///
    /// - Parameter securityGroup: The security group to check attachments for
    internal func loadAttachedServersForSecurityGroup(_ securityGroup: SecurityGroup) async {
        guard let tui = tui else { return }

        tui.selectionManager.attachedServerIds.removeAll()

        // Strategy: Check both server.securityGroups (if available) AND port security groups
        // This handles both cases: where Nova returns security groups, and where it doesn't

        for server in tui.cacheManager.cachedServers {
            var serverHasGroup = false

            // Method 1: Check server's security groups (if present)
            if let serverSecurityGroups = server.securityGroups, !serverSecurityGroups.isEmpty {
                serverHasGroup = serverSecurityGroups.contains { serverSG in
                    serverSG.name == securityGroup.name || serverSG.name == securityGroup.id
                }
            }

            // Method 2: Check ports associated with this server (fallback if Method 1 didn't find match)
            if !serverHasGroup {
                let serverPorts = tui.cacheManager.cachedPorts.filter { $0.deviceId == server.id }

                for port in serverPorts {
                    if let portSecurityGroups = port.securityGroups {
                        if portSecurityGroups.contains(securityGroup.id) ||
                           (securityGroup.name.map { name in portSecurityGroups.contains(name) } ?? false) {
                            serverHasGroup = true
                            break
                        }
                    }
                }
            }

            if serverHasGroup {
                tui.selectionManager.attachedServerIds.insert(server.id)
            }
        }
    }

    /// Apply security group changes to a server
    ///
    /// Processes pending additions and removals of security groups for a server,
    /// with enhanced progress tracking and error handling.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func applySecurityGroupChanges(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard let server = tui.securityGroupForm.selectedServer else {
            tui.statusMessage = "No server selected"
            return
        }

        let serverName = server.name ?? "Unnamed Server"
        var changeCount = 0
        var errorCount = 0

        // Apply additions with enhanced progress tracking and error handling
        let totalAdditions = tui.securityGroupForm.pendingAdditions.count
        var currentAddition = 0

        for securityGroupID in tui.securityGroupForm.pendingAdditions {
            currentAddition += 1
            if let securityGroup = tui.securityGroupForm.availableSecurityGroups.first(where: { $0.id == securityGroupID }) {
                let operationId = "add-sg-\(securityGroup.id)-\(server.id)"
                let operationName = "Adding security group '\(securityGroup.name ?? "Unknown")' to \(serverName)"

                // Start progress tracking
                tui.progressIndicator.startOperation(
                    id: operationId,
                    type: .batchOperation(itemCount: 1),
                    name: operationName,
                    isCancellable: false
                )

                // Update loading state
                let context = LoadingContext(
                    viewId: "security-group-management",
                    operation: "add_security_group",
                    resourceType: "server",
                    expectedItems: 1,
                    priority: .normal
                )

                tui.loadingStateManager.startLoading(
                    id: operationId,
                    type: .spinner,
                    message: "Adding security group (\(currentAddition)/\(totalAdditions))",
                    context: context,
                    estimatedDuration: 3.0
                )

                tui.statusMessage = "Adding security group '\(securityGroup.name ?? "Unknown")' to \(serverName) (\(currentAddition)/\(totalAdditions))..."
                await tui.draw(screen: screen)

                do {
                    // Update progress to 50% during API call
                    tui.progressIndicator.updateStageProgress(operationId: operationId, stageProgress: 0.5, message: "Sending API request...")

                    try await tui.client.addSecurityGroup(serverID: server.id, securityGroupName: securityGroup.name ?? "Unknown")

                    // Complete successfully
                    tui.progressIndicator.completeOperation(operationId: operationId, success: true, finalMessage: "Security group added successfully")
                    tui.loadingStateManager.completeLoading(id: operationId, success: true)
                    changeCount += 1

                } catch let error as OpenStackError {
                    // Enhanced error handling with user-friendly messages
                    let errorContext = ErrorContext(
                        operation: "add_security_group",
                        resourceType: "server",
                        resourceId: server.id,
                        view: "security_group_management",
                        additionalInfo: ["security_group": securityGroup.name ?? "Unknown"]
                    )

                    let enhancedError = tui.enhancedErrorHandler.processOpenStackError(error, context: errorContext)
                    tui.statusMessage = enhancedError.userMessage

                    // Complete operation with failure
                    tui.progressIndicator.completeOperation(operationId: operationId, success: false, finalMessage: enhancedError.userMessage)
                    tui.loadingStateManager.completeLoading(id: operationId, success: false)
                    errorCount += 1

                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second pause for error

                } catch {
                    // Handle other errors
                    let errorContext = ErrorContext(
                        operation: "add_security_group",
                        resourceType: "server",
                        resourceId: server.id,
                        view: "security_group_management"
                    )

                    let enhancedError = tui.enhancedErrorHandler.processError(error, context: errorContext)
                    tui.statusMessage = enhancedError.userMessage

                    tui.progressIndicator.completeOperation(operationId: operationId, success: false, finalMessage: enhancedError.userMessage)
                    tui.loadingStateManager.completeLoading(id: operationId, success: false)
                    errorCount += 1

                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        // Apply removals with enhanced progress tracking and error handling
        let totalRemovals = tui.securityGroupForm.pendingRemovals.count
        var currentRemoval = 0

        for securityGroupID in tui.securityGroupForm.pendingRemovals {
            currentRemoval += 1
            if let securityGroup = tui.securityGroupForm.serverSecurityGroups.first(where: { $0.id == securityGroupID }) {
                let operationId = "remove-sg-\(securityGroup.id)-\(server.id)"
                let operationName = "Removing security group '\(securityGroup.name ?? "Unknown")' from \(serverName)"

                // Start progress tracking
                tui.progressIndicator.startOperation(
                    id: operationId,
                    type: .batchOperation(itemCount: 1),
                    name: operationName,
                    isCancellable: false
                )

                // Update loading state
                let context = LoadingContext(
                    viewId: "security-group-management",
                    operation: "remove_security_group",
                    resourceType: "server",
                    expectedItems: 1,
                    priority: .normal
                )

                tui.loadingStateManager.startLoading(
                    id: operationId,
                    type: .spinner,
                    message: "Removing security group (\(currentRemoval)/\(totalRemovals))",
                    context: context,
                    estimatedDuration: 2.0
                )

                tui.statusMessage = "Removing security group '\(securityGroup.name ?? "Unknown")' from \(serverName) (\(currentRemoval)/\(totalRemovals))..."
                await tui.draw(screen: screen)

                do {
                    // Update progress to 50% during API call
                    tui.progressIndicator.updateStageProgress(operationId: operationId, stageProgress: 0.5, message: "Sending removal request...")

                    try await tui.client.removeSecurityGroup(serverID: server.id, securityGroupName: securityGroup.name ?? "Unknown")

                    // Complete successfully
                    tui.progressIndicator.completeOperation(operationId: operationId, success: true, finalMessage: "Security group removed successfully")
                    tui.loadingStateManager.completeLoading(id: operationId, success: true)
                    changeCount += 1
                } catch let error as OpenStackError {
                    // Enhanced error handling with user-friendly messages
                    let errorContext = ErrorContext(
                        operation: "remove_security_group",
                        resourceType: "server",
                        resourceId: server.id,
                        view: "security_group_management",
                        additionalInfo: ["security_group": securityGroup.name ?? "Unknown"]
                    )

                    let enhancedError = tui.enhancedErrorHandler.processOpenStackError(error, context: errorContext)
                    tui.statusMessage = enhancedError.userMessage

                    // Complete operation with failure
                    tui.progressIndicator.completeOperation(operationId: operationId, success: false, finalMessage: enhancedError.userMessage)
                    tui.loadingStateManager.completeLoading(id: operationId, success: false)
                    errorCount += 1

                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)

                } catch {
                    // Handle other errors
                    let errorContext = ErrorContext(
                        operation: "remove_security_group",
                        resourceType: "server",
                        resourceId: server.id,
                        view: "security_group_management"
                    )

                    let enhancedError = tui.enhancedErrorHandler.processError(error, context: errorContext)
                    tui.statusMessage = enhancedError.userMessage

                    tui.progressIndicator.completeOperation(operationId: operationId, success: false, finalMessage: enhancedError.userMessage)
                    tui.loadingStateManager.completeLoading(id: operationId, success: false)
                    errorCount += 1

                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        // Summary and refresh
        if changeCount > 0 {
            var message = "Applied \(changeCount) security group changes"
            if errorCount > 0 {
                message += " (with \(errorCount) errors)"
            }
            tui.statusMessage = message

            // Clear pending changes
            tui.securityGroupForm.pendingAdditions.removeAll()
            tui.securityGroupForm.pendingRemovals.removeAll()

            // Refresh security groups
            do {
                tui.securityGroupForm.serverSecurityGroups = try await tui.client.getServerSecurityGroups(serverID: server.id)
            } catch {
                tui.statusMessage = message + " - Warning: Failed to refresh security groups"
            }
        } else if errorCount > 0 {
            tui.statusMessage = "All \(errorCount) security group operations failed"
        } else {
            tui.statusMessage = "No changes to apply"
        }
    }

    // MARK: - Security Group CRUD Operations

    /// Submit security group creation from the create form
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func submitSecurityGroupCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Validate the form
        let validation = tui.securityGroupCreateForm.validateForm()
        if !validation.isValid {
            tui.statusMessage = "Validation errors: \(validation.errors.joined(separator: "; "))"
            return
        }

        let securityGroupName = tui.securityGroupCreateForm.securityGroupName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show creation in progress
        tui.statusMessage = "Creating security group '\(securityGroupName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            let description = tui.securityGroupCreateForm.securityGroupDescription.trimmingCharacters(in: .whitespacesAndNewlines)

            _ = try await tui.client.createSecurityGroup(
                name: securityGroupName,
                description: description.isEmpty ? nil : description
            )

            tui.statusMessage = "Security group '\(securityGroupName)' created successfully"

            tui.refreshAfterOperation()
            tui.changeView(to: .securityGroups, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create security group '\(securityGroupName)'"
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
            tui.statusMessage = "Failed to create security group '\(securityGroupName)': \(error.localizedDescription)"
        }
    }

    /// Delete the currently selected security group
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func deleteSecurityGroup(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .securityGroups else { return }

        let filteredGroups = FilterUtils.filterSecurityGroups(tui.cacheManager.cachedSecurityGroups, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredGroups.count else {
            tui.statusMessage = "No security group selected"
            return
        }

        let securityGroup = filteredGroups[tui.viewCoordinator.selectedIndex]
        let securityGroupName = securityGroup.name ?? "Unknown"

        guard await ViewUtils.confirmDelete(securityGroupName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Security group deletion cancelled"
            return
        }

        tui.statusMessage = "Deleting security group '\(securityGroupName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            try await tui.client.deleteSecurityGroup(id: securityGroup.id)

            if let index = tui.cacheManager.cachedSecurityGroups.firstIndex(where: { $0.id == securityGroup.id }) {
                tui.cacheManager.cachedSecurityGroups.remove(at: index)
            }

            if tui.viewCoordinator.selectedIndex >= filteredGroups.count && tui.viewCoordinator.selectedIndex > 0 {
                tui.viewCoordinator.selectedIndex = filteredGroups.count - 1
            }

            tui.statusMessage = "Security group '\(securityGroupName)' deleted successfully"
            Logger.shared.logInfo("Deleted security group: \(securityGroupName)")

            // Trigger accelerated refresh to show state transitions
            tui.refreshAfterOperation()

        } catch {
            tui.statusMessage = "Failed to delete security group: \(error.localizedDescription)"
            Logger.shared.logError("Failed to delete security group '\(securityGroupName)': \(error.localizedDescription)")
        }
    }

    /// Create a new security group rule
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func createSecurityGroupRule(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard var form = tui.securityGroupRuleManagementForm else { return }

        let validation = form.validateCurrentForm()
        guard validation.isValid else {
            tui.statusMessage = "Validation failed: \(validation.errors.first ?? "Unknown error")"
            return
        }

        let ruleData = form.getRuleCreationData()

        tui.statusMessage = "Creating security group rule(s)..."
        await tui.draw(screen: screen)

        do {
            if form.ruleCreateForm.remoteType == .securityGroup && !form.ruleCreateForm.selectedRemoteSecurityGroups.isEmpty {
                for securityGroupId in form.ruleCreateForm.selectedRemoteSecurityGroups {
                    let _ = try await tui.client.createSecurityGroupRule(
                        securityGroupId: form.securityGroup.id,
                        direction: ruleData.direction,
                        protocol: ruleData.protocol,
                        ethertype: ruleData.ethertype,
                        portRangeMin: ruleData.portMin,
                        portRangeMax: ruleData.portMax,
                        remoteIpPrefix: nil,
                        remoteGroupId: securityGroupId
                    )
                }
                tui.statusMessage = "Created \(form.ruleCreateForm.selectedRemoteSecurityGroups.count) security group rule(s) successfully"
            } else {
                let _ = try await tui.client.createSecurityGroupRule(
                    securityGroupId: form.securityGroup.id,
                    direction: ruleData.direction,
                    protocol: ruleData.protocol,
                    ethertype: ruleData.ethertype,
                    portRangeMin: ruleData.portMin,
                    portRangeMax: ruleData.portMax,
                    remoteIpPrefix: ruleData.remoteIPPrefix,
                    remoteGroupId: ruleData.remoteGroupID
                )
                tui.statusMessage = "Security group rule created successfully"
            }

            let updatedSecurityGroup = try await tui.client.getSecurityGroup(id: form.securityGroup.id)
            form.updateSecurityGroup(updatedSecurityGroup)
            form.returnToListMode()
            tui.securityGroupRuleManagementForm = form

            if let index = tui.cacheManager.cachedSecurityGroups.firstIndex(where: { $0.id == form.securityGroup.id }) {
                tui.cacheManager.cachedSecurityGroups[index] = updatedSecurityGroup
            }

            // Trigger accelerated refresh to show state transitions
            tui.refreshAfterOperation()
            await tui.draw(screen: screen)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create security group rule"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response"
            case .httpError(let code, let message):
                if let message = message {
                    tui.statusMessage = "\(baseMsg): \(message)"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let underlyingError):
                tui.statusMessage = "\(baseMsg): Network error - \(underlyingError.localizedDescription)"
            case .decodingError(let underlyingError):
                tui.statusMessage = "\(baseMsg): Data parsing error - \(underlyingError.localizedDescription)"
            case .encodingError(let underlyingError):
                tui.statusMessage = "\(baseMsg): Data encoding error - \(underlyingError.localizedDescription)"
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
            tui.statusMessage = "Failed to create security group rule: \(error.localizedDescription)"
        }
    }

    /// Update a security group rule (delete old and create new)
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func updateSecurityGroupRule(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.securityGroupRuleManagementForm != nil else { return }

        await deleteSecurityGroupRule(screen: screen, createNew: true)
    }

    /// Delete a security group rule
    /// - Parameters:
    ///   - screen: The ncurses screen pointer for UI operations
    ///   - createNew: Whether to create a new rule after deletion (for updates)
    internal func deleteSecurityGroupRule(screen: OpaquePointer?, createNew: Bool = false) async {
        guard let tui = tui else { return }
        guard var form = tui.securityGroupRuleManagementForm else { return }
        guard let rule = form.getSelectedRule() else {
            tui.statusMessage = "No security group rule selected"
            return
        }

        if !createNew {
            guard await ViewUtils.confirmDelete("security group rule", screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
                tui.statusMessage = "Security group rule deletion cancelled"
                return
            }
        }

        tui.statusMessage = createNew ? "Updating security group rule..." : "Deleting security group rule..."
        await tui.draw(screen: screen)

        do {
            try await tui.client.deleteSecurityGroupRule(id: rule.id)

            if createNew {
                await createSecurityGroupRule(screen: screen)
                return
            }

            let updatedSecurityGroup = try await tui.client.getSecurityGroup(id: form.securityGroup.id)
            form.updateSecurityGroup(updatedSecurityGroup)
            tui.securityGroupRuleManagementForm = form

            if let index = tui.cacheManager.cachedSecurityGroups.firstIndex(where: { $0.id == form.securityGroup.id }) {
                tui.cacheManager.cachedSecurityGroups[index] = updatedSecurityGroup
            }

            tui.statusMessage = "Security group rule deleted successfully"

            // Trigger accelerated refresh to show state transitions
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = createNew ? "Failed to update security group rule" : "Failed to delete security group rule"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response"
            case .httpError(let code, let message):
                if let message = message {
                    tui.statusMessage = "\(baseMsg): \(message)"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let description):
                tui.statusMessage = "\(baseMsg): Network error - \(description)"
            case .decodingError(let description):
                tui.statusMessage = "\(baseMsg): Decoding error - \(description)"
            case .encodingError(let description):
                tui.statusMessage = "\(baseMsg): Encoding error - \(description)"
            case .configurationError(let description):
                tui.statusMessage = "\(baseMsg): Configuration error - \(description)"
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
            let baseMsg = createNew ? "update" : "delete"
            tui.statusMessage = "Failed to \(baseMsg) security group rule: \(error.localizedDescription)"
        }
    }

    // MARK: - Batch Security Group Operations

    /// Perform batch security group attachment to selected servers
    ///
    /// Attaches the currently selected security group to all servers that have been
    /// selected in the server attachment view. Provides progress feedback and
    /// handles errors for individual server attachments.
    ///
    /// This method:
    /// - Validates that servers and a security group are selected
    /// - Iterates through selected servers and attaches the security group
    /// - Logs success and failure for each operation
    /// - Updates the status message with summary results
    /// - Clears selections and returns to security groups view
    /// - Triggers a data refresh to reflect changes
    internal func performBatchSecurityGroupAttachment() async {
        guard let tui = tui else { return }

        guard !tui.selectionManager.selectedServers.isEmpty else {
            tui.statusMessage = "No servers selected for security group attachment"
            return
        }

        guard let selectedSecurityGroup = tui.viewCoordinator.selectedResource as? SecurityGroup else {
            tui.statusMessage = "No security group selected for attachment"
            return
        }

        let securityGroupName = selectedSecurityGroup.name ?? "Unknown"
        let serverCount = tui.selectionManager.selectedServers.count

        tui.statusMessage = "Attaching security group '\(securityGroupName)' to \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        var successCount = 0
        var errorCount = 0
        var errors: [String] = []

        for serverId in tui.selectionManager.selectedServers {
            // Find the server object
            guard let server = tui.cacheManager.cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                errors.append("Server with ID \(serverId) not found")
                continue
            }

            do {
                // Attach security group to server
                try await tui.client.addSecurityGroup(serverID: serverId, securityGroupName: selectedSecurityGroup.name ?? selectedSecurityGroup.id)
                successCount += 1
                Logger.shared.logUserAction("security_group_attached_to_server", details: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "securityGroupId": selectedSecurityGroup.id,
                    "securityGroupName": securityGroupName
                ])
            } catch {
                errorCount += 1
                let serverName = server.name ?? "Unknown"
                let errorMessage = "Failed to attach security group to '\(serverName)': \(error.localizedDescription)"
                errors.append(errorMessage)
                Logger.shared.logError("Failed to attach security group to server", error: error, context: [
                    "serverId": serverId,
                    "serverName": serverName,
                    "securityGroupId": selectedSecurityGroup.id,
                    "securityGroupName": securityGroupName
                ])
            }
        }

        // Update status message with results
        if errorCount == 0 {
            tui.statusMessage = "Successfully attached security group '\(securityGroupName)' to \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            tui.statusMessage = "Failed to attach security group to any servers. See logs for details."
        } else {
            tui.statusMessage = "Attached security group to \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed. See logs for details."
        }

        // Clear selections and return to security groups view
        tui.selectionManager.selectedServers.removeAll()
        tui.changeView(to: .securityGroups, resetSelection: false)

        // Refresh server data to show updated security group attachments
        tui.refreshAfterOperation()
    }

    /// Perform enhanced security group management with attach/detach modes
    ///
    /// Performs batch security group attachment or detachment operations based on
    /// the current attachment mode. Supports toggling between attach and detach
    /// modes for flexible security group management.
    ///
    /// This method:
    /// - Validates that servers and a security group are selected
    /// - Determines the operation based on attachmentMode (attach/detach)
    /// - Iterates through selected servers and performs the operation
    /// - Logs results and errors for each operation
    /// - Updates the status message with summary results
    /// - Clears selections and returns to security groups view
    /// - Triggers a data refresh to reflect changes
    internal func performEnhancedSecurityGroupManagement() async {
        guard let tui = tui else { return }

        guard !tui.selectionManager.selectedServers.isEmpty else {
            tui.statusMessage = "No servers selected for security group \(tui.selectionManager.attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }
        guard let selectedSecurityGroup = tui.viewCoordinator.selectedResource as? SecurityGroup else {
            tui.statusMessage = "No security group selected for \(tui.selectionManager.attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }

        let groupName = selectedSecurityGroup.name ?? "Unknown"
        let serverCount = tui.selectionManager.selectedServers.count
        let action = tui.selectionManager.attachmentMode == .attach ? "attaching" : "detaching"
        tui.statusMessage = "\(action.capitalized) security group '\(groupName)' \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        var successCount = 0
        var errorCount = 0

        for serverId in tui.selectionManager.selectedServers {
            guard let server = tui.cacheManager.cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                continue
            }

            do {
                if tui.selectionManager.attachmentMode == .attach {
                    try await tui.client.addSecurityGroup(serverID: serverId, securityGroupName: selectedSecurityGroup.name ?? selectedSecurityGroup.id)
                } else {
                    try await tui.client.removeSecurityGroup(serverID: serverId, securityGroupName: selectedSecurityGroup.name ?? selectedSecurityGroup.id)
                }
                successCount += 1
            } catch {
                errorCount += 1
                Logger.shared.logError("Failed to \(tui.selectionManager.attachmentMode == .attach ? "attach" : "detach") security group", error: error, context: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "securityGroupId": selectedSecurityGroup.id,
                    "securityGroupName": groupName
                ])
            }
        }

        if errorCount == 0 {
            tui.statusMessage = "Successfully \(tui.selectionManager.attachmentMode == .attach ? "attached" : "detached") security group '\(groupName)' \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            tui.statusMessage = "Failed to \(tui.selectionManager.attachmentMode == .attach ? "attach" : "detach") security group \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") any servers"
        } else {
            tui.statusMessage = "\(tui.selectionManager.attachmentMode == .attach ? "Attached" : "Detached") security group \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed"
        }

        tui.selectionManager.selectedServers.removeAll()
        tui.changeView(to: .securityGroups, resetSelection: false)
        tui.refreshAfterOperation()
    }
}
