// Sources/Substation/Modules/ServerGroups/ServerGroupsModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Server Groups Module
/// Manages server group scheduling policies for high availability and performance optimization.
/// Server groups control placement of instances on physical hosts through affinity/anti-affinity policies.
@MainActor
final class ServerGroupsModule: OpenStackModule {
    // MARK: - Module Identity

    /// Unique module identifier
    let identifier: String = "servergroups"

    /// Display name in UI
    let displayName: String = "Server Groups"

    /// Module version
    let version: String = "1.0.0"

    /// Module dependencies (none for server groups)
    let dependencies: [String] = []

    /// View modes handled by this module
    var handledViewModes: Set<ViewMode> {
        return [.serverGroups, .serverGroupDetail, .serverGroupCreate]
    }

    // MARK: - TUI Reference

    /// Reference to TUI system
    internal weak var tui: TUI?

    /// Form state container for ServerGroups module
    internal var formState = ServerGroupsFormState()

    // MARK: - Initialization

    /// Initialize module with TUI context
    /// - Parameter tui: Main TUI system instance
    required init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Module Configuration

    /// Configure module after initialization
    /// Performs any necessary setup and validation
    func configure() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        // Verify client is available
        guard tui.client.isAuthenticated else {
            throw ModuleError.configurationFailed("Client not authenticated")
        }

        // Initialize form states if needed
        if tui.serverGroupCreateFormState.fields.isEmpty {
            tui.serverGroupCreateFormState = FormBuilderState(
                fields: tui.serverGroupCreateForm.buildFields(
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )
        }

        // Module is ready - no additional configuration needed

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .serverGroups,
            detailViewMode: .serverGroupDetail
        )

        // Register as data provider
        let dataProvider = ServerGroupsDataProvider(module: self, tui: tui)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)
    }

    /// Load configuration for this module
    ///
    /// - Parameter config: Module-specific configuration (currently unused)
    func loadConfiguration(_ config: ModuleConfig?) {
        // Configuration acknowledged - no module-specific settings required
        Logger.shared.logDebug("[\(identifier)] Configuration loaded", context: [:])
    }

    // MARK: - View Registration

    /// Register all server group views with TUI system
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else { return [] }

        var registrations: [ModuleViewRegistration] = []

        // Server Groups List View
        registrations.append(ModuleViewRegistration(
            viewMode: .serverGroups,
            title: "Server Groups",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                await self.renderServerGroupsList(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: nil, // Uses standard list input handling
            category: .compute
        ))

        // Server Group Detail View
        registrations.append(ModuleViewRegistration(
            viewMode: .serverGroupDetail,
            title: "Server Group Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                await self.renderServerGroupDetail(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: nil, // Uses standard detail view input handling
            category: .compute
        ))

        // Server Group Create View
        registrations.append(ModuleViewRegistration(
            viewMode: .serverGroupCreate,
            title: "Create Server Group",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                await self.renderServerGroupCreate(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleServerGroupCreateInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        // Server Group Management View
        registrations.append(ModuleViewRegistration(
            viewMode: .serverGroupManagement,
            title: "Manage Server Group",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                await self.renderServerGroupManagement(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: nil, // Uses standard management view input handling
            category: .compute
        ))

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers with TUI system
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else { return [] }

        return [
            ModuleFormHandlerRegistration(
                viewMode: .serverGroupCreate,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleServerGroupCreateInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return tui.serverGroupCreateForm.isValid()
                }
            )
        ]
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else { return [] }

        return [
            ModuleDataRefreshRegistration(
                identifier: "servergroups",
                refreshHandler: { [weak tui] in
                    guard let tui = tui else {
                        throw ModuleError.invalidState("TUI reference is nil")
                    }
                    await tui.dataManager.refreshAllData()
                },
                cacheKey: "serverGroups",
                refreshInterval: 30.0 // Refresh every 30 seconds
            )
        ]
    }

    // MARK: - Cleanup

    /// Cleanup when module is unloaded
    func cleanup() async {
        // Clear any module-specific caches or state
        tui?.serverGroupCreateForm.reset()
        tui?.serverGroupManagementForm.reset()
    }

    // MARK: - Health Check

    /// Module health check for monitoring
    /// - Returns: Health status with metrics
    func healthCheck() async -> ModuleHealthStatus {
        var errors: [String] = []
        var metrics: [String: Any] = [:]

        // Check TUI reference
        guard let tui = tui else {
            errors.append("TUI reference is nil")
            return ModuleHealthStatus(
                isHealthy: false,
                lastCheck: Date(),
                errors: errors,
                metrics: metrics
            )
        }

        // Check cache status
        let cachedServerGroups = tui.cacheManager.cachedServerGroups
        metrics["cached_server_groups"] = cachedServerGroups.count

        if cachedServerGroups.isEmpty {
            metrics["warning"] = "No server groups loaded"
        }

        // Check form states
        metrics["create_form_initialized"] = !tui.serverGroupCreateFormState.fields.isEmpty

        return ModuleHealthStatus(
            isHealthy: errors.isEmpty,
            lastCheck: Date(),
            errors: errors,
            metrics: metrics
        )
    }

    // MARK: - Computed Properties

    /// Get all cached server groups
    ///
    /// Returns all server groups from the cache manager.
    /// Used for server group listing, filtering, and selection operations.
    var serverGroups: [ServerGroup] {
        return tui?.cacheManager.cachedServerGroups ?? []
    }
}

// MARK: - ActionProvider Conformance

extension ServerGroupsModule: ActionProvider {
    /// Actions available in the list view for server groups
    ///
    /// Includes create, delete, refresh, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .clearCache]
    }

    /// The view mode for creating a new server group
    var createViewMode: ViewMode? {
        .serverGroupCreate
    }

    /// Execute an action for the selected server group
    ///
    /// - Parameters:
    ///   - action: The action type to execute
    ///   - screen: Screen pointer for confirmation dialogs
    ///   - tui: The TUI instance for state management
    /// - Returns: Boolean indicating if the action was handled
    func executeAction(_ action: ActionType, screen: OpaquePointer?, tui: TUI) async -> Bool {
        switch action {
        case .create:
            guard let createMode = createViewMode else { return false }

            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".serverGroupCreate")
            tui.changeView(to: createMode)
            tui.serverGroupCreateForm = ServerGroupCreateForm()

            // Initialize FormBuilderState with form fields
            tui.serverGroupCreateFormState = FormBuilderState(fields: tui.serverGroupCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))

            tui.statusMessage = "Create new server group"
            return true
        case .delete:
            await deleteServerGroup(screen: screen)
            return true
        default:
            return false
        }
    }

    /// Get the bulk delete operation for selected server groups
    ///
    /// Creates a batch operation for deleting multiple server groups at once.
    ///
    /// - Parameters:
    ///   - selectedIDs: Set of server group IDs to delete
    ///   - tui: The TUI instance for state management
    /// - Returns: BatchOperationType for server group bulk delete, or nil if not supported
    func getBulkDeleteOperation(selectedIDs: Set<String>, tui: TUI) -> BatchOperationType? {
        return .serverGroupBulkDelete(serverGroupIDs: Array(selectedIDs))
    }

    /// Get the ID of the currently selected server group
    ///
    /// Returns the server group ID based on the current selection index, accounting for any
    /// search filtering that may be applied to the list.
    ///
    /// - Parameter tui: The TUI instance for state management
    /// - Returns: Server group ID string, or empty string if no valid selection
    func getSelectedResourceId(tui: TUI) -> String {
        let filtered = FilterUtils.filterServerGroups(tui.cacheManager.cachedServerGroups, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filtered.count else { return "" }
        return filtered[tui.viewCoordinator.selectedIndex].id
    }
}

extension ServerGroupsModule {
    // MARK: - View Rendering Methods

    /// Render server groups list view
    func renderServerGroupsList(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        let cachedServerGroups = tui.cacheManager.cachedServerGroups

        await ServerGroupViews.drawDetailedServerGroupList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            cachedServerGroups: cachedServerGroups,
            searchQuery: tui.searchQuery,
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex,
            multiSelectMode: tui.selectionManager.multiSelectMode,
            selectedItems: tui.selectionManager.multiSelectedResourceIDs
        )
    }

    /// Render server group detail view
    func renderServerGroupDetail(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let serverGroup = tui.viewCoordinator.selectedResource as? ServerGroup else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol + 2, y: startRow + 2, width: width - 4, height: 1)
            await SwiftNCurses.render(
                Text("No server group selected").error(),
                on: surface,
                in: bounds
            )
            return
        }

        let cachedServers = tui.cacheManager.cachedServers

        await ServerGroupViews.drawServerGroupDetail(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            serverGroup: serverGroup,
            cachedServers: cachedServers,
            scrollOffset: tui.viewCoordinator.detailScrollOffset
        )
    }

    /// Render server group create form
    func renderServerGroupCreate(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await ServerGroupViews.drawServerGroupCreateForm(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            form: tui.serverGroupCreateForm,
            formState: tui.serverGroupCreateFormState
        )
    }

    /// Render server group management view
    func renderServerGroupManagement(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await ServerGroupViews.drawServerGroupManagement(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            form: tui.serverGroupManagementForm
        )
    }
}
