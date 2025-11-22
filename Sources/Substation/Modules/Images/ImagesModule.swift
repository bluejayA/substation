// Sources/Substation/Modules/Images/ImagesModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// Glance Image Service module implementation
///
/// This is a read-only module providing OpenStack Glance (Image Service) functionality including:
/// - Image listing and browsing with status-based filtering
/// - Detailed image views with property classification
/// - Technical specifications, metadata, and snapshot information display
///
/// The module integrates with the TUI system through the OpenStackModule protocol
/// and delegates rendering to ImageViews for consistent UI presentation.
///
/// Note: This module is read-only - it provides no forms for image creation or modification.
/// All image management operations must be performed through the OpenStack CLI or API.
@MainActor
final class ImagesModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Images module
    let identifier: String = "images"

    /// Display name shown in the UI
    let displayName: String = "Images (Glance)"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies (Images has no dependencies)
    let dependencies: [String] = []

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    // MARK: - Initialization

    /// Initialize the Images module with TUI context
    /// - Parameter tui: The main TUI instance
    required init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs any necessary setup for the Images module.
    /// Currently, Images requires no special configuration beyond registration.
    func configure() async throws {
        guard tui != nil else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        // Images module is ready to use immediately
        // No additional configuration required

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .images,
            detailViewMode: .imageDetail
        )

        // Register as data provider
        let dataProvider = ImagesDataProvider(module: self, tui: tui!)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all Images views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .images: List view of all images
    /// - .imageDetail: Detail view for a selected image
    ///
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            return []
        }

        var registrations: [ModuleViewRegistration] = []

        // Register images list view
        registrations.append(ModuleViewRegistration(
            viewMode: .images,
            title: "Images",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await ImageViews.drawDetailedImageList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedImages: tui.cacheManager.cachedImages,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex,
                    multiSelectMode: tui.selectionManager.multiSelectMode,
                    selectedItems: tui.selectionManager.multiSelectedResourceIDs
                )
            },
            inputHandler: { _, _ in
                // Let the default system handle input
                return false
            },
            category: .compute
        ))

        // Register image detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .imageDetail,
            title: "Image Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let image = tui.viewCoordinator.selectedResource as? Image else { return }

                await ImageViews.drawImageDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    image: image,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: { _, _ in
                // Let the default system handle input
                return false
            },
            category: .compute
        ))

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for Images forms
    ///
    /// Images module is read-only and provides no forms.
    /// Image creation and modification must be done through external tools.
    ///
    /// - Returns: Empty array (no form handlers)
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        // Images is a read-only module with no forms
        return []
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for Images resources
    ///
    /// Registers a handler to refresh the images list from the Glance API.
    ///
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else {
            return []
        }

        var handlers: [ModuleDataRefreshRegistration] = []

        // Register images refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "images.list",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }
                // Refresh images from the Glance API
                await tui.dataManager.refreshAllData()
            },
            cacheKey: "images",
            refreshInterval: 60.0
        ))

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    /// It ensures proper resource cleanup and state management.
    func cleanup() async {
        // Clear any module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil

        // TUI reference will be released naturally via weak reference
    }

    // MARK: - Health Check

    /// Perform a health check on the Images module
    ///
    /// This method verifies that:
    /// - TUI reference is valid
    /// - Glance service is accessible via the API client
    /// - Core functionality is operational
    ///
    /// - Returns: ModuleHealthStatus indicating module health
    func healthCheck() async -> ModuleHealthStatus {
        var errors: [String] = []
        var metrics: [String: Any] = [:]

        // Check TUI reference
        guard let tui = tui else {
            errors.append("TUI reference is nil")
            return ModuleHealthStatus(
                isHealthy: false,
                lastCheck: Date(),
                errors: errors,
                metrics: metrics
            )
        }

        // Check if images are loaded
        let imageCount = tui.cacheManager.cachedImages.count
        metrics["imageCount"] = imageCount

        if imageCount == 0 {
            metrics["warning"] = "No images loaded"
        }

        // Update health tracking
        lastHealthCheck = Date()
        healthErrors = errors

        return ModuleHealthStatus(
            isHealthy: errors.isEmpty,
            lastCheck: Date(),
            errors: errors,
            metrics: metrics
        )
    }

    // MARK: - Computed Properties

    /// Get all cached images
    ///
    /// Returns all images from the cache manager.
    /// Used for image listing, filtering, and selection operations.
    var images: [Image] {
        return tui?.cacheManager.cachedImages ?? []
    }
}

// MARK: - ActionProvider Conformance

extension ImagesModule: ActionProvider {
    /// Actions available in the list view for images
    ///
    /// Images module is read-only so no create action. Includes delete, refresh, and cache management.
    var listViewActions: [ActionType] {
        [.delete, .refresh, .clearCache]
    }

    /// The view mode for creating a new image
    ///
    /// Returns nil as Images module is read-only.
    var createViewMode: ViewMode? {
        nil
    }

    /// Execute an action for the selected image
    ///
    /// - Parameters:
    ///   - action: The action type to execute
    ///   - screen: Screen pointer for confirmation dialogs
    ///   - tui: The TUI instance for state management
    /// - Returns: Boolean indicating if the action was handled
    func executeAction(_ action: ActionType, screen: OpaquePointer?, tui: TUI) async -> Bool {
        switch action {
        case .delete:
            await deleteImage(screen: screen)
            return true
        default:
            return false
        }
    }
}
