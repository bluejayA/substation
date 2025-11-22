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

            // Trigger accelerated refresh to show state transitions
            tui.refreshAfterOperation()

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
}
