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
        case .refresh:
            // Global action - handled directly
            tui.statusMessage = "Refreshing data..."
            await tui.dataManager.refreshAllData()
            tui.refreshAfterOperation()
            tui.statusMessage = "Data refreshed"
            return true
        case .clearCache:
            // Global action - handled directly
            return await executeClearCacheAction(tui: tui, screen: screen)
        default:
            // Module-specific actions - delegate to provider
            return await executeViaProvider(action, in: context, tui: tui, screen: screen)
        }
    }

    // MARK: - Action Execution Implementation

    /// Execute action via module provider
    ///
    /// Delegates action execution to the registered module provider.
    /// Handles global actions (refresh, clearCache) directly.
    ///
    /// - Parameters:
    ///   - action: The action to execute
    ///   - context: The current view mode
    ///   - tui: The TUI instance
    ///   - screen: Screen pointer for dialogs
    /// - Returns: True if the action was executed
    private func executeViaProvider(
        _ action: ActionType,
        in context: ViewMode,
        tui: TUI,
        screen: OpaquePointer?
    ) async -> Bool {
        // Look up provider from registry
        if let provider = ActionProviderRegistry.shared.provider(for: context) {
            return await provider.executeAction(action, screen: screen, tui: tui)
        }

        tui.statusMessage = "\(action.rawValue.capitalized) not supported in \(context.title)"
        return false
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
        // Check if there's a registered provider for this view mode
        if let provider = ActionProviderRegistry.shared.provider(for: context) {
            // Return list or detail actions based on view type
            if ActionProviderRegistry.shared.isDetailView(context) {
                return provider.detailViewActions
            } else {
                return provider.listViewActions
            }
        }

        // Dynamic fallback based on view mode characteristics
        let viewName = String(describing: context)

        // Form/create views have no actions
        if viewName.contains("Create") || viewName.contains("Management") ||
           viewName.contains("Selection") || viewName.contains("Attachment") {
            return []
        }

        // Loading and help views have no actions
        if viewName == "loading" || viewName == "help" || viewName == "about" ||
           viewName == "welcome" || viewName == "tutorial" || viewName == "shortcuts" ||
           viewName == "examples" {
            return []
        }

        // Default: basic refresh and cache actions for unregistered views
        return [.refresh, .clearCache]
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
