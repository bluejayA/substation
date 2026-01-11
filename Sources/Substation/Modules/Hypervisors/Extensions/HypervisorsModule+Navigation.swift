// Sources/Substation/Modules/Hypervisors/Extensions/HypervisorsModule+Navigation.swift
import Foundation
import OSClient

/// Navigation provider implementation for Hypervisors module
extension HypervisorsModule: ModuleNavigationProvider {

    // MARK: - ModuleNavigationProvider Protocol

    /// Total number of items in the current list
    var itemCount: Int {
        guard let tui = tui else { return 0 }
        let hypervisors = tui.cacheManager.cachedHypervisors
        if let query = tui.searchQuery, !query.isEmpty {
            return FilterUtils.filterHypervisors(hypervisors, query: query).count
        }
        return hypervisors.count
    }

    /// Maximum valid selection index
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh hypervisor data from API
    ///
    /// - Throws: API errors or network errors
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        let hypervisors = try await tui.client.nova.listHypervisors(forceRefresh: true)
        tui.cacheManager.cachedHypervisors = hypervisors
    }

    /// Get contextual search suggestions
    ///
    /// - Returns: Array of suggested search terms
    func getContextualSuggestions() -> [String] {
        return [
            "up",
            "down",
            "enabled",
            "disabled",
            "kvm",
            "qemu"
        ]
    }

    /// Navigation provider for delegation
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for selected hypervisor
    ///
    /// - Parameter tui: TUI instance
    /// - Returns: True if navigation was successful
    func openDetailView(tui: TUI) -> Bool {
        let hypervisors = tui.cacheManager.cachedHypervisors
        let filteredHypervisors = FilterUtils.filterHypervisors(
            hypervisors,
            query: tui.searchQuery
        )

        guard tui.viewCoordinator.selectedIndex < filteredHypervisors.count else {
            return false
        }

        let selectedHypervisor = filteredHypervisors[tui.viewCoordinator.selectedIndex]
        tui.viewCoordinator.selectedResource = selectedHypervisor
        tui.changeView(to: .hypervisorDetail, resetSelection: false)
        return true
    }
}
