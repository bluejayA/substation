// Sources/Substation/Modules/Networks/Extensions/NetworksModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension NetworksModule: ModuleNavigationProvider {

    /// Number of networks in the current view
    ///
    /// Returns the count of cached networks, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let networks = tui.cacheManager.cachedNetworks

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterNetworks(networks, query: query)
            return filtered.count
        }

        return networks.count
    }

    /// Maximum selection index for networks view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh network data from the API
    ///
    /// Clears cached network data and fetches fresh data from Neutron.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("NetworksModule refreshing data", context: [:])

        // Fetch networks
        let networks = try await tui.client.neutron.listNetworks(forceRefresh: true)
        tui.cacheManager.cachedNetworks = networks

        Logger.shared.logInfo("NetworksModule refresh completed", context: [
            "networkCount": networks.count
        ])
    }

    /// Get contextual command suggestions for networks view
    ///
    /// Returns commands that are commonly used when working with networks,
    /// such as related resource views and network operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["subnets", "ports", "routers", "floatingips", "securitygroups"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since NetworksModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected network
    ///
    /// Handles navigation to the network detail view for the currently selected
    /// network in the networks list. This filters networks based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle networks view
        guard tui.viewCoordinator.currentView == .networks else {
            return false
        }

        // Filter networks using the same logic as itemCount
        let networks = tui.cacheManager.cachedNetworks
        let filteredNetworks: [Network]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredNetworks = FilterUtils.filterNetworks(networks, query: query)
        } else {
            filteredNetworks = networks
        }

        // Validate selection
        guard !filteredNetworks.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredNetworks.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredNetworks[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .networkDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
