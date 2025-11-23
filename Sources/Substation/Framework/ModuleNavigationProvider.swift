// Sources/Substation/Framework/ModuleNavigationProvider.swift
import Foundation

/// Protocol that modules can implement to provide navigation-related functionality
///
/// This protocol enables modules to provide information about their current view state
/// including item counts, selection bounds, refresh capabilities, and contextual suggestions.
/// The TUI system can delegate navigation operations to modules that conform to this protocol.
///
/// Modules implement this protocol to:
/// - Report item counts for their current view
/// - Provide maximum selection indices for bounds checking
/// - Handle data refresh operations
/// - Suggest contextual commands based on the current view
@MainActor
protocol ModuleNavigationProvider {

    /// Number of items in the current view
    ///
    /// Returns the total count of items currently displayed by this module.
    /// This is used for scroll calculations and empty state detection.
    var itemCount: Int { get }

    /// Maximum selection index for bounds checking
    ///
    /// Returns the maximum valid selection index for the current view.
    /// Typically this is `itemCount - 1`, but may differ for views with
    /// headers or other non-selectable elements.
    var maxSelectionIndex: Int { get }

    /// Refresh data for this module
    ///
    /// Clears cached data and fetches fresh data from the server.
    /// Called when the user triggers a manual refresh or when the
    /// automatic refresh interval expires.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws

    /// Get contextual command suggestions for the current view
    ///
    /// Returns an array of command strings that are relevant to the
    /// current module state. These are displayed in the command mode
    /// to help users discover available navigation options.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String]

    /// Open detail view for the currently selected resource
    ///
    /// Handles navigation to the detail view for the currently selected item
    /// in this module's list view. Each module implements this to handle
    /// its specific resource types and detail view transitions.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool

    /// Ensure data is loaded for the current view
    ///
    /// Called when entering a view to perform any necessary lazy loading.
    /// This is used for views that only load their data on first access
    /// rather than during initial data load (e.g., Barbican secrets, Swift objects).
    ///
    /// - Parameter tui: The TUI instance for accessing view state
    func ensureDataLoaded(tui: TUI) async
}

// MARK: - Default Implementations

extension ModuleNavigationProvider {

    /// Default implementation returns item count minus one
    ///
    /// Most views have a straightforward one-to-one mapping between
    /// items and selection indices. Override this for views with
    /// non-selectable elements.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Default implementation returns empty array
    ///
    /// Modules that do not provide contextual suggestions can use
    /// this default implementation.
    func getContextualSuggestions() -> [String] {
        return []
    }

    /// Default implementation returns false (not handled)
    ///
    /// Modules that do not provide detail view navigation can use
    /// this default implementation. The TUI will fall back to its
    /// built-in switch statement for these modules.
    func openDetailView(tui: TUI) -> Bool {
        return false
    }

    /// Default implementation does nothing
    ///
    /// Most modules load their data during initial app load and do not
    /// need lazy loading. Override this for modules that defer data
    /// loading until the view is first accessed.
    func ensureDataLoaded(tui: TUI) async {
        // Default: no lazy loading needed
    }
}
