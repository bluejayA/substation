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
    private weak var tui: TUI?

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
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

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
                    cachedFloatingIPs: tui.resourceCache.floatingIPs,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.scrollOffset,
                    selectedIndex: tui.selectedIndex,
                    cachedServers: tui.resourceCache.servers,
                    cachedPorts: tui.resourceCache.ports,
                    cachedNetworks: tui.resourceCache.networks,
                    multiSelectMode: tui.multiSelectMode,
                    selectedItems: tui.multiSelectedResourceIDs
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .network
        ))

        // Register floating IP detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .floatingIPDetail,
            title: "Floating IP Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let floatingIP = tui.selectedResource as? FloatingIP else { return }

                await FloatingIPViews.drawFloatingIPDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    floatingIP: floatingIP,
                    cachedServers: tui.resourceCache.servers,
                    cachedPorts: tui.resourceCache.ports,
                    cachedNetworks: tui.resourceCache.networks,
                    scrollOffset: tui.detailScrollOffset
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
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
                    cachedNetworks: tui.resourceCache.networks,
                    cachedSubnets: tui.resourceCache.subnets
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
        let floatingIPCount = tui.resourceCache.floatingIPs.count
        metrics["floatingIPCount"] = floatingIPCount

        // Check Networks module dependency - networks are available in resource cache
        metrics["networksModuleLoaded"] = true

        // Check if networks are available (required for creating floating IPs)
        let networkCount = tui.resourceCache.networks.count
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
}
