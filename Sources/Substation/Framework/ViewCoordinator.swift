import Foundation
import OSClient

// MARK: - ViewCoordinator

/// Manages view state, navigation, and selection for the TUI.
/// Centralizes all view transition logic, scroll offsets, and selection indices.
@MainActor
final class ViewCoordinator {

    // MARK: - View State

    /// Current view being displayed
    var currentView: ViewMode = .loading

    /// Previous view (for back navigation)
    var previousView: ViewMode = .loading

    // MARK: - Selection State

    /// Currently selected index in list views
    var selectedIndex: Int = 0

    /// Currently selected resource for detail views
    var selectedResource: Any?

    /// Name of previously selected resource (for display in sub-views)
    var previousSelectedResourceName: String?

    // MARK: - Scroll State

    /// Scroll offset for list views
    var scrollOffset: Int = 0

    /// Scroll offset for help view
    var helpScrollOffset: Int = 0

    /// Scroll offset for detail views
    var detailScrollOffset: Int = 0

    /// Scroll offset for quota displays
    var quotaScrollOffset: Int = 0

    // MARK: - Search State

    /// Resource ID selected from search results
    var searchSelectedResourceId: String?

    // MARK: - Navigation States

    /// Health dashboard navigation state
    lazy var healthDashboardNavState: HealthDashboardView.NavigationState = HealthDashboardView.NavigationState()

    /// Swift object storage navigation state
    lazy var swiftNavState: SwiftNavigationState = SwiftNavigationState()

    // MARK: - Callbacks

    /// Callback to mark the screen as needing redraw
    var markNeedsRedraw: (() -> Void)?

    /// Callback to mark a view transition occurred (full screen redraw)
    var markViewTransition: (() -> Void)?

    /// Callback to get the current status message
    var getStatusMessage: (() -> String?)?

    /// Callback to set the status message
    var setStatusMessage: ((String?) -> Void)?

    /// Callback to get the current search query
    var getSearchQuery: (() -> String?)?

    /// Callback to set the search query
    var setSearchQuery: ((String?) -> Void)?

    // MARK: - Initialization

    /// Initializes a new ViewCoordinator instance
    init() {
        Logger.shared.logDebug("ViewCoordinator initialized")
    }

    // MARK: - View Transition

    /// Change to a new view with optional selection reset and status preservation
    ///
    /// - Parameters:
    ///   - newView: The view mode to transition to
    ///   - resetSelection: Whether to reset selection indices and scroll offsets
    ///   - preserveStatus: Whether to keep the current status message
    func changeView(to newView: ViewMode, resetSelection: Bool = true, preserveStatus: Bool = false) {
        // Store previous view for back navigation (but not if current view is help)
        if currentView != newView && currentView != .help {
            previousView = currentView
        }

        // Update current view
        currentView = newView

        // Reset selection state if requested
        if resetSelection {
            selectedIndex = 0
            scrollOffset = 0
            detailScrollOffset = 0
            quotaScrollOffset = 0
            selectedResource = nil
        }

        // Clear search when changing views
        setSearchQuery?(nil)

        // Clear status message when changing views (unless preserving)
        if !preserveStatus {
            setStatusMessage?(nil)
        }

        // Initialize view-specific state
        if newView == .healthDashboard {
            HealthDashboardView.resetNavigationState(healthDashboardNavState)
        }

        // Force full screen redraw for view transitions
        markViewTransition?()

        Logger.shared.logDebug("View changed to: \(newView)")
    }

    // MARK: - Selection Index Calculation

    /// Get the maximum selection index for the current view
    ///
    /// - Parameters:
    ///   - cacheManager: The cache manager containing resource data
    ///   - searchQuery: Optional search query for filtering
    ///   - resourceResolver: The resource resolver for name lookups
    /// - Returns: The maximum valid selection index
    func getMaxSelectionIndex(
        cacheManager: CacheManager,
        searchQuery: String?,
        resourceResolver: ResourceResolver
    ) -> Int {
        return UIUtils.getMaxSelectionIndex(
            for: currentView,
            cachedServers: cacheManager.cachedServers,
            cachedNetworks: cacheManager.cachedNetworks,
            cachedVolumes: cacheManager.cachedVolumes,
            cachedImages: cacheManager.cachedImages,
            cachedFlavors: cacheManager.cachedFlavors,
            cachedKeyPairs: cacheManager.cachedKeyPairs,
            cachedSubnets: cacheManager.cachedSubnets,
            cachedPorts: cacheManager.cachedPorts,
            cachedRouters: cacheManager.cachedRouters,
            cachedFloatingIPs: cacheManager.cachedFloatingIPs,
            cachedServerGroups: cacheManager.cachedServerGroups,
            cachedSecurityGroups: cacheManager.cachedSecurityGroups,
            cachedSecrets: cacheManager.cachedSecrets,
            cachedVolumeSnapshots: cacheManager.cachedVolumeSnapshots,
            cachedVolumeBackups: cacheManager.cachedVolumeBackups,
            cachedSwiftContainers: cacheManager.cachedSwiftContainers,
            cachedSwiftObjects: cacheManager.cachedSwiftObjects,
            searchQuery: searchQuery,
            resourceResolver: resourceResolver,
            swiftNavState: swiftNavState
        )
    }

    /// Get the maximum index for the current view based on cached resource counts
    ///
    /// - Parameter cacheManager: The cache manager containing resource data
    /// - Returns: The count of resources in the current view
    func getMaxIndexForCurrentView(cacheManager: CacheManager) -> Int {
        switch currentView {
        case .servers:
            return cacheManager.cachedServers.count
        case .volumes:
            return cacheManager.cachedVolumes.count
        case .networks:
            return cacheManager.cachedNetworks.count
        case .images:
            return cacheManager.cachedImages.count
        case .flavors:
            return cacheManager.cachedFlavors.count
        case .floatingIPs:
            return cacheManager.cachedFloatingIPs.count
        case .routers:
            return cacheManager.cachedRouters.count
        case .securityGroups:
            return cacheManager.cachedSecurityGroups.count
        case .keyPairs:
            return cacheManager.cachedKeyPairs.count
        case .ports:
            return cacheManager.cachedPorts.count
        case .subnets:
            return cacheManager.cachedSubnets.count
        case .serverGroups:
            return cacheManager.cachedServerGroups.count
        case .barbicanSecrets:
            return cacheManager.cachedSecrets.count
        case .swift:
            return cacheManager.cachedSwiftContainers.count
        case .swiftContainerDetail:
            return cacheManager.cachedSwiftObjects?.count ?? 0
        default:
            return 0
        }
    }

    // MARK: - Scroll Offset Calculation

    /// Calculate the maximum scroll offset for detail views
    ///
    /// - Returns: The maximum scroll offset value
    func calculateMaxDetailScrollOffset() -> Int {
        // For DetailView-based views, use a generous max scroll value
        // The DetailView itself handles bounds checking
        if currentView.isDetailView {
            return 200
        }
        return 0
    }

    /// Calculate the maximum scroll offset for quota panel on dashboard
    ///
    /// - Parameters:
    ///   - screenCols: The screen width in columns
    ///   - screenRows: The screen height in rows
    ///   - cachedComputeLimits: Cached compute limits
    ///   - cachedNetworkQuotas: Cached network quotas
    ///   - cachedVolumeQuotas: Cached volume quotas
    /// - Returns: The maximum quota scroll offset
    func calculateMaxQuotaScrollOffset(
        screenCols: Int32,
        screenRows: Int32,
        cachedComputeLimits: ComputeQuotaSet?,
        cachedNetworkQuotas: NetworkQuotaSet?,
        cachedVolumeQuotas: VolumeQuotaSet?
    ) -> Int {
        // Check if we're in vertical layout mode for dashboard
        if currentView == .dashboard {
            let mainWidth = screenCols - LayoutUtilities.shared.calculateSidebarWidth(screenCols: screenCols) - 2
            let mainHeight = screenRows - 4
            let minWidthForGrid = Int32(120)
            let minHeightForGrid = Int32(30)
            let useVerticalLayout = mainWidth < minWidthForGrid || mainHeight < minHeightForGrid

            if useVerticalLayout {
                // Vertical layout - calculate scroll based on total content height
                let panelHeight = min(mainHeight / 6, Int32(12))
                let panelSpacing = Int32(1)
                let totalPanels = 6
                let totalContentHeight = Int32(totalPanels) * (panelHeight + panelSpacing) + 2
                let availableHeight = mainHeight - 4

                return max(0, Int(totalContentHeight - availableHeight))
            }
        }

        // Grid layout or other views - use quota item calculation
        var totalQuotaItems = 0

        // Count compute quota items
        if let computeLimits = cachedComputeLimits {
            totalQuotaItems += 1 // Section header
            if computeLimits.instances != nil {
                totalQuotaItems += 1
            }
            if computeLimits.cores != nil {
                totalQuotaItems += 1
            }
            if computeLimits.ram != nil {
                totalQuotaItems += 1
            }
            totalQuotaItems += 1 // Section separator
        }

        // Count network quota items
        if cachedNetworkQuotas != nil {
            totalQuotaItems += 1 // Section header
            totalQuotaItems += 1 // network
            totalQuotaItems += 1 // router
            totalQuotaItems += 1 // port
            totalQuotaItems += 1 // Section separator
        }

        // Count volume quota items
        if cachedVolumeQuotas != nil {
            totalQuotaItems += 1 // Section header
            totalQuotaItems += 1 // volumes
            totalQuotaItems += 1 // gigabytes
            totalQuotaItems += 1 // snapshots
            totalQuotaItems += 1 // Section separator
        }

        // Available height in quota panel is roughly 8 lines
        let visibleQuotaItems = 8
        return max(0, totalQuotaItems - visibleQuotaItems)
    }

    // MARK: - Resource Selection

    /// Get the currently selected image based on selection index and search filter
    ///
    /// - Parameters:
    ///   - cachedImages: Array of cached images
    ///   - searchQuery: Optional search query for filtering
    /// - Returns: The selected image or nil
    func getSelectedImage(cachedImages: [Image], searchQuery: String?) -> Image? {
        let filteredImages = cachedImages.filter { image in
            if searchQuery?.isEmpty ?? true {
                return true
            }
            let name = image.name ?? ""
            let id = image.id
            let query = searchQuery ?? ""
            return name.localizedCaseInsensitiveContains(query) ||
                   id.localizedCaseInsensitiveContains(query)
        }

        guard selectedIndex < filteredImages.count else { return nil }
        return filteredImages[selectedIndex]
    }

    // MARK: - Detail View Management

    /// Open a detail view for the currently selected resource
    ///
    /// - Parameters:
    ///   - cacheManager: The cache manager containing resource data
    ///   - searchQuery: Optional search query for filtering
    ///   - dataManager: The data manager for fetching additional data
    func openDetailView(
        cacheManager: CacheManager,
        searchQuery: String?,
        dataManager: DataManager
    ) {
        guard !currentView.isDetailView else { return }

        let filteredResources: [Any]
        let targetDetailView: ViewMode

        switch currentView {
        case .servers:
            filteredResources = FilterUtils.filterServers(cacheManager.cachedServers, query: searchQuery)
            targetDetailView = .serverDetail
        case .serverGroups:
            filteredResources = FilterUtils.filterServerGroups(cacheManager.cachedServerGroups, query: searchQuery)
            targetDetailView = .serverGroupDetail
        case .networks:
            filteredResources = FilterUtils.filterNetworks(cacheManager.cachedNetworks, query: searchQuery)
            targetDetailView = .networkDetail
        case .securityGroups:
            filteredResources = FilterUtils.filterSecurityGroups(cacheManager.cachedSecurityGroups, query: searchQuery)
            targetDetailView = .securityGroupDetail
        case .volumes:
            filteredResources = FilterUtils.filterVolumes(cacheManager.cachedVolumes, query: searchQuery)
            targetDetailView = .volumeDetail
        case .images:
            filteredResources = FilterUtils.filterImages(cacheManager.cachedImages, query: searchQuery)
            targetDetailView = .imageDetail
        case .flavors:
            filteredResources = FilterUtils.filterFlavors(cacheManager.cachedFlavors, query: searchQuery)
            targetDetailView = .flavorDetail
        case .subnets:
            filteredResources = FilterUtils.filterSubnets(cacheManager.cachedSubnets, query: searchQuery)
            targetDetailView = .subnetDetail
        case .ports:
            filteredResources = FilterUtils.filterPorts(cacheManager.cachedPorts, query: searchQuery)
            targetDetailView = .portDetail
        case .routers:
            filteredResources = FilterUtils.filterRouters(cacheManager.cachedRouters, query: searchQuery)
            targetDetailView = .routerDetail
        case .keyPairs:
            filteredResources = FilterUtils.filterKeyPairs(cacheManager.cachedKeyPairs, query: searchQuery)
            targetDetailView = .keyPairDetail
        case .floatingIPs:
            filteredResources = FilterUtils.filterFloatingIPs(cacheManager.cachedFloatingIPs, query: searchQuery)
            targetDetailView = .floatingIPDetail
        case .healthDashboard:
            // Use the selected service from health dashboard navigation state
            if let selectedService = healthDashboardNavState.selectedService {
                selectedResource = selectedService
                changeView(to: .healthDashboardServiceDetail, resetSelection: false)
                detailScrollOffset = 0
                return
            } else {
                return // No service selected
            }
        case .barbicanSecrets:
            // Apply filtering logic
            let filteredSecrets = searchQuery?.isEmpty ?? true ? cacheManager.cachedSecrets : cacheManager.cachedSecrets.filter { secret in
                (secret.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false) ||
                (secret.secretType?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false)
            }
            filteredResources = filteredSecrets
            targetDetailView = .barbicanSecretDetail
        case .volumeArchives:
            // Build unified archive list (snapshots + backups + server backups)
            var archives: [Any] = []
            archives.append(contentsOf: cacheManager.cachedVolumeSnapshots)
            archives.append(contentsOf: cacheManager.cachedVolumeBackups)

            // Add server backups (images with image_type == "snapshot")
            let serverBackups = cacheManager.cachedImages.filter { image in
                if let properties = image.properties,
                   let imageType = properties["image_type"],
                   imageType == "snapshot" {
                    return true
                }
                return false
            }
            archives.append(contentsOf: serverBackups)

            // Sort by creation date (newest first)
            archives.sort { (a, b) -> Bool in
                let aDate = getArchiveCreationDate(a)
                let bDate = getArchiveCreationDate(b)
                return aDate > bDate
            }

            // Apply search filter if needed
            if let query = searchQuery, !query.isEmpty {
                let lowercaseQuery = query.lowercased()
                archives = archives.filter { archive in
                    if let snapshot = archive as? VolumeSnapshot {
                        return (snapshot.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                               (snapshot.status?.lowercased().contains(lowercaseQuery) ?? false)
                    } else if let backup = archive as? VolumeBackup {
                        return (backup.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                               (backup.status?.lowercased().contains(lowercaseQuery) ?? false)
                    } else if let image = archive as? Image {
                        return (image.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                               (image.status?.lowercased().contains(lowercaseQuery) ?? false)
                    }
                    return false
                }
            }

            filteredResources = archives
            targetDetailView = .volumeArchiveDetail
        case .swift:
            // Filter Swift containers based on search query
            let filteredContainers = searchQuery?.isEmpty ?? true ? cacheManager.cachedSwiftContainers : cacheManager.cachedSwiftContainers.filter { container in
                container.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false
            }
            filteredResources = filteredContainers
            targetDetailView = .swiftContainerDetail
        case .swiftContainerDetail:
            // When in container detail view, navigating opens object detail
            if let objects = cacheManager.cachedSwiftObjects {
                let filteredObjects = searchQuery?.isEmpty ?? true ? objects : objects.filter { object in
                    object.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false
                }
                filteredResources = filteredObjects
                targetDetailView = .swiftObjectDetail
            } else {
                return
            }
        default:
            return // No detail view available for this view type
        }

        // Check if we have resources and a valid selection
        guard !filteredResources.isEmpty && selectedIndex < filteredResources.count else { return }

        // Set the selected resource and change to detail view
        selectedResource = filteredResources[selectedIndex]
        changeView(to: targetDetailView, resetSelection: false)
        detailScrollOffset = 0 // Reset detail scroll when opening
    }

    // MARK: - Private Helpers

    /// Get the creation date from an archive item
    ///
    /// - Parameter archive: The archive item (VolumeSnapshot, VolumeBackup, or Image)
    /// - Returns: The creation date or distant past if not available
    private func getArchiveCreationDate(_ archive: Any) -> Date {
        if let snapshot = archive as? VolumeSnapshot {
            return snapshot.createdAt ?? Date.distantPast
        } else if let backup = archive as? VolumeBackup {
            return backup.createdAt ?? Date.distantPast
        } else if let image = archive as? Image {
            return image.createdAt ?? Date.distantPast
        }
        return Date.distantPast
    }
}
