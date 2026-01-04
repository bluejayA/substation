// Sources/Substation/Modules/Barbican/Extensions/BarbicanModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Barbican module
///
/// This extension defines all view identifiers and metadata registration
/// for the Barbican module using the new ViewIdentifier system.
extension BarbicanModule {
    // MARK: - View Identifiers

    /// View identifiers for the Barbican module
    enum Views {
        /// Secrets list view
        static let secrets = DynamicViewIdentifier(
            id: "barbican.secrets",
            moduleId: "barbican",
            viewType: .list
        )

        /// Secret detail view
        static let secretDetail = DynamicViewIdentifier(
            id: "barbican.secretDetail",
            moduleId: "barbican",
            viewType: .detail
        )

        /// Secret create view
        static let secretCreate = DynamicViewIdentifier(
            id: "barbican.secretCreate",
            moduleId: "barbican",
            viewType: .create
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [secrets, secretDetail, secretCreate]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register all barbican views with metadata
    ///
    /// This method returns ViewMetadata for registration with the enhanced
    /// ViewRegistry system. It provides complete view information including
    /// parent views for navigation and multi-select support flags.
    ///
    /// - Returns: Array of ViewMetadata for all module views
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            // Secrets List View
            ViewMetadata(
                identifier: Views.secrets,
                title: "Secrets",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .security,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    let secrets = tui.cacheManager.cachedSecrets
                    await BarbicanViews.drawBarbicanSecretList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        secrets: secrets,
                        searchQuery: tui.searchQuery ?? "",
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        filterCache: tui.resourceNameCache,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: nil
            ),

            // Secret Detail View
            ViewMetadata(
                identifier: Views.secretDetail,
                title: "Secret Details",
                parentViewId: Views.secrets.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .security,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let secret = tui.viewCoordinator.selectedResource as? Secret else { return }
                    await BarbicanViews.drawBarbicanSecretDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        secret: secret,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            ),

            // Secret Create View
            ViewMetadata(
                identifier: Views.secretCreate,
                title: "Create Secret",
                parentViewId: Views.secrets.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .security,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await BarbicanViews.drawBarbicanSecretCreateForm(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.barbicanSecretCreateForm,
                        formState: tui.barbicanSecretCreateFormState
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleBarbicanSecretCreateInput(ch, screen: screen)
                    return true
                }
            )
        ]
    }
}
