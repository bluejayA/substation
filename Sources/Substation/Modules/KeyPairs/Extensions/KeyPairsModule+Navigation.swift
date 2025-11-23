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
    /// Key pairs do not have a detail view, so this always returns false.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: false as key pairs do not have detail views
    func openDetailView(tui: TUI) -> Bool {
        // Key pairs do not have a detail view
        return false
    }
}
