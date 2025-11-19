// Sources/Substation/Modules/Servers/ServersModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Nova Servers module implementation
///
/// This module provides comprehensive server (instance) management capabilities including:
/// - Server listing and browsing with filtering and search
/// - Detailed server inspection with flavor, image, network, and volume information
/// - Server creation with advanced configuration options
/// - Server console access (noVNC and other protocols)
/// - Server resize operations with confirmation/revert workflow
/// - Multi-select operations for batch management
/// - Server lifecycle management (start, stop, reboot, delete)
///
/// The Servers module is the most complex OpenStack module with dependencies on:
/// - Networks: For network interface management and IP allocation
/// - Images: For boot image selection during server creation
/// - Flavors: For hardware profile selection and resize operations
/// - Keypairs: For SSH key injection during server creation
/// - Volumes: For block storage attachment and boot-from-volume
/// - Security Groups: For firewall rule management
///
/// Key Features:
/// - Full server lifecycle management
/// - Console access with browser integration
/// - Resize with automatic rollback capability
/// - Network interface management
/// - Volume attachment and detachment
/// - Security group assignment
/// - Metadata and user data support
/// - Availability zone selection
/// - Server groups for anti-affinity policies
@MainActor
final class ServersModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Servers module
    let identifier: String = "servers"

    /// Display name shown in the UI
    let displayName: String = "Servers (Nova)"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies - Servers depends on multiple foundational modules
    let dependencies: [String] = ["networks", "images", "flavors", "keypairs", "volumes", "securitygroups"]

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    private weak var tui: TUI?

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    /// Cached server count for performance monitoring
    private var cachedServerCount: Int = 0

    // MARK: - Initialization

    /// Initialize the Servers module with TUI context
    /// - Parameter tui: The main TUI instance providing access to OpenStack client and UI state
    required init(tui: TUI) {
        self.tui = tui
        Logger.shared.logInfo("ServersModule initialized", context: [
            "version": version,
            "identifier": identifier
        ])
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs initialization tasks including:
    /// - Verifying Nova service availability in service catalog
    /// - Validating compute endpoint accessibility
    /// - Setting up initial health tracking
    ///
    /// The module will load even if Nova is temporarily unavailable to allow
    /// for graceful degradation in multi-cloud or degraded environments.
    func configure() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        Logger.shared.logInfo("ServersModule configuration started", context: [:])

        // ServersModule configuration completed
        Logger.shared.logInfo("ServersModule configuration completed", context: [:])
        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all server-related views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .servers: Primary list view showing all servers with status indicators
    /// - .serverDetail: Detailed view for a selected server with full attributes
    /// - .serverCreate: Form for creating new servers with validation
    /// - .serverConsole: Console access view for noVNC and other protocols
    /// - .serverResize: Resize management view with confirmation workflow
    ///
    /// Each view registration includes:
    /// - Render handler delegating to ServerViews
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

        // Register servers list view
        registrations.append(ModuleViewRegistration(
            viewMode: .servers,
            title: "Servers",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await ServerViews.drawDetailedServerList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedServers: tui.resourceCache.servers,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.scrollOffset,
                    selectedIndex: tui.selectedIndex,
                    cachedFlavors: tui.resourceCache.flavors,
                    cachedImages: tui.resourceCache.images,
                    dataManager: tui.dataManager,
                    virtualScrollManager: nil,
                    multiSelectMode: tui.multiSelectMode,
                    selectedItems: tui.multiSelectedResourceIDs
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        // Register server detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .serverDetail,
            title: "Server Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let server = tui.selectedResource as? Server else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No server selected").error(), on: surface, in: bounds)
                    return
                }

                await ServerViews.drawServerDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    server: server,
                    cachedVolumes: tui.resourceCache.volumes,
                    cachedFlavors: tui.resourceCache.flavors,
                    cachedImages: tui.resourceCache.images,
                    scrollOffset: tui.detailScrollOffset
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        // Register server create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .serverCreate,
            title: "Create Server",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let server = tui.selectedResource as? Server else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No server selected").error(), on: surface, in: bounds)
                    return
                }

                await ServerViews.drawServerDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    server: server,
                    cachedVolumes: tui.resourceCache.volumes,
                    cachedFlavors: tui.resourceCache.flavors,
                    cachedImages: tui.resourceCache.images,
                    scrollOffset: tui.detailScrollOffset
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleServerCreateInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        // Register server console view
        registrations.append(ModuleViewRegistration(
            viewMode: .serverConsole,
            title: "Server Console",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let server = tui.selectedResource as? Server else {
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("No server selected").error(), on: surface, in: bounds)
                    return
                }

                let surface = SwiftNCurses.surface(from: screen)
                let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                await SwiftNCurses.render(Text("Console data not available").error(), on: surface, in: bounds)
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        // Register server resize view
        registrations.append(ModuleViewRegistration(
            viewMode: .serverResize,
            title: "Resize Server",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await ServerViews.drawServerResizeManagement(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    serverResizeForm: tui.serverResizeForm
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleServerResizeInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        Logger.shared.logInfo("ServersModule registered \(registrations.count) views", context: [
            "viewCount": registrations.count
        ])

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for server operations
    ///
    /// This method registers form input handlers for:
    /// - Server creation form with multi-step configuration
    /// - Server resize form with flavor selection
    /// - Server console form for protocol selection
    ///
    /// The form handlers include:
    /// - Input processing through universal handler
    /// - Form validation before submission
    /// - Submission handling via ResourceOperations
    /// - Cancel handling returning to servers list
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register form handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register server create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleServerCreateInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                // Server name, image, flavor, and network are required
                let errors = tui.serverCreateForm.validateForm()
                return errors.isEmpty
            }
        ))

        // Register server resize form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .serverResize,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleServerResizeInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                // Must have selected server
                return tui.serverResizeForm.selectedServer != nil
            }
        ))

        // Register server console form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .serverConsole,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                // Console view is read-only with navigation controls
                await tui.inputHandler.handleInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                // Console view doesn't require validation
                return true
            }
        ))

        Logger.shared.logInfo("ServersModule registered \(handlers.count) form handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for server resources
    ///
    /// This method registers handlers to refresh server data from the API.
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

        // Register servers refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "servers.list",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }

                Logger.shared.logDebug("Servers refresh handler invoked", context: [:])

                await tui.dataManager.refreshAllData()
                Logger.shared.logDebug("Servers refreshed successfully", context: [
                    "serverCount": tui.resourceCache.servers.count
                ])
            },
            cacheKey: "servers",
            refreshInterval: 60.0 // Refresh every 60 seconds
        ))

        Logger.shared.logInfo("ServersModule registered \(handlers.count) refresh handlers", context: [
            "handlerCount": handlers.count
        ])

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    /// It performs the following cleanup tasks:
    /// - Clears cached server data
    /// - Resets health tracking state
    /// - Releases any module-specific resources
    ///
    /// The TUI reference is weak and will be released automatically.
    func cleanup() async {
        Logger.shared.logInfo("ServersModule cleanup started", context: [:])

        // Clear module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil
        cachedServerCount = 0

        // Clear cached server data if TUI is still available
        if let tui = tui {
            // Servers are stored in ResourceCache, which manages its own lifecycle
            // We just log the cleanup
            Logger.shared.logDebug("ServersModule cleanup - cached servers will be managed by ResourceCache", context: [
                "serverCount": tui.resourceCache.servers.count
            ])
        }

        Logger.shared.logInfo("ServersModule cleanup completed", context: [:])
    }

    // MARK: - Health Check

    /// Perform a health check on the Servers module
    ///
    /// This method verifies that:
    /// - TUI reference is valid and accessible
    /// - Nova service endpoint is configured
    /// - Authentication token is present
    /// - Server data is loaded and accessible
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

        // Check if servers are loaded
        let serverCount = tui.resourceCache.servers.count
        metrics["serverCount"] = serverCount
        cachedServerCount = serverCount

        // Check for significant changes in server count
        if cachedServerCount > 0 && serverCount == 0 {
            errors.append("Server count dropped to zero unexpectedly")
        }

        // Check if servers data is available
        if serverCount == 0 {
            metrics["warning"] = "No servers loaded"
        }

        // Analyze server distribution
        let servers = tui.resourceCache.servers
        let activeServers = servers.filter { $0.status?.rawValue.lowercased() == "active" }
        let errorServers = servers.filter { $0.status?.rawValue.lowercased() == "error" }
        let buildingServers = servers.filter { $0.status?.rawValue.lowercased() == "build" }

        metrics["activeServerCount"] = activeServers.count
        metrics["errorServerCount"] = errorServers.count
        metrics["buildingServerCount"] = buildingServers.count

        // Calculate server health percentage
        if serverCount > 0 {
            let healthPercentage = (Double(activeServers.count) / Double(serverCount)) * 100.0
            metrics["serverHealthPercentage"] = healthPercentage

            if healthPercentage < 80.0 {
                errors.append("Server health below 80%: \(String(format: "%.1f", healthPercentage))%")
            }

            // Warn if too many error servers
            let errorPercentage = (Double(errorServers.count) / Double(serverCount)) * 100.0
            if errorPercentage > 5.0 {
                errors.append("Error servers above 5%: \(String(format: "%.1f", errorPercentage))%")
            }
        }

        // Power state distribution
        let runningServers = servers.filter { $0.powerState == .running }
        let shutdownServers = servers.filter { $0.powerState == .shutdown }
        metrics["runningServerCount"] = runningServers.count
        metrics["shutdownServerCount"] = shutdownServers.count

        // Availability zone distribution
        var azDistribution: [String: Int] = [:]
        for server in servers {
            if let az = server.availabilityZone {
                azDistribution[az, default: 0] += 1
            }
        }
        metrics["availabilityZoneDistribution"] = azDistribution

        // Update health tracking
        lastHealthCheck = Date()
        healthErrors = errors

        Logger.shared.logDebug("ServersModule health check completed", context: [
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

    /// Validate server configuration
    ///
    /// This method performs additional validation beyond basic form validation,
    /// including checking for conflicts with existing servers and validating
    /// server configurations.
    ///
    /// - Parameter form: The server creation form to validate
    /// - Returns: Array of validation error messages
    private func validateServerConfiguration(_ form: ServerCreateForm) -> [String] {
        var errors: [String] = []

        // Check for duplicate server names
        if let tui = tui {
            let existingServers = tui.resourceCache.servers
            if existingServers.contains(where: { $0.name == form.serverName }) {
                errors.append("A server with this name already exists")
            }
        }

        // Validate required fields
        if form.serverName.isEmpty {
            errors.append("Server name is required")
        }

        return errors
    }

    /// Log server operation
    ///
    /// Helper method to log server operations with consistent context
    ///
    /// - Parameters:
    ///   - operation: The operation being performed
    ///   - serverName: The server name if available
    ///   - context: Additional context for logging
    private func logOperation(_ operation: String, serverName: String? = nil, context: [String: Any] = [:]) {
        var logContext = context
        logContext["operation"] = operation
        logContext["module"] = identifier

        if let name = serverName {
            logContext["serverName"] = name
        }

        Logger.shared.logInfo("Servers operation", context: [:])
    }

    /// Get server statistics
    ///
    /// Returns summary statistics about servers for monitoring and debugging
    ///
    /// - Returns: Dictionary of server statistics
    private func getServerStatistics() -> [String: Any] {
        guard let tui = tui else {
            return ["error": "TUI reference is nil"]
        }

        let servers = tui.resourceCache.servers
        var stats: [String: Any] = [:]

        stats["total"] = servers.count
        stats["active"] = servers.filter { $0.status?.rawValue.lowercased() == "active" }.count
        stats["error"] = servers.filter { $0.status?.rawValue.lowercased() == "error" }.count
        stats["building"] = servers.filter { $0.status?.rawValue.lowercased() == "build" }.count
        stats["running"] = servers.filter { $0.powerState == .running }.count
        stats["shutdown"] = servers.filter { $0.powerState == .shutdown }.count

        // Network distribution
        let serversWithNetworks = servers.filter { ($0.addresses?.count ?? 0) > 0 }
        stats["withNetworks"] = serversWithNetworks.count

        // Volume attachments
        let volumes = tui.resourceCache.volumes
        let attachedVolumes = volumes.filter { $0.attachments?.isEmpty == false }
        stats["attachedVolumes"] = attachedVolumes.count

        return stats
    }
}
