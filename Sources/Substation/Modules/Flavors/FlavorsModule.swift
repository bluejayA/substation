// Sources/Substation/Modules/Flavors/FlavorsModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Instance Flavors Module
///
/// This is a read-only module that provides flavor (instance type) browsing and inspection.
/// Flavors define the compute, memory, and storage capacity of Nova compute instances.
/// This module provides:
/// - Flavor listing with resource specifications
/// - Detailed flavor view with performance analysis and recommendations
///
/// This module has no forms or write operations - flavors are typically managed by administrators
/// through the OpenStack API or CLI outside the TUI application.
@MainActor
final class FlavorsModule: OpenStackModule {
    // MARK: - Module Identity

    /// Unique module identifier
    let identifier: String = "flavors"

    /// Display name in UI
    let displayName: String = "Instance Flavors"

    /// Module version
    let version: String = "1.0.0"

    /// Module dependencies (none for flavors)
    let dependencies: [String] = []

    // MARK: - TUI Reference

    /// Reference to TUI system
    private weak var tui: TUI?

    // MARK: - Health Tracking

    /// Last health check timestamp
    private var lastHealthCheck: Date?

    /// Health check errors
    private var healthErrors: [String] = []

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
        guard tui != nil else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        // Flavors module is read-only and requires no special configuration
        // Data is loaded via standard data refresh handlers
        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all flavor views with TUI system
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else { return [] }

        var registrations: [ModuleViewRegistration] = []

        // Flavors List View
        registrations.append(ModuleViewRegistration(
            viewMode: .flavors,
            title: "Instance Flavors",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                await self.renderFlavorsList(
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
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        // Flavor Detail View
        registrations.append(ModuleViewRegistration(
            viewMode: .flavorDetail,
            title: "Flavor Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                await self.renderFlavorDetail(
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
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers with TUI system
    /// - Returns: Empty array (read-only module has no forms)
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        // Flavors module is read-only - no form handlers needed
        return []
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else { return [] }

        return [
            ModuleDataRefreshRegistration(
                identifier: "flavors.list",
                refreshHandler: { [weak tui] in
                    guard let tui = tui else {
                        throw ModuleError.invalidState("TUI reference is nil")
                    }
                    // Flavors are loaded via DataManager.fetchFlavors
                    // Called during initial data load and periodic refreshes
                    let flavors = try await tui.client.listFlavors(forceRefresh: true)
                    _ = flavors
                },
                cacheKey: "flavors",
                refreshInterval: 300.0 // Refresh every 5 minutes (flavors change infrequently)
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
        let flavorCount = tui.resourceCache.flavors.count
        metrics["cached_flavors"] = flavorCount

        // Verify at least some flavors are available
        if flavorCount == 0 {
            metrics["warning"] = "No flavors cached - may not have loaded yet"
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

    /// Render flavors list view
    /// - Parameters:
    ///   - tui: TUI instance
    ///   - screen: NCurses screen pointer
    ///   - startRow: Starting row for rendering
    ///   - startCol: Starting column for rendering
    ///   - width: Available width
    ///   - height: Available height
    private func renderFlavorsList(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await FlavorViews.drawDetailedFlavorList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            cachedFlavors: tui.resourceCache.flavors,
            searchQuery: tui.searchQuery,
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex
        )
    }

    /// Render flavor detail view
    /// - Parameters:
    ///   - tui: TUI instance
    ///   - screen: NCurses screen pointer
    ///   - startRow: Starting row for rendering
    ///   - startCol: Starting column for rendering
    ///   - width: Available width
    ///   - height: Available height
    private func renderFlavorDetail(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let flavor = tui.viewCoordinator.selectedResource as? Flavor else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol + 2, y: startRow + 2, width: width - 4, height: 1)
            await SwiftNCurses.render(
                Text("No flavor selected").error(),
                on: surface,
                in: bounds
            )
            return
        }

        await FlavorViews.drawFlavorDetailGoldStandard(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            flavor: flavor,
            scrollOffset: tui.viewCoordinator.detailScrollOffset
        )
    }
}
