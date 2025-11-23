// Sources/Substation/Modules/Barbican/Extensions/BarbicanModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension BarbicanModule: ModuleNavigationProvider {

    /// Number of secrets in the current view
    ///
    /// Returns the count of cached secrets, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let secrets = tui.cacheManager.cachedSecrets

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = secrets.filter { secret in
                (secret.name?.lowercased().contains(query.lowercased()) ?? false) ||
                (secret.secretType?.lowercased().contains(query.lowercased()) ?? false)
            }
            return filtered.count
        }

        return secrets.count
    }

    /// Maximum selection index for secrets view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh secret data from the API
    ///
    /// Clears cached secret data and fetches fresh data from Barbican.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("BarbicanModule refreshing data", context: [:])

        // Fetch secrets
        let secrets = try await tui.client.barbican.listSecrets()
        tui.cacheManager.cachedSecrets = secrets

        Logger.shared.logInfo("BarbicanModule refresh completed", context: [
            "secretCount": secrets.count
        ])
    }

    /// Get contextual command suggestions for secrets view
    ///
    /// Returns commands that are commonly used when working with secrets,
    /// such as related resource views and secret operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["servers", "volumes"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since BarbicanModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Ensure required data is loaded for the current Barbican view
    ///
    /// Lazily loads secrets data when entering Barbican views if not already cached.
    /// This prevents empty views when navigating directly to Barbican resources.
    ///
    /// - Parameter tui: The TUI instance for accessing view state and cache
    func ensureDataLoaded(tui: TUI) async {
        switch tui.viewCoordinator.currentView {
        case .barbicanSecrets, .barbican:
            if tui.cacheManager.cachedSecrets.isEmpty {
                Logger.shared.logInfo("Loading Barbican secrets data on view change")
                let _ = await DataProviderRegistry.shared.fetchData(for: "secrets", priority: .onDemand, forceRefresh: true)
            }
        default:
            break
        }
    }

    /// Open detail view for the currently selected secret
    ///
    /// Handles navigation to the secret detail view for the currently selected
    /// secret in the secrets list. This filters secrets based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle barbican secrets view
        guard tui.viewCoordinator.currentView == .barbicanSecrets else {
            return false
        }

        // Filter secrets using the same logic as itemCount
        let secrets = tui.cacheManager.cachedSecrets
        let filteredSecrets: [Secret]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredSecrets = secrets.filter { secret in
                (secret.name?.lowercased().contains(query.lowercased()) ?? false) ||
                (secret.secretType?.lowercased().contains(query.lowercased()) ?? false)
            }
        } else {
            filteredSecrets = secrets
        }

        // Validate selection
        guard !filteredSecrets.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredSecrets.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredSecrets[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .barbicanSecretDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}
