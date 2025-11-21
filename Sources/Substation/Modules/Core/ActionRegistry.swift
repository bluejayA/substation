// Sources/Substation/Modules/Core/ActionRegistry.swift
import Foundation
import SwiftNCurses

/// Registration for a module-provided action
///
/// This type describes an action that can be performed on resources,
/// including its keybinding, applicable views, and execution handler.
struct ModuleActionRegistration {
    /// Unique identifier for the action (e.g., "floatingip.assign_server")
    let identifier: String

    /// Human-readable title for the action (e.g., "Assign to Server")
    let title: String

    /// Optional keyboard shortcut (e.g., "a" for attach)
    let keybinding: Character?

    /// View modes where this action is available
    let viewModes: Set<ViewMode>

    /// The action handler that performs the operation
    let handler: @MainActor @Sendable (OpaquePointer?) async -> Void

    /// Optional description for help text
    let description: String?

    /// Whether this action requires confirmation
    let requiresConfirmation: Bool

    /// Category for organizing actions in menus
    let category: ActionCategory

    /// Initialize a module action registration
    /// - Parameters:
    ///   - identifier: Unique identifier for the action
    ///   - title: Human-readable title
    ///   - keybinding: Optional keyboard shortcut character
    ///   - viewModes: Set of view modes where action is available
    ///   - handler: Async handler that performs the action
    ///   - description: Optional description for help
    ///   - requiresConfirmation: Whether to confirm before executing
    ///   - category: Action category for organization
    init(
        identifier: String,
        title: String,
        keybinding: Character? = nil,
        viewModes: Set<ViewMode>,
        handler: @escaping @MainActor @Sendable (OpaquePointer?) async -> Void,
        description: String? = nil,
        requiresConfirmation: Bool = false,
        category: ActionCategory = .general
    ) {
        self.identifier = identifier
        self.title = title
        self.keybinding = keybinding
        self.viewModes = viewModes
        self.handler = handler
        self.description = description
        self.requiresConfirmation = requiresConfirmation
        self.category = category
    }
}

/// Categories for organizing actions
enum ActionCategory: String, CaseIterable {
    case general = "General"
    case lifecycle = "Lifecycle"
    case network = "Network"
    case storage = "Storage"
    case security = "Security"
    case management = "Management"
}

/// Central registry for module-provided actions
///
/// This registry maintains all action registrations from modules,
/// providing lookup by identifier, keybinding, and view mode.
@MainActor
final class ActionRegistry {
    /// Shared singleton instance
    static let shared = ActionRegistry()

    /// All registered actions indexed by identifier
    private var actionsByIdentifier: [String: ModuleActionRegistration] = [:]

    /// Actions indexed by view mode for quick lookup
    private var actionsByViewMode: [ViewMode: [ModuleActionRegistration]] = [:]

    /// Actions indexed by keybinding for input handling
    private var actionsByKeybinding: [Character: [ModuleActionRegistration]] = [:]

    /// Private initializer for singleton
    private init() {}

    /// Register an action
    /// - Parameter registration: The action registration to add
    func register(_ registration: ModuleActionRegistration) {
        // Store by identifier
        actionsByIdentifier[registration.identifier] = registration

        // Index by view modes
        for viewMode in registration.viewModes {
            actionsByViewMode[viewMode, default: []].append(registration)
        }

        // Index by keybinding if present
        if let key = registration.keybinding {
            actionsByKeybinding[key, default: []].append(registration)
        }

        Logger.shared.logDebug("Registered action: \(registration.identifier)", context: [
            "title": registration.title,
            "keybinding": registration.keybinding.map { String($0) } ?? "none",
            "viewModeCount": registration.viewModes.count
        ])
    }

    /// Register multiple actions at once
    /// - Parameter registrations: Array of action registrations
    func register(_ registrations: [ModuleActionRegistration]) {
        for registration in registrations {
            register(registration)
        }
    }

    /// Get action by identifier
    /// - Parameter identifier: The action identifier
    /// - Returns: The action registration if found
    func action(for identifier: String) -> ModuleActionRegistration? {
        return actionsByIdentifier[identifier]
    }

    /// Get all actions for a view mode
    /// - Parameter viewMode: The view mode to get actions for
    /// - Returns: Array of available actions
    func actions(for viewMode: ViewMode) -> [ModuleActionRegistration] {
        return actionsByViewMode[viewMode] ?? []
    }

    /// Get actions for a keybinding in a specific view
    /// - Parameters:
    ///   - key: The keyboard character
    ///   - viewMode: The current view mode
    /// - Returns: Array of matching actions
    func actions(for key: Character, in viewMode: ViewMode) -> [ModuleActionRegistration] {
        guard let keyActions = actionsByKeybinding[key] else {
            return []
        }
        return keyActions.filter { $0.viewModes.contains(viewMode) }
    }

    /// Execute an action by identifier
    /// - Parameters:
    ///   - identifier: The action identifier
    ///   - screen: The ncurses screen pointer
    /// - Returns: True if action was found and executed
    @discardableResult
    func execute(identifier: String, screen: OpaquePointer?) async -> Bool {
        guard let registration = actionsByIdentifier[identifier] else {
            Logger.shared.logWarning("Action not found: \(identifier)", context: [:])
            return false
        }

        Logger.shared.logDebug("Executing action: \(identifier)", context: [:])
        await registration.handler(screen)
        return true
    }

    /// Execute action for keybinding in current view
    /// - Parameters:
    ///   - key: The keyboard character
    ///   - viewMode: The current view mode
    ///   - screen: The ncurses screen pointer
    /// - Returns: True if an action was executed
    @discardableResult
    func execute(key: Character, in viewMode: ViewMode, screen: OpaquePointer?) async -> Bool {
        let matchingActions = actions(for: key, in: viewMode)

        guard let action = matchingActions.first else {
            return false
        }

        // If multiple actions match, use the first one (could add priority system later)
        if matchingActions.count > 1 {
            Logger.shared.logWarning("Multiple actions for key '\(key)' in \(viewMode)", context: [
                "actionCount": matchingActions.count,
                "executing": action.identifier
            ])
        }

        await action.handler(screen)
        return true
    }

    /// Get all registered actions
    /// - Returns: Array of all action registrations
    func allActions() -> [ModuleActionRegistration] {
        return Array(actionsByIdentifier.values)
    }

    /// Get actions by category
    /// - Parameter category: The action category
    /// - Returns: Array of actions in that category
    func actions(for category: ActionCategory) -> [ModuleActionRegistration] {
        return actionsByIdentifier.values.filter { $0.category == category }
    }

    /// Clear all registrations (for testing)
    func clear() {
        actionsByIdentifier.removeAll()
        actionsByViewMode.removeAll()
        actionsByKeybinding.removeAll()
    }

    /// Get help text for actions in a view
    /// - Parameter viewMode: The view mode to get help for
    /// - Returns: Formatted help text
    func helpText(for viewMode: ViewMode) -> String {
        let actions = self.actions(for: viewMode)
        guard !actions.isEmpty else {
            return "No actions available"
        }

        var lines: [String] = ["Available Actions:"]

        // Group by category
        let grouped = Dictionary(grouping: actions) { $0.category }

        for category in ActionCategory.allCases {
            guard let categoryActions = grouped[category], !categoryActions.isEmpty else {
                continue
            }

            lines.append("")
            lines.append("\(category.rawValue):")

            for action in categoryActions.sorted(by: { $0.title < $1.title }) {
                let keyStr = action.keybinding.map { "[\($0)]" } ?? "   "
                lines.append("  \(keyStr) \(action.title)")
                if let desc = action.description {
                    lines.append("      \(desc)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
