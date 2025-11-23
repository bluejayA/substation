// Sources/Substation/Modules/Images/Extensions/ImagesModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension ImagesModule: ModuleNavigationProvider {

    /// Number of images in the current view
    ///
    /// Returns the count of cached images, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let images = tui.cacheManager.cachedImages

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterImages(images, query: query)
            return filtered.count
        }

        return images.count
    }

    /// Maximum selection index for images view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh image data from the API
    ///
    /// Clears cached image data and fetches fresh data from Glance.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("ImagesModule refreshing data", context: [:])

        // Fetch images
        let images = try await tui.client.glance.listImages()
        tui.cacheManager.cachedImages = images

        Logger.shared.logInfo("ImagesModule refresh completed", context: [
            "imageCount": images.count
        ])
    }

    /// Get contextual command suggestions for images view
    ///
    /// Returns commands that are commonly used when working with images,
    /// such as related resource views and image operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["servers", "volumes"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since ImagesModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Ensure required data is loaded for the current Images view
    ///
    /// Lazily loads images data when entering the images view if not already cached.
    /// This prevents empty views when navigating directly to images.
    ///
    /// - Parameter tui: The TUI instance for accessing view state and cache
    func ensureDataLoaded(tui: TUI) async {
        switch tui.viewCoordinator.currentView {
        case .images:
            if tui.cacheManager.cachedImages.isEmpty {
                Logger.shared.logInfo("Loading images data on view change")
                let _ = await DataProviderRegistry.shared.fetchData(for: "images", priority: .onDemand, forceRefresh: true)
            }
        default:
            break
        }
    }

    /// Open detail view for the currently selected image
    ///
    /// Handles navigation to the image detail view for the currently selected
    /// image in the images list. This filters images based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle images view
        guard tui.viewCoordinator.currentView == .images else {
            return false
        }

        // Filter images using the same logic as itemCount
        let images = tui.cacheManager.cachedImages
        let filteredImages: [Image]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredImages = FilterUtils.filterImages(images, query: query)
        } else {
            filteredImages = images
        }

        // Validate selection
        guard !filteredImages.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredImages.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredImages[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .imageDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }

    /// Get the currently selected image from the filtered list
    ///
    /// - Parameter tui: The TUI instance for accessing cache and selection state
    /// - Returns: The selected Image, or nil if none selected
    func getSelectedImage(tui: TUI) -> Image? {
        let filteredImages = tui.cacheManager.cachedImages.filter { image in
            if tui.searchQuery?.isEmpty ?? true {
                return true
            }
            let name = image.name ?? ""
            let id = image.id
            let query = tui.searchQuery ?? ""
            return name.localizedCaseInsensitiveContains(query) ||
                   id.localizedCaseInsensitiveContains(query)
        }

        guard tui.viewCoordinator.selectedIndex < filteredImages.count else { return nil }
        return filteredImages[tui.viewCoordinator.selectedIndex]
    }
}
