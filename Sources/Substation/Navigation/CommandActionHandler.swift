import Foundation

/// Enumeration of action types that can be executed via command mode
enum ActionType: String {
    case create
    case delete
    case refresh
    case start
    case stop
    case restart
    case manage
    case clearCache = "clear-cache"

    /// Returns all available action types
    static var all: [ActionType] {
        return [.create, .delete, .refresh, .start, .stop, .restart, .manage, .clearCache]
    }

    /// Returns the command name for this action (with colon prefix for display)
    var commandName: String {
        return ":\(rawValue)"
    }
}

@MainActor
final class CommandActionHandler: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = CommandActionHandler()

    private init() {}

    // MARK: - Action Execution

    /// Execute an action in the given context (delegates to existing handler methods)
    /// - Parameters:
    ///   - action: The action to execute
    ///   - context: The current view mode context
    ///   - tui: The TUI instance to execute the action on
    ///   - screen: The screen pointer for confirmation dialogs
    /// - Returns: True if the action was executed, false if it was invalid for the context
    func executeAction(_ action: ActionType, in context: ViewMode, tui: TUI, screen: OpaquePointer?)
        async -> Bool
    {
        // Validate the action is available in this context
        guard canExecuteAction(action, in: context) else {
            Logger.shared.logError("Action \(action.rawValue) not available in \(context)")
            // Provide helpful feedback with available alternatives
            let available = getAvailableActions(for: context)
            if available.isEmpty {
                tui.statusMessage =
                    "Command '\(action.commandName)' not available in \(context.title). No actions available here."
            } else {
                let suggestions = available.map { $0.commandName }.joined(separator: ", ")
                tui.statusMessage =
                    "Command '\(action.commandName)' not available here. Available commands: \(suggestions)"
            }
            return false
        }

        Logger.shared.logUserAction(
            "command_action_executed",
            details: [
                "action": action.rawValue,
                "context": "\(context)",
            ])

        // Execute the actual action
        switch action {
        case .create:
            return await executeCreateAction(in: context, tui: tui, screen: screen)
        case .delete:
            return await executeDeleteAction(in: context, tui: tui, screen: screen)
        case .refresh:
            return await executeRefreshAction(tui: tui)
        case .start:
            return await executeStartAction(in: context, tui: tui, screen: screen)
        case .stop:
            return await executeStopAction(in: context, tui: tui, screen: screen)
        case .restart:
            return await executeRestartAction(in: context, tui: tui, screen: screen)
        case .manage:
            return await executeManageAction(in: context, tui: tui, screen: screen)
        case .clearCache:
            return await executeClearCacheAction(tui: tui, screen: screen)
        }
    }

    // MARK: - Action Execution Implementation

    /// Execute create action for the current context
    private func executeCreateAction(in context: ViewMode, tui: TUI, screen: OpaquePointer?) async
        -> Bool
    {
        // Most create operations are handled by navigating to the create view
        switch context {
        case .servers:
            tui.changeView(to: .serverCreate)
        case .networks:
            tui.changeView(to: .networkCreate)
        case .volumes:
            tui.changeView(to: .volumeCreate)
        case .keyPairs:
            tui.changeView(to: .keyPairCreate)
        case .subnets:
            tui.changeView(to: .subnetCreate)
        case .ports:
            tui.changeView(to: .portCreate)
        case .floatingIPs:
            tui.changeView(to: .floatingIPCreate)
        case .routers:
            tui.changeView(to: .routerCreate)
        case .serverGroups:
            tui.changeView(to: .serverGroupCreate)
        case .securityGroups:
            tui.changeView(to: .securityGroupCreate)
        case .barbicanSecrets:
            await tui.resourceOperations.createSecret(screen: screen)
        case .swift:
            tui.changeView(to: .swiftContainerCreate)
        default:
            tui.statusMessage = "Create not supported in \(context.title)"
            return false
        }
        tui.statusMessage = "Opening create form..."
        return true
    }

    /// Execute delete action for the current context
    private func executeDeleteAction(in context: ViewMode, tui: TUI, screen: OpaquePointer?) async
        -> Bool
    {
        switch context {
        case .servers, .serverDetail:
            await tui.resourceOperations.deleteServer(screen: screen)
        case .networks, .networkDetail:
            await tui.resourceOperations.deleteNetwork(screen: screen)
        case .volumes, .volumeDetail:
            await tui.resourceOperations.deleteVolume(screen: screen)
        case .images, .imageDetail:
            await tui.resourceOperations.deleteImage(screen: screen)
        case .keyPairs, .keyPairDetail:
            await tui.resourceOperations.deleteKeyPair(screen: screen)
        case .subnets, .subnetDetail:
            await tui.resourceOperations.deleteSubnet(screen: screen)
        case .ports, .portDetail:
            await tui.resourceOperations.deletePort(screen: screen)
        case .floatingIPs, .floatingIPDetail:
            await tui.resourceOperations.deleteFloatingIP(screen: screen)
        case .routers, .routerDetail:
            await tui.resourceOperations.deleteRouter(screen: screen)
        case .serverGroups, .serverGroupDetail:
            await tui.resourceOperations.deleteServerGroup(screen: screen)
        case .securityGroups, .securityGroupDetail:
            await tui.resourceOperations.deleteSecurityGroup(screen: screen)
        case .barbicanSecrets:
            await tui.resourceOperations.deleteSecret(screen: screen)
        case .swift, .swiftContainerDetail:
            await tui.resourceOperations.deleteSwiftContainer(screen: screen)
        case .volumeArchives, .volumeArchiveDetail:
            // Archives are handled by the selected resource type
            // This would need special handling in the actual delete flow
            tui.statusMessage = "Delete for archives - use detail view"
            return false
        default:
            tui.statusMessage = "Delete not supported in \(context.title)"
            return false
        }
        return true
    }

    /// Execute refresh action
    private func executeRefreshAction(tui: TUI) async -> Bool {
        tui.statusMessage = "Refreshing data..."
        await tui.dataManager.refreshAllData()
        tui.refreshAfterOperation()
        tui.statusMessage = "Data refreshed"
        return true
    }

    /// Execute start action (servers only)
    private func executeStartAction(in context: ViewMode, tui: TUI, screen: OpaquePointer?) async
        -> Bool
    {
        guard context == .servers || context == .serverDetail else {
            tui.statusMessage = "Start action only available for servers"
            return false
        }
        await tui.actions.startServer(screen: screen)
        return true
    }

    /// Execute stop action (servers only)
    private func executeStopAction(in context: ViewMode, tui: TUI, screen: OpaquePointer?) async
        -> Bool
    {
        guard context == .servers || context == .serverDetail else {
            tui.statusMessage = "Stop action only available for servers"
            return false
        }
        await tui.actions.stopServer(screen: screen)
        return true
    }

    /// Execute restart action (servers only)
    private func executeRestartAction(in context: ViewMode, tui: TUI, screen: OpaquePointer?) async
        -> Bool
    {
        guard context == .servers || context == .serverDetail else {
            tui.statusMessage = "Restart action only available for servers"
            return false
        }
        await tui.actions.restartServer(screen: screen)
        return true
    }

    /// Execute manage action for the current context
    private func executeManageAction(in context: ViewMode, tui: TUI, screen: OpaquePointer?) async
        -> Bool
    {
        switch context {
        case .networks:
            await tui.actions.manageNetworkToServers(screen: screen)
        case .volumes:
            await tui.actions.manageVolumeToServers(screen: screen)
        case .subnets:
            await tui.actions.manageSubnetRouterAttachment(screen: screen)
        case .ports:
            await tui.actions.managePortServerAssignment(screen: screen)
        case .floatingIPs:
            await tui.actions.manageFloatingIPServerAssignment(screen: screen)
        case .serverGroups:
            // Server groups don't have a manage method - they're managed through server detail
            tui.statusMessage = "Server group management - use server detail view"
            return false
        case .securityGroups:
            await tui.actions.manageSecurityGroupToServers(screen: screen)
        case .swift, .swiftContainerDetail:
            // Swift management could open metadata or web access forms
            tui.statusMessage = "Swift management coming soon"
            return false
        default:
            tui.statusMessage = "Manage not supported in \(context.title)"
            return false
        }
        return true
    }

    /// Execute clear-cache action to purge all application caches
    /// - Parameters:
    ///   - tui: The TUI instance containing the resource cache
    ///   - screen: The screen pointer for displaying confirmation dialog
    /// - Returns: True if cache was cleared, false if cancelled or failed
    private func executeClearCacheAction(tui: TUI, screen: OpaquePointer?) async -> Bool {
        guard let screen = screen else {
            tui.statusMessage = "Cannot clear cache: screen not available"
            return false
        }

        let confirmation = await ViewUtils.confirmOperation(
            title: "Clear Cache",
            message: "Clear all application caches?",
            details: [
                "This will clear resource names, filters, search results, and UI caches.",
                "Cached data will be reloaded from OpenStack APIs as needed."
            ],
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        )

        guard confirmation else {
            tui.statusMessage = "Cache clear cancelled"
            return false
        }

        tui.statusMessage = "Clearing caches..."

        // Clear all cache layers
        await tui.resourceCache.clearAll()

        // Log the action
        Logger.shared.logUserAction("cache_cleared", details: [
            "source": "command_mode",
            "timestamp": Date().ISO8601Format()
        ])

        tui.statusMessage = "All caches cleared successfully"
        return true
    }

    // MARK: - Action Availability

    /// Check if an action can be executed in the given context
    /// - Parameters:
    ///   - action: The action to check
    ///   - context: The current view mode
    /// - Returns: True if the action is valid in this context
    func canExecuteAction(_ action: ActionType, in context: ViewMode) -> Bool {
        let available = getAvailableActions(for: context)
        return available.contains(action)
    }

    /// Get all actions available in the given context
    /// - Parameter context: The current view mode
    /// - Returns: Array of available action types
    func getAvailableActions(for context: ViewMode) -> [ActionType] {
        switch context {
        // List views with create/delete/refresh
        case .servers:
            return [.create, .delete, .refresh, .start, .stop, .restart, .clearCache]
        case .networks:
            return [.create, .delete, .refresh, .manage, .clearCache]
        case .volumes:
            return [.create, .delete, .refresh, .manage, .clearCache]
        case .images:
            return [.delete, .refresh, .clearCache]
        case .keyPairs:
            return [.create, .delete, .refresh, .clearCache]
        case .subnets:
            return [.create, .delete, .refresh, .manage, .clearCache]
        case .ports:
            return [.create, .delete, .refresh, .manage, .clearCache]
        case .floatingIPs:
            return [.create, .delete, .refresh, .manage, .clearCache]
        case .routers:
            return [.create, .delete, .refresh, .clearCache]
        case .serverGroups:
            return [.create, .delete, .refresh, .manage, .clearCache]
        case .securityGroups:
            return [.create, .delete, .refresh, .manage, .clearCache]
        case .barbicanSecrets:
            return [.create, .delete, .refresh, .clearCache]
        case .swift:
            return [.create, .delete, .refresh, .manage, .clearCache]
        case .volumeArchives:
            return [.delete, .refresh, .clearCache]

        // Detail views with limited actions
        case .serverDetail:
            return [.delete, .start, .stop, .restart, .refresh, .clearCache]
        case .networkDetail, .volumeDetail, .imageDetail, .subnetDetail, .portDetail,
            .floatingIPDetail, .routerDetail, .serverGroupDetail, .securityGroupDetail:
            return [.delete, .refresh, .clearCache]
        case .keyPairDetail:
            return [.delete, .refresh, .clearCache]
        case .swiftContainerDetail:
            return [.delete, .refresh, .manage, .clearCache]

        // Views with no actions
        case .loading, .serverCreate, .networkCreate, .volumeCreate, .keyPairCreate, .subnetCreate,
            .portCreate, .floatingIPCreate, .routerCreate, .serverGroupCreate, .securityGroupCreate,
            .barbicanSecretCreate, .swiftContainerCreate, .help, .about, .welcome, .tutorial, .shortcuts,
            .examples, .advancedSearch, .serverConsole, .serverResize, .serverSecurityGroups,
            .serverNetworkInterfaces, .serverGroupManagement, .volumeManagement, .floatingIPServerSelect,
            .serverSnapshotManagement, .volumeSnapshotManagement, .volumeBackupManagement,
            .networkServerAttachment, .securityGroupServerAttachment,
            .securityGroupServerManagement, .networkServerManagement, .volumeServerManagement,
            .floatingIPServerManagement, .floatingIPPortManagement, .portServerManagement,
            .portAllowedAddressPairManagement, .subnetRouterManagement,
            .securityGroupRuleManagement, .flavorSelection:
            return []

        // Service views
        case .volumeArchiveDetail, .flavorDetail, .flavors, .healthDashboardServiceDetail,
            .barbican, .octavia, .barbicanSecretDetail,
            .octaviaLoadBalancerDetail, .swiftObjectDetail,
            .swiftBackgroundOperationDetail, .octaviaLoadBalancerCreate,
            .swiftObjectUpload, .swiftContainerDownload, .swiftObjectDownload,
            .swiftDirectoryDownload, .swiftContainerMetadata, .swiftObjectMetadata,
            .swiftDirectoryMetadata, .swiftContainerWebAccess, .swiftBackgroundOperations,
            .performanceMetrics, .dashboard, .healthDashboard:
            return [.refresh, .clearCache]
        }
    }

    // MARK: - Help Text Generation

    /// Get help text for available actions in a context
    /// - Parameter context: The current view mode
    /// - Returns: Formatted help text showing available actions
    func getActionsHelpText(for context: ViewMode) -> String {
        let actions = getAvailableActions(for: context)
        guard !actions.isEmpty else { return "" }

        let actionStrings = actions.map { $0.commandName }
        return actionStrings.joined(separator: "  ")
    }

    /// Get detailed help text for a specific action
    /// - Parameter action: The action to describe
    /// - Returns: Human-readable description of the action
    func getActionDescription(_ action: ActionType) -> String {
        switch action {
        case .create:
            return "Create a new resource"
        case .delete:
            return "Delete the selected resource"
        case .refresh:
            return "Refresh the current view"
        case .start:
            return "Start the selected server"
        case .stop:
            return "Stop the selected server"
        case .restart:
            return "Restart the selected server"
        case .manage:
            return "Manage resource associations"
        case .clearCache:
            return "Clear all application caches"
        }
    }
}
