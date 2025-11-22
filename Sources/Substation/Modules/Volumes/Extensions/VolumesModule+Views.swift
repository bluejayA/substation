// Sources/Substation/Modules/Volumes/Extensions/VolumesModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Volumes module
///
/// This extension defines all view identifiers and metadata registration
/// for the Volumes module using the new ViewIdentifier system.
extension VolumesModule {
    // MARK: - View Identifiers

    /// View identifiers for the Volumes module
    enum Views {
        /// Volume list view
        static let list = DynamicViewIdentifier(
            id: "volumes.list",
            moduleId: "volumes",
            viewType: .list
        )

        /// Volume detail view
        static let detail = DynamicViewIdentifier(
            id: "volumes.detail",
            moduleId: "volumes",
            viewType: .detail
        )

        /// Volume create view
        static let create = DynamicViewIdentifier(
            id: "volumes.create",
            moduleId: "volumes",
            viewType: .create
        )

        /// Volume archives view
        static let archives = DynamicViewIdentifier(
            id: "volumes.archives",
            moduleId: "volumes",
            viewType: .list
        )

        /// Volume archive detail view
        static let archiveDetail = DynamicViewIdentifier(
            id: "volumes.archiveDetail",
            moduleId: "volumes",
            viewType: .detail
        )

        /// Volume management view
        static let management = DynamicViewIdentifier(
            id: "volumes.management",
            moduleId: "volumes",
            viewType: .management
        )

        /// Volume server management view
        static let serverManagement = DynamicViewIdentifier(
            id: "volumes.serverManagement",
            moduleId: "volumes",
            viewType: .management
        )

        /// Volume snapshot management view
        static let snapshotManagement = DynamicViewIdentifier(
            id: "volumes.snapshotManagement",
            moduleId: "volumes",
            viewType: .management
        )

        /// Volume backup management view
        static let backupManagement = DynamicViewIdentifier(
            id: "volumes.backupManagement",
            moduleId: "volumes",
            viewType: .management
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [
                list, detail, create, archives, archiveDetail,
                management, serverManagement, snapshotManagement, backupManagement
            ]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register all volume views with metadata
    ///
    /// This method returns ViewMetadata for registration with the enhanced
    /// ViewRegistry system. It provides complete view information including
    /// parent views for navigation and multi-select support flags.
    ///
    /// - Returns: Array of ViewMetadata for all module views
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            // Volumes List View
            ViewMetadata(
                identifier: Views.list,
                title: "Volumes",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .storage,
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
                inputHandler: nil
            ),

            // Volume Detail View
            ViewMetadata(
                identifier: Views.detail,
                title: "Volume Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .storage,
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
                inputHandler: nil
            ),

            // Volume Create View
            ViewMetadata(
                identifier: Views.create,
                title: "Create Volume",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
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
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleVolumeCreateInput(ch, screen: screen)
                    return true
                }
            ),

            // Volume Archives View
            ViewMetadata(
                identifier: Views.archives,
                title: "Volume Archives",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .storage,
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
                inputHandler: nil
            ),

            // Volume Archive Detail View
            ViewMetadata(
                identifier: Views.archiveDetail,
                title: "Archive Details",
                parentViewId: Views.archives.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .storage,
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
                inputHandler: nil
            ),

            // Volume Server Management View
            ViewMetadata(
                identifier: Views.serverManagement,
                title: "Server Management",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .storage,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    if let volume = tui.viewCoordinator.selectedResource as? Volume {
                        await VolumeServerManagementView.draw(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            volume: volume,
                            servers: tui.cacheManager.cachedServers,
                            attachedServerIds: tui.selectionManager.attachedServerIds,
                            selectedServers: tui.selectionManager.selectedServers,
                            searchQuery: tui.searchQuery,
                            scrollOffset: tui.viewCoordinator.scrollOffset,
                            selectedIndex: tui.viewCoordinator.selectedIndex,
                            mode: tui.selectionManager.attachmentMode,
                            resourceResolver: tui.resourceResolver
                        )
                    }
                },
                inputHandler: nil
            )
        ]
    }
}
