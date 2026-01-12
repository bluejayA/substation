// Sources/Substation/Modules/Magnum/MagnumModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// Magnum Container Infrastructure module implementation
///
/// This module provides OpenStack Magnum (Container Infrastructure Management) functionality:
/// - Cluster listing and browsing with status-based filtering
/// - Cluster detail views with nodegroup information
/// - Cluster template listing and details
/// - Nodegroup listing within clusters
///
/// The module integrates with the TUI system through the OpenStackModule protocol
/// and delegates rendering to MagnumViews for consistent UI presentation.
@MainActor
final class MagnumModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Magnum module
    let identifier: String = "magnum"

    /// Display name shown in the UI
    let displayName: String = "Container Infra (Magnum)"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies (Magnum has no dependencies)
    let dependencies: [String] = []

    /// View modes handled by this module
    var handledViewModes: Set<ViewMode> {
        return [.clusters, .clusterDetail, .clusterTemplates, .clusterTemplateDetail,
                .clusterCreate, .clusterResize, .clusterTemplateCreate]
    }

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    /// Form state for Magnum module
    var formState: MagnumFormState = MagnumFormState()

    // MARK: - Initialization

    /// Initialize the Magnum module with TUI context
    /// - Parameter tui: The main TUI instance
    required init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs any necessary setup for the Magnum module.
    func configure() async throws {
        guard let tuiInstance = tui else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        // Register as action provider for clusters
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .clusters,
            detailViewMode: .clusterDetail
        )

        // Register as action provider for cluster templates
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .clusterTemplates,
            detailViewMode: .clusterTemplateDetail
        )

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as data provider
        let dataProvider = MagnumDataProvider(module: self, tui: tuiInstance)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)

        lastHealthCheck = Date()
    }

    /// Load configuration for this module
    ///
    /// - Parameter config: Module-specific configuration (currently unused)
    func loadConfiguration(_ config: ModuleConfig?) {
        // Configuration acknowledged - no module-specific settings required
        Logger.shared.logDebug("[\(identifier)] Configuration loaded", context: [:])
    }

    // MARK: - View Registration

    /// Register all Magnum views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .clusters: List view of all clusters
    /// - .clusterDetail: Detail view for a selected cluster
    /// - .clusterTemplates: List view of cluster templates
    /// - .clusterTemplateDetail: Detail view for a selected template
    ///
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            return []
        }

        var registrations: [ModuleViewRegistration] = []

        // Register clusters list view
        registrations.append(ModuleViewRegistration(
            viewMode: .clusters,
            title: "Clusters",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await MagnumViews.drawClusterList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedClusters: tui.cacheManager.cachedClusters,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex,
                    multiSelectMode: tui.selectionManager.multiSelectMode,
                    selectedItems: tui.selectionManager.multiSelectedResourceIDs
                )
            },
            inputHandler: nil,
            category: .compute
        ))

        // Register cluster detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .clusterDetail,
            title: "Cluster Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let cluster = tui.viewCoordinator.selectedResource as? Cluster else { return }

                await MagnumViews.drawClusterDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cluster: cluster,
                    nodegroups: tui.cacheManager.cachedNodegroups,
                    clusterTemplate: tui.cacheManager.cachedClusterTemplates.first {
                        $0.uuid == cluster.clusterTemplateId
                    },
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: nil,
            category: .compute
        ))

        // Register cluster templates list view
        registrations.append(ModuleViewRegistration(
            viewMode: .clusterTemplates,
            title: "Cluster Templates",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await MagnumViews.drawClusterTemplateList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedTemplates: tui.cacheManager.cachedClusterTemplates,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex,
                    multiSelectMode: tui.selectionManager.multiSelectMode,
                    selectedItems: tui.selectionManager.multiSelectedResourceIDs
                )
            },
            inputHandler: nil,
            category: .compute
        ))

        // Register cluster template detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .clusterTemplateDetail,
            title: "Cluster Template Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let template = tui.viewCoordinator.selectedResource as? ClusterTemplate else { return }

                await MagnumViews.drawClusterTemplateDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    template: template,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: nil,
            category: .compute
        ))

        // Register cluster create view
        registrations.append(ModuleViewRegistration(
            viewMode: .clusterCreate,
            title: "Create Cluster",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await ClusterCreateView.draw(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    form: tui.clusterCreateForm,
                    formState: tui.clusterCreateFormState
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleClusterCreateInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        // Register cluster resize view
        registrations.append(ModuleViewRegistration(
            viewMode: .clusterResize,
            title: "Resize Cluster",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let resizeState = tui.clusterResizeFormState else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No cluster selected for resize").error(), on: surface, in: bounds)
                    return
                }

                await MagnumViews.drawClusterResizeForm(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    resizeState: resizeState
                )
            },
            inputHandler: { [weak self, weak tui] ch, screen in
                guard let self = self, let tui = tui else { return false }
                return await self.handleClusterResizeInput(ch, screen: screen, tui: tui)
            },
            category: .compute
        ))

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for Magnum forms
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        // Magnum is read-only for now - no forms to register
        return []
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for Magnum resources
    ///
    /// Registers handlers to refresh clusters and templates from the Magnum API.
    ///
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else {
            return []
        }

        var handlers: [ModuleDataRefreshRegistration] = []

        // Register clusters refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "magnum.clusters",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }
                await tui.dataManager.refreshAllData()
            },
            cacheKey: "clusters",
            refreshInterval: 60.0
        ))

        // Register cluster templates refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "magnum.templates",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }
                await tui.dataManager.refreshAllData()
            },
            cacheKey: "clusterTemplates",
            refreshInterval: 120.0
        ))

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    func cleanup() async {
        healthErrors.removeAll()
        lastHealthCheck = nil
    }

    // MARK: - Health Check

    /// Perform a health check on the Magnum module
    ///
    /// This method verifies that:
    /// - TUI reference is valid
    /// - Magnum service is accessible via the API client
    ///
    /// - Returns: ModuleHealthStatus indicating module health
    func healthCheck() async -> ModuleHealthStatus {
        var errors: [String] = []
        var metrics: [String: Any] = [:]

        guard let tui = tui else {
            errors.append("TUI reference is nil")
            return ModuleHealthStatus(
                isHealthy: false,
                lastCheck: Date(),
                errors: errors,
                metrics: metrics
            )
        }

        // Check if clusters are loaded
        let clusterCount = tui.cacheManager.cachedClusters.count
        metrics["clusterCount"] = clusterCount

        let templateCount = tui.cacheManager.cachedClusterTemplates.count
        metrics["templateCount"] = templateCount

        lastHealthCheck = Date()
        healthErrors = errors

        return ModuleHealthStatus(
            isHealthy: errors.isEmpty,
            lastCheck: Date(),
            errors: errors,
            metrics: metrics
        )
    }

    // MARK: - Computed Properties

    /// Get all cached clusters
    var clusters: [Cluster] {
        return tui?.cacheManager.cachedClusters ?? []
    }

    /// Get all cached cluster templates
    var clusterTemplates: [ClusterTemplate] {
        return tui?.cacheManager.cachedClusterTemplates ?? []
    }
}

// MARK: - ActionProvider Conformance

extension MagnumModule: ActionProvider {
    /// Actions available in the list view for clusters
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .clearCache]
    }

    /// The view mode for creating a new cluster
    var createViewMode: ViewMode? {
        .clusterCreate
    }

    /// Execute an action for the selected cluster or cluster template
    ///
    /// - Parameters:
    ///   - action: The action type to execute
    ///   - screen: Screen pointer for confirmation dialogs
    ///   - tui: The TUI instance for state management
    /// - Returns: Boolean indicating if the action was handled
    func executeAction(_ action: ActionType, screen: OpaquePointer?, tui: TUI) async -> Bool {
        switch action {
        case .create:
            // Determine which create view to navigate to based on current view
            if tui.viewCoordinator.currentView == .clusterTemplates {
                Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".clusterTemplateCreate")
                let _ = tui.initializeClusterTemplateCreateForm()
                tui.viewCoordinator.previousView = .clusterTemplates
                tui.viewCoordinator.currentView = .clusterTemplateCreate
            } else {
                Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".clusterCreate")
                let _ = tui.initializeClusterCreateForm()
                tui.viewCoordinator.previousView = .clusters
                tui.viewCoordinator.currentView = .clusterCreate
            }
            return true
        case .delete:
            // Handle delete based on current view
            if tui.viewCoordinator.currentView == .clusterTemplates {
                await deleteClusterTemplate(screen: screen, tui: tui)
            } else {
                await deleteCluster(screen: screen)
            }
            return true
        default:
            return false
        }
    }

    /// Get the bulk delete operation for selected Magnum resources
    ///
    /// Returns the appropriate BatchOperationType based on the current view mode.
    /// For clusters view, returns clusterBulkDelete. For cluster templates view,
    /// returns clusterTemplateBulkDelete.
    ///
    /// - Parameters:
    ///   - selectedIDs: Set of resource IDs to delete
    ///   - tui: The TUI instance for state management
    /// - Returns: BatchOperationType for cluster or template bulk delete
    func getBulkDeleteOperation(selectedIDs: Set<String>, tui: TUI) -> BatchOperationType? {
        guard !selectedIDs.isEmpty else { return nil }

        let ids = Array(selectedIDs)
        let currentView = tui.viewCoordinator.currentView

        if currentView == .clusterTemplates {
            return .clusterTemplateBulkDelete(templateIDs: ids)
        } else {
            return .clusterBulkDelete(clusterIDs: ids)
        }
    }

    /// Get the ID of the currently selected cluster
    ///
    /// - Parameter tui: The TUI instance for state management
    /// - Returns: Cluster ID string, or empty string if no valid selection
    func getSelectedResourceId(tui: TUI) -> String {
        let filtered = FilterUtils.filterClusters(tui.cacheManager.cachedClusters, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filtered.count else { return "" }
        return filtered[tui.viewCoordinator.selectedIndex].uuid
    }

    /// Delete a cluster with confirmation dialog
    ///
    /// Shows a confirmation modal before deleting the selected cluster.
    ///
    /// - Parameter screen: Screen pointer for confirmation dialog
    private func deleteCluster(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let filtered = FilterUtils.filterClusters(tui.cacheManager.cachedClusters, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filtered.count else {
            tui.statusMessage = "No cluster selected"
            return
        }

        let cluster = filtered[tui.viewCoordinator.selectedIndex]

        // Check if cluster is in a deletable state
        if let status = cluster.status?.uppercased(),
           status.contains("DELETE") {
            tui.statusMessage = "Cluster is already being deleted"
            return
        }

        // Show confirmation dialog
        guard await ViewUtils.confirmDelete(
            cluster.displayName,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Cluster deletion cancelled"
            return
        }

        tui.statusMessage = "Deleting cluster '\(cluster.displayName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            let magnumService = await tui.client.magnum
            try await magnumService.deleteCluster(id: cluster.uuid)

            // Update cache
            if let index = tui.cacheManager.cachedClusters.firstIndex(where: { $0.uuid == cluster.uuid }) {
                tui.cacheManager.cachedClusters.remove(at: index)
            }

            // Adjust selection index
            let newMaxIndex = max(0, filtered.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Cluster '\(cluster.displayName)' deletion initiated"
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            ViewUtils.setEnhancedStatusMessage(
                for: error,
                operation: "delete cluster",
                resourceType: "Cluster",
                resourceId: cluster.uuid,
                currentView: tui.viewCoordinator.currentView,
                enhancedErrorHandler: tui.enhancedErrorHandler,
                statusMessage: &tui.statusMessage
            )
            Logger.shared.logError("Failed to delete cluster: \(error)")
        } catch {
            tui.statusMessage = "Failed to delete cluster: \(error.localizedDescription)"
            Logger.shared.logError("Failed to delete cluster: \(error)")
        }
    }

    /// Delete a cluster template with confirmation dialog
    ///
    /// Shows a confirmation modal before deleting the selected cluster template.
    ///
    /// - Parameters:
    ///   - screen: Screen pointer for confirmation dialog
    ///   - tui: The TUI instance for state management
    private func deleteClusterTemplate(screen: OpaquePointer?, tui: TUI) async {
        let filtered = FilterUtils.filterClusterTemplates(
            tui.cacheManager.cachedClusterTemplates,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filtered.count else {
            tui.statusMessage = "No cluster template selected"
            return
        }

        let template = filtered[tui.viewCoordinator.selectedIndex]

        // Show confirmation dialog
        guard await ViewUtils.confirmDelete(
            template.displayName,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Cluster template deletion cancelled"
            return
        }

        tui.statusMessage = "Deleting cluster template '\(template.displayName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            let magnumService = await tui.client.magnum
            try await magnumService.deleteClusterTemplate(id: template.uuid)

            // Update cache
            if let index = tui.cacheManager.cachedClusterTemplates.firstIndex(where: { $0.uuid == template.uuid }) {
                tui.cacheManager.cachedClusterTemplates.remove(at: index)
            }

            // Adjust selection index
            let newMaxIndex = max(0, filtered.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Cluster template '\(template.displayName)' deleted successfully"
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            ViewUtils.setEnhancedStatusMessage(
                for: error,
                operation: "delete cluster template",
                resourceType: "ClusterTemplate",
                resourceId: template.uuid,
                currentView: tui.viewCoordinator.currentView,
                enhancedErrorHandler: tui.enhancedErrorHandler,
                statusMessage: &tui.statusMessage
            )
            Logger.shared.logError("Failed to delete cluster template: \(error)")
        } catch {
            tui.statusMessage = "Failed to delete cluster template: \(error.localizedDescription)"
            Logger.shared.logError("Failed to delete cluster template: \(error)")
        }
    }
}

// MARK: - Input Handlers

extension MagnumModule {
    /// Submit the cluster creation request
    ///
    /// - Parameter tui: The TUI instance
    func submitClusterCreate(tui: TUI) async {
        let form = tui.clusterCreateForm

        // Validate form
        guard form.isValid else {
            tui.statusMessage = "Please fill in all required fields"
            return
        }

        let name = form.clusterName
        let templateId = form.selectedTemplateId ?? ""
        let keypair = form.selectedKeypairId
        let masterCount = Int(form.masterCount)
        let nodeCount = Int(form.nodeCount)
        let createTimeout = Int(form.createTimeout)

        // Debug logging
        Logger.shared.logDebug("Cluster create request", context: [
            "name": name,
            "templateId": templateId,
            "keypair": keypair ?? "nil",
            "masterCount": String(masterCount ?? 0),
            "nodeCount": String(nodeCount ?? 0),
            "createTimeout": String(createTimeout ?? 0)
        ])

        guard !templateId.isEmpty else {
            tui.statusMessage = "Error: No cluster template selected"
            Logger.shared.logError("Cluster template ID is empty")
            return
        }

        tui.statusMessage = "Creating cluster '\(name)'..."

        do {
            let request = ClusterCreateRequest(
                name: name,
                clusterTemplateId: templateId,
                keypair: keypair?.isEmpty == true ? nil : keypair,
                masterCount: masterCount,
                nodeCount: nodeCount,
                createTimeout: createTimeout
            )

            let magnumService = await tui.client.magnum
            let cluster = try await magnumService.createCluster(request: request)

            tui.statusMessage = "Cluster '\(cluster.displayName)' creation initiated"
            tui.viewCoordinator.currentView = .clusters

            // Reset form and refresh data
            tui.clusterCreateForm.reset()
            tui.clusterCreateFormState = FormBuilderState(fields: [])
            await tui.dataManager.refreshAllData()

        } catch {
            tui.statusMessage = "Failed to create cluster: \(error.localizedDescription)"
            Logger.shared.logError("Failed to create cluster: \(error)")
        }
    }

    /// Handle input for cluster resize view
    ///
    /// - Parameters:
    ///   - ch: The key code
    ///   - screen: The ncurses screen pointer
    ///   - tui: The TUI instance
    /// - Returns: true if input was handled
    func handleClusterResizeInput(_ ch: Int32, screen: OpaquePointer?, tui: TUI) async -> Bool {
        guard let resizeState = tui.clusterResizeFormState else {
            return false
        }

        // Handle ESC - cancel and go back
        if ch == 27 {
            tui.clusterResizeFormState = nil
            tui.viewCoordinator.currentView = .clusterDetail
            return true
        }

        // Handle ENTER - submit resize
        if ch == 10 || ch == 13 {
            if resizeState.needsResize && !resizeState.isSubmitting {
                await submitClusterResize(tui: tui, resizeState: resizeState)
            }
            return true
        }

        // Handle + key - increment nodes
        if ch == Int32(Character("+").asciiValue!) || ch == Int32(Character("=").asciiValue!) {
            resizeState.incrementNodes()
            return true
        }

        // Handle - key - decrement nodes
        if ch == Int32(Character("-").asciiValue!) || ch == Int32(Character("_").asciiValue!) {
            resizeState.decrementNodes()
            return true
        }

        // Handle up arrow - increment nodes
        if ch == 259 { // KEY_UP
            resizeState.incrementNodes()
            return true
        }

        // Handle down arrow - decrement nodes
        if ch == 258 { // KEY_DOWN
            resizeState.decrementNodes()
            return true
        }

        return false
    }

    /// Submit the cluster resize request
    private func submitClusterResize(tui: TUI, resizeState: ClusterResizeFormState) async {
        resizeState.isSubmitting = true
        resizeState.errorMessage = nil

        tui.statusMessage = "Resizing cluster '\(resizeState.clusterName)'..."

        do {
            let magnumService = await tui.client.magnum
            _ = try await magnumService.resizeCluster(id: resizeState.clusterUUID, nodeCount: resizeState.newNodeCount)

            tui.statusMessage = "Cluster '\(resizeState.clusterName)' resize initiated to \(resizeState.newNodeCount) workers"

            // Clear resize state and go back to detail view
            tui.clusterResizeFormState = nil
            tui.viewCoordinator.currentView = .clusterDetail

            // Refresh data
            await tui.dataManager.refreshAllData()

        } catch {
            resizeState.isSubmitting = false
            resizeState.errorMessage = error.localizedDescription
            tui.statusMessage = "Failed to resize cluster: \(error.localizedDescription)"
            Logger.shared.logError("Failed to resize cluster: \(error)")
        }
    }

    /// Navigate to cluster create view
    func navigateToClusterCreate(tui: TUI) {
        // Initialize the create form
        _ = tui.initializeClusterCreateForm()
        tui.viewCoordinator.previousView = .clusters
        tui.viewCoordinator.currentView = .clusterCreate
    }

    /// Submit the cluster template creation request
    ///
    /// Extracts form field values and calls the Magnum API to create
    /// a new cluster template.
    ///
    /// - Parameter tui: The TUI instance
    func submitClusterTemplateCreate(tui: TUI) async {
        let formState = tui.clusterTemplateCreateFormState

        // Extract form values
        let name = formState.textFieldStates["name"]?.value ?? ""
        guard !name.isEmpty else {
            tui.statusMessage = "Template name is required"
            return
        }

        let coe = formState.selectorStates["coe"]?.selectedItemId ?? "kubernetes"
        let imageId = formState.selectorStates["image_id"]?.selectedItemId ?? ""
        guard !imageId.isEmpty else {
            tui.statusMessage = "Node image is required"
            return
        }

        let externalNetworkId = formState.selectorStates["external_network_id"]?.selectedItemId
        let flavorId = formState.selectorStates["flavor_id"]?.selectedItemId
        let masterFlavorId = formState.selectorStates["master_flavor_id"]?.selectedItemId
        let keypairId = formState.selectorStates["keypair_id"]?.selectedItemId
        let networkDriver = formState.selectorStates["network_driver"]?.selectedItemId
        let dockerVolumeSizeStr = formState.textFieldStates["docker_volume_size"]?.value ?? "50"
        let dockerVolumeSize = Int(dockerVolumeSizeStr)
        let floatingIpEnabled = formState.getToggleValue("floating_ip_enabled") ?? true
        let masterLbEnabled = formState.getToggleValue("master_lb_enabled") ?? true

        tui.statusMessage = "Creating cluster template '\(name)'..."

        do {
            let request = ClusterTemplateCreateRequest(
                name: name,
                coe: coe,
                imageId: imageId,
                externalNetworkId: externalNetworkId?.isEmpty == true ? nil : externalNetworkId,
                flavorId: flavorId?.isEmpty == true ? nil : flavorId,
                masterFlavorId: masterFlavorId?.isEmpty == true ? nil : masterFlavorId,
                keypairId: keypairId?.isEmpty == true ? nil : keypairId,
                fixedNetwork: nil,
                fixedSubnet: nil,
                networkDriver: networkDriver?.isEmpty == true ? nil : networkDriver,
                volumeDriver: nil,
                dockerVolumeSize: dockerVolumeSize,
                dnsNameserver: nil,
                floatingIpEnabled: floatingIpEnabled,
                masterLbEnabled: masterLbEnabled,
                tlsDisabled: nil,
                isPublic: nil,
                registryEnabled: nil,
                httpProxy: nil,
                httpsProxy: nil,
                noProxy: nil,
                labels: nil
            )

            let magnumService = await tui.client.magnum
            let template = try await magnumService.createClusterTemplate(request: request)

            tui.statusMessage = "Cluster template '\(template.displayName)' created successfully"
            tui.viewCoordinator.currentView = .clusterTemplates

            // Refresh data
            await tui.dataManager.refreshAllData()

        } catch {
            tui.statusMessage = "Failed to create cluster template: \(error.localizedDescription)"
            Logger.shared.logError("Failed to create cluster template: \(error)")
        }
    }
}
