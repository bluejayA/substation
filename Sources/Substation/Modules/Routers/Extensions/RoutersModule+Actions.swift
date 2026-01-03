// Sources/Substation/Modules/Routers/RoutersModule+Actions.swift
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

extension RoutersModule {
    /// Register all router actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Subnet router attachment management
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register subnet router attachment action
        actions.append(ModuleActionRegistration(
            identifier: "router.manage_subnet_attachment",
            title: "Manage Subnet Router Attachment",
            keybinding: "a",
            viewModes: [.subnets],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.manageSubnetRouterAttachment(screen: screen)
            },
            description: "Attach or detach a router to/from the selected subnet",
            requiresConfirmation: false,
            category: .network
        ))

        // Register delete router action
        actions.append(ModuleActionRegistration(
            identifier: "router.delete",
            title: "Delete Router",
            keybinding: "d",
            viewModes: [.routers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteRouter(screen: screen)
            },
            description: "Delete the selected router",
            requiresConfirmation: true,
            category: .network
        ))

        // Register create router action
        actions.append(ModuleActionRegistration(
            identifier: "router.create",
            title: "Create Router",
            keybinding: "c",
            viewModes: [.routers],
            handler: { [weak tui] screen in
                guard let tui = tui else { return }
                tui.changeView(to: .routerCreate)
                tui.routerCreateForm = RouterCreateForm()
                // Get availability zones from ServersModule via ModuleRegistry
                var availabilityZones: [String] = []
                if let serversModule = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
                    availabilityZones = serversModule.availabilityZones
                }
                // Get external networks from NetworksModule via ModuleRegistry
                var externalNetworks: [Network] = []
                if let networksModule = ModuleRegistry.shared.module(for: "networks") as? NetworksModule {
                    externalNetworks = networksModule.externalNetworks
                }
                tui.routerCreateFormState = FormBuilderState(fields: tui.routerCreateForm.buildFields(
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: []),
                    availabilityZones: availabilityZones,
                    externalNetworks: externalNetworks
                ))
            },
            description: "Create a new router",
            requiresConfirmation: false,
            category: .network
        ))

        // Register edit router action
        actions.append(ModuleActionRegistration(
            identifier: "router.edit",
            title: "Edit Router",
            keybinding: "E",
            viewModes: [.routers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.editRouter(screen: screen)
            },
            description: "Edit the selected router",
            requiresConfirmation: false,
            category: .network
        ))

        // Register manage subnet interfaces action
        actions.append(ModuleActionRegistration(
            identifier: "router.manage_subnets",
            title: "Manage Subnet Interfaces",
            keybinding: "S",
            viewModes: [.routers],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.manageRouterSubnetInterfaces(screen: screen)
            },
            description: "Attach or detach subnet interfaces to/from the router",
            requiresConfirmation: false,
            category: .network
        ))

        return actions
    }
}

// MARK: - Router Action Implementations

extension RoutersModule {
    /// Manage subnet to router attachment
    ///
    /// Opens the router management view to attach or detach a subnet
    /// to a router. This action is available from the subnets view.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func manageSubnetRouterAttachment(screen: OpaquePointer?) async {
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
        let subnetName = subnet.name ?? "Unnamed Subnet"

        // Switch to subnet router management view
        tui.viewCoordinator.selectedResource = subnet
        tui.selectionManager.attachmentMode = .attach

        // Load attached routers for filtering
        await loadAttachedRoutersForSubnet(subnet)

        tui.changeView(to: .subnetRouterManagement, resetSelection: false)
        tui.statusMessage = "Select a router to attach subnet '\(subnetName)'"
    }

    /// Load the routers that are currently attached to the subnet
    ///
    /// Uses cached router interface data to find attachments without
    /// making additional API calls.
    ///
    /// - Parameter subnet: The subnet to check for attached routers
    internal func loadAttachedRoutersForSubnet(_ subnet: Subnet) async {
        guard let tui = tui else { return }

        tui.selectionManager.attachedRouterIds.removeAll()

        Logger.shared.logInfo(
            "=== Loading attached routers for subnet \(subnet.name ?? subnet.id) (\(subnet.id)) ===",
            context: [:]
        )
        Logger.shared.logInfo(
            "Available routers: \(tui.cacheManager.cachedRouters.count)",
            context: [:]
        )

        // Use cached router interface data to find attachments
        for router in tui.cacheManager.cachedRouters {
            if let interfaces = router.interfaces {
                Logger.shared.logInfo(
                    "Router \(router.name ?? router.id) has \(interfaces.count) cached interfaces",
                    context: [:]
                )

                for interface in interfaces {
                    if interface.subnetId == subnet.id {
                        tui.selectionManager.attachedRouterIds.insert(router.id)
                        Logger.shared.logInfo(
                            "Found router \(router.name ?? router.id) attached to subnet \(subnet.name ?? subnet.id) via cached interface data",
                            context: [:]
                        )
                        break
                    }
                }
            } else {
                Logger.shared.logInfo(
                    "Router \(router.name ?? router.id) has no cached interface data",
                    context: [:]
                )
            }
        }

        Logger.shared.logInfo(
            "=== Final result: Subnet \(subnet.name ?? subnet.id) has \(tui.selectionManager.attachedRouterIds.count) attached routers: \(Array(tui.selectionManager.attachedRouterIds)) ===",
            context: [:]
        )
    }

    // MARK: - Router CRUD Operations

    /// Delete the selected router
    ///
    /// Prompts for confirmation before deleting the router from OpenStack.
    /// Automatically cleans up interfaces and gateway before deletion.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteRouter(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .routers else { return }

        let filteredRouters = FilterUtils.filterRouters(tui.cacheManager.cachedRouters, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredRouters.count else {
            tui.statusMessage = "No router selected"
            return
        }

        let router = filteredRouters[tui.viewCoordinator.selectedIndex]
        let routerName = router.name ?? "Unnamed router"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(routerName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Router deletion cancelled"
            return
        }

        // Create background operation for router deletion with dependency cleanup
        let interfaceCount = router.interfaces?.count ?? 0
        let hasGateway = router.externalGatewayInfo != nil
        let totalSteps = interfaceCount + (hasGateway ? 1 : 0) + 1

        let operation = SwiftBackgroundOperation(
            type: .bulkDelete,
            resourceType: "router",
            itemsTotal: totalSteps
        )
        tui.swiftBackgroundOps.addOperation(operation)

        // Show status and navigate to operations view
        tui.statusMessage = "Started cleanup and deletion of router '\(routerName)'"
        tui.changeView(to: .swiftBackgroundOperations, resetSelection: false)

        // Launch background cleanup task
        Task { @MainActor [weak self, weak operation] in
            guard let self = self, let tui = self.tui, let operation = operation else { return }
            operation.status = .running
            var completedSteps = 0

            do {
                // Step 0: Fetch fresh router details to get all current interfaces
                Logger.shared.logInfo("Fetching fresh router details for cleanup")
                let freshRouter = try await tui.client.getRouter(id: router.id, forceRefresh: true)

                // Update total steps based on actual interface count
                let actualInterfaceCount = freshRouter.interfaces?.count ?? 0
                let actualHasGateway = freshRouter.externalGatewayInfo != nil
                let actualTotalSteps = actualInterfaceCount + (actualHasGateway ? 1 : 0) + 1
                operation.itemsTotal = actualTotalSteps

                Logger.shared.logInfo("Router cleanup details", context: [
                    "routerId": router.id,
                    "interfaceCount": actualInterfaceCount,
                    "hasGateway": actualHasGateway,
                    "totalSteps": actualTotalSteps
                ])

                // Step 1: Remove all router interfaces (subnet detachments)
                if let interfaces = freshRouter.interfaces, !interfaces.isEmpty {
                    Logger.shared.logInfo("Removing \(interfaces.count) router interfaces")
                    for (index, interface) in interfaces.enumerated() {
                        Logger.shared.logInfo("Processing interface \(index + 1)/\(interfaces.count)", context: [
                            "subnetId": interface.subnetId ?? "nil",
                            "portId": interface.portId ?? "nil",
                            "ipAddress": interface.ipAddress ?? "nil"
                        ])

                        if let portId = interface.portId {
                            try await tui.client.removeRouterInterface(routerId: router.id, portId: portId)
                            Logger.shared.logInfo("Removed router interface using port ID: \(portId)")
                        } else if let subnetId = interface.subnetId {
                            try await tui.client.removeRouterInterface(routerId: router.id, subnetId: subnetId)
                            Logger.shared.logInfo("Removed router interface using subnet ID: \(subnetId)")
                        } else {
                            Logger.shared.logWarning("Interface has neither port ID nor subnet ID, skipping")
                        }
                        completedSteps += 1
                        operation.itemsCompleted = completedSteps
                        operation.progress = Double(completedSteps) / Double(actualTotalSteps)
                    }
                } else {
                    Logger.shared.logInfo("No interfaces found on router")
                }

                // Step 2: Clear external gateway if present
                if freshRouter.externalGatewayInfo != nil {
                    Logger.shared.logInfo("Clearing external gateway for router: \(router.id)")
                    let clearGatewayRequest = UpdateRouterRequest(
                        name: nil,
                        description: nil,
                        adminStateUp: nil,
                        externalGatewayInfo: nil,
                        routes: nil
                    )
                    _ = try await tui.client.updateRouter(id: router.id, request: clearGatewayRequest)
                    Logger.shared.logInfo("Cleared external gateway")
                    completedSteps += 1
                    operation.itemsCompleted = completedSteps
                    operation.progress = Double(completedSteps) / Double(actualTotalSteps)
                }

                // Step 3: Delete the router
                Logger.shared.logInfo("Deleting router: \(router.id)")
                try await tui.client.deleteRouter(id: router.id)
                completedSteps += 1
                operation.itemsCompleted = completedSteps
                operation.progress = 1.0

                // Mark operation as completed
                operation.markCompleted()

                // Refresh data
                await tui.dataManager.refreshAllData()

                Logger.shared.logInfo("Router '\(routerName)' deleted successfully with all dependencies cleaned up")

            } catch {
                Logger.shared.logError("Failed to delete router '\(routerName)': \(error)")
                operation.itemsFailed = totalSteps - completedSteps
                operation.markFailed(error: error.localizedDescription)

                // Refresh data even on failure to show current state
                await tui.dataManager.refreshAllData()
            }
        }
    }

    /// Submit router creation from the router create form
    ///
    /// Validates the form data and creates a new router in OpenStack.
    /// Updates the UI and refreshes the router cache after successful creation.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func submitRouterCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Get availability zones from ServersModule via ModuleRegistry
        var availabilityZones: [String] = []
        if let serversModule = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
            availabilityZones = serversModule.availabilityZones
        }
        // Get external networks from NetworksModule via ModuleRegistry
        var externalNetworks: [Network] = []
        if let networksModule = ModuleRegistry.shared.module(for: "networks") as? NetworksModule {
            externalNetworks = networksModule.externalNetworks
        }

        let errors = tui.routerCreateForm.validateForm(availabilityZones: availabilityZones, externalNetworks: externalNetworks)
        guard errors.isEmpty else {
            return
        }

        do {
            let externalNetworkId = tui.routerCreateForm.selectedExternalNetworkId
            let _ = try await tui.client.createRouter(
                name: tui.routerCreateForm.getTrimmedName(),
                description: tui.routerCreateForm.getTrimmedDescription().isEmpty ? nil : tui.routerCreateForm.getTrimmedDescription(),
                adminStateUp: true,
                externalGatewayInfo: externalNetworkId
            )

            Logger.shared.logInfo("Router '\(tui.routerCreateForm.getTrimmedName())' created successfully")

            // Immediately refresh routers cache for faster feedback
            let _ = await DataProviderRegistry.shared.fetchData(
                for: "routers",
                priority: .critical,
                forceRefresh: true
            )
            tui.resourceOperations.updateResourceCounts()
            tui.markNeedsRedraw()

            tui.statusMessage = "Router created successfully"
            tui.viewCoordinator.currentView = .routers
            tui.routerCreateForm = RouterCreateForm()
            tui.routerCreateFormState = FormBuilderState(fields: [])
            await tui.draw(screen: screen)
        } catch {
            Logger.shared.logError("Failed to create router '\(tui.routerCreateForm.getTrimmedName())': \(error.localizedDescription)")
            tui.statusMessage = "Error: \(error.localizedDescription)"
            await tui.draw(screen: screen)
        }
    }

    /// Open the edit form for the selected router
    ///
    /// Loads the selected router's current values into the edit form
    /// and navigates to the router edit view.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func editRouter(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .routers else { return }

        let filteredRouters = FilterUtils.filterRouters(tui.cacheManager.cachedRouters, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredRouters.count else {
            tui.statusMessage = "No router selected"
            return
        }

        let router = filteredRouters[tui.viewCoordinator.selectedIndex]
        let routerName = router.name ?? "Unnamed router"

        // Initialize the edit form with the selected router's values
        tui.routerEditForm = RouterEditForm(router: router)

        // Get external networks for the form
        let externalNetworks = tui.cacheManager.cachedNetworks.filter { $0.external == true }

        // Initialize FormBuilderState with form fields
        tui.routerEditFormState = FormBuilderState(
            fields: tui.routerEditForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: nil,
                externalNetworks: externalNetworks
            )
        )

        // Navigate to edit view
        tui.changeView(to: .routerEdit, resetSelection: false)
        tui.statusMessage = "Editing router '\(routerName)'"

        Logger.shared.logInfo("Opened edit form for router '\(routerName)'", context: [
            "routerId": router.id
        ])
    }

    /// Submit router edit from the router edit form
    ///
    /// Validates the form data and updates the router in OpenStack.
    /// Updates the UI and refreshes the router cache after successful update.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func submitRouterEdit(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Sync form state before submission
        tui.routerEditForm.updateFromFormState(tui.routerEditFormState)

        // Get external networks for validation
        let externalNetworks = tui.cacheManager.cachedNetworks.filter { $0.external == true }

        let errors = tui.routerEditForm.validateForm(externalNetworks: externalNetworks)
        guard errors.isEmpty else {
            tui.statusMessage = "Validation errors: \(errors.joined(separator: ", "))"
            return
        }

        let routerId = tui.routerEditForm.routerId
        guard !routerId.isEmpty else {
            tui.statusMessage = "Error: No router ID"
            return
        }

        // Log the values being submitted for debugging
        Logger.shared.logInfo("Submitting router edit", context: [
            "routerId": routerId,
            "name": tui.routerEditForm.getTrimmedName(),
            "description": tui.routerEditForm.getTrimmedDescription(),
            "adminStateUp": tui.routerEditForm.adminStateUp,
            "externalGatewayEnabled": tui.routerEditForm.externalGatewayEnabled,
            "selectedExternalNetworkId": tui.routerEditForm.selectedExternalNetworkId ?? "nil"
        ])

        do {
            // Build external gateway info if enabled
            var externalGatewayInfo: ExternalGatewayInfo? = nil
            var shouldClearGateway = false

            if tui.routerEditForm.externalGatewayEnabled {
                if let networkId = tui.routerEditForm.selectedExternalNetworkId {
                    externalGatewayInfo = ExternalGatewayInfo(
                        networkId: networkId,
                        enableSnat: true,
                        externalFixedIps: nil
                    )
                }
            } else {
                // User wants to disable external gateway - need to explicitly clear it
                shouldClearGateway = true
            }

            // Create update request
            let request = UpdateRouterRequest(
                name: tui.routerEditForm.getTrimmedName(),
                description: tui.routerEditForm.getTrimmedDescription().isEmpty ? nil : tui.routerEditForm.getTrimmedDescription(),
                adminStateUp: tui.routerEditForm.adminStateUp,
                externalGatewayInfo: externalGatewayInfo,
                routes: nil,
                clearExternalGateway: shouldClearGateway
            )

            // Update the router
            _ = try await tui.client.updateRouter(id: routerId, request: request)

            Logger.shared.logInfo("Router '\(tui.routerEditForm.getTrimmedName())' updated successfully")

            // Immediately refresh routers cache for faster feedback
            let _ = await DataProviderRegistry.shared.fetchData(
                for: "routers",
                priority: .critical,
                forceRefresh: true
            )
            tui.resourceOperations.updateResourceCounts()
            tui.markNeedsRedraw()

            // Return to routers list
            tui.changeView(to: .routers, resetSelection: false)
            tui.routerEditForm = RouterEditForm()
            tui.routerEditFormState = FormBuilderState(fields: [])
            tui.statusMessage = "Router updated successfully"
            await tui.draw(screen: screen)
        } catch {
            Logger.shared.logError("Failed to update router: \(error.localizedDescription)")
            tui.statusMessage = "Error: \(error.localizedDescription)"
            await tui.draw(screen: screen)
        }
    }

    // MARK: - Router Subnet Interface Management

    /// Open the subnet interface management view for the selected router
    ///
    /// Loads the currently attached subnets and presents a selection interface
    /// for attaching or detaching subnets from the router.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func manageRouterSubnetInterfaces(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .routers else { return }

        let filteredRouters = FilterUtils.filterRouters(tui.cacheManager.cachedRouters, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredRouters.count else {
            tui.statusMessage = "No router selected"
            return
        }

        let router = filteredRouters[tui.viewCoordinator.selectedIndex]
        let routerName = router.name ?? "Unnamed Router"

        tui.statusMessage = "Loading subnets for router '\(routerName)'..."
        await tui.draw(screen: screen)

        // Ensure subnets are loaded
        if tui.cacheManager.cachedSubnets.isEmpty {
            let _ = await DataProviderRegistry.shared.fetchData(
                for: "subnets",
                priority: .critical,
                forceRefresh: true
            )
        }

        // Load attached subnets for this router
        await loadAttachedSubnetsForRouter(router)

        // Reset selection state
        tui.selectionManager.attachmentMode = .attach
        tui.selectionManager.selectedSubnetId = nil

        // Navigate to subnet management view (resetSelection: false to preserve selectedResource)
        tui.changeView(to: .routerSubnetManagement, resetSelection: false)

        // Reset scroll and index for the new view, but keep selectedResource
        tui.viewCoordinator.selectedIndex = 0
        tui.viewCoordinator.scrollOffset = 0

        // Store the selected router AFTER changeView to ensure it's not cleared
        tui.viewCoordinator.selectedResource = router

        let subnetCount = tui.cacheManager.cachedSubnets.count
        let attachedCount = tui.selectionManager.attachedSubnetIds.count
        tui.statusMessage = "Managing subnet interfaces for router '\(routerName)' (\(subnetCount) subnets, \(attachedCount) attached)"

        Logger.shared.logInfo("Opened subnet interface management for router '\(routerName)'", context: [
            "routerId": router.id,
            "totalSubnets": subnetCount,
            "attachedSubnets": attachedCount
        ])
    }

    /// Load the subnets that are currently attached to the router
    ///
    /// Uses the router's interface data to determine which subnets are attached.
    ///
    /// - Parameter router: The router to check for attached subnets
    internal func loadAttachedSubnetsForRouter(_ router: Router) async {
        guard let tui = tui else { return }

        tui.selectionManager.attachedSubnetIds.removeAll()

        Logger.shared.logInfo(
            "=== Loading attached subnets for router \(router.name ?? router.id) (\(router.id)) ===",
            context: [:]
        )

        // Use router's interface data to find attached subnets
        if let interfaces = router.interfaces {
            Logger.shared.logInfo(
                "Router has \(interfaces.count) interfaces",
                context: [:]
            )

            for interface in interfaces {
                if let subnetId = interface.subnetId {
                    tui.selectionManager.attachedSubnetIds.insert(subnetId)
                    Logger.shared.logInfo(
                        "Found attached subnet \(subnetId) via interface",
                        context: [:]
                    )
                }
            }
        } else {
            Logger.shared.logInfo(
                "Router has no cached interface data",
                context: [:]
            )
        }

        Logger.shared.logInfo(
            "=== Final result: Router \(router.name ?? router.id) has \(tui.selectionManager.attachedSubnetIds.count) attached subnets ===",
            context: [:]
        )
    }

    /// Perform the subnet attachment or detachment operation
    ///
    /// Based on the current attachment mode and selected subnet, either attaches
    /// a new subnet interface or detaches an existing one.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func performRouterSubnetManagement(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard let router = tui.viewCoordinator.selectedResource as? Router else {
            tui.statusMessage = "Error: No router selected"
            return
        }

        guard let selectedSubnetId = tui.selectionManager.selectedSubnetId else {
            tui.statusMessage = "No subnet selected. Use SPACE to select a subnet."
            return
        }

        // Find the selected subnet for display purposes
        let subnet = tui.cacheManager.cachedSubnets.first { $0.id == selectedSubnetId }
        let subnetName = subnet?.name ?? subnet?.cidr ?? selectedSubnetId

        let routerName = router.name ?? router.id

        do {
            switch tui.selectionManager.attachmentMode {
            case .attach:
                Logger.shared.logInfo("Attaching subnet '\(subnetName)' to router '\(routerName)'")
                tui.statusMessage = "Attaching subnet '\(subnetName)' to router..."

                try await tui.client.addRouterInterface(routerId: router.id, subnetId: selectedSubnetId)

                Logger.shared.logInfo("Successfully attached subnet '\(subnetName)' to router '\(routerName)'")
                tui.statusMessage = "Subnet '\(subnetName)' attached to router"

                // Update local state
                tui.selectionManager.attachedSubnetIds.insert(selectedSubnetId)

            case .detach:
                Logger.shared.logInfo("Detaching subnet '\(subnetName)' from router '\(routerName)'")
                tui.statusMessage = "Detaching subnet '\(subnetName)' from router..."

                try await tui.client.removeRouterInterface(routerId: router.id, subnetId: selectedSubnetId)

                Logger.shared.logInfo("Successfully detached subnet '\(subnetName)' from router '\(routerName)'")
                tui.statusMessage = "Subnet '\(subnetName)' detached from router"

                // Update local state
                tui.selectionManager.attachedSubnetIds.remove(selectedSubnetId)
            }

            // Clear selection
            tui.selectionManager.selectedSubnetId = nil

            // Immediately refresh routers cache for faster feedback
            let _ = await DataProviderRegistry.shared.fetchData(
                for: "routers",
                priority: .critical,
                forceRefresh: true
            )
            tui.resourceOperations.updateResourceCounts()
            tui.markNeedsRedraw()

            await tui.draw(screen: screen)

        } catch {
            Logger.shared.logError("Failed to \(tui.selectionManager.attachmentMode == .attach ? "attach" : "detach") subnet: \(error.localizedDescription)")
            tui.statusMessage = "Error: \(error.localizedDescription)"
            await tui.draw(screen: screen)
        }
    }
}
