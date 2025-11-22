// Sources/Substation/Modules/KeyPairs/Extensions/KeyPairsModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the KeyPairs module
///
/// This extension defines all view identifiers and metadata registration
/// for the KeyPairs module using the new ViewIdentifier system.
extension KeyPairsModule {
    // MARK: - View Identifiers

    /// View identifiers for the KeyPairs module
    enum Views {
        /// KeyPair list view
        static let list = DynamicViewIdentifier(
            id: "keypairs.list",
            moduleId: "keypairs",
            viewType: .list
        )

        /// KeyPair detail view
        static let detail = DynamicViewIdentifier(
            id: "keypairs.detail",
            moduleId: "keypairs",
            viewType: .detail
        )

        /// KeyPair create view
        static let create = DynamicViewIdentifier(
            id: "keypairs.create",
            moduleId: "keypairs",
            viewType: .create
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [list, detail, create]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register all key pair views with metadata
    ///
    /// This method returns ViewMetadata for registration with the enhanced
    /// ViewRegistry system. It provides complete view information including
    /// parent views for navigation and multi-select support flags.
    ///
    /// - Returns: Array of ViewMetadata for all module views
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            // KeyPairs List View
            ViewMetadata(
                identifier: Views.list,
                title: "SSH KeyPairs",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await KeyPairViews.drawDetailedKeyPairList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedKeyPairs: tui.cacheManager.cachedKeyPairs,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: nil
            ),

            // KeyPair Detail View
            ViewMetadata(
                identifier: Views.detail,
                title: "KeyPair Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let keyPair = tui.viewCoordinator.selectedResource as? KeyPair else { return }
                    await KeyPairViews.drawKeyPairDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        keyPair: keyPair,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            ),

            // KeyPair Create View
            ViewMetadata(
                identifier: Views.create,
                title: "Import SSH KeyPair",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await KeyPairViews.drawKeyPairCreate(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        keyPairCreateForm: tui.keyPairCreateForm,
                        keyPairCreateFormState: tui.keyPairCreateFormState
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleKeyPairCreateInput(ch, screen: screen)
                    return true
                }
            )
        ]
    }
}
