// Sources/Substation/Modules/FloatingIPs/Extensions/FloatingIPsModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the FloatingIPs module
extension FloatingIPsModule {
    // MARK: - View Identifiers

    enum Views {
        static let list = DynamicViewIdentifier(id: "floatingips.list", moduleId: "floatingips", viewType: .list)
        static let detail = DynamicViewIdentifier(id: "floatingips.detail", moduleId: "floatingips", viewType: .detail)
        static let create = DynamicViewIdentifier(id: "floatingips.create", moduleId: "floatingips", viewType: .create)
        static let serverSelect = DynamicViewIdentifier(id: "floatingips.serverSelect", moduleId: "floatingips", viewType: .selection)
        static let serverManagement = DynamicViewIdentifier(id: "floatingips.serverManagement", moduleId: "floatingips", viewType: .management)
        static let portManagement = DynamicViewIdentifier(id: "floatingips.portManagement", moduleId: "floatingips", viewType: .management)

        static var all: [DynamicViewIdentifier] { [list, detail, create, serverSelect, serverManagement, portManagement] }
    }

    // MARK: - Enhanced View Registration

    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            ViewMetadata(
                identifier: Views.list,
                title: "Floating IPs",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await FloatingIPViews.drawDetailedFloatingIPList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedFloatingIPs: tui.cacheManager.cachedFloatingIPs,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        cachedServers: tui.cacheManager.cachedServers,
                        cachedPorts: tui.cacheManager.cachedPorts,
                        cachedNetworks: tui.cacheManager.cachedNetworks,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: nil
            ),
            ViewMetadata(
                identifier: Views.detail,
                title: "Floating IP Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let floatingIP = tui.viewCoordinator.selectedResource as? FloatingIP else { return }
                    await FloatingIPViews.drawFloatingIPDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        floatingIP: floatingIP,
                        cachedServers: tui.cacheManager.cachedServers,
                        cachedPorts: tui.cacheManager.cachedPorts,
                        cachedNetworks: tui.cacheManager.cachedNetworks,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            ),
            ViewMetadata(
                identifier: Views.serverSelect,
                title: "Select Server",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    if let floatingIP = tui.viewCoordinator.selectedResource as? FloatingIP {
                        await FloatingIPViews.drawServerSelectionView(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            floatingIP: floatingIP,
                            cachedServers: tui.cacheManager.cachedServers,
                            cachedPorts: tui.cacheManager.cachedPorts,
                            scrollOffset: tui.viewCoordinator.scrollOffset,
                            selectedIndex: tui.viewCoordinator.selectedIndex
                        )
                    }
                },
                inputHandler: nil
            ),
            ViewMetadata(
                identifier: Views.serverManagement,
                title: "Server Management",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    if let floatingIP = tui.viewCoordinator.selectedResource as? FloatingIP {
                        await FloatingIPServerManagementView.draw(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            floatingIP: floatingIP,
                            servers: tui.cacheManager.cachedServers,
                            attachedServerId: tui.selectionManager.attachedServerId,
                            selectedServerId: tui.selectionManager.selectedServerId,
                            searchQuery: tui.searchQuery,
                            scrollOffset: tui.viewCoordinator.scrollOffset,
                            selectedIndex: tui.viewCoordinator.selectedIndex,
                            mode: tui.selectionManager.attachmentMode,
                            resourceResolver: tui.resourceResolver
                        )
                    }
                },
                inputHandler: nil
            ),
            ViewMetadata(
                identifier: Views.portManagement,
                title: "Port Management",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    if let floatingIP = tui.viewCoordinator.selectedResource as? FloatingIP {
                        await FloatingIPPortManagementView.draw(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            floatingIP: floatingIP,
                            ports: tui.cacheManager.cachedPorts,
                            attachedPortId: tui.selectionManager.attachedPortId,
                            selectedPortId: tui.selectionManager.selectedPortId,
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
