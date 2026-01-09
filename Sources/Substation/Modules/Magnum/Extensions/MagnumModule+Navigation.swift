// Sources/Substation/Modules/Magnum/Extensions/MagnumModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension MagnumModule: ModuleNavigationProvider {

    /// Number of items in the current view
    ///
    /// Returns the count of cached items based on the current view mode.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        switch tui.viewCoordinator.currentView {
        case .clusters:
            let clusters = tui.cacheManager.cachedClusters
            if let query = tui.searchQuery, !query.isEmpty {
                return FilterUtils.filterClusters(clusters, query: query).count
            }
            return clusters.count

        case .clusterTemplates:
            let templates = tui.cacheManager.cachedClusterTemplates
            if let query = tui.searchQuery, !query.isEmpty {
                return FilterUtils.filterClusterTemplates(templates, query: query).count
            }
            return templates.count

        default:
            return 0
        }
    }

    /// Maximum selection index for the current view
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh Magnum data from the API
    ///
    /// Fetches clusters, templates, and related resources.
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("MagnumModule refreshing data", context: [:])

        let magnumService = await tui.client.magnum

        // Fetch clusters
        let clusters = try await magnumService.listClusters()
        tui.cacheManager.cachedClusters = clusters

        // Fetch cluster templates
        let templates = try await magnumService.listClusterTemplates()
        tui.cacheManager.cachedClusterTemplates = templates

        Logger.shared.logInfo("MagnumModule refresh completed", context: [
            "clusterCount": clusters.count,
            "templateCount": templates.count
        ])
    }

    /// Get contextual command suggestions for Magnum views
    func getContextualSuggestions() -> [String] {
        return ["clusters", "clustertemplates", "flavors", "images", "networks", "keypairs"]
    }

    /// Ensure data is loaded when navigating to Magnum views
    ///
    /// This loads cluster and template data if the cache is empty,
    /// preventing empty views when navigating directly.
    ///
    /// - Parameter tui: The TUI instance for accessing view state and cache
    func ensureDataLoaded(tui: TUI) async {
        switch tui.viewCoordinator.currentView {
        case .clusters, .clusterTemplates:
            // Check if we need to load data
            let clustersEmpty = tui.cacheManager.cachedClusters.isEmpty
            let templatesEmpty = tui.cacheManager.cachedClusterTemplates.isEmpty

            if clustersEmpty || templatesEmpty {
                Logger.shared.logInfo("Loading Magnum data on view change", context: [
                    "clustersEmpty": clustersEmpty,
                    "templatesEmpty": templatesEmpty
                ])
                let _ = await DataProviderRegistry.shared.fetchData(
                    for: "clusters",
                    priority: .onDemand,
                    forceRefresh: true
                )
            }
        default:
            break
        }
    }

    /// Navigation provider accessor
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected item
    ///
    /// - Parameter tui: The TUI instance
    /// - Returns: true if the detail view was opened
    func openDetailView(tui: TUI) -> Bool {
        switch tui.viewCoordinator.currentView {
        case .clusters:
            return openClusterDetail(tui: tui)

        case .clusterTemplates:
            return openClusterTemplateDetail(tui: tui)

        default:
            return false
        }
    }

    /// Open cluster detail view
    private func openClusterDetail(tui: TUI) -> Bool {
        let clusters = tui.cacheManager.cachedClusters
        let filtered = FilterUtils.filterClusters(clusters, query: tui.searchQuery)

        guard tui.viewCoordinator.selectedIndex < filtered.count else {
            return false
        }

        let cluster = filtered[tui.viewCoordinator.selectedIndex]
        tui.viewCoordinator.selectedResource = cluster
        tui.viewCoordinator.previousView = .clusters
        tui.viewCoordinator.currentView = .clusterDetail

        // Fetch nodegroups for the cluster
        Task {
            do {
                let magnumService = await tui.client.magnum
                let nodegroups = try await magnumService.listNodegroups(clusterId: cluster.uuid)
                tui.cacheManager.cachedNodegroups = nodegroups
            } catch {
                Logger.shared.logError("Failed to fetch nodegroups: \(error)")
            }
        }

        return true
    }

    /// Open cluster template detail view
    private func openClusterTemplateDetail(tui: TUI) -> Bool {
        let templates = tui.cacheManager.cachedClusterTemplates
        let filtered = FilterUtils.filterClusterTemplates(templates, query: tui.searchQuery)

        guard tui.viewCoordinator.selectedIndex < filtered.count else {
            return false
        }

        let template = filtered[tui.viewCoordinator.selectedIndex]
        tui.viewCoordinator.selectedResource = template
        tui.viewCoordinator.previousView = .clusterTemplates
        tui.viewCoordinator.currentView = .clusterTemplateDetail

        return true
    }

    /// Handle escape key for navigation
    ///
    /// - Parameter tui: The TUI instance
    /// - Returns: true if escape was handled
    func handleEscape(tui: TUI) -> Bool {
        switch tui.viewCoordinator.currentView {
        case .clusterDetail:
            tui.viewCoordinator.currentView = .clusters
            tui.viewCoordinator.selectedResource = nil
            return true

        case .clusterTemplateDetail:
            tui.viewCoordinator.currentView = .clusterTemplates
            tui.viewCoordinator.selectedResource = nil
            return true

        case .clusterCreate:
            tui.viewCoordinator.currentView = .clusters
            return true

        case .clusterResize:
            tui.viewCoordinator.currentView = .clusterDetail
            return true

        default:
            return false
        }
    }
}
