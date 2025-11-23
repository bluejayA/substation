// Sources/Substation/Modules/Subnets/Extensions/SubnetsModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension SubnetsModule: ModuleNavigationProvider {

    /// Number of subnets in the current view
    ///
    /// Returns the count of cached subnets, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let subnets = tui.cacheManager.cachedSubnets

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterSubnets(subnets, query: query)
            return filtered.count
        }

        return subnets.count
    }

    /// Maximum selection index for subnets view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh subnet data from the API
    ///
    /// Clears cached subnet data and fetches fresh data from Neutron.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("SubnetsModule refreshing data", context: [:])

        // Fetch subnets
        let subnets = try await tui.client.neutron.listSubnets(forceRefresh: true)
        tui.cacheManager.cachedSubnets = subnets

        Logger.shared.logInfo("SubnetsModule refresh completed", context: [
            "subnetCount": subnets.count
        ])
    }

    /// Get contextual command suggestions for subnets view
    ///
    /// Returns commands that are commonly used when working with subnets,
    /// such as related resource views and subnet operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["networks", "ports", "routers"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since SubnetsModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected subnet
    ///
    /// Handles navigation to the subnet detail view for the currently selected
    /// subnet in the subnets list. This filters subnets based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle subnets view
        guard tui.viewCoordinator.currentView == .subnets else {
            return false
        }

        // Filter subnets using the same logic as itemCount
        let subnets = tui.cacheManager.cachedSubnets
        let filteredSubnets: [Subnet]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredSubnets = FilterUtils.filterSubnets(subnets, query: query)
        } else {
            filteredSubnets = subnets
        }

        // Validate selection
        guard !filteredSubnets.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredSubnets.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredSubnets[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .subnetDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
