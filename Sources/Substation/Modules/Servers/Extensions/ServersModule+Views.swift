// Sources/Substation/Modules/Servers/Extensions/ServersModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Servers module
///
/// This extension defines all view identifiers and metadata registration
/// for the Servers module using the new ViewIdentifier system.
extension ServersModule {
    // MARK: - View Identifiers

    /// View identifiers for the Servers module
    enum Views {
        /// Server list view
        static let list = DynamicViewIdentifier(
            id: "servers.list",
            moduleId: "servers",
            viewType: .list
        )

        /// Server detail view
        static let detail = DynamicViewIdentifier(
            id: "servers.detail",
            moduleId: "servers",
            viewType: .detail
        )

        /// Server create view
        static let create = DynamicViewIdentifier(
            id: "servers.create",
            moduleId: "servers",
            viewType: .create
        )

        /// Server console view
        static let console = DynamicViewIdentifier(
            id: "servers.console",
            moduleId: "servers",
            viewType: .console
        )

        /// Server resize view
        static let resize = DynamicViewIdentifier(
            id: "servers.resize",
            moduleId: "servers",
            viewType: .management
        )

        /// Server snapshot management view
        static let snapshotManagement = DynamicViewIdentifier(
            id: "servers.snapshotManagement",
            moduleId: "servers",
            viewType: .management
        )

        /// Server security groups view
        static let securityGroups = DynamicViewIdentifier(
            id: "servers.securityGroups",
            moduleId: "servers",
            viewType: .management
        )

        /// Server network interfaces view
        static let networkInterfaces = DynamicViewIdentifier(
            id: "servers.networkInterfaces",
            moduleId: "servers",
            viewType: .management
        )

        /// Server group management view
        static let groupManagement = DynamicViewIdentifier(
            id: "servers.groupManagement",
            moduleId: "servers",
            viewType: .management
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [
                list, detail, create, console, resize,
                snapshotManagement, securityGroups, networkInterfaces, groupManagement
            ]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register all server views with metadata
    ///
    /// This method returns ViewMetadata for registration with the enhanced
    /// ViewRegistry system. It provides complete view information including
    /// parent views for navigation and multi-select support flags.
    ///
    /// - Returns: Array of ViewMetadata for all module views
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            // Servers List View
            ViewMetadata(
                identifier: Views.list,
                title: "Servers",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await ServerViews.drawDetailedServerList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedServers: tui.cacheManager.cachedServers,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        cachedFlavors: tui.cacheManager.cachedFlavors,
                        cachedImages: tui.cacheManager.cachedImages,
                        dataManager: tui.dataManager,
                        virtualScrollManager: nil,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: nil
            ),

            // Server Detail View
            ViewMetadata(
                identifier: Views.detail,
                title: "Server Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let server = tui.viewCoordinator.selectedResource as? Server else {
                        let surface = SwiftNCurses.surface(from: screen)
                        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                        await SwiftNCurses.render(Text("No server selected").error(), on: surface, in: bounds)
                        return
                    }
                    await ServerViews.drawServerDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        server: server,
                        cachedVolumes: tui.cacheManager.cachedVolumes,
                        cachedFlavors: tui.cacheManager.cachedFlavors,
                        cachedImages: tui.cacheManager.cachedImages,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            ),

            // Server Create View
            ViewMetadata(
                identifier: Views.create,
                title: "Create Server",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await ServerCreateView.drawServerCreateForm(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.serverCreateForm,
                        formState: tui.serverCreateFormState
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleServerCreateInput(ch, screen: screen)
                    return true
                }
            ),

            // Server Console View
            ViewMetadata(
                identifier: Views.console,
                title: "Server Console",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard tui.viewCoordinator.selectedResource is Server else {
                        let surface = SwiftNCurses.surface(from: screen)
                        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                        await SwiftNCurses.render(Text("No server selected").error(), on: surface, in: bounds)
                        return
                    }
                    let surface = SwiftNCurses.surface(from: screen)
                    let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                    await SwiftNCurses.render(Text("Console data not available").error(), on: surface, in: bounds)
                },
                inputHandler: nil
            ),

            // Server Resize View
            ViewMetadata(
                identifier: Views.resize,
                title: "Resize Server",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await ServerViews.drawServerResizeManagement(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        serverResizeForm: tui.serverResizeForm
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleServerResizeInput(ch, screen: screen)
                    return true
                }
            ),

            // Server Snapshot Management View
            ViewMetadata(
                identifier: Views.snapshotManagement,
                title: "Create Server Snapshot",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await SnapshotManagementView.drawServerSnapshotManagement(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.snapshotManagementForm,
                        formBuilderState: tui.snapshotManagementFormState
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSnapshotManagementInput(ch, screen: screen)
                    return true
                }
            ),

            // Server Security Groups Management View
            ViewMetadata(
                identifier: Views.securityGroups,
                title: "Manage Security Groups",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await SecurityGroupViews.drawServerSecurityGroupManagement(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.securityGroupForm
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSecurityGroupInput(ch, screen: screen)
                    return true
                }
            ),

            // Server Network Interfaces Management View
            ViewMetadata(
                identifier: Views.networkInterfaces,
                title: "Manage Network Interfaces",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await NetworkInterfaceManagementView.drawServerNetworkInterfaceManagement(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.networkInterfaceForm,
                        resourceNameCache: tui.resourceNameCache,
                        resourceResolver: tui.resourceResolver
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleNetworkInterfaceInput(ch, screen: screen)
                    return true
                }
            ),

            // Server Group Management View
            ViewMetadata(
                identifier: Views.groupManagement,
                title: "Manage Server Group",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await ServerGroupViews.drawServerGroupManagement(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.serverGroupManagementForm
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleServerGroupManagementInput(ch, screen: screen)
                    return true
                }
            )
        ]
    }
}
