// Sources/Substation/Modules/Networks/Extensions/NetworksModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Networks module
///
/// This extension defines all view identifiers and metadata registration
/// for the Networks module using the new ViewIdentifier system.
extension NetworksModule {
    // MARK: - View Identifiers

    /// View identifiers for the Networks module
    enum Views {
        /// Network list view
        static let list = DynamicViewIdentifier(
            id: "networks.list",
            moduleId: "networks",
            viewType: .list
        )

        /// Network detail view
        static let detail = DynamicViewIdentifier(
            id: "networks.detail",
            moduleId: "networks",
            viewType: .detail
        )

        /// Network create view
        static let create = DynamicViewIdentifier(
            id: "networks.create",
            moduleId: "networks",
            viewType: .create
        )

        /// Network server attachment view
        static let serverAttachment = DynamicViewIdentifier(
            id: "networks.serverAttachment",
            moduleId: "networks",
            viewType: .management
        )

        /// Network server management view
        static let serverManagement = DynamicViewIdentifier(
            id: "networks.serverManagement",
            moduleId: "networks",
            viewType: .management
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [list, detail, create, serverAttachment, serverManagement]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register all network views with metadata
    ///
    /// This method returns ViewMetadata for registration with the enhanced
    /// ViewRegistry system. It provides complete view information including
    /// parent views for navigation and multi-select support flags.
    ///
    /// - Returns: Array of ViewMetadata for all module views
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            // Networks List View
            ViewMetadata(
                identifier: Views.list,
                title: "Networks",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await NetworkViews.drawDetailedNetworkList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedNetworks: tui.cacheManager.cachedNetworks,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        dataManager: tui.dataManager,
                        virtualScrollManager: nil,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: nil
            ),

            // Network Detail View
            ViewMetadata(
                identifier: Views.detail,
                title: "Network Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let network = tui.viewCoordinator.selectedResource as? Network else {
                        let surface = SwiftNCurses.surface(from: screen)
                        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                        await SwiftNCurses.render(Text("No network selected").error(), on: surface, in: bounds)
                        return
                    }
                    await NetworkViews.drawNetworkDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        network: network,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            ),

            // Network Create View
            ViewMetadata(
                identifier: Views.create,
                title: "Create Network",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await NetworkViews.drawNetworkCreate(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        networkCreateForm: tui.networkCreateForm,
                        networkCreateFormState: tui.networkCreateFormState
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleNetworkCreateInput(ch, screen: screen)
                    return true
                }
            ),

            // Network Server Attachment View
            ViewMetadata(
                identifier: Views.serverAttachment,
                title: "Attach Servers",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await NetworkServerAttachmentView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        servers: tui.cacheManager.cachedServers,
                        selectedServers: tui.selectionManager.selectedServers,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex
                    )
                },
                inputHandler: nil
            ),

            // Network Server Management View
            ViewMetadata(
                identifier: Views.serverManagement,
                title: "Server Management",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    if let network = tui.viewCoordinator.selectedResource as? Network {
                        await NetworkServerManagementView.draw(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            network: network,
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
