// Sources/Substation/Modules/Networks/NetworksModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Neutron Networks module implementation
///
/// This module provides comprehensive network management capabilities including:
/// - Network listing and browsing with filtering and search
/// - Detailed network inspection with provider attributes and segments
/// - Network creation with advanced configuration options
/// - Multi-select operations for batch management
///
/// The Networks module is a foundational dependency for other Neutron resources
/// including Subnets, Routers, Floating IPs, and Ports. It integrates with the
/// TUI system through the OpenStackModule protocol and delegates rendering to
/// NetworkViews for consistent UI presentation.
///
/// Key Features:
/// - Provider network attributes (VLAN, VXLAN, Flat, GRE, Geneve)
/// - Multi-segment network support
/// - MTU configuration and validation
/// - Port security management
/// - External network identification
/// - Shared network visibility
/// - QoS policy integration
/// - Availability zone awareness
@MainActor
final class NetworksModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Networks module
    let identifier: String = "networks"

    /// Display name shown in the UI
    let displayName: String = "Networks (Neutron)"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies - Networks has no dependencies as it is a base module
    let dependencies: [String] = []

    /// View modes handled by this module
    var handledViewModes: Set<ViewMode> {
        return [.networks, .networkDetail, .networkCreate, .networkServerAttachment]
    }

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    /// Form state container for Networks module
    internal var formState = NetworksFormState()

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    /// Cached network count for performance monitoring
    private var cachedNetworkCount: Int = 0

    // MARK: - Initialization

    /// Initialize the Networks module with TUI context
    /// - Parameter tui: The main TUI instance providing access to OpenStack client and UI state
    required init(tui: TUI) {
        self.tui = tui
        Logger.shared.logInfo("NetworksModule initialized", context: [
            "version": version,
            "identifier": identifier
        ])
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs initialization tasks including:
    /// - Verifying Neutron service availability in service catalog
    /// - Validating network endpoint accessibility
    /// - Setting up initial health tracking
    ///
    /// The module will load even if Neutron is temporarily unavailable to allow
    /// for graceful degradation in multi-cloud or degraded environments.
    func configure() async throws {
        guard let tuiInstance = tui else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        Logger.shared.logInfo("NetworksModule configuration started", context: [:])

        // NetworksModule configuration completed
        Logger.shared.logInfo("NetworksModule configuration completed", context: [:])

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .networks,
            detailViewMode: .networkDetail
        )

        // Register as data provider
        let dataProvider = NetworksDataProvider(module: self, tui: tuiInstance)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)

        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all network-related views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .networks: Primary list view showing all networks with status indicators
    /// - .networkDetail: Detailed view for a selected network with full attributes
    /// - .networkCreate: Form for creating new networks with validation
    ///
    /// Each view registration includes:
    /// - Render handler delegating to NetworkViews
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

        // Register networks list view
        registrations.append(ModuleViewRegistration(
            viewMode: .networks,
            title: "Networks",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await NetworkViews.drawDetailedNetworkList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedNetworks: tui.cacheManager.cachedNetworks,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex,
                    dataManager: tui.dataManager,
                    virtualScrollManager: nil,
                    multiSelectMode: tui.selectionManager.multiSelectMode,
                    selectedItems: tui.selectionManager.multiSelectedResourceIDs
                )
            },
            inputHandler: nil,
            category: .network
        ))

        // Register network detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .networkDetail,
            title: "Network Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let network = tui.viewCoordinator.selectedResource as? Network else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No network selected").error(), on: surface, in: bounds)
                    return
                }

                await NetworkViews.drawNetworkDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    network: network,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: nil, // Default system handles input
            category: .network
        ))

        // Register network create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .networkCreate,
            title: "Create Network",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await NetworkViews.drawNetworkCreate(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    networkCreateForm: tui.networkCreateForm,
                    networkCreateFormState: tui.networkCreateFormState
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleNetworkCreateInput(ch, screen: screen)
                return true
            },
            category: .network
        ))

        Logger.shared.logInfo("NetworksModule registered \(registrations.count) views", context: [
            "viewCount": registrations.count
        ])

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for network operations
    ///
    /// This method registers form input handlers for:
    /// - Network creation form using universalFormInputHandler pattern
    ///
    /// The form handler includes:
    /// - Input processing through universal handler
    /// - Form validation before submission
    /// - Submission handling via ResourceOperations
    /// - Cancel handling returning to networks list
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register form handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register network create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .networkCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleNetworkCreateInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                // Network name is required, MTU must be valid if provided
                let errors = tui.networkCreateForm.validateForm()
                return errors.isEmpty
            }
        ))

        Logger.shared.logInfo("NetworksModule registered \(handlers.count) form handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for network resources
    ///
    /// This method registers handlers to refresh network data from the API.
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

        // Register networks refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "networks.list",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }

                Logger.shared.logDebug("Networks refresh handler invoked", context: [:])

                await tui.dataManager.refreshAllData()
                Logger.shared.logDebug("Networks refreshed successfully", context: [
                    "networkCount": tui.cacheManager.cachedNetworks.count
                ])
            },
            cacheKey: "networks",
            refreshInterval: 60.0 // Refresh every 60 seconds
        ))

        Logger.shared.logInfo("NetworksModule registered \(handlers.count) refresh handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    /// It performs the following cleanup tasks:
    /// - Clears cached network data
    /// - Resets health tracking state
    /// - Releases any module-specific resources
    ///
    /// The TUI reference is weak and will be released automatically.
    func cleanup() async {
        Logger.shared.logInfo("NetworksModule cleanup started", context: [:])

        // Clear module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil
        cachedNetworkCount = 0

        // Clear cached network data if TUI is still available
        if let tui = tui {
            // Networks are stored in ResourceCache, which manages its own lifecycle
            // We just log the cleanup
            Logger.shared.logDebug("NetworksModule cleanup - cached networks will be managed by ResourceCache", context: [
                "networkCount": tui.cacheManager.cachedNetworks.count
            ])
        }

        Logger.shared.logInfo("NetworksModule cleanup completed", context: [:])
    }

    // MARK: - Health Check

    /// Perform a health check on the Networks module
    ///
    /// This method verifies that:
    /// - TUI reference is valid and accessible
    /// - Neutron service endpoint is configured
    /// - Authentication token is present
    /// - Network data is loaded and accessible
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

        // Check if networks are loaded
        let networkCount = tui.cacheManager.cachedNetworks.count
        metrics["networkCount"] = networkCount

        // Check for significant changes in network count (compare BEFORE updating cached value)
        if cachedNetworkCount > 0 && networkCount == 0 {
            errors.append("Network count dropped to zero unexpectedly")
        }

        // Update cached count AFTER comparison
        cachedNetworkCount = networkCount

        // Check if networks data is available
        if networkCount == 0 {
            metrics["warning"] = "No networks loaded"
        }

        // Analyze network distribution
        let networks = tui.cacheManager.cachedNetworks
        let externalNetworks = networks.filter { $0.external == true }
        let sharedNetworks = networks.filter { $0.shared == true }
        let activeNetworks = networks.filter { $0.status?.lowercased() == "active" }

        metrics["externalNetworkCount"] = externalNetworks.count
        metrics["sharedNetworkCount"] = sharedNetworks.count
        metrics["activeNetworkCount"] = activeNetworks.count

        // Calculate network health percentage
        if networkCount > 0 {
            let healthPercentage = (Double(activeNetworks.count) / Double(networkCount)) * 100.0
            metrics["networkHealthPercentage"] = healthPercentage

            if healthPercentage < 80.0 {
                errors.append("Network health below 80%: \(String(format: "%.1f", healthPercentage))%")
            }
        }

        // Provider network type distribution
        var providerTypes: [String: Int] = [:]
        for network in networks {
            if let providerType = network.providerNetworkType {
                providerTypes[providerType, default: 0] += 1
            }
        }
        metrics["providerNetworkTypes"] = providerTypes

        // MTU analysis
        let mtuValues = networks.compactMap { $0.mtu }
        if !mtuValues.isEmpty {
            let avgMTU = mtuValues.reduce(0, +) / mtuValues.count
            metrics["averageMTU"] = avgMTU
        }

        // Update health tracking
        lastHealthCheck = Date()
        healthErrors = errors

        Logger.shared.logDebug("NetworksModule health check completed", context: [
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

    /// Validate network configuration
    ///
    /// This method performs additional validation beyond basic form validation,
    /// including checking for conflicts with existing networks and validating
    /// provider network configurations.
    ///
    /// - Parameter form: The network creation form to validate
    /// - Returns: Array of validation error messages
    private func validateNetworkConfiguration(_ form: NetworkCreateForm) -> [String] {
        var errors: [String] = []

        // Check for duplicate network names
        if let tui = tui {
            let existingNetworks = tui.cacheManager.cachedNetworks
            if existingNetworks.contains(where: { $0.name == form.networkName }) {
                errors.append("A network with this name already exists")
            }
        }

        // Validate MTU range
        if let mtuValue = Int(form.mtu) {
            if mtuValue < 68 || mtuValue > 9000 {
                errors.append("MTU must be between 68 and 9000")
            }

            // Warn about common MTU issues
            if mtuValue > 1500 && mtuValue < 9000 {
                Logger.shared.logWarning("MTU value between standard and jumbo frames", context: [
                    "mtu": mtuValue,
                    "recommendation": "Use 1500 for standard or 9000 for jumbo frames"
                ])
            }
        }

        return errors
    }

    /// Log network operation
    ///
    /// Helper method to log network operations with consistent context
    ///
    /// - Parameters:
    ///   - operation: The operation being performed
    ///   - networkName: The network name if available
    ///   - context: Additional context for logging
    private func logOperation(_ operation: String, networkName: String? = nil, context: [String: any Sendable] = [:]) {
        var logContext: [String: any Sendable] = context
        logContext["operation"] = operation
        logContext["module"] = identifier

        if let name = networkName {
            logContext["networkName"] = name
        }

        Logger.shared.logInfo("Networks operation", context: logContext)
    }

    /// Get network statistics
    ///
    /// Returns summary statistics about networks for monitoring and debugging
    ///
    /// - Returns: Dictionary of network statistics
    private func getNetworkStatistics() -> [String: Any] {
        guard let tui = tui else {
            return ["error": "TUI reference is nil"]
        }

        let networks = tui.cacheManager.cachedNetworks
        var stats: [String: Any] = [:]

        stats["total"] = networks.count
        stats["external"] = networks.filter { $0.external == true }.count
        stats["shared"] = networks.filter { $0.shared == true }.count
        stats["active"] = networks.filter { $0.status?.lowercased() == "active" }.count
        stats["withPortSecurity"] = networks.filter { $0.portSecurityEnabled == true }.count

        // Segment distribution
        let segmentedNetworks = networks.filter { ($0.segments?.count ?? 0) > 0 }
        stats["segmented"] = segmentedNetworks.count

        // Subnet distribution
        let networksWithSubnets = networks.filter { ($0.subnets?.count ?? 0) > 0 }
        stats["withSubnets"] = networksWithSubnets.count

        return stats
    }

    // MARK: - Computed Properties

    /// Get external networks from cache
    ///
    /// Returns all networks marked as external from the cached networks.
    /// External networks are used for floating IP allocation and router gateways.
    var externalNetworks: [Network] {
        return tui?.cacheManager.cachedNetworks.filter { $0.external == true } ?? []
    }

    /// Get all cached networks
    ///
    /// Returns all networks from the cache manager.
    /// Used for network listing, filtering, and selection operations.
    var networks: [Network] {
        return tui?.cacheManager.cachedNetworks ?? []
    }
}

// MARK: - ActionProvider Conformance

extension NetworksModule: ActionProvider {
    /// Actions available in the list view for networks
    ///
    /// Includes create, delete, refresh, manage, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .manage, .clearCache]
    }

    /// The view mode for creating a new network
    var createViewMode: ViewMode? {
        .networkCreate
    }

    /// Execute an action for the selected network
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

            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".networkCreate")
            tui.changeView(to: createMode)
            tui.networkCreateForm = NetworkCreateForm()

            // Initialize FormBuilderState with form fields
            tui.networkCreateFormState = FormBuilderState(fields: tui.networkCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))

            tui.statusMessage = "Create new network"
            return true
        case .delete:
            await deleteNetwork(screen: screen)
            return true
        case .manage:
            await manageNetworkToServers(screen: screen)
            return true
        default:
            return false
        }
    }

    /// Get the bulk delete operation for selected networks
    ///
    /// Creates a batch operation for deleting multiple networks at once.
    ///
    /// - Parameters:
    ///   - selectedIDs: Set of network IDs to delete
    ///   - tui: The TUI instance for state management
    /// - Returns: BatchOperationType for network bulk delete, or nil if not supported
    func getBulkDeleteOperation(selectedIDs: Set<String>, tui: TUI) -> BatchOperationType? {
        return .networkBulkDelete(networkIDs: Array(selectedIDs))
    }

    /// Get the ID of the currently selected network
    ///
    /// Returns the network ID based on the current selection index, accounting for any
    /// search filtering that may be applied to the list.
    ///
    /// - Parameter tui: The TUI instance for state management
    /// - Returns: Network ID string, or empty string if no valid selection
    func getSelectedResourceId(tui: TUI) -> String {
        let filtered = FilterUtils.filterNetworks(tui.cacheManager.cachedNetworks, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filtered.count else { return "" }
        return filtered[tui.viewCoordinator.selectedIndex].id
    }
}
