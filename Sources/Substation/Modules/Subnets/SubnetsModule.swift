// Sources/Substation/Modules/Subnets/SubnetsModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Neutron Subnets module implementation
///
/// This module provides comprehensive subnet management capabilities including:
/// - Subnet listing and browsing with filtering and search
/// - Detailed subnet inspection with CIDR analysis and allocation pool information
/// - Subnet creation with IP version selection and DHCP configuration
/// - Router management for subnet connectivity
///
/// The Subnets module depends on the Networks module as subnets are always
/// associated with a parent network. It integrates with the TUI system through
/// the OpenStackModule protocol and delegates rendering to SubnetViews for
/// consistent UI presentation.
///
/// Key Features:
/// - IPv4 and IPv6 subnet support
/// - CIDR network analysis and IP allocation tracking
/// - DHCP configuration and DNS nameserver management
/// - Gateway IP configuration
/// - Allocation pool management for IP address ranges
/// - Host routes for custom routing tables
/// - Router interface attachment and detachment
/// - Integration with Networks module for parent network context
///
/// Dependencies:
/// - Networks module: Required for network association and parent network lookups
@MainActor
final class SubnetsModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Subnets module
    let identifier: String = "subnets"

    /// Display name shown in the UI
    let displayName: String = "Subnets (Neutron)"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies - Subnets depends on Networks as parent resource
    let dependencies: [String] = ["networks"]

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    private weak var tui: TUI?

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    /// Cached subnet count for performance monitoring
    private var cachedSubnetCount: Int = 0

    // MARK: - Initialization

    /// Initialize the Subnets module with TUI context
    /// - Parameter tui: The main TUI instance providing access to OpenStack client and UI state
    required init(tui: TUI) {
        self.tui = tui
        Logger.shared.logInfo("SubnetsModule initialized", context: [
            "version": version,
            "identifier": identifier,
            "dependencies": dependencies.joined(separator: ", ")
        ])
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs initialization tasks including:
    /// - Verifying Neutron service availability in service catalog
    /// - Validating subnet endpoint accessibility
    /// - Verifying Networks module dependency is loaded
    /// - Setting up initial health tracking
    ///
    /// The module will load even if Neutron is temporarily unavailable to allow
    /// for graceful degradation in multi-cloud or degraded environments.
    func configure() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        Logger.shared.logInfo("SubnetsModule configuration started", context: [:])

        // Module is ready for use
        Logger.shared.logInfo("SubnetsModule configuration completed", context: [:])

        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all subnet-related views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .subnets: Primary list view showing all subnets with network association
    /// - .subnetDetail: Detailed view for a selected subnet with CIDR analysis
    /// - .subnetCreate: Form for creating new subnets with validation
    /// - .subnetRouterManagement: Interface for attaching/detaching router interfaces
    ///
    /// Each view registration includes:
    /// - Render handler delegating to SubnetViews
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

        // Register subnets list view
        registrations.append(ModuleViewRegistration(
            viewMode: .subnets,
            title: "Subnets",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await SubnetViews.drawDetailedSubnetList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedSubnets: tui.resourceCache.subnets,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.scrollOffset,
                    selectedIndex: tui.selectedIndex,
                    multiSelectMode: tui.multiSelectMode,
                    selectedItems: tui.multiSelectedResourceIDs
                )
            },
            inputHandler: nil,
            category: .network
        ))

        // Register subnet detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .subnetDetail,
            title: "Subnet Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let subnet = tui.selectedResource as? Subnet else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No subnet selected").error(), on: surface, in: bounds)
                    return
                }

                await SubnetViews.drawSubnetDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    subnet: subnet,
                    scrollOffset: tui.detailScrollOffset
                )
            },
            inputHandler: nil,
            category: .network
        ))

        // Register subnet create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .subnetCreate,
            title: "Create Subnet",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await SubnetViews.drawSubnetCreate(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    subnetCreateForm: tui.subnetCreateForm,
                    cachedNetworks: tui.resourceCache.networks,
                    formState: tui.subnetCreateFormState
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleSubnetCreateInput(ch, screen: screen)
                return true
            },
            category: .network
        ))

        // Register subnet router management view
        registrations.append(ModuleViewRegistration(
            viewMode: .subnetRouterManagement,
            title: "Subnet Router Management",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let subnet = tui.selectedResource as? Subnet else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No subnet selected for router management").error(), on: surface, in: bounds)
                    return
                }

                // Render subnet detail view for router management
                await SubnetViews.drawSubnetDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    subnet: subnet,
                    scrollOffset: tui.scrollOffset
                )
            },
            inputHandler: nil,
            category: .network
        ))

        Logger.shared.logInfo("SubnetsModule registered \(registrations.count) views", context: [
            "viewCount": registrations.count
        ])

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for subnet operations
    ///
    /// This method registers form input handlers for:
    /// - Subnet creation form using universalFormInputHandler pattern
    /// - Router management form for interface operations
    ///
    /// The form handlers include:
    /// - Input processing through universal handler
    /// - Form validation before submission
    /// - Submission handling via ResourceOperations
    /// - Cancel handling returning to subnets list
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register form handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register subnet create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .subnetCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleSubnetCreateInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                // Subnet name, network, CIDR are required, IP version must be valid
                let errors = tui.subnetCreateForm.validate(availableNetworks: tui.resourceCache.networks)
                return errors.isEmpty
            }
        ))

        // Register subnet router management form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .subnetRouterManagement,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleSubnetRouterManagementInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                // Valid if a subnet is selected
                return tui.selectedResource is Subnet
            }
        ))

        Logger.shared.logInfo("SubnetsModule registered \(handlers.count) form handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for subnet resources
    ///
    /// This method registers handlers to refresh subnet data from the API.
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

        // Register subnets refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "subnets.list",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }

                Logger.shared.logDebug("Subnets refresh handler invoked", context: [:])

                // Trigger a full data refresh which includes subnets
                await tui.dataManager.refreshAllData()
                Logger.shared.logDebug("Subnets refreshed successfully", context: [
                    "subnetCount": tui.resourceCache.subnets.count
                ])
            },
            cacheKey: "subnets",
            refreshInterval: 60.0 // Refresh every 60 seconds
        ))

        Logger.shared.logInfo("SubnetsModule registered \(handlers.count) refresh handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    /// It performs the following cleanup tasks:
    /// - Clears cached subnet data
    /// - Resets health tracking state
    /// - Releases any module-specific resources
    ///
    /// The TUI reference is weak and will be released automatically.
    func cleanup() async {
        Logger.shared.logInfo("SubnetsModule cleanup started", context: [:])

        // Clear module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil
        cachedSubnetCount = 0

        // Clear cached subnet data if TUI is still available
        if let tui = tui {
            // Subnets are stored in ResourceCache, which manages its own lifecycle
            // We just log the cleanup
            Logger.shared.logDebug("SubnetsModule cleanup - cached subnets will be managed by ResourceCache", context: [
                "subnetCount": tui.resourceCache.subnets.count
            ])
        }

        Logger.shared.logInfo("SubnetsModule cleanup completed", context: [:])
    }

    // MARK: - Health Check

    /// Perform a health check on the Subnets module
    ///
    /// This method verifies that:
    /// - TUI reference is valid and accessible
    /// - Neutron service endpoint is configured
    /// - Authentication token is present
    /// - Subnet data is loaded and accessible
    /// - Networks module dependency is available
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

        // Check if subnets are loaded
        let subnetCount = tui.resourceCache.subnets.count
        metrics["subnetCount"] = subnetCount

        // Check for significant changes in subnet count
        if cachedSubnetCount > 0 && subnetCount == 0 {
            errors.append("Subnet count dropped to zero unexpectedly")
        }
        cachedSubnetCount = subnetCount

        // Check if subnets cache is populated
        if subnetCount > 0 {
            metrics["hasCachedSubnets"] = true
        } else {
            metrics["hasCachedSubnets"] = false
            Logger.shared.logDebug("No subnets in cache", context: [:])
        }

        // Check Networks module dependency
        let networks = tui.resourceCache.networks
        metrics["networkCount"] = networks.count
        if networks.isEmpty {
            Logger.shared.logWarning("Networks module has no data - subnets may not function correctly", context: [:])
        }

        // Analyze subnet distribution
        let subnets = tui.resourceCache.subnets
        let ipv4Subnets = subnets.filter { $0.ipVersion == 4 }
        let ipv6Subnets = subnets.filter { $0.ipVersion == 6 }
        let dhcpEnabledSubnets = subnets.filter { $0.dhcpEnabled == true || $0.enableDhcp == true }

        metrics["ipv4SubnetCount"] = ipv4Subnets.count
        metrics["ipv6SubnetCount"] = ipv6Subnets.count
        metrics["dhcpEnabledCount"] = dhcpEnabledSubnets.count

        // Calculate DHCP coverage percentage
        if subnetCount > 0 {
            let dhcpPercentage = (Double(dhcpEnabledSubnets.count) / Double(subnetCount)) * 100.0
            metrics["dhcpCoveragePercentage"] = dhcpPercentage
        }

        // Gateway configuration analysis
        let subnetsWithGateway = subnets.filter { subnet in
            if let gateway = subnet.gatewayIp, !gateway.isEmpty {
                return true
            }
            return false
        }
        metrics["subnetsWithGateway"] = subnetsWithGateway.count

        // Allocation pool analysis
        let subnetsWithPools = subnets.filter { subnet in
            (subnet.allocationPools?.count ?? 0) > 0
        }
        metrics["subnetsWithAllocationPools"] = subnetsWithPools.count

        // DNS nameserver analysis
        var totalDNSServers = 0
        for subnet in subnets {
            totalDNSServers += subnet.dnsNameservers?.count ?? 0
        }
        metrics["totalDNSServers"] = totalDNSServers
        if subnetCount > 0 {
            let avgDNSServers = Double(totalDNSServers) / Double(subnetCount)
            metrics["averageDNSServersPerSubnet"] = avgDNSServers
        }

        // Network association check
        var orphanedSubnets = 0
        for subnet in subnets {
            let hasNetwork = networks.contains { $0.id == subnet.networkId }
            if !hasNetwork {
                orphanedSubnets += 1
            }
        }
        metrics["orphanedSubnets"] = orphanedSubnets
        if orphanedSubnets > 0 {
            errors.append("Found \(orphanedSubnets) subnets without parent network in cache")
        }

        // Update health tracking
        lastHealthCheck = Date()
        healthErrors = errors

        Logger.shared.logDebug("SubnetsModule health check completed", context: [
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

    /// Validate subnet configuration
    ///
    /// This method performs additional validation beyond basic form validation,
    /// including checking for conflicts with existing subnets and validating
    /// CIDR ranges and IP allocation pools.
    ///
    /// - Parameter form: The subnet creation form to validate
    /// - Returns: Array of validation error messages
    private func validateSubnetConfiguration(_ form: SubnetCreateForm) -> [String] {
        var errors: [String] = []

        guard let tui = tui else {
            errors.append("TUI reference is nil")
            return errors
        }

        // Check for basic form completeness
        if form.subnetName.isEmpty {
            errors.append("Subnet name is required")
        }

        if form.cidr.isEmpty {
            errors.append("CIDR is required")
        }

        // Check if network is selected
        let networks = tui.resourceCache.networks
        if networks.isEmpty {
            errors.append("No networks available - please create a network first")
        }

        return errors
    }

    /// Log subnet operation
    ///
    /// Helper method to log subnet operations with consistent context
    ///
    /// - Parameters:
    ///   - operation: The operation being performed
    ///   - subnetName: The subnet name if available
    ///   - context: Additional context for logging
    private func logOperation(_ operation: String, subnetName: String? = nil, context: [String: Any] = [:]) {
        var logContext = context
        logContext["operation"] = operation
        logContext["module"] = identifier

        if let name = subnetName {
            logContext["subnetName"] = name
        }

        Logger.shared.logInfo("Subnets operation", context: [:])
    }

    /// Get subnet statistics
    ///
    /// Returns summary statistics about subnets for monitoring and debugging
    ///
    /// - Returns: Dictionary of subnet statistics
    private func getSubnetStatistics() -> [String: Any] {
        guard let tui = tui else {
            return ["error": "TUI reference is nil"]
        }

        let subnets = tui.resourceCache.subnets
        let networks = tui.resourceCache.networks
        var stats: [String: Any] = [:]

        stats["total"] = subnets.count
        stats["ipv4"] = subnets.filter { $0.ipVersion == 4 }.count
        stats["ipv6"] = subnets.filter { $0.ipVersion == 6 }.count
        stats["dhcpEnabled"] = subnets.filter { $0.dhcpEnabled == true || $0.enableDhcp == true }.count
        stats["withGateway"] = subnets.filter { subnet in
            if let gateway = subnet.gatewayIp, !gateway.isEmpty {
                return true
            }
            return false
        }.count

        // Network association
        var subnetsPerNetwork: [String: Int] = [:]
        for subnet in subnets {
            subnetsPerNetwork[subnet.networkId, default: 0] += 1
        }
        stats["networksWithSubnets"] = subnetsPerNetwork.count
        stats["maxSubnetsPerNetwork"] = subnetsPerNetwork.values.max() ?? 0

        // Allocation pools
        let totalPools = subnets.reduce(0) { count, subnet in
            count + (subnet.allocationPools?.count ?? 0)
        }
        stats["totalAllocationPools"] = totalPools

        return stats
    }
}
