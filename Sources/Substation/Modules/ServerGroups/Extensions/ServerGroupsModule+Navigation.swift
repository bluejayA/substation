// Sources/Substation/Modules/ServerGroups/Extensions/ServerGroupsModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension ServerGroupsModule: ModuleNavigationProvider {

    /// Number of server groups in the current view
    ///
    /// Returns the count of cached server groups, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let serverGroups = tui.cacheManager.cachedServerGroups

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterServerGroups(serverGroups, query: query)
            return filtered.count
        }

        return serverGroups.count
    }

    /// Maximum selection index for server groups view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh server group data from the API
    ///
    /// Clears cached server group data and fetches fresh data from Nova.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("ServerGroupsModule refreshing data", context: [:])

        // Fetch server groups
        let serverGroups = try await tui.client.nova.listServerGroups()
        tui.cacheManager.cachedServerGroups = serverGroups

        Logger.shared.logInfo("ServerGroupsModule refresh completed", context: [
            "serverGroupCount": serverGroups.count
        ])
    }

    /// Get contextual command suggestions for server groups view
    ///
    /// Returns commands that are commonly used when working with server groups,
    /// such as related resource views and server group operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["servers"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since ServerGroupsModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected server group
    ///
    /// Handles navigation to the server group detail view for the currently selected
    /// server group in the server groups list. This filters server groups based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle server groups view
        guard tui.viewCoordinator.currentView == .serverGroups else {
            return false
        }

        // Filter server groups using the same logic as itemCount
        let serverGroups = tui.cacheManager.cachedServerGroups
        let filteredServerGroups: [ServerGroup]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredServerGroups = FilterUtils.filterServerGroups(serverGroups, query: query)
        } else {
            filteredServerGroups = serverGroups
        }

        // Validate selection
        guard !filteredServerGroups.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredServerGroups.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredServerGroups[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .serverGroupDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
