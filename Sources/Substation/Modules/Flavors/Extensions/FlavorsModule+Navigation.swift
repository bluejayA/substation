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
    /// Handles navigation to the flavor detail view for the currently selected
    /// flavor in the flavors list. This filters flavors based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle flavors view
        guard tui.viewCoordinator.currentView == .flavors else {
            return false
        }

        // Filter flavors using the same logic as itemCount
        let flavors = tui.cacheManager.cachedFlavors
        let filteredFlavors: [Flavor]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredFlavors = FilterUtils.filterFlavors(flavors, query: query)
        } else {
            filteredFlavors = flavors
        }

        // Validate selection
        guard !filteredFlavors.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredFlavors.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredFlavors[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .flavorDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
