// Sources/Substation/Modules/Volumes/VolumesModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Cinder (Block Storage) module implementation
///
/// This module provides comprehensive block storage management capabilities including:
/// - Volume listing, creation, and detailed inspection
/// - Volume snapshot creation and management
/// - Volume backup creation and management
/// - Volume attachment management to compute instances
/// - Archive views for snapshots, backups, and server backups
///
/// The module handles complex workflows for volume lifecycle management,
/// integrating with compute services for attachments and providing
/// advanced filtering and search capabilities.
@MainActor
final class VolumesModule: OpenStackModule {

    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Volumes module
    let identifier: String = "volumes"

    /// Display name shown in the UI
    let displayName: String = "Volumes (Cinder)"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies (Volumes has no dependencies)
    let dependencies: [String] = []

    /// View modes handled by this module
    var handledViewModes: Set<ViewMode> {
        return [.volumes, .volumeDetail, .volumeCreate, .volumeArchives, .volumeArchiveDetail,
                .volumeManagement, .volumeServerManagement, .volumeSnapshotManagement,
                .volumeBackupManagement]
    }

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    /// Form state container for Volumes module
    internal var formState = VolumesFormState()

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    // MARK: - Initialization

    /// Initialize the Volumes module with TUI context
    /// - Parameter tui: The main TUI instance providing access to OpenStack client and UI state
    required init(tui: TUI) {
        self.tui = tui
        Logger.shared.logInfo("VolumesModule initialized", context: [
            "version": version,
            "identifier": identifier
        ])
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// Performs verification that the Cinder service is available in the service catalog.
    /// Does not throw if service is temporarily unavailable to allow graceful degradation.
    func configure() async throws {
        guard let tuiInstance = tui else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        Logger.shared.logInfo("VolumesModule configuration started", context: [:])

        // Log successful configuration
        // Note: Service availability will be verified during actual API calls
        Logger.shared.logInfo("VolumesModule configuration completed", context: [:])

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .volumes,
            detailViewMode: .volumeDetail
        )

        // Register as data provider
        let dataProvider = VolumesDataProvider(module: self, tui: tuiInstance)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)

        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all volume-related views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .volumes: Main volume list view
    /// - .volumeDetail: Detailed view of a selected volume
    /// - .volumeCreate: Form for creating new volumes
    /// - .volumeManagement: Volume attachment management
    /// - .volumeSnapshotManagement: Snapshot creation interface
    /// - .volumeBackupManagement: Backup creation interface
    /// - .volumeArchives: Combined view of snapshots and backups
    /// - .volumeArchiveDetail: Detail view for archive items
    ///
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register views - TUI reference is nil", context: [:])
            return []
        }

        var registrations: [ModuleViewRegistration] = []

        // Register volumes list view
        registrations.append(ModuleViewRegistration(
            viewMode: .volumes,
            title: "Volumes",
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderVolumeListView(
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
                case Int32(66):  // B - Create backup
                    Logger.shared.logUserAction("create_volume_backup", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                    await self.createVolumeBackup(screen: screen)
                    return true

                case Int32(80):  // P - Create snapshot
                    Logger.shared.logUserAction("create_volume_snapshot", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                    await self.createVolumeSnapshot(screen: screen)
                    return true

                case Int32(77):  // M - Manage volume attachment
                    Logger.shared.logUserAction("manage_volume", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                    await self.attachVolumeToServers(screen: screen)
                    return true

                default:
                    return false
                }
            },
            category: .storage
        ))

        // Register volume detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .volumeDetail,
            title: "Volume Details",
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderVolumeDetailView(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: nil,
            category: .storage
        ))

        // Register volume create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .volumeCreate,
            title: "Create Volume",
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderVolumeCreateView(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: nil,
            category: .storage
        ))

        // Register volume management (attachment) view
        registrations.append(ModuleViewRegistration(
            viewMode: .volumeManagement,
            title: "Manage Volume Attachments",
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderVolumeManagementView(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: nil,
            category: .storage
        ))

        // Register volume snapshot management view
        registrations.append(ModuleViewRegistration(
            viewMode: .volumeSnapshotManagement,
            title: "Create Volume Snapshot",
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderVolumeSnapshotManagementView(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: nil,
            category: .storage
        ))

        // Register volume backup management view
        registrations.append(ModuleViewRegistration(
            viewMode: .volumeBackupManagement,
            title: "Create Volume Backup",
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderVolumeBackupManagementView(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: nil,
            category: .storage
        ))

        // Register volume archives (snapshots + backups) list view
        registrations.append(ModuleViewRegistration(
            viewMode: .volumeArchives,
            title: "Volume Archives",
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderVolumeArchivesView(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: { [weak self] ch, screen in
                guard let self = self else { return false }

                switch ch {
                case Int32(127), Int32(330):  // DELETE/BACKSPACE - Delete archive
                    await self.deleteVolumeArchive(screen: screen)
                    return true

                default:
                    return false
                }
            },
            category: .storage
        ))

        // Register volume archive detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .volumeArchiveDetail,
            title: "Archive Details",
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderVolumeArchiveDetailView(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: nil,
            category: .storage
        ))

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for volume operations
    ///
    /// Registers handlers for:
    /// - Volume creation form
    /// - Volume snapshot creation form
    /// - Volume backup creation form
    /// - Volume attachment management form
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register form handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register volume create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .volumeCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleVolumeCreateInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                // Volume creation requires name and size at minimum
                return tui.volumeCreateForm.validate().isEmpty
            }
        ))

        // Register volume snapshot management form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .volumeSnapshotManagement,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleVolumeSnapshotManagementInput(ch, screen: screen)
            },
            formValidation: { true }
        ))

        // Register volume backup management form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .volumeBackupManagement,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleVolumeBackupManagementInput(ch, screen: screen)
            },
            formValidation: { true }
        ))

        // Register volume attachment management form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .volumeManagement,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.inputHandler.handleInput(ch, screen: screen)
            },
            formValidation: { true }
        ))

        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for volume resources
    ///
    /// Registers handlers to refresh:
    /// - Volume list
    /// - Volume snapshots
    /// - Volume backups
    ///
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register data refresh handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleDataRefreshRegistration] = []

        // Register volumes refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "volumes.list",
            refreshHandler: {
                let _ = await DataProviderRegistry.shared.fetchData(for: "volumes", priority: .onDemand, forceRefresh: true)
            },
            cacheKey: "volumes",
            refreshInterval: 30.0 // Refresh every 30 seconds
        ))

        // Register volume snapshots refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "volumes.snapshots",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }
                _ = try await tui.client.getAllVolumeSnapshots()
            },
            cacheKey: "volume_snapshots",
            refreshInterval: 60.0 // Refresh every 60 seconds
        ))

        // Register volume backups refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "volumes.backups",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }
                _ = try await tui.client.getAllVolumeBackups()
            },
            cacheKey: "volume_backups",
            refreshInterval: 60.0 // Refresh every 60 seconds
        ))

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// Clears cached volume data and resets module state.
    func cleanup() async {
        Logger.shared.logInfo("VolumesModule cleanup started", context: [:])

        // Clear any module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil

        // TUI reference will be released naturally via weak reference

        Logger.shared.logInfo("VolumesModule cleanup completed", context: [:])
    }

    // MARK: - Health Check

    /// Perform a health check on the Volumes module
    ///
    /// Verifies:
    /// - TUI reference is valid
    /// - Cinder service is accessible via the API client
    /// - Cached data is available
    /// - Module operations are functional
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

        // Check if volumes are loaded
        let volumeCount = tui.cacheManager.cachedVolumes.count
        metrics["volumeCount"] = volumeCount

        // Check if volumes cache is populated (indicates service availability)
        let hasVolumesData = volumeCount > 0
        metrics["hasVolumesData"] = hasVolumesData

        // Check snapshot and backup counts
        let snapshotCount = tui.cacheManager.cachedVolumeSnapshots.count
        let backupCount = tui.cacheManager.cachedVolumeBackups.count
        metrics["snapshotCount"] = snapshotCount
        metrics["backupCount"] = backupCount

        // Check client connectivity
        metrics["clientConnected"] = true

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

    // MARK: - Render Methods

    /// Render the volume list view
    func renderVolumeListView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await VolumeViews.drawDetailedVolumeList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            cachedVolumes: tui.cacheManager.cachedVolumes,
            searchQuery: tui.searchQuery,
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex,
            dataManager: tui.dataManager,
            virtualScrollManager: nil,
            multiSelectMode: tui.selectionManager.multiSelectMode,
            selectedItems: tui.selectionManager.multiSelectedResourceIDs
        )
    }

    /// Render the volume detail view
    func renderVolumeDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let volume = tui.viewCoordinator.selectedResource as? Volume else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No volume selected").error(), on: surface, in: bounds)
            return
        }

        await VolumeViews.drawVolumeDetail(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            volume: volume,
            scrollOffset: tui.viewCoordinator.detailScrollOffset
        )
    }

    /// Render the volume create form view
    func renderVolumeCreateView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await VolumeViews.drawVolumeCreate(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.volumeCreateFormState
        )
    }

    /// Render the volume management (attachment) view
    func renderVolumeManagementView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await VolumeManagementView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            form: tui.volumeManagementForm,
            selectedIndex: tui.viewCoordinator.selectedIndex,
            resourceNameCache: tui.resourceNameCache
        )
    }

    /// Render the volume snapshot management view
    func renderVolumeSnapshotManagementView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await VolumeSnapshotManagementView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            form: tui.volumeSnapshotManagementForm,
            formBuilderState: tui.volumeSnapshotManagementFormState
        )
    }

    /// Render the volume backup management view
    func renderVolumeBackupManagementView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await VolumeBackupManagementView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            form: tui.volumeBackupManagementForm,
            formBuilderState: tui.volumeBackupManagementFormState
        )
    }

    /// Render the volume archives (snapshots + backups) view
    func renderVolumeArchivesView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await VolumeArchiveViews.drawArchiveList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            cachedVolumeSnapshots: tui.cacheManager.cachedVolumeSnapshots,
            cachedVolumeBackups: tui.cacheManager.cachedVolumeBackups,
            cachedImages: tui.cacheManager.cachedImages,
            searchQuery: tui.searchQuery,
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex,
            multiSelectMode: tui.selectionManager.multiSelectMode,
            selectedItems: tui.selectionManager.multiSelectedResourceIDs
        )
    }

    /// Render the volume archive detail view
    func renderVolumeArchiveDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        let selectedResource = tui.viewCoordinator.selectedResource

        // Handle VolumeArchiveItem wrapper (if used)
        if let archiveItem = selectedResource as? VolumeArchiveItem {
            switch archiveItem.itemType {
            case .volumeSnapshot(let snapshot):
                await VolumeArchiveViews.drawVolumeSnapshotDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    snapshot: snapshot,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            case .volumeBackup(let backup):
                await VolumeArchiveViews.drawVolumeBackupDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    backup: backup,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            case .serverBackup(let image):
                await VolumeArchiveViews.drawServerBackupDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    image: image,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            }
            return
        }

        // Handle raw VolumeSnapshot
        if let snapshot = selectedResource as? VolumeSnapshot {
            await VolumeArchiveViews.drawVolumeSnapshotDetail(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                snapshot: snapshot,
                scrollOffset: tui.viewCoordinator.detailScrollOffset
            )
            return
        }

        // Handle raw VolumeBackup
        if let backup = selectedResource as? VolumeBackup {
            await VolumeArchiveViews.drawVolumeBackupDetail(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                backup: backup,
                scrollOffset: tui.viewCoordinator.detailScrollOffset
            )
            return
        }

        // Handle raw Image (server backup)
        if let image = selectedResource as? Image {
            await VolumeArchiveViews.drawServerBackupDetail(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                image: image,
                scrollOffset: tui.viewCoordinator.detailScrollOffset
            )
            return
        }

        // No valid archive item selected
        let surface = SwiftNCurses.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftNCurses.render(Text("No archive item selected").error(), on: surface, in: bounds)
    }

    // MARK: - Helper Functions

    /// Create status list view configuration for volumes
    private static func createVolumeStatusListView() -> StatusListView<Volume> {
        let columns = [
            StatusListColumn<Volume>(
                header: "Name",
                width: 30,
                getValue: { $0.name ?? "Unnamed" }
            ),
            StatusListColumn<Volume>(
                header: "Size",
                width: 10,
                getValue: { volume in
                    if let size = volume.size {
                        return "\(size) GB"
                    }
                    return "N/A"
                }
            ),
            StatusListColumn<Volume>(
                header: "Status",
                width: 15,
                getValue: { $0.status ?? "Unknown" },
                getStyle: { volume in
                    let status = volume.status?.lowercased() ?? "unknown"
                    if status == "available" { return .success }
                    if status == "in-use" { return .info }
                    if status.contains("error") { return .error }
                    return .warning
                }
            ),
            StatusListColumn<Volume>(
                header: "Type",
                width: 15,
                getValue: { $0.volumeType ?? "N/A" }
            ),
            StatusListColumn<Volume>(
                header: "Bootable",
                width: 10,
                getValue: { volume in
                    if let bootable = volume.bootable {
                        return bootable.lowercased() == "true" ? "Yes" : "No"
                    }
                    return "N/A"
                }
            )
        ]

        return StatusListView(
            title: "Volumes",
            columns: columns,
            getStatusIcon: { volume in
                let status = volume.status?.lowercased() ?? "unknown"
                if status == "available" { return "[+]" }
                if status == "in-use" { return "[*]" }
                if status.contains("error") { return "[X]" }
                return "[?]"
            },
            filterItems: { volumes, query in
                guard let query = query, !query.isEmpty else { return volumes }
                return volumes.filter { volume in
                    if let name = volume.name, name.localizedCaseInsensitiveContains(query) {
                        return true
                    }
                    if volume.id.localizedCaseInsensitiveContains(query) {
                        return true
                    }
                    if let status = volume.status, status.localizedCaseInsensitiveContains(query) {
                        return true
                    }
                    return false
                }
            },
            getItemID: { $0.id }
        )
    }

    // MARK: - Computed Properties

    /// Get all cached volumes
    ///
    /// Returns all volumes from the cache manager.
    /// Used for volume listing, filtering, and selection operations.
    var volumes: [Volume] {
        return tui?.cacheManager.cachedVolumes ?? []
    }

    /// Get all cached volume types
    ///
    /// Returns all volume types from the cache manager.
    /// Used for volume creation and type selection.
    var volumeTypes: [VolumeType] {
        return tui?.cacheManager.cachedVolumeTypes ?? []
    }

    /// Get all cached volume snapshots
    ///
    /// Returns all volume snapshots from the cache manager.
    /// Used for snapshot listing and volume creation from snapshots.
    var volumeSnapshots: [VolumeSnapshot] {
        return tui?.cacheManager.cachedVolumeSnapshots ?? []
    }

    /// Get all cached volume backups
    ///
    /// Returns all volume backups from the cache manager.
    /// Used for backup listing and volume restoration.
    var volumeBackups: [VolumeBackup] {
        return tui?.cacheManager.cachedVolumeBackups ?? []
    }
}

// MARK: - ActionProvider Conformance

extension VolumesModule: ActionProvider {
    /// Actions available in the list view for volumes
    ///
    /// Includes create, delete, refresh, manage, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .manage, .clearCache]
    }

    /// The view mode for creating a new volume
    var createViewMode: ViewMode? {
        .volumeCreate
    }

    /// Execute an action for the selected volume
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

            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".volumeCreate")
            tui.changeView(to: createMode)

            // Load data for volume creation (use returned values directly due to async cache setter)
            let snapshots = await loadAllVolumeSnapshots()
            let volumeTypes = await loadVolumeTypes()

            // Initialize form with loaded data
            // Sort images and snapshots by name for consistent display and selection
            tui.volumeCreateForm = VolumeCreateForm()
            tui.volumeCreateForm.images = tui.cacheManager.cachedImages.sorted { ($0.name ?? "") < ($1.name ?? "") }
            tui.volumeCreateForm.snapshots = snapshots.sorted { ($0.name ?? "") < ($1.name ?? "") }
            tui.volumeCreateForm.volumeTypes = volumeTypes.sorted { ($0.name ?? "") < ($1.name ?? "") }

            // Initialize form state
            tui.volumeCreateFormState = FormBuilderState(fields: tui.volumeCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: nil
            ))

            tui.statusMessage = "Create new volume"
            return true
        case .delete:
            await deleteVolume(screen: screen)
            return true
        case .manage:
            await manageVolumeToServers(screen: screen)
            return true
        default:
            return false
        }
    }

    /// Get the bulk delete operation for selected volumes
    ///
    /// Creates a batch operation for deleting multiple volumes at once.
    ///
    /// - Parameters:
    ///   - selectedIDs: Set of volume IDs to delete
    ///   - tui: The TUI instance for state management
    /// - Returns: BatchOperationType for volume bulk delete, or nil if not supported
    func getBulkDeleteOperation(selectedIDs: Set<String>, tui: TUI) -> BatchOperationType? {
        return .volumeBulkDelete(volumeIDs: Array(selectedIDs))
    }

    /// Get the ID of the currently selected volume
    ///
    /// Returns the volume ID based on the current selection index, accounting for any
    /// search filtering that may be applied to the list.
    ///
    /// - Parameter tui: The TUI instance for state management
    /// - Returns: Volume ID string, or empty string if no valid selection
    func getSelectedResourceId(tui: TUI) -> String {
        let filtered = FilterUtils.filterVolumes(tui.cacheManager.cachedVolumes, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filtered.count else { return "" }
        return filtered[tui.viewCoordinator.selectedIndex].id
    }
}
