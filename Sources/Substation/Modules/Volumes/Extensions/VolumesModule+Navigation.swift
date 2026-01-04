// Sources/Substation/Modules/Volumes/Extensions/VolumesModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension VolumesModule: ModuleNavigationProvider {

    /// Number of volumes in the current view
    ///
    /// Returns the count of cached volumes, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let currentView = tui.viewCoordinator.currentView

        switch currentView {
        case .volumes:
            let volumes = tui.cacheManager.cachedVolumes

            // Apply search filter if present
            if let query = tui.searchQuery, !query.isEmpty {
                let filtered = FilterUtils.filterVolumes(volumes, query: query)
                return filtered.count
            }

            return volumes.count

        case .volumeArchives:
            return getArchiveItems(tui: tui).count

        default:
            return 0
        }
    }

    /// Maximum selection index for volumes view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh volume data from the API
    ///
    /// Clears cached volume data and fetches fresh data from Cinder.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("VolumesModule refreshing data", context: [:])

        let currentView = tui.viewCoordinator.currentView

        switch currentView {
        case .volumes, .volumeDetail:
            // Fetch volumes
            let volumes = try await tui.client.cinder.listVolumes()
            tui.cacheManager.cachedVolumes = volumes

            Logger.shared.logInfo("VolumesModule refresh completed", context: [
                "volumeCount": volumes.count
            ])

        case .volumeArchives, .volumeArchiveDetail:
            // Fetch snapshots and backups
            let snapshots = try await tui.client.cinder.listSnapshots()
            tui.cacheManager.cachedVolumeSnapshots = snapshots

            let backups = try await tui.client.cinder.listBackups()
            tui.cacheManager.cachedVolumeBackups = backups

            // Also refresh images for server backups
            let images = try await tui.client.glance.listImages()
            tui.cacheManager.cachedImages = images

            Logger.shared.logInfo("VolumesModule archives refresh completed", context: [
                "snapshotCount": snapshots.count,
                "backupCount": backups.count,
                "imageCount": images.count
            ])

        default:
            // Default volume refresh
            let volumes = try await tui.client.cinder.listVolumes()
            tui.cacheManager.cachedVolumes = volumes
        }
    }

    /// Get contextual command suggestions for volumes view
    ///
    /// Returns commands that are commonly used when working with volumes,
    /// such as related resource views and volume operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["servers", "images", "snapshots", "backups"]
    }

    /// Ensure data is loaded when navigating to a view
    ///
    /// Loads volume snapshots, backups, and images when navigating to Volume Archives.
    /// This ensures data is available even on first navigation.
    ///
    /// - Parameter tui: The TUI instance for accessing cache and client
    func ensureDataLoaded(tui: TUI) async {
        switch tui.viewCoordinator.currentView {
        case .volumeArchives, .volumeArchiveDetail:
            // Load snapshots, backups, and images if not already cached
            let snapshotsEmpty = tui.cacheManager.cachedVolumeSnapshots.isEmpty
            let backupsEmpty = tui.cacheManager.cachedVolumeBackups.isEmpty

            if snapshotsEmpty || backupsEmpty {
                Logger.shared.logInfo("Loading volume archives data on view change")

                do {
                    // Load snapshots
                    let snapshots = try await tui.client.cinder.listSnapshots()
                    tui.cacheManager.cachedVolumeSnapshots = snapshots

                    // Load backups
                    let backups = try await tui.client.cinder.listBackups()
                    tui.cacheManager.cachedVolumeBackups = backups

                    // Load images for server backups
                    if tui.cacheManager.cachedImages.isEmpty {
                        let images = try await tui.client.glance.listImages()
                        tui.cacheManager.cachedImages = images
                    }

                    Logger.shared.logInfo("Volume archives data loaded", context: [
                        "snapshotCount": snapshots.count,
                        "backupCount": backups.count
                    ])
                } catch {
                    Logger.shared.logError("Failed to load volume archives: \(error.localizedDescription)")
                    tui.statusMessage = "Failed to load archives: \(error.localizedDescription)"
                }
            }

        case .volumes:
            // Load volumes if not already cached
            if tui.cacheManager.cachedVolumes.isEmpty {
                Logger.shared.logInfo("Loading volumes data on view change")
                let _ = await DataProviderRegistry.shared.fetchData(for: "volumes", priority: .onDemand, forceRefresh: true)
            }

        default:
            break
        }
    }

    /// Navigation provider accessor
    ///
    /// Returns self since VolumesModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected volume or archive
    ///
    /// Handles navigation to the detail view for the currently selected
    /// item in the volumes or archives list. This filters items based on
    /// any active search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        let currentView = tui.viewCoordinator.currentView

        switch currentView {
        case .volumes:
            // Filter volumes using the same logic as itemCount
            let volumes = tui.cacheManager.cachedVolumes
            let filteredVolumes: [Volume]

            if let query = tui.searchQuery, !query.isEmpty {
                filteredVolumes = FilterUtils.filterVolumes(volumes, query: query)
            } else {
                filteredVolumes = volumes
            }

            // Validate selection
            guard !filteredVolumes.isEmpty &&
                  tui.viewCoordinator.selectedIndex < filteredVolumes.count else {
                return false
            }

            // Set selected resource and navigate to detail view
            tui.viewCoordinator.selectedResource = filteredVolumes[tui.viewCoordinator.selectedIndex]
            tui.changeView(to: .volumeDetail, resetSelection: false)
            tui.viewCoordinator.detailScrollOffset = 0

            return true

        case .volumeArchives:
            let archives = getArchiveItems(tui: tui)

            // Validate selection
            guard !archives.isEmpty &&
                  tui.viewCoordinator.selectedIndex < archives.count else {
                return false
            }

            // Set selected resource and navigate to detail view
            tui.viewCoordinator.selectedResource = archives[tui.viewCoordinator.selectedIndex]
            tui.changeView(to: .volumeArchiveDetail, resetSelection: false)
            tui.viewCoordinator.detailScrollOffset = 0

            return true

        default:
            return false
        }
    }

    // MARK: - Private Helpers

    /// Build unified archive list with snapshots, backups, and server backups
    ///
    /// - Parameter tui: The TUI instance for accessing cache
    /// - Returns: Array of archive items sorted by creation date
    private func getArchiveItems(tui: TUI) -> [Any] {
        var archives: [Any] = []
        archives.append(contentsOf: tui.cacheManager.cachedVolumeSnapshots)
        archives.append(contentsOf: tui.cacheManager.cachedVolumeBackups)

        // Add server backups (images with image_type == "snapshot")
        let serverBackups = tui.cacheManager.cachedImages.filter { image in
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
            let aDate = ArchiveUtilities.getArchiveCreationDate(a)
            let bDate = ArchiveUtilities.getArchiveCreationDate(b)
            return aDate > bDate
        }

        // Apply search filter if needed
        if let query = tui.searchQuery, !query.isEmpty {
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

        return archives
    }
}
