// Sources/Substation/Modules/SecurityGroups/Extensions/SecurityGroupsModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension SecurityGroupsModule: ModuleNavigationProvider {

    /// Number of security groups in the current view
    ///
    /// Returns the count of cached security groups, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let securityGroups = tui.cacheManager.cachedSecurityGroups

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterSecurityGroups(securityGroups, query: query)
            return filtered.count
        }

        return securityGroups.count
    }

    /// Maximum selection index for security groups view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh security group data from the API
    ///
    /// Clears cached security group data and fetches fresh data from Neutron.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("SecurityGroupsModule refreshing data", context: [:])

        // Fetch security groups
        let securityGroups = try await tui.client.neutron.listSecurityGroups()
        tui.cacheManager.cachedSecurityGroups = securityGroups

        Logger.shared.logInfo("SecurityGroupsModule refresh completed", context: [
            "securityGroupCount": securityGroups.count
        ])
    }

    /// Get contextual command suggestions for security groups view
    ///
    /// Returns commands that are commonly used when working with security groups,
    /// such as related resource views and security group operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["servers", "networks", "ports", "floatingips"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since SecurityGroupsModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected security group
    ///
    /// Handles navigation to the security group detail view for the currently selected
    /// security group in the security groups list. This filters security groups based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle security groups view
        guard tui.viewCoordinator.currentView == .securityGroups else {
            return false
        }

        // Filter security groups using the same logic as itemCount
        let securityGroups = tui.cacheManager.cachedSecurityGroups
        let filteredSecurityGroups: [SecurityGroup]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredSecurityGroups = FilterUtils.filterSecurityGroups(securityGroups, query: query)
        } else {
            filteredSecurityGroups = securityGroups
        }

        // Validate selection
        guard !filteredSecurityGroups.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredSecurityGroups.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredSecurityGroups[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .securityGroupDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
