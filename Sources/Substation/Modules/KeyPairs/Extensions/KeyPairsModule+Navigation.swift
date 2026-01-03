// Sources/Substation/Modules/KeyPairs/Extensions/KeyPairsModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension KeyPairsModule: ModuleNavigationProvider {

    /// Number of key pairs in the current view
    ///
    /// Returns the count of cached key pairs, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let keyPairs = tui.cacheManager.cachedKeyPairs

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterKeyPairs(keyPairs, query: query)
            return filtered.count
        }

        return keyPairs.count
    }

    /// Maximum selection index for key pairs view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh key pair data from the API
    ///
    /// Clears cached key pair data and fetches fresh data from Nova.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("KeyPairsModule refreshing data", context: [:])

        // Fetch key pairs
        let keyPairs = try await tui.client.nova.listKeyPairs(forceRefresh: true)
        tui.cacheManager.cachedKeyPairs = keyPairs

        Logger.shared.logInfo("KeyPairsModule refresh completed", context: [
            "keyPairCount": keyPairs.count
        ])
    }

    /// Get contextual command suggestions for key pairs view
    ///
    /// Returns commands that are commonly used when working with key pairs,
    /// such as related resource views and key pair operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["servers"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since KeyPairsModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected key pair
    ///
    /// Handles navigation to the key pair detail view for the currently selected
    /// key pair in the key pairs list. This filters key pairs based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle key pairs view
        guard tui.viewCoordinator.currentView == .keyPairs else {
            return false
        }

        // Filter key pairs using the same logic as itemCount
        let keyPairs = tui.cacheManager.cachedKeyPairs
        let filteredKeyPairs: [KeyPair]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredKeyPairs = FilterUtils.filterKeyPairs(keyPairs, query: query)
        } else {
            filteredKeyPairs = keyPairs
        }

        // Validate selection
        guard !filteredKeyPairs.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredKeyPairs.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredKeyPairs[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .keyPairDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
