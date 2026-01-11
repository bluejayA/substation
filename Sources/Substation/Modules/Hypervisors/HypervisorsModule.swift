// Sources/Substation/Modules/Hypervisors/HypervisorsModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Hypervisors Module
///
/// Admin-focused module for managing compute hypervisors. This module provides:
/// - Hypervisor listing with resource usage metrics
/// - Detailed hypervisor information and status
/// - Enable/disable operations via compute services API
/// - Server instance discovery on hypervisors
///
/// Note: Hypervisor operations require administrative privileges.
/// Regular users will see an empty list or receive permission errors.
@MainActor
final class HypervisorsModule: OpenStackModule {
    // MARK: - Module Identity

    /// Unique module identifier
    let identifier: String = "hypervisors"

    /// Display name in UI
    let displayName: String = "Hypervisors"

    /// Module version
    let version: String = "1.0.0"

    /// Module dependencies (none for hypervisors)
    let dependencies: [String] = []

    /// View modes handled by this module
    var handledViewModes: Set<ViewMode> {
        return [.hypervisors, .hypervisorDetail]
    }

    // MARK: - TUI Reference

    /// Reference to TUI system
    internal weak var tui: TUI?

    // MARK: - Health Tracking

    /// Last health check timestamp
    private var lastHealthCheck: Date?

    /// Health check errors
    private var healthErrors: [String] = []

    // MARK: - Initialization

    /// Initialize module with TUI context
    ///
    /// - Parameter tui: Main TUI system instance
    required init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Module Configuration

    /// Configure module after initialization
    ///
    /// Performs any necessary setup and validation.
    func configure() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        // Register as data provider
        let dataProvider = HypervisorsDataProvider(module: self, tui: tui)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)

        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all hypervisor views with TUI system
    ///
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else { return [] }

        var registrations: [ModuleViewRegistration] = []

        // Hypervisors List View
        registrations.append(ModuleViewRegistration(
            viewMode: .hypervisors,
            title: "Hypervisors",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                await self.renderHypervisorsList(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: { [weak self, weak tui] ch, screen in
                guard let self = self, let tui = tui else { return false }
                return await self.handleListViewInput(ch, screen: screen, tui: tui)
            },
            category: .compute
        ))

        // Hypervisor Detail View
        registrations.append(ModuleViewRegistration(
            viewMode: .hypervisorDetail,
            title: "Hypervisor Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                await self.renderHypervisorDetail(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: { [weak self, weak tui] ch, screen in
                guard let self = self, let tui = tui else { return false }
                return await self.handleDetailViewInput(ch, screen: screen, tui: tui)
            },
            category: .compute
        ))

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers with TUI system
    ///
    /// - Returns: Empty array (read-only module has no forms)
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        // Hypervisors module is primarily read-only - no form handlers needed
        return []
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers
    ///
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else { return [] }

        return [
            ModuleDataRefreshRegistration(
                identifier: "hypervisors.list",
                refreshHandler: { [weak tui] in
                    guard let tui = tui else {
                        throw ModuleError.invalidState("TUI reference is nil")
                    }
                    let hypervisors = try await tui.client.nova.listHypervisors(forceRefresh: true)
                    tui.cacheManager.cachedHypervisors = hypervisors
                },
                cacheKey: "hypervisors",
                refreshInterval: 60.0  // Refresh every minute (resource usage changes frequently)
            )
        ]
    }

    // MARK: - Cleanup

    /// Cleanup when module is unloaded
    func cleanup() async {
        // Clear health tracking state
        healthErrors.removeAll()
        lastHealthCheck = nil

        // TUI reference will be released via weak reference
    }

    // MARK: - Health Check

    /// Module health check for monitoring
    ///
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
        let hypervisorCount = tui.cacheManager.cachedHypervisors.count
        metrics["cached_hypervisors"] = hypervisorCount

        // Analyze hypervisor status
        let hypervisors = tui.cacheManager.cachedHypervisors
        let upHypervisors = hypervisors.filter { $0.state?.lowercased() == "up" }
        let enabledHypervisors = hypervisors.filter { $0.status?.lowercased() == "enabled" }
        let operationalHypervisors = hypervisors.filter { $0.isOperational }

        metrics["up_hypervisors"] = upHypervisors.count
        metrics["enabled_hypervisors"] = enabledHypervisors.count
        metrics["operational_hypervisors"] = operationalHypervisors.count

        // Calculate total resources
        let totalVcpus = hypervisors.compactMap { $0.vcpus }.reduce(0, +)
        let usedVcpus = hypervisors.compactMap { $0.vcpusUsed }.reduce(0, +)
        let totalMemoryGb = hypervisors.compactMap { $0.memoryMb }.reduce(0, +) / 1024
        let usedMemoryGb = hypervisors.compactMap { $0.memoryMbUsed }.reduce(0, +) / 1024
        let runningVms = hypervisors.compactMap { $0.runningVms }.reduce(0, +)

        metrics["total_vcpus"] = totalVcpus
        metrics["used_vcpus"] = usedVcpus
        metrics["total_memory_gb"] = totalMemoryGb
        metrics["used_memory_gb"] = usedMemoryGb
        metrics["running_vms"] = runningVms

        // Verify at least some hypervisors are available
        if hypervisorCount == 0 {
            metrics["warning"] = "No hypervisors cached - may require admin privileges"
        }

        // Check for down hypervisors
        let downHypervisors = hypervisors.filter { $0.state?.lowercased() == "down" }
        if !downHypervisors.isEmpty {
            errors.append("\(downHypervisors.count) hypervisor(s) are down")
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

    // MARK: - View Rendering Methods

    /// Render hypervisors list view
    ///
    /// - Parameters:
    ///   - tui: TUI instance
    ///   - screen: NCurses screen pointer
    ///   - startRow: Starting row for rendering
    ///   - startCol: Starting column for rendering
    ///   - width: Available width
    ///   - height: Available height
    func renderHypervisorsList(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await HypervisorViews.drawDetailedHypervisorList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            cachedHypervisors: tui.cacheManager.cachedHypervisors,
            searchQuery: tui.searchQuery,
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex
        )
    }

    /// Render hypervisor detail view
    ///
    /// - Parameters:
    ///   - tui: TUI instance
    ///   - screen: NCurses screen pointer
    ///   - startRow: Starting row for rendering
    ///   - startCol: Starting column for rendering
    ///   - width: Available width
    ///   - height: Available height
    func renderHypervisorDetail(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let hypervisor = tui.viewCoordinator.selectedResource as? Hypervisor else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol + 2, y: startRow + 2, width: width - 4, height: 1)
            await SwiftNCurses.render(
                Text("No hypervisor selected").error(),
                on: surface,
                in: bounds
            )
            return
        }

        await HypervisorViews.drawHypervisorDetail(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            hypervisor: hypervisor,
            scrollOffset: tui.viewCoordinator.detailScrollOffset
        )
    }

    // MARK: - Input Handling

    /// Handle detail view input
    ///
    /// - Parameters:
    ///   - ch: Key code pressed
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    /// - Returns: True if input was handled
    func handleDetailViewInput(_ ch: Int32, screen: OpaquePointer?, tui: TUI) async -> Bool {
        switch ch {
        case Int32(Character("E").asciiValue!), Int32(Character("e").asciiValue!):
            // E - Enable hypervisor
            await enableHypervisor(screen: screen, tui: tui)
            return true

        case Int32(Character("D").asciiValue!), Int32(Character("d").asciiValue!):
            // D - Disable hypervisor
            await disableHypervisor(screen: screen, tui: tui)
            return true

        case Int32(Character("S").asciiValue!), Int32(Character("s").asciiValue!):
            // S - Show servers on hypervisor
            await viewHypervisorServers(screen: screen, tui: tui)
            return true

        default:
            return false
        }
    }

    // MARK: - Computed Properties

    /// Get all cached hypervisors
    ///
    /// Returns all hypervisors from the cache manager.
    var hypervisors: [Hypervisor] {
        return tui?.cacheManager.cachedHypervisors ?? []
    }
}
