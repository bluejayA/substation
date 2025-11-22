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

        static var all: [DynamicViewIdentifier] { [list, detail, create] }
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
                inputHandler: nil
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
            )
        ]
    }
}
