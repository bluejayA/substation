// Sources/Substation/Modules/Flavors/Extensions/FlavorsModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension FlavorsModule: ModuleNavigationProvider {

    /// Number of flavors in the current view
    ///
    /// Returns the count of cached flavors, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let flavors = tui.cacheManager.cachedFlavors

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterFlavors(flavors, query: query)
            return filtered.count
        }

        return flavors.count
    }

    /// Maximum selection index for flavors view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh flavor data from the API
    ///
    /// Clears cached flavor data and fetches fresh data from Nova.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("FlavorsModule refreshing data", context: [:])

        // Fetch flavors
        let flavors = try await tui.client.nova.listFlavors(forceRefresh: true)
        tui.cacheManager.cachedFlavors = flavors

        Logger.shared.logInfo("FlavorsModule refresh completed", context: [
            "flavorCount": flavors.count
        ])
    }

    /// Get contextual command suggestions for flavors view
    ///
    /// Returns commands that are commonly used when working with flavors,
    /// such as related resource views.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["servers"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since FlavorsModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected flavor
    ///
    /// Flavors do not have a detail view, so this always returns false.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: false as flavors do not have detail views
    func openDetailView(tui: TUI) -> Bool {
        // Flavors do not have a detail view
        return false
    }
}
