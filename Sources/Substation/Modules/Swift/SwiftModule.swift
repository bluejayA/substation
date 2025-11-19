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

    // MARK: - Private Properties

    private weak var tui: TUI?

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
        _ = tui

        Logger.shared.logInfo("SwiftModule configuration started", context: [:])

        // Module configured successfully
        // Swift service availability will be checked during actual API calls
        Logger.shared.logInfo("SwiftModule configuration completed", context: [:])
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await self.renderSwiftContainerListView(
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
                    await tui.inputHandler.handleInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Container detail view
            ModuleViewRegistration(
                viewMode: .swiftContainerDetail,
                title: "Container Details",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await self.renderSwiftContainerDetailView(
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
                    await tui.inputHandler.handleInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Object detail view
            ModuleViewRegistration(
                viewMode: .swiftObjectDetail,
                title: "Object Details",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await self.renderSwiftObjectDetailView(
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
                    await tui.inputHandler.handleInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Container create form
            ModuleViewRegistration(
                viewMode: .swiftContainerCreate,
                title: "Create Container",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                    await tui.inputHandler.handleInput(ch, screen: screen)
                    return true
                },
                category: .storage
            ),

            // Background operation detail
            ModuleViewRegistration(
                viewMode: .swiftBackgroundOperationDetail,
                title: "Operation Details",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                    await tui.inputHandler.handleInput(ch, screen: screen)
                    return true
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
        guard let tui = tui else {
            Logger.shared.logError("Cannot register data refresh handlers - TUI reference is nil", context: [:])
            return []
        }

        return [
            // Object list refresh for current container
            ModuleDataRefreshRegistration(
                identifier: "swift.objects",
                refreshHandler: { [weak tui] in
                    guard let tui = tui else { return }
                    guard let containerName = tui.swiftNavState.currentContainer else {
                        Logger.shared.logDebug("No container selected for object refresh")
                        return
                    }
                    await tui.dataManager.fetchSwiftObjects(
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

        // Clear any cached Swift data
        if let tui = tui {
            tui.cachedSwiftContainers = []
            // Reset navigation state
            tui.swiftNavState.reset()
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
        let containerCount = tui.cachedSwiftContainers.count
        metrics["cached_containers"] = containerCount
        metrics["service_available"] = containerCount > 0

        if containerCount == 0 {
            errors.append("No Swift containers loaded - service may be unavailable")
        }

        if let currentContainer = tui.swiftNavState.currentContainer,
           let objects = tui.cachedSwiftObjects {
            metrics["cached_objects"] = objects.count
            metrics["current_container"] = currentContainer
        }

        // Navigation state metrics
        metrics["navigation_depth"] = tui.swiftNavState.depth
        metrics["is_at_container_list"] = tui.swiftNavState.isAtContainerList

        return ModuleHealthStatus(
            isHealthy: errors.isEmpty,
            lastCheck: Date(),
            errors: errors,
            metrics: metrics
        )
    }

    // MARK: - Private Render Methods

    /// Render the Swift container list view
    private func renderSwiftContainerListView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        let containers = tui.cachedSwiftContainers
        let searchQuery = tui.searchQuery ?? ""

        await SwiftViews.drawSwiftContainerList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            containers: containers,
            searchQuery: searchQuery,
            scrollOffset: tui.scrollOffset,
            selectedIndex: tui.selectedIndex,
            dataManager: tui.dataManager,
            virtualScrollManager: nil,
            multiSelectMode: tui.multiSelectMode,
            selectedItems: tui.multiSelectedResourceIDs
        )
    }

    /// Render the Swift container detail view
    private func renderSwiftContainerDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let container = tui.selectedResource as? SwiftContainer else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No container selected").error(), on: surface, in: bounds)
            return
        }

        // TODO: Metadata fetching not yet implemented
        let metadata: SwiftContainerMetadataResponse? = nil

        await SwiftViews.drawSwiftContainerDetail(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            container: container,
            metadata: metadata,
            scrollOffset: tui.detailScrollOffset
        )
    }

    /// Render the Swift object detail view
    private func renderSwiftObjectDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let object = tui.selectedResource as? SwiftObject else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No object selected").error(), on: surface, in: bounds)
            return
        }

        guard let containerName = tui.swiftNavState.currentContainer else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No container context").error(), on: surface, in: bounds)
            return
        }

        // TODO: Metadata fetching not yet implemented
        let metadata: SwiftObjectMetadataResponse? = nil

        await SwiftViews.drawSwiftObjectDetail(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            object: object,
            containerName: containerName,
            metadata: metadata,
            scrollOffset: tui.detailScrollOffset
        )
    }

    /// Render container create form view
    private func renderSwiftContainerCreateView(
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
    private func renderSwiftObjectUploadView(
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
    private func renderSwiftContainerDownloadView(
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
    private func renderSwiftObjectDownloadView(
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
    private func renderSwiftDirectoryDownloadView(
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
    private func renderSwiftContainerMetadataView(
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
    private func renderSwiftObjectMetadataView(
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
    private func renderSwiftDirectoryMetadataView(
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
    private func renderSwiftContainerWebAccessView(
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
    private func renderSwiftBackgroundOperationsView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        // TODO: Background operations view not yet implemented
        let surface = SwiftNCurses.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftNCurses.render(
            Text("Background operations view not yet implemented").warning(),
            on: surface,
            in: bounds
        )
    }

    /// Render background operation detail view
    private func renderSwiftBackgroundOperationDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        // TODO: Background operation detail view not yet implemented
        let surface = SwiftNCurses.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftNCurses.render(
            Text("Background operation detail view not yet implemented").warning(),
            on: surface,
            in: bounds
        )
    }
}
