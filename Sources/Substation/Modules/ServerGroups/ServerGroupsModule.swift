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

    // MARK: - TUI Reference

    /// Reference to TUI system
    private weak var tui: TUI?

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
        let cachedServerGroups = tui.resourceCache.serverGroups
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

    // MARK: - View Rendering Methods

    /// Render server groups list view
    private func renderServerGroupsList(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        let cachedServerGroups = tui.resourceCache.serverGroups

        await ServerGroupViews.drawDetailedServerGroupList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            cachedServerGroups: cachedServerGroups,
            searchQuery: tui.searchQuery,
            scrollOffset: tui.scrollOffset,
            selectedIndex: tui.selectedIndex,
            multiSelectMode: tui.multiSelectMode,
            selectedItems: tui.multiSelectedResourceIDs
        )
    }

    /// Render server group detail view
    private func renderServerGroupDetail(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let serverGroup = tui.selectedResource as? ServerGroup else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol + 2, y: startRow + 2, width: width - 4, height: 1)
            await SwiftNCurses.render(
                Text("No server group selected").error(),
                on: surface,
                in: bounds
            )
            return
        }

        let cachedServers = tui.resourceCache.servers

        await ServerGroupViews.drawServerGroupDetail(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            serverGroup: serverGroup,
            cachedServers: cachedServers,
            scrollOffset: tui.detailScrollOffset
        )
    }

    /// Render server group create form
    private func renderServerGroupCreate(
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
    private func renderServerGroupManagement(
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
