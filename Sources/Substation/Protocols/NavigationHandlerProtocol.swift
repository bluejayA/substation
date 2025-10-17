import Foundation
import SwiftNCurses

/// Defines the context for navigation operations
/// This helps determine which navigation patterns to apply
enum NavigationContext {
    /// List view with selectable items
    case list(maxIndex: Int)
    /// Form with multiple fields
    case form(fieldCount: Int)
    /// Management view with items to select/toggle
    case management(itemCount: Int)
    /// Detail view with scrollable content
    case detail(scrollable: Bool)
    /// Custom navigation context
    case custom
}

/// Protocol for handlers that support centralized navigation
/// This protocol standardizes navigation input handling across all views
@MainActor
protocol NavigationHandlerProtocol {
    /// The current navigation context for this handler
    var navigationContext: NavigationContext { get }

    /// The TUI instance this handler is associated with
    var tui: TUI? { get }

    /// Handle common navigation inputs (UP/DOWN/PAGE/HOME/END/ESC)
    /// Returns true if the input was handled
    func handleCommonNavigation(_ ch: Int32, screen: OpaquePointer?) async -> Bool

    /// Handle view-specific input after common navigation
    /// Returns true if the input was handled
    func handleViewSpecificInput(_ ch: Int32, screen: OpaquePointer?) async -> Bool

    /// Handle ESC key with context-aware behavior
    /// Returns true if the input was handled
    func handleEscape() async -> Bool
}

/// Default implementations for navigation protocol
extension NavigationHandlerProtocol {
    /// Default implementation delegates to NavigationInputHandler
    func handleCommonNavigation(_ ch: Int32, screen: OpaquePointer?) async -> Bool {
        guard let tui = tui else { return false }

        switch navigationContext {
        case .list(let maxIndex):
            return await NavigationInputHandler.handleListNavigation(ch, maxIndex: maxIndex, tui: tui)

        case .form(let fieldCount):
            return await NavigationInputHandler.handleFormNavigation(ch, fieldCount: fieldCount, tui: tui)

        case .management(let itemCount):
            return await NavigationInputHandler.handleManagementNavigation(ch, itemCount: itemCount, tui: tui)

        case .detail(let scrollable):
            return await NavigationInputHandler.handleDetailNavigation(ch, scrollable: scrollable, tui: tui)

        case .custom:
            // Custom contexts must implement their own navigation
            return false
        }
    }

    /// Default ESC handling delegates to centralized handler
    func handleEscape() async -> Bool {
        guard let tui = tui else { return false }
        return await NavigationInputHandler.handleEscapeKey(tui: tui)
    }
}
