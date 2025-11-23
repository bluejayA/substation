// Sources/Substation/Modules/Swift/Extensions/SwiftModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension SwiftModule: ModuleNavigationProvider {

    /// Number of items in the current Swift view
    ///
    /// Returns the count of items based on the current view context:
    /// - Container list: Returns filtered container count
    /// - Container detail: Returns filtered tree item count for current path
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let currentView = tui.viewCoordinator.currentView

        switch currentView {
        case .swift:
            // Container list view
            let containers = tui.cacheManager.cachedSwiftContainers

            // Apply search filter if present
            if let query = tui.searchQuery, !query.isEmpty {
                let filtered = containers.filter {
                    $0.name?.localizedCaseInsensitiveContains(query) ?? false
                }
                return filtered.count
            }

            return containers.count

        case .swiftContainerDetail:
            // Object/directory tree view
            guard let objects = tui.cacheManager.cachedSwiftObjects else {
                return 0
            }

            let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)

            // Apply search filter if present
            if let query = tui.searchQuery, !query.isEmpty {
                let filtered = SwiftTreeItem.filterItems(treeItems, query: query)
                return filtered.count
            }

            return treeItems.count

        case .swiftBackgroundOperations:
            // Background operations list
            return tui.swiftBackgroundOps.getAllOperations().count

        default:
            return 0
        }
    }

    /// Maximum selection index for Swift views
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh Swift data from the API
    ///
    /// Refreshes data based on the current view context:
    /// - Container list: Fetches all containers
    /// - Container detail: Fetches objects for the current container
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("SwiftModule refreshing data", context: [:])

        let currentView = tui.viewCoordinator.currentView

        switch currentView {
        case .swift:
            // Refresh container list
            let containers = try await tui.client.swift.listContainers()
            tui.cacheManager.cachedSwiftContainers = containers

            Logger.shared.logInfo("SwiftModule refresh completed", context: [
                "containerCount": containers.count
            ])

        case .swiftContainerDetail:
            // Refresh objects in current container
            if let containerName = tui.viewCoordinator.swiftNavState.currentContainer {
                // Clear ETag cache to force fresh fetch
                clearETagCache(forContainer: containerName)

                let objects = try await tui.client.swift.listObjects(containerName: containerName)
                await setSwiftObjects(objects, forContainer: containerName)

                // Rebuild prefetched trees
                await prefetchSubdirectoryTrees(containerName: containerName, objects: objects)

                Logger.shared.logInfo("SwiftModule refresh completed", context: [
                    "containerName": containerName,
                    "objectCount": objects.count
                ])
            }

        default:
            // For other Swift views, refresh the container list as default
            let containers = try await tui.client.swift.listContainers()
            tui.cacheManager.cachedSwiftContainers = containers

            Logger.shared.logInfo("SwiftModule refresh completed", context: [
                "containerCount": containers.count
            ])
        }
    }

    /// Get contextual command suggestions for Swift views
    ///
    /// Returns commands that are commonly used when working with Swift storage,
    /// such as related resource views and object operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        guard let tui = tui else { return [] }

        let currentView = tui.viewCoordinator.currentView

        switch currentView {
        case .swift:
            return ["volumes", "images", "servers"]

        case .swiftContainerDetail:
            // Suggest navigation commands when inside a container
            return ["swift", "volumes", "servers"]

        case .swiftBackgroundOperations:
            return ["swift", "servers", "volumes"]

        default:
            return ["swift", "volumes", "servers"]
        }
    }

    /// Navigation provider accessor
    ///
    /// Returns self since SwiftModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Ensure required data is loaded for the current Swift view
    ///
    /// Lazily loads Swift objects when entering the container detail view if not already cached.
    /// This prevents empty views when navigating directly to container contents.
    ///
    /// - Parameter tui: The TUI instance for accessing view state and cache
    func ensureDataLoaded(tui: TUI) async {
        switch tui.viewCoordinator.currentView {
        case .swiftContainerDetail:
            if let containerName = tui.viewCoordinator.swiftNavState.currentContainer {
                Logger.shared.logInfo("Loading Swift objects for container: \(containerName)")
                if let swiftModule = ModuleRegistry.shared.module(for: "swift") as? SwiftModule {
                    await swiftModule.fetchSwiftObjects(containerName: containerName, priority: "interactive")
                }
            }
        default:
            break
        }
    }

    /// Open detail view for the currently selected Swift resource
    ///
    /// Handles navigation based on the current Swift view context:
    /// - Container list (.swift): Returns false (handled by ViewRegistry inputHandler)
    /// - Container detail (.swiftContainerDetail): Opens object detail or navigates into directory
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        let currentView = tui.viewCoordinator.currentView

        switch currentView {
        case .swift:
            // Container list view navigation is handled by ViewRegistry inputHandler
            // which properly handles navigateIntoContainer and fetchSwiftObjects
            return false

        case .swiftContainerDetail:
            // Object/directory tree view
            guard let objects = tui.cacheManager.cachedSwiftObjects else {
                return false
            }

            let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)

            // Apply search filter if present
            let filteredItems: [SwiftTreeItem]
            if let query = tui.searchQuery, !query.isEmpty {
                filteredItems = SwiftTreeItem.filterItems(treeItems, query: query)
            } else {
                filteredItems = treeItems
            }

            // Validate selection
            guard !filteredItems.isEmpty &&
                  tui.viewCoordinator.selectedIndex < filteredItems.count else {
                return false
            }

            let selectedItem = filteredItems[tui.viewCoordinator.selectedIndex]
            switch selectedItem {
            case .object(let object):
                tui.viewCoordinator.selectedResource = object
                tui.changeView(to: .swiftObjectDetail, resetSelection: false)
                tui.viewCoordinator.detailScrollOffset = 0
                return true

            case .directory(let name, _, _):
                // Navigate into subdirectory - no loading state needed since all objects are cached
                tui.viewCoordinator.swiftNavState.navigateIntoDirectory(name)
                tui.viewCoordinator.selectedIndex = 0
                tui.viewCoordinator.scrollOffset = 0
                return true
            }

        default:
            return false
        }
    }
}
