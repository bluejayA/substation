// Sources/Substation/Modules/Ports/Extensions/PortsModule+Navigation.swift
import Foundation
import OSClient
import struct OSClient.Port

// MARK: - ModuleNavigationProvider Conformance

extension PortsModule: ModuleNavigationProvider {

    /// Number of ports in the current view
    ///
    /// Returns the count of cached ports, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let ports = tui.cacheManager.cachedPorts

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterPorts(ports, query: query)
            return filtered.count
        }

        return ports.count
    }

    /// Maximum selection index for ports view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh port data from the API
    ///
    /// Clears cached port data and fetches fresh data from Neutron.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("PortsModule refreshing data", context: [:])

        // Fetch ports
        let ports = try await tui.client.neutron.listPorts(forceRefresh: true)
        tui.cacheManager.cachedPorts = ports

        Logger.shared.logInfo("PortsModule refresh completed", context: [
            "portCount": ports.count
        ])
    }

    /// Get contextual command suggestions for ports view
    ///
    /// Returns commands that are commonly used when working with ports,
    /// such as related resource views and port operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["networks", "subnets", "servers", "floatingips", "securitygroups"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since PortsModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Ensure required data is loaded for the current Ports view
    ///
    /// Lazily loads security groups data when entering the port create view if not already cached.
    /// This ensures security group selection is available during port creation.
    ///
    /// - Parameter tui: The TUI instance for accessing view state and cache
    func ensureDataLoaded(tui: TUI) async {
        switch tui.viewCoordinator.currentView {
        case .portCreate:
            if tui.cacheManager.cachedSecurityGroups.isEmpty {
                Logger.shared.logInfo("Loading security groups data for port creation")
                let _ = await DataProviderRegistry.shared.fetchData(for: "securitygroups", priority: .onDemand, forceRefresh: true)
            }
        default:
            break
        }
    }

    /// Open detail view for the currently selected port
    ///
    /// Handles navigation to the port detail view for the currently selected
    /// port in the ports list. This filters ports based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle ports view
        guard tui.viewCoordinator.currentView == .ports else {
            return false
        }

        // Filter ports using the same logic as itemCount
        let ports = tui.cacheManager.cachedPorts
        let filteredPorts: [Port]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredPorts = FilterUtils.filterPorts(ports, query: query)
        } else {
            filteredPorts = ports
        }

        // Validate selection
        guard !filteredPorts.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredPorts.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredPorts[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .portDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
