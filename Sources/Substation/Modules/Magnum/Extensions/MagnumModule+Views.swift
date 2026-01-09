// Sources/Substation/Modules/Magnum/Extensions/MagnumModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Magnum module
extension MagnumModule {
    // MARK: - View Identifiers

    /// View identifiers for the Magnum module
    enum Views {
        /// Cluster list view
        static let clusters = DynamicViewIdentifier(
            id: "magnum.clusters",
            moduleId: "magnum",
            viewType: .list
        )

        /// Cluster detail view
        static let clusterDetail = DynamicViewIdentifier(
            id: "magnum.clusterDetail",
            moduleId: "magnum",
            viewType: .detail
        )

        /// Cluster template list view
        static let clusterTemplates = DynamicViewIdentifier(
            id: "magnum.clusterTemplates",
            moduleId: "magnum",
            viewType: .list
        )

        /// Cluster template detail view
        static let clusterTemplateDetail = DynamicViewIdentifier(
            id: "magnum.clusterTemplateDetail",
            moduleId: "magnum",
            viewType: .detail
        )

        /// Cluster create view
        static let clusterCreate = DynamicViewIdentifier(
            id: "magnum.clusterCreate",
            moduleId: "magnum",
            viewType: .create
        )

        /// Cluster resize view
        static let clusterResize = DynamicViewIdentifier(
            id: "magnum.clusterResize",
            moduleId: "magnum",
            viewType: .detail
        )

        /// Cluster template create view
        static let clusterTemplateCreate = DynamicViewIdentifier(
            id: "magnum.clusterTemplateCreate",
            moduleId: "magnum",
            viewType: .create
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [clusters, clusterDetail, clusterTemplates, clusterTemplateDetail,
                    clusterCreate, clusterResize, clusterTemplateCreate]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register all Magnum views with metadata
    ///
    /// - Returns: Array of view metadata for registration
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            // Clusters List View
            ViewMetadata(
                identifier: Views.clusters,
                title: "Clusters",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await MagnumViews.drawClusterList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedClusters: tui.cacheManager.cachedClusters,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: nil
            ),

            // Cluster Detail View
            ViewMetadata(
                identifier: Views.clusterDetail,
                title: "Cluster Details",
                parentViewId: Views.clusters.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let cluster = tui.viewCoordinator.selectedResource as? Cluster else { return }
                    // Get nodegroups for this cluster
                    let nodegroups = tui.cacheManager.cachedNodegroups.filter {
                        $0.clusterUuid == cluster.uuid
                    }
                    // Get the cluster template
                    let clusterTemplate = tui.cacheManager.cachedClusterTemplates.first {
                        $0.uuid == cluster.clusterTemplateId
                    }
                    await MagnumViews.drawClusterDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cluster: cluster,
                        nodegroups: nodegroups,
                        clusterTemplate: clusterTemplate,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            ),

            // Cluster Templates List View
            ViewMetadata(
                identifier: Views.clusterTemplates,
                title: "Cluster Templates",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await MagnumViews.drawClusterTemplateList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedTemplates: tui.cacheManager.cachedClusterTemplates,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex
                    )
                },
                inputHandler: nil
            ),

            // Cluster Template Detail View
            ViewMetadata(
                identifier: Views.clusterTemplateDetail,
                title: "Template Details",
                parentViewId: Views.clusterTemplates.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let template = tui.viewCoordinator.selectedResource as? ClusterTemplate else { return }
                    await MagnumViews.drawClusterTemplateDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        template: template,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            ),

            // Cluster Create View
            ViewMetadata(
                identifier: Views.clusterCreate,
                title: "Create Cluster",
                parentViewId: Views.clusters.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await ClusterCreateView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.clusterCreateForm,
                        formState: tui.clusterCreateFormState
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return true }
                    await tui.handleClusterCreateInput(ch, screen: screen)
                    return true
                }
            ),

            // Cluster Resize View
            ViewMetadata(
                identifier: Views.clusterResize,
                title: "Resize Cluster",
                parentViewId: Views.clusterDetail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let resizeState = tui.clusterResizeFormState else { return }
                    await MagnumViews.drawClusterResizeForm(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        resizeState: resizeState
                    )
                },
                inputHandler: { [weak self, weak tui] ch, screen in
                    guard let self = self, let tui = tui else { return true }
                    return await self.handleClusterResizeInput(ch, screen: screen, tui: tui)
                }
            ),

            // Cluster Template Create View
            ViewMetadata(
                identifier: Views.clusterTemplateCreate,
                title: "Create Cluster Template",
                parentViewId: Views.clusterTemplates.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await ClusterTemplateCreateView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.clusterTemplateCreateForm,
                        formState: tui.clusterTemplateCreateFormState
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return true }
                    await tui.handleClusterTemplateCreateInput(ch, screen: screen)
                    return true
                }
            )
        ]
    }
}
