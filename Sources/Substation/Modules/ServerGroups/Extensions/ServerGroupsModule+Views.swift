// Sources/Substation/Modules/ServerGroups/Extensions/ServerGroupsModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the ServerGroups module
extension ServerGroupsModule {
    // MARK: - View Identifiers

    /// View identifiers for the ServerGroups module
    enum Views {
        static let list = DynamicViewIdentifier(id: "servergroups.list", moduleId: "servergroups", viewType: .list)
        static let detail = DynamicViewIdentifier(id: "servergroups.detail", moduleId: "servergroups", viewType: .detail)
        static let create = DynamicViewIdentifier(id: "servergroups.create", moduleId: "servergroups", viewType: .create)

        static var all: [DynamicViewIdentifier] { [list, detail, create] }
    }

    // MARK: - Enhanced View Registration

    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            ViewMetadata(
                identifier: Views.list,
                title: "Server Groups",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .compute,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderServerGroupsList(
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
            ViewMetadata(
                identifier: Views.detail,
                title: "Server Group Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderServerGroupDetail(
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
            ViewMetadata(
                identifier: Views.create,
                title: "Create Server Group",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderServerGroupCreate(
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
                    await tui.handleServerGroupCreateInput(ch, screen: screen)
                    return true
                }
            )
        ]
    }
}
