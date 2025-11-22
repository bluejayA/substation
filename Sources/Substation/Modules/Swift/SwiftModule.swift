// Sources/Substation/Modules/Swift/SwiftModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Swift (Object Storage) module implementation
/// Provides comprehensive object storage management capabilities including containers,
/// objects, metadata management, and background operations tracking.
@MainActor
final class SwiftModule: OpenStackModule {

    // MARK: - OpenStackModule Protocol Properties

    let identifier: String = "swift"
    let displayName: String = "Object Storage (Swift)"
    let version: String = "1.0.0"
    let dependencies: [String] = []

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    /// Background sync task for keeping active container cache up to date
    private var backgroundSyncTask: Task<Void, Never>?

    /// Interval between background sync operations (in seconds)
    private let backgroundSyncInterval: TimeInterval = 60

    // MARK: - Initialization

    /// Initialize the Swift module with TUI context
    /// - Parameter tui: The main TUI instance providing access to OpenStack client and UI state
    required init(tui: TUI) {
        self.tui = tui
        Logger.shared.logInfo("SwiftModule initialized", context: [
            "version": version,
            "identifier": identifier
        ])
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    /// Performs any necessary setup, validation, and initialization tasks
    func configure() async throws {
        guard let tuiInstance = tui else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        Logger.shared.logInfo("SwiftModule configuration started", context: [:])

        // Module configured successfully
        // Swift service availability will be checked during actual API calls
        Logger.shared.logInfo("SwiftModule configuration completed", context: [:])

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .swift,
            detailViewMode: .swiftContainerDetail
        )

        // Register as data provider
        let dataProvider = SwiftDataProvider(module: self, tui: tuiInstance)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)

        // Start background sync task for active container
        startBackgroundSyncTask()
    }

    // MARK: - Background Sync

    /// Start the background sync task for keeping active container cache up to date
    private func startBackgroundSyncTask() {
        // Cancel any existing task
        backgroundSyncTask?.cancel()

        backgroundSyncTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                // Sleep for the sync interval
                try? await Task.sleep(nanoseconds: UInt64(self.backgroundSyncInterval * 1_000_000_000))

                // Check if cancelled during sleep
                if Task.isCancelled { break }

                // Perform background sync
                await self.performBackgroundSync()
            }

            Logger.shared.logDebug("SwiftModule background sync task stopped")
        }

        Logger.shared.logInfo("SwiftModule background sync task started (interval: \(Int(backgroundSyncInterval))s) with ETag-based differential sync")
    }

    /// Stop the background sync task
    func stopBackgroundSyncTask() {
        backgroundSyncTask?.cancel()
        backgroundSyncTask = nil
        Logger.shared.logDebug("SwiftModule background sync task cancelled")
    }

    /// Perform a background sync of the active container's objects
    ///
    /// This refreshes the cache for the currently viewed container to detect
    /// any changes made outside of Substation. Uses ETag-based differential
    /// sync to avoid unnecessary full fetches.
    private func performBackgroundSync() async {
        // Use differential sync with ETag checking
        await performDifferentialSync()
    }

    /// Revalidate container cache in background (stale-while-revalidate pattern)
    ///
    /// Uses ETag-based differential sync to detect changes and avoid unnecessary
    /// full fetches. Shows status indicator while revalidating.
    ///
    /// - Parameter containerName: Name of the container to revalidate
    private func revalidateContainerCache(containerName: String) async {
        guard let tui = tui else { return }

        // Show revalidating indicator
        tui.statusMessage = "Refreshing \(containerName)..."

        Logger.shared.logDebug("SwiftModule - Revalidating cache for container '\(containerName)' with ETag check")

        // Use ETag-based differential sync
        let refreshed = await fetchWithETagCheck(containerName: containerName)

        // Check if we're still viewing this container
        if tui.viewCoordinator.swiftNavState.currentContainer == containerName {
            if refreshed {
                // Validate selectedIndex after cache update to prevent out-of-bounds access
                await validateSelectedIndexAfterCacheUpdate()

                let objectCount = tui.cacheManager.cachedSwiftObjects?.count ?? 0
                Logger.shared.logInfo("SwiftModule - Revalidation detected change: \(objectCount) objects")
                tui.statusMessage = "Updated: \(objectCount) objects"
            } else {
                Logger.shared.logDebug("SwiftModule - Revalidation completed, no changes (ETag match)")
                tui.statusMessage = nil
            }
            tui.markNeedsRedraw()
        }

        // Manage cache size - evict old containers if needed
        await manageCacheSize()
    }

    // MARK: - Cache Management

    /// Maximum number of containers to keep cached
    private let maxCachedContainers = 10

    /// Prefetched directory tree cache for instant navigation
    private var prefetchedTrees: [String: [SwiftTreeItem]] = [:]

    /// ETag cache for differential sync
    private var containerETags: [String: String] = [:]

    /// Manage cache size by evicting least recently used containers
    ///
    /// Keeps only the most recently accessed containers to manage memory.
    private func manageCacheSize() async {
        guard let tui = tui else { return }

        // Get all cached container names with their timestamps
        let cachedContainers = tui.cacheManager.resourceCache.swiftObjectsByContainer.keys
        guard cachedContainers.count > maxCachedContainers else { return }

        // Build list of containers with their cache times
        var containerTimes: [(name: String, time: Date)] = []
        for containerName in cachedContainers {
            if let cacheTime = tui.cacheManager.getSwiftObjectsCacheTime(forContainer: containerName) {
                containerTimes.append((name: containerName, time: cacheTime))
            }
        }

        // Sort by time (oldest first)
        containerTimes.sort { $0.time < $1.time }

        // Evict oldest containers until we're under the limit
        let containersToEvict = containerTimes.count - maxCachedContainers
        if containersToEvict > 0 {
            for i in 0..<containersToEvict {
                let containerName = containerTimes[i].name
                // Don't evict the currently viewed container
                if containerName != tui.viewCoordinator.swiftNavState.currentContainer {
                    tui.cacheManager.clearSwiftObjects(forContainer: containerName)
                    clearPrefetchedTrees(forContainer: containerName)
                    clearETagCache(forContainer: containerName)
                    Logger.shared.logDebug("SwiftModule - Evicted cached objects for container '\(containerName)' (LRU)")
                }
            }
        }
    }

    // MARK: - Prefetching

    /// Prefetch subdirectory trees for instant navigation
    ///
    /// After loading a container's objects, this method pre-builds tree structures
    /// for immediate subdirectories so navigation is instant.
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - objects: All objects in the container
    private func prefetchSubdirectoryTrees(containerName: String, objects: [SwiftObject]) async {
        // Build tree for root path to identify top-level directories
        let rootTree = SwiftTreeItem.buildTree(from: objects, currentPath: "")

        // Find top-level directories to prefetch
        var directoriesToPrefetch: [String] = []
        for item in rootTree {
            if case .directory(let name, _, _) = item {
                directoriesToPrefetch.append(name)
            }
        }

        // Limit prefetching to first 10 directories to avoid excessive memory use
        let prefetchLimit = min(directoriesToPrefetch.count, 10)

        Logger.shared.logDebug("SwiftModule - Prefetching \(prefetchLimit) subdirectory trees for container '\(containerName)'")

        // Prefetch tree structures in background
        for i in 0..<prefetchLimit {
            let dirName = directoriesToPrefetch[i]
            let dirPath = dirName + "/"

            // Build and cache tree for this subdirectory
            let tree = SwiftTreeItem.buildTree(from: objects, currentPath: dirPath)
            let cacheKey = "\(containerName):\(dirPath)"
            prefetchedTrees[cacheKey] = tree

            Logger.shared.logDebug("SwiftModule - Prefetched tree for '\(dirPath)' (\(tree.count) items)")
        }

        Logger.shared.logInfo("SwiftModule - Prefetched \(prefetchLimit) subdirectory trees for container '\(containerName)'")
    }

    /// Get prefetched tree for a container path, or build it if not cached
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - path: Current path within the container
    ///   - objects: All objects in the container
    /// - Returns: Tree items for the specified path
    func getPrefetchedTree(containerName: String, path: String, objects: [SwiftObject]) -> [SwiftTreeItem] {
        let cacheKey = "\(containerName):\(path)"

        // Check if we have a prefetched tree
        if let cached = prefetchedTrees[cacheKey] {
            Logger.shared.logDebug("SwiftModule - Using prefetched tree for '\(path)'")
            return cached
        }

        // Build tree on demand
        let tree = SwiftTreeItem.buildTree(from: objects, currentPath: path)

        // Cache it for future use
        prefetchedTrees[cacheKey] = tree

        return tree
    }

    /// Clear prefetched trees for a container
    ///
    /// - Parameter containerName: Name of the container
    func clearPrefetchedTrees(forContainer containerName: String) {
        let keysToRemove = prefetchedTrees.keys.filter { $0.hasPrefix("\(containerName):") }
        for key in keysToRemove {
            prefetchedTrees.removeValue(forKey: key)
        }
        Logger.shared.logDebug("SwiftModule - Cleared \(keysToRemove.count) prefetched trees for container '\(containerName)'")
    }

    // MARK: - Differential Sync (ETags)

    /// Fetch container objects with ETag-based differential sync
    ///
    /// Uses ETags to detect if container contents have changed. Only fetches
    /// full object list if ETag differs from cached value.
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    /// - Returns: True if objects were refreshed, false if cache is still valid
    private func fetchWithETagCheck(containerName: String) async -> Bool {
        guard let tui = tui else { return false }

        // Get stored ETag for this container
        let storedETag = containerETags[containerName]

        do {
            // First, do a HEAD request to get current ETag without fetching objects
            // Note: Swift API returns ETag in container metadata
            let containerInfo = try await tui.client.swift.getContainerMetadata(containerName: containerName)

            // Extract ETag from response (use object count as pseudo-ETag)
            let currentETag = String(containerInfo.objectCount)

            // Compare ETags
            if let stored = storedETag, stored == currentETag {
                Logger.shared.logDebug("SwiftModule - ETag match for container '\(containerName)', skipping fetch")
                return false
            }

            // ETags differ or no stored ETag - fetch full object list
            Logger.shared.logDebug("SwiftModule - ETag mismatch for container '\(containerName)', fetching objects (stored: \(storedETag ?? "nil"), current: \(currentETag))")

            let objects = try await tui.client.swift.listObjects(containerName: containerName)

            // Update cache with fresh data
            await self.setSwiftObjects(objects, forContainer: containerName)

            // Store new ETag
            containerETags[containerName] = currentETag

            // Prefetch subdirectory trees with new data
            await prefetchSubdirectoryTrees(containerName: containerName, objects: objects)

            return true
        } catch {
            Logger.shared.logError("SwiftModule - ETag check failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Perform differential sync for active container using ETags
    ///
    /// Only fetches objects if the container's ETag (object count) has changed.
    private func performDifferentialSync() async {
        guard let tui = tui else { return }

        // Only sync if we're viewing a Swift container
        guard tui.viewCoordinator.currentView == .swiftContainerDetail else {
            return
        }

        // Get the current container name
        guard let containerName = tui.viewCoordinator.swiftNavState.currentContainer else {
            return
        }

        // Check if cache exists - only sync if we have existing data
        guard tui.cacheManager.cachedSwiftObjects != nil else {
            return
        }

        // Don't sync if an operation is in progress
        if tui.viewCoordinator.isLoadingSwiftObjects {
            return
        }

        Logger.shared.logDebug("SwiftModule - Performing differential sync for container '\(containerName)'")

        // Use ETag-based check
        let refreshed = await fetchWithETagCheck(containerName: containerName)

        if refreshed {
            // Validate selectedIndex after cache update to prevent out-of-bounds access
            await validateSelectedIndexAfterCacheUpdate()

            // Show status update
            let objectCount = tui.cacheManager.cachedSwiftObjects?.count ?? 0
            tui.statusMessage = "Updated: \(objectCount) objects"
            tui.markNeedsRedraw()

            // Clear status after delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if tui.statusMessage == "Updated: \(objectCount) objects" {
                    tui.statusMessage = nil
                }
            }
        }
    }

    /// Validate and correct selectedIndex after cache updates
    ///
    /// Ensures selectedIndex remains within bounds after background cache updates.
    /// This prevents rendering issues when the cache size changes.
    private func validateSelectedIndexAfterCacheUpdate() async {
        guard let tui = tui else { return }

        // Get current objects and build tree for the current path
        guard let objects = tui.cacheManager.cachedSwiftObjects else { return }

        let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
        let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)

        // Apply search filter if present
        let searchQuery = tui.searchQuery ?? ""
        let filteredItems = SwiftTreeItem.filterItems(treeItems, query: searchQuery.isEmpty ? nil : searchQuery)

        // Validate selectedIndex
        let itemCount = filteredItems.count
        if itemCount == 0 {
            tui.viewCoordinator.selectedIndex = 0
            tui.viewCoordinator.scrollOffset = 0
        } else if tui.viewCoordinator.selectedIndex >= itemCount {
            let oldIndex = tui.viewCoordinator.selectedIndex
            tui.viewCoordinator.selectedIndex = itemCount - 1
            Logger.shared.logDebug("SwiftModule - Validated selectedIndex: \(oldIndex) -> \(tui.viewCoordinator.selectedIndex) (items: \(itemCount))")
        }

        // Validate scrollOffset
        let visibleItems = max(5, Int(tui.screenRows) - 10)
        let maxScrollOffset = max(0, itemCount - visibleItems)
        if tui.viewCoordinator.scrollOffset > maxScrollOffset {
            tui.viewCoordinator.scrollOffset = maxScrollOffset
        }

        // Ensure selectedIndex is visible within viewport
        if tui.viewCoordinator.selectedIndex < tui.viewCoordinator.scrollOffset {
            tui.viewCoordinator.scrollOffset = tui.viewCoordinator.selectedIndex
        } else if tui.viewCoordinator.selectedIndex >= tui.viewCoordinator.scrollOffset + visibleItems {
            tui.viewCoordinator.scrollOffset = max(0, tui.viewCoordinator.selectedIndex - visibleItems + 1)
        }
    }

    /// Clear ETag cache for a container
    ///
    /// - Parameter containerName: Name of the container
    func clearETagCache(forContainer containerName: String) {
        containerETags.removeValue(forKey: containerName)
        Logger.shared.logDebug("SwiftModule - Cleared ETag cache for container '\(containerName)'")
    }

    // MARK: - View Registration

    /// Register all Swift-related views with the TUI system
    /// - Returns: Array of view registrations for containers, objects, metadata, and operations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register views - TUI reference is nil", context: [:])
            return []
        }

        return [
            // Main container list view
            ModuleViewRegistration(
                viewMode: .swift,
                title: "Swift Containers",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerListView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak self, weak tui] ch, screen in
                    guard let self = self, let tui = tui else { return false }

                    // Debug: Log that this handler is being called
                    if ch == Int32(32) {
                        Logger.shared.logDebug("SwiftModule.swift inputHandler received SPACEBAR")
                    }

                    // Filter containers based on search query to match displayed list
                    let filteredContainers: [SwiftContainer]
                    if let query = tui.searchQuery, !query.isEmpty {
                        filteredContainers = tui.cacheManager.cachedSwiftContainers.filter {
                            $0.name?.localizedCaseInsensitiveContains(query) ?? false
                        }
                    } else {
                        filteredContainers = tui.cacheManager.cachedSwiftContainers
                    }

                    switch ch {
                    case Int32(32):  // SPACEBAR - Navigate into container
                        Logger.shared.logUserAction("swift_navigate_into_container_MVR", details: [
                            "selectedIndex": tui.viewCoordinator.selectedIndex,
                            "containerCount": filteredContainers.count,
                            "source": "ModuleViewRegistration"
                        ])
                        guard tui.viewCoordinator.selectedIndex < filteredContainers.count else {
                            tui.statusMessage = "No container selected [MVR] (idx: \(tui.viewCoordinator.selectedIndex), cnt: \(filteredContainers.count))"
                            return true
                        }
                        let container = filteredContainers[tui.viewCoordinator.selectedIndex]
                        guard let containerName = container.name else {
                            tui.statusMessage = "Invalid container"
                            return true
                        }

                        // Clear cached objects immediately for visual feedback
                        tui.cacheManager.clearSwiftObjects(forContainer: containerName)

                        // Set loading state before fetching
                        tui.viewCoordinator.isLoadingSwiftObjects = true

                        tui.viewCoordinator.swiftNavState.navigateIntoContainer(containerName)
                        tui.changeView(to: .swiftContainerDetail, resetSelection: true)
                        // Set selectedResource AFTER changeView because resetSelection clears it
                        tui.viewCoordinator.selectedResource = container

                        // Force screen redraw to show loading state
                        tui.renderCoordinator.renderOptimizer.markFullScreenDirty()
                        await tui.draw(screen: screen)

                        await self.fetchSwiftObjectsPaginated(containerName: containerName, marker: nil, limit: 100, priority: "interactive", forceRefresh: false)
                        return true

                    case Int32(87):  // W - Manage web access
                        Logger.shared.logUserAction("manage_container_web_access", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleManageContainerWebAccess(screen: screen)
                        return true

                    case Int32(77):  // M - Manage container metadata
                        Logger.shared.logUserAction("manage_container_metadata", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleManageContainerMetadata(screen: screen)
                        return true

                    case Int32(85):  // U - Upload object to container
                        Logger.shared.logUserAction("upload_object_to_container", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleUploadObjectToContainer(screen: screen)
                        return true

                    case Int32(68):  // D - Download container
                        Logger.shared.logUserAction("download_container", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleDownloadContainer(screen: screen)
                        return true

                    default:
                        return false
                    }
                },
                category: .storage
            ),

            // Container detail view
            ModuleViewRegistration(
                viewMode: .swiftContainerDetail,
                title: "Container Details",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerDetailView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak self, weak tui] ch, screen in
                    guard let self = self, let tui = tui else { return false }

                    switch ch {
                    case Int32(32):  // SPACEBAR - Navigate into directory or open object detail
                        Logger.shared.logUserAction("swift_navigate_into_item", details: [
                            "selectedIndex": tui.viewCoordinator.selectedIndex,
                            "currentPath": tui.viewCoordinator.swiftNavState.currentPathString
                        ])
                        guard let allObjects = tui.cacheManager.cachedSwiftObjects else {
                            tui.statusMessage = "No objects loaded"
                            return true
                        }
                        let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
                        let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)
                        guard tui.viewCoordinator.selectedIndex < treeItems.count else {
                            tui.statusMessage = "No item selected"
                            return true
                        }
                        let selectedItem = treeItems[tui.viewCoordinator.selectedIndex]
                        switch selectedItem {
                        case .object(let object):
                            tui.viewCoordinator.selectedResource = object
                            tui.changeView(to: .swiftObjectDetail, resetSelection: false)
                        case .directory(let name, _, _):
                            // Set loading state for directory navigation
                            tui.viewCoordinator.isLoadingSwiftObjects = true

                            tui.viewCoordinator.swiftNavState.navigateIntoDirectory(name)
                            tui.viewCoordinator.selectedIndex = 0
                            tui.viewCoordinator.scrollOffset = 0

                            // Force full redraw to show loading state
                            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()

                            // Clear loading state after navigation (tree is already cached)
                            tui.viewCoordinator.isLoadingSwiftObjects = false
                            tui.markNeedsRedraw()
                        }
                        return true

                    case Int32(77):  // M - Manage tree item metadata
                        Logger.shared.logUserAction("manage_tree_item_metadata", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleSwiftTreeItemMetadata(screen: screen)
                        return true

                    case Int32(85):  // U - Upload object
                        Logger.shared.logUserAction("upload_object_to_container_from_detail", details: ["container": tui.viewCoordinator.swiftNavState.currentContainer ?? "unknown"])
                        await self.handleUploadObjectToContainer(screen: screen)
                        return true

                    case Int32(68):  // D - Download object
                        Logger.shared.logUserAction("download_object", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleDownloadObject(screen: screen)
                        return true

                    case Int32(27):  // ESC - Navigate up in hierarchy or back to container list
                        // Check if we can navigate up within the hierarchy
                        if tui.viewCoordinator.swiftNavState.canNavigateUp() && !tui.viewCoordinator.swiftNavState.isAtContainerRoot {
                            // Navigate up one directory level
                            Logger.shared.logUserAction("swift_navigate_up", details: [
                                "fromPath": tui.viewCoordinator.swiftNavState.currentPathString,
                                "depth": tui.viewCoordinator.swiftNavState.depth
                            ])

                            tui.viewCoordinator.swiftNavState.navigateUp()

                            // Reset selection to top
                            tui.viewCoordinator.selectedIndex = 0
                            tui.viewCoordinator.scrollOffset = 0

                            // Stay in the same view (swiftContainerDetail)
                            tui.markNeedsRedraw()

                            Logger.shared.logInfo("Navigated up to path: \(tui.viewCoordinator.swiftNavState.currentPathString)")
                            return true
                        } else {
                            // Navigate back to container list
                            Logger.shared.logNavigation("swiftContainerDetail", to: "swift", details: [
                                "action": "escape_container",
                                "containerName": tui.viewCoordinator.swiftNavState.currentContainer ?? "unknown"
                            ])

                            // Clear cached objects for this container before navigating away
                            // This ensures fresh data will be fetched when re-entering the container
                            if let containerName = tui.viewCoordinator.swiftNavState.currentContainer {
                                tui.cacheManager.clearSwiftObjects(forContainer: containerName)
                                Logger.shared.logDebug("Cleared Swift objects cache for container '\(containerName)' on navigation up")
                            }

                            // Restore selection to the container that was opened
                            if let containerName = tui.viewCoordinator.swiftNavState.currentContainer,
                               let index = tui.cacheManager.cachedSwiftContainers.firstIndex(where: { $0.name == containerName }) {
                                tui.viewCoordinator.selectedIndex = index
                                // Ensure the selected item is visible in the viewport
                                let visibleItems = Int(tui.screenRows) - 10
                                if index < tui.viewCoordinator.scrollOffset {
                                    tui.viewCoordinator.scrollOffset = index
                                } else if index >= tui.viewCoordinator.scrollOffset + visibleItems {
                                    tui.viewCoordinator.scrollOffset = max(0, index - visibleItems + 1)
                                }
                            }

                            // Reset navigation state
                            tui.viewCoordinator.swiftNavState.reset()

                            // Return to container list view
                            tui.changeView(to: .swift, resetSelection: false)
                            tui.viewCoordinator.selectedResource = nil
                            return true
                        }

                    default:
                        return false
                    }
                },
                category: .storage
            ),

            // Object detail view
            ModuleViewRegistration(
                viewMode: .swiftObjectDetail,
                title: "Object Details",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftObjectDetailView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, _ in
                    guard let tui = tui else { return false }

                    switch ch {
                    case Int32(27):  // ESC - Return to container detail with selection restored
                        Logger.shared.logNavigation("swiftObjectDetail", to: "swiftContainerDetail", details: ["action": "escape_detail"])

                        // Restore selection to the object that was opened
                        if let object = tui.viewCoordinator.selectedResource as? SwiftObject,
                           let objectName = object.name,
                           let objects = tui.cacheManager.cachedSwiftObjects,
                           let index = objects.firstIndex(where: { $0.name == objectName }) {
                            tui.viewCoordinator.selectedIndex = index
                            // Ensure the selected item is visible in the viewport
                            let visibleItems = Int(tui.screenRows) - 10
                            if index < tui.viewCoordinator.scrollOffset {
                                tui.viewCoordinator.scrollOffset = index
                            } else if index >= tui.viewCoordinator.scrollOffset + visibleItems {
                                tui.viewCoordinator.scrollOffset = max(0, index - visibleItems + 1)
                            }
                        }

                        tui.changeView(to: .swiftContainerDetail, resetSelection: false)
                        tui.viewCoordinator.selectedResource = nil
                        return true

                    default:
                        return false
                    }
                },
                category: .storage
            ),

            // Container create form
            ModuleViewRegistration(
                viewMode: .swiftContainerCreate,
                title: "Create Container",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerCreateView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftContainerCreateInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Object upload form
            ModuleViewRegistration(
                viewMode: .swiftObjectUpload,
                title: "Upload Object",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftObjectUploadView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftObjectUploadInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Container download form
            ModuleViewRegistration(
                viewMode: .swiftContainerDownload,
                title: "Download Container",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerDownloadView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftContainerDownloadInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Object download form
            ModuleViewRegistration(
                viewMode: .swiftObjectDownload,
                title: "Download Object",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftObjectDownloadView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftObjectDownloadInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Directory download form
            ModuleViewRegistration(
                viewMode: .swiftDirectoryDownload,
                title: "Download Directory",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftDirectoryDownloadView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftDirectoryDownloadInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Container metadata form
            ModuleViewRegistration(
                viewMode: .swiftContainerMetadata,
                title: "Set Container Metadata",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerMetadataView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftContainerMetadataInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Object metadata form
            ModuleViewRegistration(
                viewMode: .swiftObjectMetadata,
                title: "Set Object Metadata",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftObjectMetadataView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftObjectMetadataInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Directory metadata form
            ModuleViewRegistration(
                viewMode: .swiftDirectoryMetadata,
                title: "Set Directory Metadata",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftDirectoryMetadataView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftDirectoryMetadataInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Container web access form
            ModuleViewRegistration(
                viewMode: .swiftContainerWebAccess,
                title: "Manage Web Access",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerWebAccessView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftContainerWebAccessInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Background operations list
            ModuleViewRegistration(
                viewMode: .swiftBackgroundOperations,
                title: "Background Operations",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftBackgroundOperationsView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }

                    switch ch {
                    case Int32(32):  // SPACEBAR - Open operation detail
                        let operations = tui.swiftBackgroundOps.getAllOperations()
                        guard tui.viewCoordinator.selectedIndex < operations.count else {
                            tui.statusMessage = "No operation selected"
                            return true
                        }

                        let operation = operations[tui.viewCoordinator.selectedIndex]
                        tui.viewCoordinator.selectedResource = operation
                        tui.changeView(to: .swiftBackgroundOperationDetail, resetSelection: false)
                        tui.viewCoordinator.detailScrollOffset = 0
                        return true

                    case Int32(77):  // M - Show performance metrics
                        Logger.shared.logUserAction("show_performance_metrics", details: ["view": "swiftBackgroundOperations"])
                        Logger.shared.logNavigation("swiftBackgroundOperations", to: "performanceMetrics")
                        tui.viewCoordinator.scrollOffset = 0
                        tui.changeView(to: .performanceMetrics, resetSelection: false)
                        return true

                    case Int32(127), Int32(330):  // DELETE/BACKSPACE - Cancel or remove operation
                        let operations = tui.swiftBackgroundOps.getAllOperations()
                        guard tui.viewCoordinator.selectedIndex < operations.count else {
                            tui.statusMessage = "No operation selected"
                            await tui.draw(screen: screen)
                            return true
                        }

                        let operation = operations[tui.viewCoordinator.selectedIndex]

                        // Context-aware behavior based on operation status
                        if operation.status.isActive {
                            // Active operation: Cancel it
                            let operationDesc = operation.displayName
                            let confirmed = await ViewUtils.confirmOperation(
                                title: "Cancel Operation",
                                message: "Cancel '\(operationDesc)'?",
                                details: [
                                    "Type: \(operation.type.displayName)",
                                    "Status: \(operation.status.displayName)",
                                    "Progress: \(operation.progressPercentage)%"
                                ],
                                screen: screen,
                                screenRows: tui.screenRows,
                                screenCols: tui.screenCols
                            )

                            guard confirmed else {
                                tui.statusMessage = "Cancellation aborted"
                                await tui.draw(screen: screen)
                                return true
                            }

                            operation.cancel()
                            tui.statusMessage = "Operation cancelled: \(operation.displayName)"
                            Logger.shared.logUserAction("cancel_background_operation", details: [
                                "operationId": operation.id.uuidString,
                                "type": "\(operation.type)",
                                "objectName": operation.objectName ?? "unknown"
                            ])
                        } else {
                            // Inactive operation: Remove from history
                            let operationDesc = operation.displayName
                            let confirmed = await ViewUtils.confirmOperation(
                                title: "Remove Operation",
                                message: "Remove '\(operationDesc)' from history?",
                                details: [
                                    "Type: \(operation.type.displayName)",
                                    "Status: \(operation.status.displayName)"
                                ],
                                screen: screen,
                                screenRows: tui.screenRows,
                                screenCols: tui.screenCols
                            )

                            guard confirmed else {
                                tui.statusMessage = "Removal aborted"
                                await tui.draw(screen: screen)
                                return true
                            }

                            tui.swiftBackgroundOps.removeOperation(id: operation.id)

                            // Reset selection immediately after removal
                            let remainingOps = tui.swiftBackgroundOps.getAllOperations()
                            if tui.viewCoordinator.selectedIndex >= remainingOps.count {
                                tui.viewCoordinator.selectedIndex = max(0, remainingOps.count - 1)
                            }

                            // Force full screen refresh to immediately show the removal
                            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()

                            tui.statusMessage = "Removed operation: \(operation.displayName)"
                            Logger.shared.logUserAction("remove_background_operation", details: [
                                "operationId": operation.id.uuidString,
                                "type": "\(operation.type)",
                                "status": "\(operation.status)",
                                "objectName": operation.objectName ?? "unknown"
                            ])
                        }

                        await tui.draw(screen: screen)
                        return true

                    default:
                        return false
                    }
                },
                category: .storage
            ),

            // Background operation detail
            ModuleViewRegistration(
                viewMode: .swiftBackgroundOperationDetail,
                title: "Operation Details",
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftBackgroundOperationDetailView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }

                    switch ch {
                    case Int32(127), Int32(330):  // DELETE/BACKSPACE - Cancel or remove operation
                        guard let operation = tui.viewCoordinator.selectedResource as? SwiftBackgroundOperation else {
                            tui.statusMessage = "No operation selected"
                            await tui.draw(screen: screen)
                            return true
                        }

                        // Context-aware behavior based on operation status
                        if operation.status.isActive {
                            // Active operation: Cancel it
                            let operationDesc = operation.displayName
                            let confirmed = await ViewUtils.confirmOperation(
                                title: "Cancel Operation",
                                message: "Cancel '\(operationDesc)'?",
                                details: [
                                    "Type: \(operation.type.displayName)",
                                    "Status: \(operation.status.displayName)",
                                    "Progress: \(operation.progressPercentage)%"
                                ],
                                screen: screen,
                                screenRows: tui.screenRows,
                                screenCols: tui.screenCols
                            )

                            guard confirmed else {
                                tui.statusMessage = "Cancellation aborted"
                                await tui.draw(screen: screen)
                                return true
                            }

                            operation.cancel()
                            tui.statusMessage = "Operation cancelled: \(operation.displayName)"
                            Logger.shared.logUserAction("cancel_background_operation_detail", details: [
                                "operationId": operation.id.uuidString,
                                "type": "\(operation.type)",
                                "objectName": operation.objectName ?? "unknown"
                            ])
                        } else {
                            // Inactive operation: Remove from history and return to list
                            let operationDesc = operation.displayName
                            let confirmed = await ViewUtils.confirmOperation(
                                title: "Remove Operation",
                                message: "Remove '\(operationDesc)' from history?",
                                details: [
                                    "Type: \(operation.type.displayName)",
                                    "Status: \(operation.status.displayName)"
                                ],
                                screen: screen,
                                screenRows: tui.screenRows,
                                screenCols: tui.screenCols
                            )

                            guard confirmed else {
                                tui.statusMessage = "Removal aborted"
                                await tui.draw(screen: screen)
                                return true
                            }

                            tui.swiftBackgroundOps.removeOperation(id: operation.id)

                            // Reset selection immediately after removal
                            let remainingOps = tui.swiftBackgroundOps.getAllOperations()
                            if tui.viewCoordinator.selectedIndex >= remainingOps.count {
                                tui.viewCoordinator.selectedIndex = max(0, remainingOps.count - 1)
                            }

                            tui.statusMessage = "Removed operation: \(operation.displayName)"
                            Logger.shared.logUserAction("remove_background_operation_detail", details: [
                                "operationId": operation.id.uuidString,
                                "type": "\(operation.type)",
                                "status": "\(operation.status)",
                                "objectName": operation.objectName ?? "unknown"
                            ])

                            // Return to operations list
                            tui.changeView(to: .swiftBackgroundOperations, resetSelection: false)

                            // Force full screen refresh to immediately show the removal
                            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()
                        }

                        await tui.draw(screen: screen)
                        return true

                    default:
                        return false
                    }
                },
                category: .storage
            )
        ]
    }

    // MARK: - Form Handler Registration

    /// Register form input handlers for Swift operations
    /// - Returns: Array of form handler registrations for create, upload, and metadata forms
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register form handlers - TUI reference is nil", context: [:])
            return []
        }

        return [
            ModuleFormHandlerRegistration(
                viewMode: .swiftContainerCreate,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftContainerCreateInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftContainerCreateForm.containerName.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftObjectUpload,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftObjectUploadInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftObjectUploadForm.filePath.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftContainerDownload,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftContainerDownloadInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftContainerDownloadForm.destinationPath.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftObjectDownload,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftObjectDownloadInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftObjectDownloadForm.destinationPath.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftDirectoryDownload,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftDirectoryDownloadInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftDirectoryDownloadForm.destinationPath.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftContainerMetadata,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftContainerMetadataInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    _ = tui
                    // Metadata forms are always valid - can set or clear metadata
                    return true
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftObjectMetadata,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftObjectMetadataInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    _ = tui
                    return true
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftDirectoryMetadata,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftDirectoryMetadataInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    _ = tui
                    return true
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftContainerWebAccess,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftContainerWebAccessInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    _ = tui
                    return true
                }
            )
        ]
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for Swift resources
    /// - Returns: Array of refresh handler registrations for containers and objects
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard tui != nil else {
            Logger.shared.logError("Cannot register data refresh handlers - TUI reference is nil", context: [:])
            return []
        }

        return [
            // Object list refresh for current container
            ModuleDataRefreshRegistration(
                identifier: "swift.objects",
                refreshHandler: { [weak self] in
                    guard let self = self else { return }
                    guard let containerName = self.tui?.viewCoordinator.swiftNavState.currentContainer else {
                        Logger.shared.logDebug("No container selected for object refresh")
                        return
                    }
                    await self.fetchSwiftObjects(
                        containerName: containerName,
                        priority: "user-initiated",
                        forceRefresh: true
                    )
                },
                cacheKey: nil, // Dynamic based on container
                refreshInterval: 15.0
            )
        ]
    }

    // MARK: - Cleanup

    /// Cleanup module resources when unloading
    func cleanup() async {
        Logger.shared.logInfo("SwiftModule cleanup started", context: [:])

        // Stop background sync
        stopBackgroundSyncTask()

        // Clear prefetched trees and ETags
        prefetchedTrees.removeAll()
        containerETags.removeAll()

        // Clear any cached Swift data
        if let tui = tui {
            tui.cacheManager.cachedSwiftContainers = []
            // Reset navigation state
            tui.viewCoordinator.swiftNavState.reset()
        }

        Logger.shared.logInfo("SwiftModule cleanup completed", context: [:])
    }

    // MARK: - Health Check

    /// Perform health check on Swift module
    /// - Returns: Health status including service availability and metrics
    func healthCheck() async -> ModuleHealthStatus {
        var errors: [String] = []
        var metrics: [String: Any] = [:]

        guard let tui = tui else {
            return ModuleHealthStatus(
                isHealthy: false,
                lastCheck: Date(),
                errors: ["TUI reference is nil"],
                metrics: [:]
            )
        }

        // Check if we have Swift containers loaded
        let containerCount = tui.cacheManager.cachedSwiftContainers.count
        metrics["cached_containers"] = containerCount
        metrics["service_available"] = containerCount > 0

        if containerCount == 0 {
            errors.append("No Swift containers loaded - service may be unavailable")
        }

        if let currentContainer = tui.viewCoordinator.swiftNavState.currentContainer,
           let objects = tui.cacheManager.cachedSwiftObjects {
            metrics["cached_objects"] = objects.count
            metrics["current_container"] = currentContainer
        }

        // Navigation state metrics
        metrics["navigation_depth"] = tui.viewCoordinator.swiftNavState.depth
        metrics["is_at_container_list"] = tui.viewCoordinator.swiftNavState.isAtContainerList

        return ModuleHealthStatus(
            isHealthy: errors.isEmpty,
            lastCheck: Date(),
            errors: errors,
            metrics: metrics
        )
    }

    // MARK: - Computed Properties

    /// Get all cached Swift containers
    ///
    /// Returns all Swift containers from the cache manager.
    /// Used for container listing, filtering, and selection operations.
    var swiftContainers: [SwiftContainer] {
        return tui?.cacheManager.cachedSwiftContainers ?? []
    }

    /// Get cached Swift objects by container
    ///
    /// Returns all Swift objects organized by container name from the resource cache.
    /// Used for object listing and management across multiple containers.
    var swiftObjectsByContainer: [String: [SwiftObject]] {
        return tui?.cacheManager.resourceCache.swiftObjectsByContainer ?? [:]
    }

    /// Get Swift objects for a specific container from cache
    ///
    /// - Parameter containerName: Name of the container
    /// - Returns: Array of Swift objects, or nil if not cached
    func getSwiftObjects(forContainer containerName: String) -> [SwiftObject]? {
        return tui?.cacheManager.resourceCache.getSwiftObjects(forContainer: containerName)
    }

    /// Set Swift objects in cache for a specific container
    ///
    /// - Parameters:
    ///   - objects: Array of Swift objects
    ///   - containerName: Name of the container
    func setSwiftObjects(_ objects: [SwiftObject], forContainer containerName: String) async {
        await tui?.cacheManager.resourceCache.setSwiftObjects(objects, forContainer: containerName)
    }

    // MARK: - Render Methods

    /// Render the Swift container list view
    func renderSwiftContainerListView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        let containers = tui.cacheManager.cachedSwiftContainers
        let searchQuery = tui.searchQuery ?? ""

        await SwiftViews.drawSwiftContainerList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            containers: containers,
            searchQuery: searchQuery,
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex,
            dataManager: tui.dataManager,
            virtualScrollManager: nil,
            multiSelectMode: tui.selectionManager.multiSelectMode,
            selectedItems: tui.selectionManager.multiSelectedResourceIDs
        )
    }

    /// Render the Swift container detail view (shows objects inside container)
    func renderSwiftContainerDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let containerName = tui.viewCoordinator.swiftNavState.currentContainer else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No container selected").error(), on: surface, in: bounds)
            return
        }

        // Check if we're in loading state - show loading message instead of stale data
        if tui.viewCoordinator.isLoadingSwiftObjects {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            surface.clear(rect: bounds)

            // Build loading message with container context
            let navTitle = tui.viewCoordinator.swiftNavState.getTitle()
            let loadingComponent = VStack(spacing: 1, children: [
                Text(navTitle).bold(),
                Text(""),
                Text("Loading objects...").info(),
                Text("").secondary()
            ])

            await SwiftNCurses.render(loadingComponent, on: surface, in: bounds)
            return
        }

        // Get objects from cache
        let objects = tui.cacheManager.cachedSwiftObjects ?? []

        await SwiftViews.drawSwiftObjectList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            objects: objects,
            containerName: containerName,
            currentPath: tui.viewCoordinator.swiftNavState.currentPathString,
            searchQuery: tui.searchQuery ?? "",
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex,
            navState: tui.viewCoordinator.swiftNavState,
            dataManager: tui.dataManager,
            virtualScrollManager: nil,
            multiSelectMode: tui.selectionManager.multiSelectMode,
            selectedItems: tui.selectionManager.multiSelectedResourceIDs
        )
    }

    /// Render the Swift object detail view
    func renderSwiftObjectDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let object = tui.viewCoordinator.selectedResource as? SwiftObject else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No object selected").error(), on: surface, in: bounds)
            return
        }

        guard let containerName = tui.viewCoordinator.swiftNavState.currentContainer else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No container context").error(), on: surface, in: bounds)
            return
        }

        // Fetch object metadata from the Swift service
        var metadata: SwiftObjectMetadataResponse? = nil
        if let objectName = object.name {
            do {
                metadata = try await tui.client.swift.getObjectMetadata(
                    containerName: containerName,
                    objectName: objectName
                )
            } catch {
                Logger.shared.logDebug("Failed to fetch object metadata: \(error.localizedDescription)")
                // Continue without metadata - the view will handle nil gracefully
            }
        }

        await SwiftViews.drawSwiftObjectDetail(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            object: object,
            containerName: containerName,
            metadata: metadata,
            scrollOffset: tui.viewCoordinator.detailScrollOffset
        )
    }

    /// Render container create form view
    func renderSwiftContainerCreateView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftContainerCreate(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftContainerCreateFormState
        )
    }

    /// Render object upload form view
    func renderSwiftObjectUploadView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftObjectUpload(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftObjectUploadFormState
        )
    }

    /// Render container download form view
    func renderSwiftContainerDownloadView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftContainerDownload(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftContainerDownloadFormState
        )
    }

    /// Render object download form view
    func renderSwiftObjectDownloadView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftObjectDownload(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftObjectDownloadFormState
        )
    }

    /// Render directory download form view
    func renderSwiftDirectoryDownloadView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftDirectoryDownload(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftDirectoryDownloadFormState
        )
    }

    /// Render container metadata form view
    func renderSwiftContainerMetadataView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftContainerMetadata(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftContainerMetadataFormState
        )
    }

    /// Render object metadata form view
    func renderSwiftObjectMetadataView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftObjectMetadata(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftObjectMetadataFormState
        )
    }

    /// Render directory metadata form view
    func renderSwiftDirectoryMetadataView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftDirectoryMetadata(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftDirectoryMetadataFormState
        )
    }

    /// Render container web access form view
    func renderSwiftContainerWebAccessView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftContainerWebAccess(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftContainerWebAccessFormState
        )
    }

    /// Render background operations list view
    func renderSwiftBackgroundOperationsView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        // Get all background operations from the manager
        let operations = tui.swiftBackgroundOps.getAllOperations()

        await SwiftBackgroundOperationsView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            operations: operations,
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex
        )
    }

    /// Render background operation detail view
    func renderSwiftBackgroundOperationDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let operation = tui.viewCoordinator.selectedResource as? SwiftBackgroundOperation else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No operation selected").error(), on: surface, in: bounds)
            return
        }

        await SwiftBackgroundOperationDetailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            operation: operation,
            scrollOffset: tui.viewCoordinator.detailScrollOffset
        )
    }

    // MARK: - Swift Object Operations

    /// Fetch Swift objects for a specific container
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - priority: Fetch priority
    ///   - forceRefresh: Whether to bypass cache
    public func fetchSwiftObjects(containerName: String, priority: String, forceRefresh: Bool = false) async {
        guard let tui = tui else { return }

        // Check if objects are already cached (unless forceRefresh is true)
        if !forceRefresh {
            if let cachedObjects = self.getSwiftObjects(forContainer: containerName) {
                Logger.shared.logDebug("SwiftModule - Using cached Swift objects for container '\(containerName)' (\(cachedObjects.count) objects)")
                return
            }
        }

        Logger.shared.logDebug("SwiftModule - Fetching Swift objects for container '\(containerName)' (\(priority) priority)...")

        do {
            let apiStart = Date().timeIntervalSinceReferenceDate
            let objects = try await tui.client.swift.listObjects(containerName: containerName)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("SwiftModule - Fetched \(objects.count) Swift objects in \(String(format: "%.2f", apiDuration))s")
            await self.setSwiftObjects(objects, forContainer: containerName)
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Swift object access requires permissions (HTTP 403)")
            case .httpError(404, _):
                Logger.shared.logDebug("Swift container not found (HTTP 404)")
            default:
                Logger.shared.logError("Failed to fetch Swift objects: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch Swift objects: \(error)")
        }
    }

    /// Fetch Swift objects with pagination for improved performance
    ///
    /// Fetches objects in pages, providing immediate visual feedback while
    /// loading remaining objects in the background with parallel workers.
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - marker: Marker for pagination (last object name from previous page)
    ///   - limit: Number of objects per page (default 100)
    ///   - priority: Fetch priority
    ///   - forceRefresh: Whether to bypass cache
    public func fetchSwiftObjectsPaginated(
        containerName: String,
        marker: String? = nil,
        limit: Int = 100,
        priority: String,
        forceRefresh: Bool = false
    ) async {
        guard let tui = tui else { return }

        // Cache freshness threshold
        let cacheMaxAge: TimeInterval = 30

        // Stale-while-revalidate: If we have cached data, show it immediately
        // Then fetch fresh data in the background if cache is stale
        if marker == nil && !forceRefresh {
            if let cachedObjects = self.getSwiftObjects(forContainer: containerName) {
                // We have cached data - check if it's fresh
                let isFresh = tui.cacheManager.isSwiftObjectsCacheFresh(forContainer: containerName, maxAge: cacheMaxAge)

                // Clear loading state before returning (in case it was set by caller)
                tui.viewCoordinator.isLoadingSwiftObjects = false
                tui.markNeedsRedraw()

                if isFresh {
                    // Cache is fresh - use it directly
                    Logger.shared.logDebug("SwiftModule - Using fresh cached Swift objects for container '\(containerName)' (\(cachedObjects.count) objects)")
                    return
                } else {
                    // Cache is stale - show it immediately but revalidate in background
                    Logger.shared.logDebug("SwiftModule - Showing stale cache for container '\(containerName)' (\(cachedObjects.count) objects), revalidating in background")

                    // Launch background revalidation
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        await self.revalidateContainerCache(containerName: containerName)
                    }
                    return
                }
            }
        }

        // No cached data or force refresh - show loading state and fetch
        tui.viewCoordinator.isLoadingSwiftObjects = true
        defer {
            tui.viewCoordinator.isLoadingSwiftObjects = false
            tui.markNeedsRedraw()
        }

        // Clear cache on force refresh
        if marker == nil && forceRefresh {
            tui.cacheManager.clearSwiftObjects(forContainer: containerName)
        }

        Logger.shared.logDebug("SwiftModule - Fetching Swift objects page for container '\(containerName)' (marker: \(marker ?? "nil"), limit: \(limit), \(priority) priority)...")

        do {
            let apiStart = Date().timeIntervalSinceReferenceDate
            let objects = try await tui.client.swift.listObjects(
                containerName: containerName,
                limit: limit,
                marker: marker
            )
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("SwiftModule - Fetched \(objects.count) Swift objects in \(String(format: "%.2f", apiDuration))s")

            // Append results to existing objects if paginating
            if marker != nil {
                // Get existing objects and append new ones
                var existingObjects = tui.cacheManager.cachedSwiftObjects ?? []
                existingObjects.append(contentsOf: objects)
                await self.setSwiftObjects(existingObjects, forContainer: containerName)
            } else {
                // Initial load - set objects directly
                await self.setSwiftObjects(objects, forContainer: containerName)

                // Store ETag for differential sync (use object count as pseudo-ETag)
                containerETags[containerName] = String(objects.count)

                // Trigger prefetching for subdirectories
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    await self.prefetchSubdirectoryTrees(containerName: containerName, objects: objects)
                }
            }

            // Clear loading state after first page
            tui.viewCoordinator.isLoadingSwiftObjects = false
            tui.markNeedsRedraw()

            // If results count equals limit, there may be more pages
            // Launch parallel background fetchers for faster loading
            if objects.count == limit {
                if let lastObject = objects.last, let lastObjectName = lastObject.name {
                    Logger.shared.logDebug("SwiftModule - Launching parallel background fetchers (marker: \(lastObjectName))")

                    // Launch parallel background workers
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        await self.fetchSwiftObjectsParallel(
                            containerName: containerName,
                            initialMarker: lastObjectName
                        )
                    }
                }
            }
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Swift object access requires permissions (HTTP 403)")
            case .httpError(404, _):
                Logger.shared.logDebug("Swift container not found (HTTP 404)")
            default:
                Logger.shared.logError("Failed to fetch Swift objects: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch Swift objects: \(error)")
        }
    }

    /// Fetch remaining Swift objects using parallel workers
    ///
    /// Uses TaskGroup to run multiple concurrent fetchers, each processing
    /// sequential pages but all running in parallel for maximum throughput.
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - initialMarker: Starting marker for the first worker
    private func fetchSwiftObjectsParallel(
        containerName: String,
        initialMarker: String
    ) async {
        guard let tui = tui else { return }

        // Configuration for parallel fetching
        let maxConcurrentWorkers = 5
        let pageSize = 1000  // Large pages for background fetching

        // Progress tracker for parallel operations
        actor ParallelFetchState {
            var allObjects: [SwiftObject] = []
            var completedWorkers = 0
            var activeWorkers = 0
            var nextMarker: String?
            var hasMorePages = true

            func addObjects(_ objects: [SwiftObject]) {
                allObjects.append(contentsOf: objects)
            }

            func workerCompleted() {
                completedWorkers += 1
                activeWorkers -= 1
            }

            func workerStarted() {
                activeWorkers += 1
            }

            func setNextMarker(_ marker: String?) {
                nextMarker = marker
            }

            func setHasMorePages(_ hasMore: Bool) {
                hasMorePages = hasMore
            }

            func getState() -> (objects: [SwiftObject], active: Int, completed: Int, nextMarker: String?, hasMore: Bool) {
                return (allObjects, activeWorkers, completedWorkers, nextMarker, hasMorePages)
            }

            func reset() {
                allObjects = []
                completedWorkers = 0
                activeWorkers = 0
                nextMarker = nil
                hasMorePages = true
            }
        }

        let fetchState = ParallelFetchState()
        await fetchState.setNextMarker(initialMarker)

        Logger.shared.logInfo("SwiftModule - Starting parallel fetch with \(maxConcurrentWorkers) workers")
        let startTime = Date().timeIntervalSinceReferenceDate

        // Use TaskGroup for concurrent fetching
        await withTaskGroup(of: [SwiftObject].self) { group in
            var markersToProcess: [String] = [initialMarker]

            // Process until all pages are fetched
            while true {
                // Verify we're still viewing the same container
                guard tui.viewCoordinator.swiftNavState.currentContainer == containerName else {
                    Logger.shared.logDebug("SwiftModule - Cancelling parallel fetch, container changed")
                    group.cancelAll()
                    return
                }

                // Start new workers for available markers
                while let marker = markersToProcess.first {
                    markersToProcess.removeFirst()

                    let state = await fetchState.getState()
                    if state.active >= maxConcurrentWorkers {
                        // Re-add marker for later processing
                        markersToProcess.insert(marker, at: 0)
                        break
                    }

                    await fetchState.workerStarted()

                    // Capture client reference outside of task for Sendable compliance
                    let client = tui.client

                    group.addTask {
                        do {
                            let objects = try await client.swift.listObjects(
                                containerName: containerName,
                                limit: pageSize,
                                marker: marker
                            )
                            return objects
                        } catch {
                            Logger.shared.logError("Parallel fetch worker failed: \(error)")
                            return []
                        }
                    }
                }

                // Wait for a worker to complete
                if let objects = await group.next() {
                    await fetchState.workerCompleted()

                    if !objects.isEmpty {
                        await fetchState.addObjects(objects)

                        // Get next marker if there are more pages
                        if objects.count == pageSize {
                            if let lastObject = objects.last, let lastObjectName = lastObject.name {
                                markersToProcess.append(lastObjectName)
                            }
                        }

                        // Update cache with all fetched objects so far
                        let state = await fetchState.getState()
                        let existingObjects = tui.cacheManager.cachedSwiftObjects ?? []

                        // Only append new objects (state.objects already includes all fetched)
                        let newObjectCount = state.objects.count
                        let currentCount = existingObjects.count
                        if newObjectCount > currentCount - 100 {  // Account for initial page
                            // Replace with full set including initial page
                            let initialObjects = Array(existingObjects.prefix(100))
                            let allFetched = initialObjects + state.objects
                            await self.setSwiftObjects(allFetched, forContainer: containerName)

                            // Trigger redraw to show progress
                            tui.markNeedsRedraw()
                        }
                    }
                } else {
                    // No more results and no pending markers
                    if markersToProcess.isEmpty {
                        break
                    }
                }

                let state = await fetchState.getState()
                if state.active == 0 && markersToProcess.isEmpty {
                    break
                }
            }
        }

        let totalDuration = Date().timeIntervalSinceReferenceDate - startTime
        let allObjects = tui.cacheManager.cachedSwiftObjects ?? []
        let totalObjects = allObjects.count

        // Update ETag after parallel fetch completes
        containerETags[containerName] = String(totalObjects)

        // Prefetch subdirectory trees with all objects
        await prefetchSubdirectoryTrees(containerName: containerName, objects: allObjects)

        Logger.shared.logInfo("SwiftModule - Completed parallel fetch: \(totalObjects) total objects in \(String(format: "%.2f", totalDuration))s")
    }
}

// MARK: - ActionProvider Conformance

extension SwiftModule: ActionProvider {
    /// Actions available in the list view for Swift containers
    ///
    /// Includes create, delete, refresh, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .clearCache]
    }

    /// Actions available in the detail view for Swift containers
    ///
    /// Includes delete, refresh, and cache management.
    var detailViewActions: [ActionType] {
        [.delete, .refresh, .clearCache]
    }

    /// The view mode for creating a new container
    var createViewMode: ViewMode? {
        .swiftContainerCreate
    }

    /// Execute an action for the selected Swift resource
    ///
    /// - Parameters:
    ///   - action: The action type to execute
    ///   - screen: Screen pointer for confirmation dialogs
    ///   - tui: The TUI instance for state management
    /// - Returns: Boolean indicating if the action was handled
    func executeAction(_ action: ActionType, screen: OpaquePointer?, tui: TUI) async -> Bool {
        switch action {
        case .create:
            guard let createMode = createViewMode else { return false }

            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".swiftContainerCreate")
            tui.changeView(to: createMode)

            // Initialize Swift container create form
            tui.swiftContainerCreateForm = SwiftContainerCreateForm()
            tui.swiftContainerCreateFormState = FormBuilderState(
                fields: tui.swiftContainerCreateForm.buildFields(
                    selectedFieldId: "containerName",
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )

            tui.statusMessage = "Create new container"
            return true
        case .delete:
            await deleteSwiftContainer(screen: screen)
            return true
        default:
            return false
        }
    }

    /// Get the bulk delete operation for selected Swift resources
    ///
    /// Creates a batch operation for deleting multiple containers or objects at once.
    /// The operation type depends on the current view context.
    ///
    /// - Parameters:
    ///   - selectedIDs: Set of resource identifiers to delete
    ///   - tui: The TUI instance for state management
    /// - Returns: BatchOperationType for bulk delete, or nil if not supported
    func getBulkDeleteOperation(selectedIDs: Set<String>, tui: TUI) -> BatchOperationType? {
        if tui.viewCoordinator.currentView == .swiftContainerDetail {
            // Get container name from selected resource
            guard let container = tui.viewCoordinator.selectedResource as? SwiftContainer,
                  let containerName = container.name else {
                return nil
            }
            return .swiftObjectBulkDelete(containerName: containerName, objectNames: Array(selectedIDs))
        }
        return .swiftContainerBulkDelete(containerNames: Array(selectedIDs))
    }

    /// Get the ID of the currently selected Swift resource
    ///
    /// Returns the resource identifier based on the current selection index, accounting for any
    /// search filtering that may be applied. Handles both container list and container detail
    /// views with their respective filtering logic.
    ///
    /// - Parameter tui: The TUI instance for state management
    /// - Returns: Resource identifier string (object ID or container name), or empty string if no valid selection
    func getSelectedResourceId(tui: TUI) -> String {
        if tui.viewCoordinator.currentView == .swiftContainerDetail {
            guard let allObjects = tui.cacheManager.cachedSwiftObjects else { return "" }
            let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)
            let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery?.isEmpty ?? true ? nil : tui.searchQuery)
            guard tui.viewCoordinator.selectedIndex < filteredItems.count else { return "" }
            return filteredItems[tui.viewCoordinator.selectedIndex].id
        }
        // Swift container list
        let filtered = tui.searchQuery?.isEmpty ?? true ? tui.cacheManager.cachedSwiftContainers : tui.cacheManager.cachedSwiftContainers.filter { container in
            container.name?.lowercased().contains(tui.searchQuery?.lowercased() ?? "") ?? false
        }
        guard tui.viewCoordinator.selectedIndex < filtered.count else { return "" }
        return filtered[tui.viewCoordinator.selectedIndex].name ?? ""
    }
}
