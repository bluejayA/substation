// Sources/Substation/Modules/Flavors/Extensions/FlavorsModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Flavors module
///
/// This extension defines all view identifiers and metadata registration
/// for the Flavors module using the new ViewIdentifier system.
extension FlavorsModule {
    // MARK: - View Identifiers

    /// View identifiers for the Flavors module
    enum Views {
        /// Flavor list view
        static let list = DynamicViewIdentifier(
            id: "flavors.list",
            moduleId: "flavors",
            viewType: .list
        )

        /// Flavor detail view
        static let detail = DynamicViewIdentifier(
            id: "flavors.detail",
            moduleId: "flavors",
            viewType: .detail
        )

        /// Flavor selection view (for server creation)
        static let selection = DynamicViewIdentifier(
            id: "flavors.selection",
            moduleId: "flavors",
            viewType: .selection
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [list, detail, selection]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register all flavor views with metadata
    ///
    /// This method returns ViewMetadata for registration with the enhanced
    /// ViewRegistry system. It provides complete view information including
    /// parent views for navigation and multi-select support flags.
    ///
    /// - Returns: Array of ViewMetadata for all module views
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            // Flavors List View
            ViewMetadata(
                identifier: Views.list,
                title: "Instance Flavors",
                parentViewId: nil, // Root view
                isDetailView: false,
                supportsMultiSelect: false, // Flavors are read-only
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await self.renderFlavorsList(
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

            // Flavor Detail View
            ViewMetadata(
                identifier: Views.detail,
                title: "Flavor Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await self.renderFlavorDetail(
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

            // Flavor Selection View (for server creation)
            ViewMetadata(
                identifier: Views.selection,
                title: "Select Flavor",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await FlavorSelectionView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        flavors: tui.cacheManager.cachedFlavors,
                        workloadType: tui.serverCreateForm.workloadType,
                        flavorRecommendations: tui.serverCreateForm.flavorRecommendations,
                        selectedFlavorId: tui.serverCreateForm.selectedFlavorID,
                        selectedRecommendationIndex: tui.serverCreateForm.selectedRecommendationIndex,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        mode: tui.serverCreateForm.flavorSelectionMode,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        searchQuery: tui.searchQuery,
                        selectedCategoryIndex: tui.serverCreateForm.selectedCategoryIndex
                    )
                },
                inputHandler: nil
            )
        ]
    }
}
