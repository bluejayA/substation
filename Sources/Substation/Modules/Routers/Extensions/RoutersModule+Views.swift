// Sources/Substation/Modules/Routers/Extensions/RoutersModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Routers module
extension RoutersModule {
    // MARK: - View Identifiers

    enum Views {
        static let list = DynamicViewIdentifier(id: "routers.list", moduleId: "routers", viewType: .list)
        static let detail = DynamicViewIdentifier(id: "routers.detail", moduleId: "routers", viewType: .detail)
        static let create = DynamicViewIdentifier(id: "routers.create", moduleId: "routers", viewType: .create)
        static let edit = DynamicViewIdentifier(id: "routers.edit", moduleId: "routers", viewType: .edit)
        static let subnetManagement = DynamicViewIdentifier(id: "routers.subnetManagement", moduleId: "routers", viewType: .detail)

        static var all: [DynamicViewIdentifier] { [list, detail, create, edit, subnetManagement] }
    }

    // MARK: - Enhanced View Registration

    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            ViewMetadata(
                identifier: Views.list,
                title: "Routers",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await RouterViews.drawDetailedRouterList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedRouters: tui.cacheManager.cachedRouters,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: { [weak self, weak tui] ch, screen in
                    guard let self = self, let tui = tui else { return false }

                    switch ch {
                    case Int32(69):  // E - Edit selected router (SHIFT-E)
                        Logger.shared.logUserAction("edit_router", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.editRouter(screen: screen)
                        return true

                    case Int32(83):  // S - Manage subnet interfaces (SHIFT-S)
                        Logger.shared.logUserAction("manage_router_subnets", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.manageRouterSubnetInterfaces(screen: screen)
                        return true

                    default:
                        return false
                    }
                }
            ),
            ViewMetadata(
                identifier: Views.detail,
                title: "Router Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let router = tui.viewCoordinator.selectedResource as? Router else { return }
                    await RouterViews.drawRouterDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        router: router,
                        cachedSubnets: tui.cacheManager.cachedSubnets,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                    inputHandler: nil
            ),

            // Router Create View
            ViewMetadata(
                identifier: Views.create,
                title: "Create Router",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await RouterViews.drawRouterCreateForm(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        routerCreateForm: tui.routerCreateForm,
                        routerCreateFormState: tui.routerCreateFormState,
                        availabilityZones: tui.cacheManager.cachedAvailabilityZones,
                        externalNetworks: tui.cacheManager.cachedNetworks.filter { $0.external == true }
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleRouterCreateInput(ch, screen: screen)
                    return true
                }
            ),

            // Router Edit View
            ViewMetadata(
                identifier: Views.edit,
                title: "Edit Router",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await RouterViews.drawRouterEditForm(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        routerEditForm: tui.routerEditForm,
                        routerEditFormState: tui.routerEditFormState,
                        externalNetworks: tui.cacheManager.cachedNetworks.filter { $0.external == true }
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleRouterEditInput(ch, screen: screen)
                    return true
                }
            ),

            // Router Subnet Management View
            ViewMetadata(
                identifier: Views.subnetManagement,
                title: "Manage Router Subnet Interfaces",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else {
                        Logger.shared.logError("RouterSubnetManagement: TUI is nil")
                        return
                    }
                    guard let router = tui.viewCoordinator.selectedResource as? Router else {
                        Logger.shared.logError("RouterSubnetManagement: No router selected")
                        let surface = SwiftNCurses.surface(from: screen)
                        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                        await SwiftNCurses.render(
                            Text("No router selected for subnet management").error(),
                            on: surface,
                            in: bounds
                        )
                        return
                    }

                    Logger.shared.logDebug("RouterSubnetManagement: Rendering with \(tui.cacheManager.cachedSubnets.count) subnets")

                    await RouterSubnetManagementView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        router: router,
                        subnets: tui.cacheManager.cachedSubnets,
                        attachedSubnetIds: tui.selectionManager.attachedSubnetIds,
                        selectedSubnetId: tui.selectionManager.selectedSubnetId,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        mode: tui.selectionManager.attachmentMode
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleRouterSubnetManagementInput(ch, screen: screen)
                    return true
                }
            )
        ]
    }
}
