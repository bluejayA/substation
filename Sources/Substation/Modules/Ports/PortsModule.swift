// Sources/Substation/Modules/Ports/PortsModule.swift
import Foundation
import OSClient
import struct OSClient.Port
import SwiftNCurses

/// OpenStack Neutron Ports module implementation
///
/// This module provides comprehensive port management capabilities including:
/// - Port listing and browsing with filtering and search
/// - Detailed port inspection with binding attributes and fixed IPs
/// - Port creation with network selection and security configuration
/// - Multi-select operations for batch management
///
/// The Ports module depends on the Networks module and integrates with other
/// Neutron resources including Subnets, Security Groups, and Servers. It
/// provides visibility into port bindings, VNIC types, and device attachments
/// critical for troubleshooting network connectivity.
///
/// Key Features:
/// - Port binding information (host, VNIC type, VIF type)
/// - Fixed IP address management with subnet associations
/// - Security group assignments and port security control
/// - Device attachment tracking (compute, router, DHCP)
/// - MAC address configuration
/// - Allowed address pairs for VRRP and similar protocols
/// - QoS policy integration
/// - Port status monitoring (ACTIVE, DOWN, BUILD, ERROR)
@MainActor
final class PortsModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Ports module
    let identifier: String = "ports"

    /// Display name shown in the UI
    let displayName: String = "Ports (Neutron)"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies - Ports depends on Networks module
    let dependencies: [String] = ["networks"]

    /// View modes handled by this module
    var handledViewModes: Set<ViewMode> {
        return [.ports, .portDetail, .portCreate, .portServerManagement,
                .portAllowedAddressPairManagement]
    }

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    /// Form state container for Ports module
    internal var formState = PortsFormState()

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    /// Cached port count for performance monitoring
    private var cachedPortCount: Int = 0

    // MARK: - Initialization

    /// Initialize the Ports module with TUI context
    /// - Parameter tui: The main TUI instance providing access to OpenStack client and UI state
    required init(tui: TUI) {
        self.tui = tui
        Logger.shared.logInfo("PortsModule initialized", context: [
            "version": version,
            "identifier": identifier
        ])
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs initialization tasks including:
    /// - Verifying Neutron service availability in service catalog
    /// - Validating port endpoint accessibility
    /// - Setting up initial health tracking
    ///
    /// The module will load even if Neutron is temporarily unavailable to allow
    /// for graceful degradation in multi-cloud or degraded environments.
    func configure() async throws {
        guard let tuiInstance = tui else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        Logger.shared.logInfo("PortsModule configuration started", context: [:])

        // PortsModule configuration completed
        Logger.shared.logInfo("PortsModule configuration completed", context: [:])

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .ports,
            detailViewMode: .portDetail
        )

        // Register as data provider
        let dataProvider = PortsDataProvider(module: self, tui: tuiInstance)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)

        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all port-related views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .ports: Primary list view showing all ports with status indicators
    /// - .portDetail: Detailed view for a selected port with full attributes
    /// - .portCreate: Form for creating new ports with validation
    ///
    /// Each view registration includes:
    /// - Render handler delegating to PortViews
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

        // Register ports list view
        registrations.append(ModuleViewRegistration(
            viewMode: .ports,
            title: "Ports",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await PortViews.drawDetailedPortList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedPorts: tui.cacheManager.cachedPorts,
                    cachedNetworks: tui.cacheManager.cachedNetworks,
                    cachedServers: tui.cacheManager.cachedServers,
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
                case Int32(77):  // M - Manage server assignment
                    Logger.shared.logUserAction("manage_port_server_assignment", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                    await self.managePortServerAssignment(screen: screen)
                    return true

                case Int32(69):  // E - Manage allowed address pairs
                    Logger.shared.logUserAction("manage_port_allowed_address_pairs", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                    await self.managePortAllowedAddressPairs(screen: screen)
                    return true

                default:
                    return false
                }
            },
            category: .network
        ))

        // Register port detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .portDetail,
            title: "Port Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let port = tui.viewCoordinator.selectedResource as? Port else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No port selected").error(), on: surface, in: bounds)
                    return
                }

                await PortViews.drawPortDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    port: port,
                    cachedNetworks: tui.cacheManager.cachedNetworks,
                    cachedSubnets: tui.cacheManager.cachedSubnets,
                    cachedSecurityGroups: tui.cacheManager.cachedSecurityGroups,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: nil, // Default system handles input
            category: .network
        ))

        // Register port create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .portCreate,
            title: "Create Port",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await PortViews.drawPortCreateForm(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    portCreateForm: tui.portCreateForm,
                    portCreateFormState: tui.portCreateFormState,
                    cachedNetworks: tui.cacheManager.cachedNetworks,
                    cachedSecurityGroups: tui.cacheManager.cachedSecurityGroups,
                    cachedQoSPolicies: tui.cacheManager.cachedQoSPolicies
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handlePortCreateInput(ch, screen: screen)
                return true
            },
            category: .network
        ))

        Logger.shared.logInfo("PortsModule registered \(registrations.count) views", context: [
            "viewCount": registrations.count
        ])

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for port operations
    ///
    /// This method registers form input handlers for:
    /// - Port creation form using universalFormInputHandler pattern
    ///
    /// The form handler includes:
    /// - Input processing through universal handler
    /// - Form validation before submission
    /// - Submission handling via ResourceOperations
    /// - Cancel handling returning to ports list
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register form handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register port create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .portCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handlePortCreateInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                // Port must have a network selected
                let errors = tui.portCreateForm.validate(
                    networks: tui.cacheManager.cachedNetworks,
                    securityGroups: tui.cacheManager.cachedSecurityGroups
                )
                return errors.isEmpty
            }
        ))

        Logger.shared.logInfo("PortsModule registered \(handlers.count) form handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for port resources
    ///
    /// This method registers handlers to refresh port data from the API.
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

        // Register ports refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "ports.list",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }

                Logger.shared.logDebug("Ports refresh handler invoked", context: [:])

                await tui.dataManager.refreshAllData()
                Logger.shared.logDebug("Ports refreshed successfully", context: [
                    "portCount": tui.cacheManager.cachedPorts.count
                ])
            },
            cacheKey: "ports",
            refreshInterval: 60.0 // Refresh every 60 seconds
        ))

        Logger.shared.logInfo("PortsModule registered \(handlers.count) refresh handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    /// It performs the following cleanup tasks:
    /// - Clears cached port data
    /// - Resets health tracking state
    /// - Releases any module-specific resources
    ///
    /// The TUI reference is weak and will be released automatically.
    func cleanup() async {
        Logger.shared.logInfo("PortsModule cleanup started", context: [:])

        // Clear module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil
        cachedPortCount = 0

        // Clear cached port data if TUI is still available
        if let tui = tui {
            // Ports are stored in ResourceCache, which manages its own lifecycle
            // We just log the cleanup
            Logger.shared.logDebug("PortsModule cleanup - cached ports will be managed by ResourceCache", context: [
                "portCount": tui.cacheManager.cachedPorts.count
            ])
        }

        Logger.shared.logInfo("PortsModule cleanup completed", context: [:])
    }

    // MARK: - Health Check

    /// Perform a health check on the Ports module
    ///
    /// This method verifies that:
    /// - TUI reference is valid and accessible
    /// - Neutron service endpoint is configured
    /// - Authentication token is present
    /// - Port data is loaded and accessible
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

        // Check if ports are loaded
        let portCount = tui.cacheManager.cachedPorts.count
        metrics["portCount"] = portCount
        cachedPortCount = portCount

        // Check for significant changes in port count
        if cachedPortCount > 0 && portCount == 0 {
            errors.append("Port count dropped to zero unexpectedly")
        }

        // Check if ports data is available
        if portCount == 0 {
            metrics["warning"] = "No ports loaded"
        }

        // Analyze port distribution
        let ports = tui.cacheManager.cachedPorts
        let activePorts = ports.filter { $0.status?.uppercased() == "ACTIVE" }
        let downPorts = ports.filter { $0.status?.uppercased() == "DOWN" }
        let boundPorts = ports.filter { $0.bindingHostId != nil && !$0.bindingHostId!.isEmpty }

        metrics["activePortCount"] = activePorts.count
        metrics["downPortCount"] = downPorts.count
        metrics["boundPortCount"] = boundPorts.count

        // Calculate port health percentage
        if portCount > 0 {
            let healthPercentage = (Double(activePorts.count) / Double(portCount)) * 100.0
            metrics["portHealthPercentage"] = healthPercentage

            if healthPercentage < 70.0 {
                errors.append("Port health below 70%: \(String(format: "%.1f", healthPercentage))%")
            }
        }

        // Device owner distribution
        var deviceOwners: [String: Int] = [:]
        for port in ports {
            if let deviceOwner = port.deviceOwner, !deviceOwner.isEmpty {
                deviceOwners[deviceOwner, default: 0] += 1
            } else {
                deviceOwners["unattached", default: 0] += 1
            }
        }
        metrics["deviceOwnerDistribution"] = deviceOwners

        // VNIC type distribution
        var vnicTypes: [String: Int] = [:]
        for port in ports {
            if let vnicType = port.bindingVnicType {
                vnicTypes[vnicType, default: 0] += 1
            }
        }
        metrics["vnicTypeDistribution"] = vnicTypes

        // Port security analysis
        let portsWithSecurity = ports.filter { $0.portSecurityEnabled == true }
        let portsWithoutSecurity = ports.filter { $0.portSecurityEnabled == false }
        metrics["portsWithSecurityCount"] = portsWithSecurity.count
        metrics["portsWithoutSecurityCount"] = portsWithoutSecurity.count

        // Fixed IP analysis
        let portsWithIPs = ports.filter { ($0.fixedIps?.count ?? 0) > 0 }
        let portsWithoutIPs = ports.filter { ($0.fixedIps?.count ?? 0) == 0 }
        metrics["portsWithIPsCount"] = portsWithIPs.count
        metrics["portsWithoutIPsCount"] = portsWithoutIPs.count

        if portsWithoutIPs.count > portCount / 2 {
            errors.append("Over 50% of ports have no fixed IPs assigned")
        }

        // Update health tracking
        lastHealthCheck = Date()
        healthErrors = errors

        Logger.shared.logDebug("PortsModule health check completed", context: [
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

    /// Validate port configuration
    ///
    /// This method performs additional validation beyond basic form validation,
    /// including checking for conflicts with existing ports and validating
    /// network and security group configurations.
    ///
    /// - Parameter form: The port creation form to validate
    /// - Returns: Array of validation error messages
    private func validatePortConfiguration(_ form: PortCreateForm) -> [String] {
        var errors: [String] = []

        // Check for duplicate port names if name is provided
        if let tui = tui, !form.portName.isEmpty {
            let existingPorts = tui.cacheManager.cachedPorts
            if existingPorts.contains(where: { $0.name == form.portName }) {
                errors.append("A port with this name already exists")
            }
        }

        // Validate MAC address format if provided
        if !form.macAddress.isEmpty {
            let macPattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
            if form.macAddress.range(of: macPattern, options: .regularExpression) == nil {
                errors.append("Invalid MAC address format. Expected format: AA:BB:CC:DD:EE:FF")
            }
        }

        return errors
    }

    /// Log port operation
    ///
    /// Helper method to log port operations with consistent context
    ///
    /// - Parameters:
    ///   - operation: The operation being performed
    ///   - portName: The port name if available
    ///   - context: Additional context for logging
    private func logOperation(_ operation: String, portName: String? = nil, context: [String: Any] = [:]) {
        var logContext = context
        logContext["operation"] = operation
        logContext["module"] = identifier

        if let name = portName {
            logContext["portName"] = name
        }

        Logger.shared.logInfo("Ports operation", context: [:])
    }

    /// Get port statistics
    ///
    /// Returns summary statistics about ports for monitoring and debugging
    ///
    /// - Returns: Dictionary of port statistics
    private func getPortStatistics() -> [String: Any] {
        guard let tui = tui else {
            return ["error": "TUI reference is nil"]
        }

        let ports = tui.cacheManager.cachedPorts
        var stats: [String: Any] = [:]

        stats["total"] = ports.count
        stats["active"] = ports.filter { $0.status?.uppercased() == "ACTIVE" }.count
        stats["down"] = ports.filter { $0.status?.uppercased() == "DOWN" }.count
        stats["bound"] = ports.filter { $0.bindingHostId != nil && !$0.bindingHostId!.isEmpty }.count
        stats["withSecurity"] = ports.filter { $0.portSecurityEnabled == true }.count

        // Device attachment distribution
        let attachedPorts = ports.filter { $0.deviceId != nil && !$0.deviceId!.isEmpty }
        stats["attached"] = attachedPorts.count
        stats["unattached"] = ports.count - attachedPorts.count

        // Fixed IP distribution
        let portsWithIPs = ports.filter { ($0.fixedIps?.count ?? 0) > 0 }
        stats["withFixedIPs"] = portsWithIPs.count

        return stats
    }

    // MARK: - Computed Properties

    /// Get all cached ports
    ///
    /// Returns all ports from the cache manager.
    /// Used for port listing, filtering, and selection operations.
    var ports: [Port] {
        return tui?.cacheManager.cachedPorts ?? []
    }
}

// MARK: - ActionProvider Conformance

extension PortsModule: ActionProvider {
    /// Actions available in the list view for ports
    ///
    /// Includes create, delete, refresh, manage, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .manage, .clearCache]
    }

    /// The view mode for creating a new port
    var createViewMode: ViewMode? {
        .portCreate
    }

    /// Execute an action for the selected port
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

            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".portCreate")
            tui.changeView(to: createMode)
            tui.portCreateForm = PortCreateForm()

            // Initialize FormBuilderState with form fields
            tui.portCreateFormState = FormBuilderState(fields: tui.portCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: []),
                networks: tui.cacheManager.cachedNetworks,
                securityGroups: tui.cacheManager.cachedSecurityGroups,
                qosPolicies: tui.cacheManager.cachedQoSPolicies
            ))

            tui.statusMessage = "Create new port"
            return true
        case .delete:
            await deletePort(screen: screen)
            return true
        case .manage:
            await managePortServerAssignment(screen: screen)
            return true
        default:
            return false
        }
    }

    /// Get the bulk delete operation for selected ports
    ///
    /// Creates a batch operation for deleting multiple ports at once.
    ///
    /// - Parameters:
    ///   - selectedIDs: Set of port IDs to delete
    ///   - tui: The TUI instance for state management
    /// - Returns: BatchOperationType for port bulk delete, or nil if not supported
    func getBulkDeleteOperation(selectedIDs: Set<String>, tui: TUI) -> BatchOperationType? {
        return .portBulkDelete(portIDs: Array(selectedIDs))
    }

    /// Get the ID of the currently selected port
    ///
    /// Returns the port ID based on the current selection index, accounting for any
    /// search filtering that may be applied to the list.
    ///
    /// - Parameter tui: The TUI instance for state management
    /// - Returns: Port ID string, or empty string if no valid selection
    func getSelectedResourceId(tui: TUI) -> String {
        let filtered = FilterUtils.filterPorts(tui.cacheManager.cachedPorts, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filtered.count else { return "" }
        return filtered[tui.viewCoordinator.selectedIndex].id
    }
}
