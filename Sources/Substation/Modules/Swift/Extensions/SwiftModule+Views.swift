// Sources/Substation/Modules/Swift/Extensions/SwiftModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Swift module
extension SwiftModule {
    // MARK: - View Identifiers

    /// View identifiers for the Swift module
    enum Views {
        static let containers = DynamicViewIdentifier(id: "swift.containers", moduleId: "swift", viewType: .list)
        static let containerDetail = DynamicViewIdentifier(id: "swift.containerDetail", moduleId: "swift", viewType: .detail)
        static let objectDetail = DynamicViewIdentifier(id: "swift.objectDetail", moduleId: "swift", viewType: .detail)
        static let containerCreate = DynamicViewIdentifier(id: "swift.containerCreate", moduleId: "swift", viewType: .create)
        static let objectUpload = DynamicViewIdentifier(id: "swift.objectUpload", moduleId: "swift", viewType: .create)
        static let backgroundOperations = DynamicViewIdentifier(id: "swift.backgroundOperations", moduleId: "swift", viewType: .list)
        static let backgroundOperationDetail = DynamicViewIdentifier(id: "swift.backgroundOperationDetail", moduleId: "swift", viewType: .detail)

        static var all: [DynamicViewIdentifier] {
            [containers, containerDetail, objectDetail, containerCreate, objectUpload, backgroundOperations, backgroundOperationDetail]
        }
    }

    // MARK: - Enhanced View Registration

    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            ViewMetadata(
                identifier: Views.containers,
                title: "Swift Containers",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerListView(
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
                identifier: Views.containerDetail,
                title: "Container Details",
                parentViewId: Views.containers.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerDetailView(
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
                identifier: Views.objectDetail,
                title: "Object Details",
                parentViewId: Views.containerDetail.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftObjectDetailView(
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
                identifier: Views.containerCreate,
                title: "Create Container",
                parentViewId: Views.containers.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
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
                }
            ),
            ViewMetadata(
                identifier: Views.backgroundOperations,
                title: "Background Operations",
                parentViewId: Views.containers.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftBackgroundOperationsView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: nil
            )
        ]
    }
}
