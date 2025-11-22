// Sources/Substation/Modules/Subnets/Extensions/SubnetsModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Subnets module
extension SubnetsModule {
    // MARK: - View Identifiers

    /// View identifiers for the Subnets module
    enum Views {
        static let list = DynamicViewIdentifier(id: "subnets.list", moduleId: "subnets", viewType: .list)
        static let detail = DynamicViewIdentifier(id: "subnets.detail", moduleId: "subnets", viewType: .detail)
        static let create = DynamicViewIdentifier(id: "subnets.create", moduleId: "subnets", viewType: .create)
        static let routerManagement = DynamicViewIdentifier(id: "subnets.routerManagement", moduleId: "subnets", viewType: .management)

        static var all: [DynamicViewIdentifier] { [list, detail, create, routerManagement] }
    }

    // MARK: - Enhanced View Registration

    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            ViewMetadata(
                identifier: Views.list,
                title: "Subnets",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await SubnetViews.drawDetailedSubnetList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedSubnets: tui.cacheManager.cachedSubnets,
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
                title: "Subnet Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let subnet = tui.viewCoordinator.selectedResource as? Subnet else { return }
                    await SubnetViews.drawSubnetDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        subnet: subnet,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            )
            // Note: Create and router management views are handled via legacy system
        ]
    }
}
