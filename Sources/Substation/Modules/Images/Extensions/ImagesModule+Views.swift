// Sources/Substation/Modules/Images/Extensions/ImagesModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Images module
extension ImagesModule {
    // MARK: - View Identifiers

    /// View identifiers for the Images module
    enum Views {
        /// Image list view
        static let list = DynamicViewIdentifier(
            id: "images.list",
            moduleId: "images",
            viewType: .list
        )

        /// Image detail view
        static let detail = DynamicViewIdentifier(
            id: "images.detail",
            moduleId: "images",
            viewType: .detail
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [list, detail]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register all image views with metadata
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            // Images List View
            ViewMetadata(
                identifier: Views.list,
                title: "Images",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await ImageViews.drawDetailedImageList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedImages: tui.cacheManager.cachedImages,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: nil
            ),

            // Image Detail View
            ViewMetadata(
                identifier: Views.detail,
                title: "Image Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let image = tui.viewCoordinator.selectedResource as? Image else { return }
                    await ImageViews.drawImageDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        image: image,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            )
        ]
    }
}
