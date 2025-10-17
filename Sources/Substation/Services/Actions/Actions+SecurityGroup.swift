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

// MARK: - Security Group Actions

@MainActor
extension Actions {

    internal func attachSecurityGroupToServers(screen: OpaquePointer?) async {
        guard currentView == .securityGroups else { return }

        let filteredSecurityGroups = FilterUtils.filterSecurityGroups(cachedSecurityGroups, query: searchQuery)
        guard selectedIndex < filteredSecurityGroups.count else {
            statusMessage = "No security group selected"
            return
        }

        let securityGroup = filteredSecurityGroups[selectedIndex]

        // Switch to security group server management view
        selectedResource = securityGroup
        // Load attached servers for this security group
        await loadAttachedServersForSecurityGroup(securityGroup)
        attachmentMode = .attach
        selectedServers.removeAll()
        tui.changeView(to: .securityGroupServerManagement, resetSelection: false)
        let groupName = securityGroup.name ?? "Unknown"
        statusMessage = "Managing security group '\(groupName)' - \(attachedServerIds.count) server(s) currently attached. Press TAB to toggle mode."
    }

    internal func manageSecurityGroupRules(screen: OpaquePointer?) async {
        guard currentView == .securityGroups else { return }

        let filteredSecurityGroups = FilterUtils.filterSecurityGroups(cachedSecurityGroups, query: searchQuery)
        guard selectedIndex < filteredSecurityGroups.count else {
            statusMessage = "No security group selected"
            return
        }

        let securityGroup = filteredSecurityGroups[selectedIndex]

        // Initialize the security group rule management form with all cached security groups
        tui.securityGroupRuleManagementForm = SecurityGroupRuleManagementForm(
            securityGroup: securityGroup,
            availableSecurityGroups: cachedSecurityGroups
        )

        // Navigate to the security group rule management view
        tui.changeView(to: .securityGroupRuleManagement, resetSelection: false)
        statusMessage = "Managing rules for security group '\(securityGroup.name ?? "Unknown")'"
    }

    internal func manageSecurityGroupToServers(screen: OpaquePointer?) async {
        guard currentView == .securityGroups else { return }
        let filteredGroups = FilterUtils.filterSecurityGroups(cachedSecurityGroups, query: searchQuery)
        guard selectedIndex < filteredGroups.count else {
            statusMessage = "No security group selected"
            return
        }
        let selectedSecurityGroup = filteredGroups[selectedIndex]
        // Store the selected security group for reference
        selectedResource = selectedSecurityGroup
        // Load attached servers for this security group
        await loadAttachedServersForSecurityGroup(selectedSecurityGroup)
        // Clear previous selections
        selectedServers.removeAll()
        // Reset to attach mode
        attachmentMode = .attach
        // Navigate to security group server management view
        tui.changeView(to: .securityGroupServerManagement, resetSelection: false)
        let groupName = selectedSecurityGroup.name ?? "Unknown"
        statusMessage = "Managing security group '\(groupName)' - \(attachedServerIds.count) server(s) currently attached. Press TAB to toggle mode."
    }

    internal func loadAttachedServersForSecurityGroup(_ securityGroup: SecurityGroup) async {
        attachedServerIds.removeAll()

        // Strategy: Check both server.securityGroups (if available) AND port security groups
        // This handles both cases: where Nova returns security groups, and where it doesn't

        for server in cachedServers {
            var serverHasGroup = false

            // Method 1: Check server's security groups (if present)
            if let serverSecurityGroups = server.securityGroups, !serverSecurityGroups.isEmpty {
                serverHasGroup = serverSecurityGroups.contains { serverSG in
                    serverSG.name == securityGroup.name || serverSG.name == securityGroup.id
                }
            }

            // Method 2: Check ports associated with this server (fallback if Method 1 didn't find match)
            if !serverHasGroup {
                let serverPorts = cachedPorts.filter { $0.deviceId == server.id }

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
                attachedServerIds.insert(server.id)
            }
        }
    }

    internal func applySecurityGroupChanges(screen: OpaquePointer?) async {
        guard let server = securityGroupForm.selectedServer else {
            statusMessage = "No server selected"
            return
        }

        let serverName = server.name ?? "Unnamed Server"
        var changeCount = 0
        var errorCount = 0

        // Apply additions with enhanced progress tracking and error handling
        let totalAdditions = securityGroupForm.pendingAdditions.count
        var currentAddition = 0

        for securityGroupID in securityGroupForm.pendingAdditions {
            currentAddition += 1
            if let securityGroup = securityGroupForm.availableSecurityGroups.first(where: { $0.id == securityGroupID }) {
                let operationId = "add-sg-\(securityGroup.id)-\(server.id)"
                let operationName = "Adding security group '\(securityGroup.name ?? "Unknown")' to \(serverName)"

                // Start progress tracking
                progressIndicator.startOperation(
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

                loadingStateManager.startLoading(
                    id: operationId,
                    type: .spinner,
                    message: "Adding security group (\(currentAddition)/\(totalAdditions))",
                    context: context,
                    estimatedDuration: 3.0
                )

                statusMessage = "Adding security group '\(securityGroup.name ?? "Unknown")' to \(serverName) (\(currentAddition)/\(totalAdditions))..."
                await tui.draw(screen: screen)

                do {
                    // Update progress to 50% during API call
                    progressIndicator.updateStageProgress(operationId: operationId, stageProgress: 0.5, message: "Sending API request...")

                    try await client.addSecurityGroup(serverID: server.id, securityGroupName: securityGroup.name ?? "Unknown")

                    // Complete successfully
                    progressIndicator.completeOperation(operationId: operationId, success: true, finalMessage: "Security group added successfully")
                    loadingStateManager.completeLoading(id: operationId, success: true)
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

                    let enhancedError = enhancedErrorHandler.processOpenStackError(error, context: errorContext)
                    statusMessage = enhancedError.userMessage

                    // Complete operation with failure
                    progressIndicator.completeOperation(operationId: operationId, success: false, finalMessage: enhancedError.userMessage)
                    loadingStateManager.completeLoading(id: operationId, success: false)
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

                    let enhancedError = enhancedErrorHandler.processError(error, context: errorContext)
                    statusMessage = enhancedError.userMessage

                    progressIndicator.completeOperation(operationId: operationId, success: false, finalMessage: enhancedError.userMessage)
                    loadingStateManager.completeLoading(id: operationId, success: false)
                    errorCount += 1

                    await tui.draw(screen: screen)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        // Apply removals with enhanced progress tracking and error handling
        let totalRemovals = securityGroupForm.pendingRemovals.count
        var currentRemoval = 0

        for securityGroupID in securityGroupForm.pendingRemovals {
            currentRemoval += 1
            if let securityGroup = securityGroupForm.serverSecurityGroups.first(where: { $0.id == securityGroupID }) {
                let operationId = "remove-sg-\(securityGroup.id)-\(server.id)"
                let operationName = "Removing security group '\(securityGroup.name ?? "Unknown")' from \(serverName)"

                // Start progress tracking
                progressIndicator.startOperation(
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

                loadingStateManager.startLoading(
                    id: operationId,
                    type: .spinner,
                    message: "Removing security group (\(currentRemoval)/\(totalRemovals))",
                    context: context,
                    estimatedDuration: 2.0
                )

                statusMessage = "Removing security group '\(securityGroup.name ?? "Unknown")' from \(serverName) (\(currentRemoval)/\(totalRemovals))..."
                await tui.draw(screen: screen)

                do {
                    // Update progress to 50% during API call
                    progressIndicator.updateStageProgress(operationId: operationId, stageProgress: 0.5, message: "Sending removal request...")

                    try await client.removeSecurityGroup(serverID: server.id, securityGroupName: securityGroup.name ?? "Unknown")

                    // Complete successfully
                    progressIndicator.completeOperation(operationId: operationId, success: true, finalMessage: "Security group removed successfully")
                    loadingStateManager.completeLoading(id: operationId, success: true)
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

                    let enhancedError = enhancedErrorHandler.processOpenStackError(error, context: errorContext)
                    statusMessage = enhancedError.userMessage

                    // Complete operation with failure
                    progressIndicator.completeOperation(operationId: operationId, success: false, finalMessage: enhancedError.userMessage)
                    loadingStateManager.completeLoading(id: operationId, success: false)
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

                    let enhancedError = enhancedErrorHandler.processError(error, context: errorContext)
                    statusMessage = enhancedError.userMessage

                    progressIndicator.completeOperation(operationId: operationId, success: false, finalMessage: enhancedError.userMessage)
                    loadingStateManager.completeLoading(id: operationId, success: false)
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
            statusMessage = message

            // Clear pending changes
            securityGroupForm.pendingAdditions.removeAll()
            securityGroupForm.pendingRemovals.removeAll()

            // Refresh security groups
            do {
                securityGroupForm.serverSecurityGroups = try await client.getServerSecurityGroups(serverID: server.id)
            } catch {
                statusMessage = message + " - Warning: Failed to refresh security groups"
            }
        } else if errorCount > 0 {
            statusMessage = "All \(errorCount) security group operations failed"
        } else {
            statusMessage = "No changes to apply"
        }
    }
}
