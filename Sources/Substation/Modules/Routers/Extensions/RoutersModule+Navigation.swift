// Sources/Substation/Modules/Routers/Extensions/RoutersModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension RoutersModule: ModuleNavigationProvider {

    /// Number of routers in the current view
    ///
    /// Returns the count of cached routers, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let routers = tui.cacheManager.cachedRouters

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterRouters(routers, query: query)
            return filtered.count
        }

        return routers.count
    }

    /// Maximum selection index for routers view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh router data from the API
    ///
    /// Clears cached router data and fetches fresh data from Neutron.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("RoutersModule refreshing data", context: [:])

        // Fetch routers
        let routers = try await tui.client.neutron.listRouters(forceRefresh: true)
        tui.cacheManager.cachedRouters = routers

        Logger.shared.logInfo("RoutersModule refresh completed", context: [
            "routerCount": routers.count
        ])
    }

    /// Get contextual command suggestions for routers view
    ///
    /// Returns commands that are commonly used when working with routers,
    /// such as related resource views and router operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["networks", "subnets", "floatingips"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since RoutersModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected router
    ///
    /// Handles navigation to the router detail view for the currently selected
    /// router in the routers list. This filters routers based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle routers view
        guard tui.viewCoordinator.currentView == .routers else {
            return false
        }

        // Filter routers using the same logic as itemCount
        let routers = tui.cacheManager.cachedRouters
        let filteredRouters: [Router]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredRouters = FilterUtils.filterRouters(routers, query: query)
        } else {
            filteredRouters = routers
        }

        // Validate selection
        guard !filteredRouters.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredRouters.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredRouters[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .routerDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
