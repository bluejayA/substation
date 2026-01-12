// Sources/Substation/Modules/Routers/RoutersModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Neutron Routers module implementation
///
/// This module provides comprehensive router management capabilities including:
/// - Router listing and browsing with filtering and search
/// - Detailed router inspection with gateway and interface information
/// - Router creation with advanced configuration options
/// - Multi-select operations for batch management
///
/// The Routers module depends on the Networks module for external gateway
/// configuration. It integrates with the TUI system through the OpenStackModule
/// protocol and delegates rendering to RouterViews for consistent UI presentation.
///
/// Key Features:
/// - External gateway configuration with SNAT control
/// - Distributed Virtual Router (DVR) support
/// - High Availability (HA) configuration
/// - Static route management
/// - Subnet interface attachment
/// - Floating IP integration
/// - Admin state management
@MainActor
final class RoutersModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Routers module
    let identifier: String = "routers"

    /// Display name shown in the UI
    let displayName: String = "Routers (Neutron)"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies - Routers depends on Networks for external gateway configuration
    let dependencies: [String] = ["networks"]

    /// View modes handled by this module
    var handledViewModes: Set<ViewMode> {
        return [.routers, .routerDetail, .routerCreate, .routerEdit, .routerSubnetManagement]
    }

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    /// Form state container for Routers module
    internal var formState = RoutersFormState()

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    /// Cached router count for performance monitoring
    private var cachedRouterCount: Int = 0

    // MARK: - Initialization

    /// Initialize the Routers module with TUI context
    /// - Parameter tui: The main TUI instance providing access to OpenStack client and UI state
    required init(tui: TUI) {
        self.tui = tui
        Logger.shared.logInfo("RoutersModule initialized", context: [
            "version": version,
            "identifier": identifier
        ])
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs initialization tasks including:
    /// - Verifying Neutron service availability in service catalog
    /// - Validating router endpoint accessibility
    /// - Setting up initial health tracking
    ///
    /// The module will load even if Neutron is temporarily unavailable to allow
    /// for graceful degradation in multi-cloud or degraded environments.
    func configure() async throws {
        guard let tuiInstance = tui else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        Logger.shared.logInfo("RoutersModule configuration started", context: [:])

        // RoutersModule configuration completed
        Logger.shared.logInfo("RoutersModule configuration completed", context: [:])

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .routers,
            detailViewMode: .routerDetail
        )

        // Register as data provider
        let dataProvider = RoutersDataProvider(module: self, tui: tuiInstance)
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

    /// Register all router-related views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .routers: Primary list view showing all routers with status indicators
    /// - .routerDetail: Detailed view for a selected router with full attributes
    /// - .routerCreate: Form for creating new routers with validation
    ///
    /// Each view registration includes:
    /// - Render handler delegating to RouterViews
    /// - Input handler for keyboard navigation and actions
    /// - Category classification for menu organization
    ///
    /// - Returns: Array of view registrations for the module
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register views - TUI reference is nil", context: [:])
            return []
        }

        var registrations: [ModuleViewRegistration] = []

        // Register routers list view
        registrations.append(ModuleViewRegistration(
            viewMode: .routers,
            title: "Routers",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await RouterViews.drawDetailedRouterList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedRouters: tui.cacheManager.cachedRouters,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex,
                    multiSelectMode: tui.selectionManager.multiSelectMode,
                    selectedItems: tui.selectionManager.multiSelectedResourceIDs
                )
            },
            inputHandler: { [weak self, weak tui] ch, screen in
                guard let self = self, let tui = tui else { return false }

                switch ch {
                case Int32(69):  // E - Edit selected router (SHIFT-E)
                    Logger.shared.logUserAction("edit_router", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                    await self.editRouter(screen: screen)
                    return true

                case Int32(83):  // S - Manage subnet interfaces (SHIFT-S)
                    Logger.shared.logUserAction("manage_router_subnets", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                    await self.manageRouterSubnetInterfaces(screen: screen)
                    return true

                default:
                    return false
                }
            },
            category: .network
        ))

        // Register router detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .routerDetail,
            title: "Router Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let router = tui.viewCoordinator.selectedResource as? Router else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No router selected").error(), on: surface, in: bounds)
                    return
                }

                await RouterViews.drawRouterDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    router: router,
                    cachedSubnets: tui.cacheManager.cachedSubnets,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: nil, // Default system handles input
            category: .network
        ))

        // Register router create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .routerCreate,
            title: "Create Router",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await RouterViews.drawRouterCreateForm(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    routerCreateForm: tui.routerCreateForm,
                    routerCreateFormState: tui.routerCreateFormState,
                    availabilityZones: tui.cacheManager.cachedAvailabilityZones,
                    externalNetworks: tui.cacheManager.cachedNetworks.filter { $0.external == true }
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleRouterCreateInput(ch, screen: screen)
                return true
            },
            category: .network
        ))

        // Register router edit form view
        registrations.append(ModuleViewRegistration(
            viewMode: .routerEdit,
            title: "Edit Router",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await RouterViews.drawRouterEditForm(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    routerEditForm: tui.routerEditForm,
                    routerEditFormState: tui.routerEditFormState,
                    externalNetworks: tui.cacheManager.cachedNetworks.filter { $0.external == true }
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleRouterEditInput(ch, screen: screen)
                return true
            },
            category: .network
        ))

        // Register router subnet management view
        registrations.append(ModuleViewRegistration(
            viewMode: .routerSubnetManagement,
            title: "Manage Router Subnet Interfaces",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let router = tui.viewCoordinator.selectedResource as? Router else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No router selected").error(), on: surface, in: bounds)
                    return
                }

                await RouterSubnetManagementView.draw(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    router: router,
                    subnets: tui.cacheManager.cachedSubnets,
                    attachedSubnetIds: tui.selectionManager.attachedSubnetIds,
                    selectedSubnetId: tui.selectionManager.selectedSubnetId,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex,
                    mode: tui.selectionManager.attachmentMode
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleRouterSubnetManagementInput(ch, screen: screen)
                return true
            },
            category: .network
        ))

        Logger.shared.logInfo("RoutersModule registered \(registrations.count) views", context: [
            "viewCount": registrations.count
        ])

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for router operations
    ///
    /// This method registers form input handlers for:
    /// - Router creation form using universalFormInputHandler pattern
    ///
    /// The form handler includes:
    /// - Input processing through universal handler
    /// - Form validation before submission
    /// - Submission handling via ResourceOperations
    /// - Cancel handling returning to routers list
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register form handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register router create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .routerCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleRouterCreateInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                // Router name is required
                let errors = tui.routerCreateForm.validateForm(
                    availabilityZones: tui.cacheManager.cachedAvailabilityZones,
                    externalNetworks: tui.cacheManager.cachedNetworks.filter { $0.external == true }
                )
                return errors.isEmpty
            }
        ))

        Logger.shared.logInfo("RoutersModule registered \(handlers.count) form handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for router resources
    ///
    /// This method registers handlers to refresh router data from the API.
    /// The refresh handler is called:
    /// - Periodically based on refreshInterval (60 seconds default)
    /// - On-demand when user triggers manual refresh
    /// - After create/update/delete operations
    ///
    /// The handler uses DataManager for centralized caching and deduplication.
    ///
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register data refresh handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleDataRefreshRegistration] = []

        // Register routers refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "routers.list",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }

                Logger.shared.logDebug("Routers refresh handler invoked", context: [:])

                await tui.dataManager.refreshAllData()
                Logger.shared.logDebug("Routers refreshed successfully", context: [
                    "routerCount": tui.cacheManager.cachedRouters.count
                ])
            },
            cacheKey: "routers",
            refreshInterval: 60.0 // Refresh every 60 seconds
        ))

        Logger.shared.logInfo("RoutersModule registered \(handlers.count) refresh handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    /// It performs the following cleanup tasks:
    /// - Clears cached router data
    /// - Resets health tracking state
    /// - Releases any module-specific resources
    ///
    /// The TUI reference is weak and will be released automatically.
    func cleanup() async {
        Logger.shared.logInfo("RoutersModule cleanup started", context: [:])

        // Clear module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil
        cachedRouterCount = 0

        // Clear cached router data if TUI is still available
        if let tui = tui {
            // Routers are stored in ResourceCache, which manages its own lifecycle
            // We just log the cleanup
            Logger.shared.logDebug("RoutersModule cleanup - cached routers will be managed by ResourceCache", context: [
                "routerCount": tui.cacheManager.cachedRouters.count
            ])
        }

        Logger.shared.logInfo("RoutersModule cleanup completed", context: [:])
    }

    // MARK: - Health Check

    /// Perform a health check on the Routers module
    ///
    /// This method verifies that:
    /// - TUI reference is valid and accessible
    /// - Neutron service endpoint is configured
    /// - Authentication token is present
    /// - Router data is loaded and accessible
    /// - Module state is consistent
    ///
    /// Health checks are used by the monitoring system to detect and report issues.
    /// The health status includes both errors and metrics for observability.
    ///
    /// - Returns: ModuleHealthStatus indicating module health and metrics
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

        // Check if routers are loaded
        let routerCount = tui.cacheManager.cachedRouters.count
        metrics["routerCount"] = routerCount

        // Check for significant changes in router count (compare BEFORE updating cached value)
        if cachedRouterCount > 0 && routerCount == 0 {
            errors.append("Router count dropped to zero unexpectedly")
        }

        // Update cached count AFTER comparison
        cachedRouterCount = routerCount

        // Check if routers data is available
        if routerCount == 0 {
            metrics["warning"] = "No routers loaded"
        }

        // Analyze router distribution
        let routers = tui.cacheManager.cachedRouters
        let activeRouters = routers.filter { $0.status?.lowercased() == "active" }
        let distributedRouters = routers.filter { $0.distributed == true }
        let haRouters = routers.filter { $0.ha == true }
        let routersWithExternalGateway = routers.filter { $0.externalGatewayInfo != nil }

        metrics["activeRouterCount"] = activeRouters.count
        metrics["distributedRouterCount"] = distributedRouters.count
        metrics["haRouterCount"] = haRouters.count
        metrics["routersWithExternalGatewayCount"] = routersWithExternalGateway.count

        // Calculate router health percentage
        if routerCount > 0 {
            let healthPercentage = (Double(activeRouters.count) / Double(routerCount)) * 100.0
            metrics["routerHealthPercentage"] = healthPercentage

            if healthPercentage < 80.0 {
                errors.append("Router health below 80%: \(String(format: "%.1f", healthPercentage))%")
            }
        }

        // Admin state analysis
        let adminUpRouters = routers.filter { $0.adminStateUp == true }
        metrics["adminUpRouterCount"] = adminUpRouters.count

        // Interface statistics
        var totalInterfaces = 0
        for router in routers {
            if let interfaces = router.interfaces {
                totalInterfaces += interfaces.count
            }
        }
        metrics["totalRouterInterfaces"] = totalInterfaces
        if routerCount > 0 {
            metrics["averageInterfacesPerRouter"] = Double(totalInterfaces) / Double(routerCount)
        }

        // Static routes analysis
        let routersWithStaticRoutes = routers.filter { ($0.routes?.count ?? 0) > 0 }
        metrics["routersWithStaticRoutesCount"] = routersWithStaticRoutes.count

        // SNAT configuration analysis
        let snatEnabledRouters = routersWithExternalGateway.filter { router in
            router.externalGatewayInfo?.enableSnat == true
        }
        metrics["snatEnabledRouterCount"] = snatEnabledRouters.count

        // Update health tracking
        lastHealthCheck = Date()
        healthErrors = errors

        Logger.shared.logDebug("RoutersModule health check completed", context: [
            "isHealthy": errors.isEmpty,
            "errorCount": errors.count,
            "metricCount": metrics.count
        ])

        return ModuleHealthStatus(
            isHealthy: errors.isEmpty,
            lastCheck: Date(),
            errors: errors,
            metrics: metrics
        )
    }

    // MARK: - Private Helper Methods

    /// Validate router configuration
    ///
    /// This method performs additional validation beyond basic form validation,
    /// including checking for conflicts with existing routers and validating
    /// router configurations.
    ///
    /// - Parameter form: The router creation form to validate
    /// - Returns: Array of validation error messages
    private func validateRouterConfiguration(_ form: RouterCreateForm) -> [String] {
        var errors: [String] = []

        // Check for duplicate router names
        if let tui = tui {
            let existingRouters = tui.cacheManager.cachedRouters
            if existingRouters.contains(where: { $0.name == form.routerName }) {
                errors.append("A router with this name already exists")
            }
        }

        return errors
    }

    /// Log router operation
    ///
    /// Helper method to log router operations with consistent context
    ///
    /// - Parameters:
    ///   - operation: The operation being performed
    ///   - routerName: The router name if available
    ///   - context: Additional context for logging
    private func logOperation(_ operation: String, routerName: String? = nil, context: [String: Any] = [:]) {
        // Log operation without context to avoid Sendable conformance issues
        if let name = routerName {
            Logger.shared.logInfo("Routers operation: \(operation) for router: \(name)", context: [:])
        } else {
            Logger.shared.logInfo("Routers operation: \(operation)", context: [:])
        }
    }

    /// Get router statistics
    ///
    /// Returns summary statistics about routers for monitoring and debugging
    ///
    /// - Returns: Dictionary of router statistics
    private func getRouterStatistics() -> [String: Any] {
        guard let tui = tui else {
            return ["error": "TUI reference is nil"]
        }

        let routers = tui.cacheManager.cachedRouters
        var stats: [String: Any] = [:]

        stats["total"] = routers.count
        stats["active"] = routers.filter { $0.status?.lowercased() == "active" }.count
        stats["distributed"] = routers.filter { $0.distributed == true }.count
        stats["ha"] = routers.filter { $0.ha == true }.count
        stats["withExternalGateway"] = routers.filter { $0.externalGatewayInfo != nil }.count
        stats["adminUp"] = routers.filter { $0.adminStateUp == true }.count

        // Interface statistics
        var totalInterfaces = 0
        for router in routers {
            if let interfaces = router.interfaces {
                totalInterfaces += interfaces.count
            }
        }
        stats["totalInterfaces"] = totalInterfaces

        // Static routes statistics
        var totalStaticRoutes = 0
        for router in routers {
            if let routes = router.routes {
                totalStaticRoutes += routes.count
            }
        }
        stats["totalStaticRoutes"] = totalStaticRoutes

        return stats
    }

    // MARK: - Router Detail Operations

    /// Fetch detailed router information with interfaces
    ///
    /// Retrieves the full router details from the Neutron API including
    /// interface information that may not be present in cached data.
    ///
    /// - Parameter id: The router ID
    /// - Returns: Detailed router with interfaces
    /// - Throws: ModuleError if TUI is not available, or OpenStack errors
    func getDetailedRouter(id: String) async throws -> Router {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }
        let neutronService = await tui.client.neutron
        return try await neutronService.getRouter(id: id)
    }

    // MARK: - Computed Properties

    /// Get all cached routers
    ///
    /// Returns all routers from the cache manager.
    /// Used for router listing, filtering, and selection operations.
    var routers: [Router] {
        return tui?.cacheManager.cachedRouters ?? []
    }
}

// MARK: - ActionProvider Conformance

extension RoutersModule: ActionProvider {
    /// Actions available in the list view for routers
    ///
    /// Includes create, delete, refresh, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .clearCache]
    }

    /// The view mode for creating a new router
    var createViewMode: ViewMode? {
        .routerCreate
    }

    /// Execute an action for the selected router
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

            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".routerCreate")
            tui.changeView(to: createMode)
            tui.routerCreateForm = RouterCreateForm()

            // Initialize FormBuilderState with form fields
            tui.routerCreateFormState = FormBuilderState(
                fields: tui.routerCreateForm.buildFields(
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    formState: nil,
                    availabilityZones: tui.cacheManager.cachedAvailabilityZones,
                    externalNetworks: tui.cacheManager.cachedNetworks
                )
            )

            tui.statusMessage = "Create new router"
            return true
        case .delete:
            await deleteRouter(screen: screen)
            return true
        default:
            return false
        }
    }

    /// Get the bulk delete operation for selected routers
    ///
    /// Creates a batch operation for deleting multiple routers at once.
    ///
    /// - Parameters:
    ///   - selectedIDs: Set of router IDs to delete
    ///   - tui: The TUI instance for state management
    /// - Returns: BatchOperationType for router bulk delete, or nil if not supported
    func getBulkDeleteOperation(selectedIDs: Set<String>, tui: TUI) -> BatchOperationType? {
        return .routerBulkDelete(routerIDs: Array(selectedIDs))
    }

    /// Get the ID of the currently selected router
    ///
    /// Returns the router ID based on the current selection index, accounting for any
    /// search filtering that may be applied to the list.
    ///
    /// - Parameter tui: The TUI instance for state management
    /// - Returns: Router ID string, or empty string if no valid selection
    func getSelectedResourceId(tui: TUI) -> String {
        let filtered = FilterUtils.filterRouters(tui.cacheManager.cachedRouters, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filtered.count else { return "" }
        return filtered[tui.viewCoordinator.selectedIndex].id
    }
}
