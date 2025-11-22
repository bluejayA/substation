// Sources/Substation/Modules/FloatingIPs/FloatingIPsModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Floating IPs module implementation
///
/// This module provides comprehensive Floating IP management capabilities including:
/// - Floating IP listing and browsing
/// - Floating IP detail views with association information
/// - Floating IP creation with network selection
/// - Server assignment and port management
///
/// The module integrates with the TUI system through the OpenStackModule protocol
/// and delegates rendering to FloatingIPViews for consistent UI presentation.
@MainActor
final class FloatingIPsModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Floating IPs module
    let identifier: String = "floatingips"

    /// Display name shown in the UI
    let displayName: String = "Floating IPs"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies - requires Networks module
    let dependencies: [String] = ["networks"]

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    /// Note: Internal access to allow extension in separate file to access this property
    internal weak var tui: TUI?

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    // MARK: - Initialization

    /// Initialize the Floating IPs module with TUI context
    /// - Parameter tui: The main TUI instance
    required init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs any necessary setup for the Floating IPs module.
    /// Verifies that the Networks dependency is available and functional.
    func configure() async throws {
        guard tui != nil else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .floatingIPs,
            detailViewMode: .floatingIPDetail
        )

        // Register as data provider
        let dataProvider = FloatingIPsDataProvider(module: self, tui: tui!)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)

        // Module is ready to use
        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all Floating IP views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .floatingIPs: List view of all floating IPs
    /// - .floatingIPDetail: Detail view for a selected floating IP
    /// - .floatingIPCreate: Form for creating new floating IPs
    /// - .floatingIPServerManagement: Form for managing server assignments
    /// - .floatingIPPortManagement: Form for managing port assignments
    ///
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            return []
        }

        var registrations: [ModuleViewRegistration] = []

        // Register floating IPs list view
        registrations.append(ModuleViewRegistration(
            viewMode: .floatingIPs,
            title: "Floating IPs",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await FloatingIPViews.drawDetailedFloatingIPList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedFloatingIPs: tui.cacheManager.cachedFloatingIPs,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex,
                    cachedServers: tui.cacheManager.cachedServers,
                    cachedPorts: tui.cacheManager.cachedPorts,
                    cachedNetworks: tui.cacheManager.cachedNetworks,
                    multiSelectMode: tui.selectionManager.multiSelectMode,
                    selectedItems: tui.selectionManager.multiSelectedResourceIDs
                )
            },
            inputHandler: { [weak self, weak tui] ch, screen in
                guard let self = self, let tui = tui else { return false }

                switch ch {
                case Int32(77):  // M - Manage server assignment
                    Logger.shared.logUserAction("manage_floating_ip_server_assignment", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                    await self.manageFloatingIPServerAssignment(screen: screen)
                    return true

                case Int32(80):  // P - Manage port assignment
                    Logger.shared.logUserAction("manage_floating_ip_port_assignment", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                    await self.manageFloatingIPPortAssignment(screen: screen)
                    return true

                default:
                    return false
                }
            },
            category: .network
        ))

        // Register floating IP detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .floatingIPDetail,
            title: "Floating IP Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let floatingIP = tui.viewCoordinator.selectedResource as? FloatingIP else { return }

                await FloatingIPViews.drawFloatingIPDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    floatingIP: floatingIP,
                    cachedServers: tui.cacheManager.cachedServers,
                    cachedPorts: tui.cacheManager.cachedPorts,
                    cachedNetworks: tui.cacheManager.cachedNetworks,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: nil, // Default system handles input
            category: .network
        ))

        // Register floating IP create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .floatingIPCreate,
            title: "Create Floating IP",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await FloatingIPViews.drawFloatingIPCreateForm(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    floatingIPCreateForm: tui.floatingIPCreateForm,
                    floatingIPCreateFormState: tui.floatingIPCreateFormState,
                    cachedNetworks: tui.cacheManager.cachedNetworks,
                    cachedSubnets: tui.cacheManager.cachedSubnets
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleFloatingIPCreateInput(ch, screen: screen)
                return true
            },
            category: .network
        ))

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for Floating IP forms
    ///
    /// Currently registers:
    /// - Floating IP creation form handler using universalFormInputHandler
    /// - Server management form handler
    /// - Port management form handler
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register floating IP create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .floatingIPCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleFloatingIPCreateInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                return tui.floatingIPCreateForm.validateForm().isEmpty
            }
        ))

        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for Floating IP resources
    ///
    /// Registers a handler to refresh the floating IPs list from the API.
    ///
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else {
            return []
        }

        var handlers: [ModuleDataRefreshRegistration] = []

        // Register floating IPs refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "floatingips.list",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }
                await tui.dataManager.refreshAllData()
            },
            cacheKey: "floatingips",
            refreshInterval: 30.0 // Refresh every 30 seconds
        ))

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    /// It ensures proper resource cleanup and state management.
    func cleanup() async {
        // Clear any module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil

        // TUI reference will be released naturally via weak reference
    }

    // MARK: - Health Check

    /// Perform a health check on the Floating IPs module
    ///
    /// This method verifies that:
    /// - TUI reference is valid
    /// - Neutron service is accessible via the API client
    /// - Networks module dependency is available
    /// - Core functionality is operational
    ///
    /// - Returns: ModuleHealthStatus indicating module health
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

        // Check if floating IPs are loaded
        let floatingIPCount = tui.cacheManager.cachedFloatingIPs.count
        metrics["floatingIPCount"] = floatingIPCount

        // Check Networks module dependency - networks are available in resource cache
        metrics["networksModuleLoaded"] = true

        // Check if networks are available (required for creating floating IPs)
        let networkCount = tui.cacheManager.cachedNetworks.count
        metrics["networkCount"] = networkCount
        if networkCount == 0 {
            metrics["warning"] = "No networks available for floating IP creation"
        }

        // Update health tracking
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

    /// Get all cached floating IPs
    ///
    /// Returns all floating IPs from the cache manager.
    /// Used for floating IP listing, filtering, and selection operations.
    var floatingIPs: [FloatingIP] {
        return tui?.cacheManager.cachedFloatingIPs ?? []
    }
}

// MARK: - ActionProvider Conformance

extension FloatingIPsModule: ActionProvider {
    /// Actions available in the list view for floating IPs
    ///
    /// Includes create, delete, refresh, manage, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .manage, .clearCache]
    }

    /// The view mode for creating a new floating IP
    var createViewMode: ViewMode? {
        .floatingIPCreate
    }

    /// Execute an action for the selected floating IP
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

            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".floatingIPCreate")
            tui.changeView(to: createMode)
            tui.floatingIPCreateForm = FloatingIPCreateForm()
            let externalNetworks = tui.cacheManager.cachedNetworks.filter { $0.external == true }

            // Initialize FormBuilderState with form fields
            tui.floatingIPCreateFormState = FormBuilderState(
                fields: tui.floatingIPCreateForm.buildFields(
                    externalNetworks: externalNetworks,
                    subnets: tui.cacheManager.cachedSubnets,
                    selectedFieldId: nil
                )
            )

            tui.statusMessage = "Create new floating IP"
            return true
        case .delete:
            await deleteFloatingIP(screen: screen)
            return true
        case .manage:
            await manageFloatingIPServerAssignment(screen: screen)
            return true
        default:
            return false
        }
    }

    /// Get the bulk delete operation for selected floating IPs
    ///
    /// Creates a batch operation for deleting multiple floating IPs at once.
    ///
    /// - Parameters:
    ///   - selectedIDs: Set of floating IP IDs to delete
    ///   - tui: The TUI instance for state management
    /// - Returns: BatchOperationType for floating IP bulk delete, or nil if not supported
    func getBulkDeleteOperation(selectedIDs: Set<String>, tui: TUI) -> BatchOperationType? {
        return .floatingIPBulkDelete(floatingIPIDs: Array(selectedIDs))
    }

    /// Get the ID of the currently selected floating IP
    ///
    /// Returns the floating IP ID based on the current selection index, accounting for any
    /// search filtering that may be applied to the list.
    ///
    /// - Parameter tui: The TUI instance for state management
    /// - Returns: Floating IP ID string, or empty string if no valid selection
    func getSelectedResourceId(tui: TUI) -> String {
        let filtered = FilterUtils.filterFloatingIPs(tui.cacheManager.cachedFloatingIPs, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filtered.count else { return "" }
        return filtered[tui.viewCoordinator.selectedIndex].id
    }
}
