// Sources/Substation/Modules/FloatingIPs/Extensions/FloatingIPsModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension FloatingIPsModule: ModuleNavigationProvider {

    /// Number of floating IPs in the current view
    ///
    /// Returns the count of cached floating IPs, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let floatingIPs = tui.cacheManager.cachedFloatingIPs

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterFloatingIPs(floatingIPs, query: query)
            return filtered.count
        }

        return floatingIPs.count
    }

    /// Maximum selection index for floating IPs view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh floating IP data from the API
    ///
    /// Clears cached floating IP data and fetches fresh data from Neutron.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("FloatingIPsModule refreshing data", context: [:])

        // Fetch floating IPs
        let floatingIPs = try await tui.client.neutron.listFloatingIPs()
        tui.cacheManager.cachedFloatingIPs = floatingIPs

        Logger.shared.logInfo("FloatingIPsModule refresh completed", context: [
            "floatingIPCount": floatingIPs.count
        ])
    }

    /// Get contextual command suggestions for floating IPs view
    ///
    /// Returns commands that are commonly used when working with floating IPs,
    /// such as related resource views and floating IP operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["servers", "networks", "ports", "routers"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since FloatingIPsModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected floating IP
    ///
    /// Handles navigation to the floating IP detail view for the currently selected
    /// floating IP in the floating IPs list. This filters floating IPs based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle floating IPs view
        guard tui.viewCoordinator.currentView == .floatingIPs else {
            return false
        }

        // Filter floating IPs using the same logic as itemCount
        let floatingIPs = tui.cacheManager.cachedFloatingIPs
        let filteredFloatingIPs: [FloatingIP]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredFloatingIPs = FilterUtils.filterFloatingIPs(floatingIPs, query: query)
        } else {
            filteredFloatingIPs = floatingIPs
        }

        // Validate selection
        guard !filteredFloatingIPs.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredFloatingIPs.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredFloatingIPs[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .floatingIPDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
