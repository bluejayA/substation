// Sources/Substation/Modules/Magnum/Extensions/MagnumModule+Actions.swift
import Foundation
import OSClient
import SwiftNCurses

// MARK: - Action Registration

extension MagnumModule {
    /// Register all Magnum actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Cluster resize (scale workers)
    /// - Kubeconfig download
    /// - Cluster deletion
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register resize cluster action (scale workers)
        actions.append(ModuleActionRegistration(
            identifier: "cluster.resize",
            title: "Resize Cluster",
            keybinding: "r",
            viewModes: [.clusters, .clusterDetail],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.resizeCluster(screen: screen)
            },
            description: "Scale the number of worker nodes in the cluster",
            requiresConfirmation: false,
            category: .management
        ))

        // Register get kubeconfig action
        actions.append(ModuleActionRegistration(
            identifier: "cluster.kubeconfig",
            title: "Get Kubeconfig",
            keybinding: "k",
            viewModes: [.clusters, .clusterDetail],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.getKubeconfig(screen: screen)
            },
            description: "Download the kubeconfig for the cluster",
            requiresConfirmation: false,
            category: .management
        ))

        // Register delete cluster action
        actions.append(ModuleActionRegistration(
            identifier: "cluster.delete",
            title: "Delete Cluster",
            keybinding: "d",
            viewModes: [.clusters],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteClusterWithConfirmation(screen: screen)
            },
            description: "Delete the selected cluster",
            requiresConfirmation: true,
            category: .lifecycle
        ))

        // Register view cluster templates action
        actions.append(ModuleActionRegistration(
            identifier: "cluster.templates",
            title: "View Templates",
            keybinding: "t",
            viewModes: [.clusters],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.viewClusterTemplates()
            },
            description: "View cluster templates",
            requiresConfirmation: false,
            category: .general
        ))

        // Register create cluster template action (SHIFT-C on cluster templates view)
        actions.append(ModuleActionRegistration(
            identifier: "clustertemplate.create",
            title: "Create Template",
            keybinding: "C",
            viewModes: [.clusterTemplates],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.createClusterTemplate(screen: screen)
            },
            description: "Create a new cluster template",
            requiresConfirmation: false,
            category: .management
        ))

        // Register delete cluster template action
        actions.append(ModuleActionRegistration(
            identifier: "clustertemplate.delete",
            title: "Delete Template",
            keybinding: "d",
            viewModes: [.clusterTemplates],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteClusterTemplateWithConfirmation(screen: screen)
            },
            description: "Delete the selected cluster template",
            requiresConfirmation: true,
            category: .lifecycle
        ))

        return actions
    }
}

// MARK: - Action Implementations

extension MagnumModule {
    /// Resize a cluster by scaling worker nodes
    ///
    /// Opens the cluster resize view to adjust the number of worker nodes.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func resizeCluster(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Get the selected cluster
        let cluster: Cluster?

        if tui.viewCoordinator.currentView == .clusterDetail {
            cluster = tui.viewCoordinator.selectedResource as? Cluster
        } else {
            let filtered = FilterUtils.filterClusters(
                tui.cacheManager.cachedClusters,
                query: tui.searchQuery
            )
            guard tui.viewCoordinator.selectedIndex < filtered.count else {
                tui.statusMessage = "No cluster selected"
                return
            }
            cluster = filtered[tui.viewCoordinator.selectedIndex]
        }

        guard let selectedCluster = cluster else {
            tui.statusMessage = "No cluster selected"
            return
        }

        // Check if cluster is in a state that allows resizing
        if let status = selectedCluster.status?.uppercased(),
           status.contains("IN_PROGRESS") {
            tui.statusMessage = "Cannot resize cluster while operation is in progress"
            return
        }

        // Store cluster for resize view
        tui.viewCoordinator.selectedResource = selectedCluster
        tui.viewCoordinator.previousView = tui.viewCoordinator.currentView
        tui.viewCoordinator.currentView = .clusterResize

        // Initialize resize form state
        tui.clusterResizeFormState = ClusterResizeFormState(
            clusterUUID: selectedCluster.uuid,
            clusterName: selectedCluster.displayName,
            currentNodeCount: selectedCluster.nodeCount ?? 1
        )
    }

    /// Get kubeconfig for a cluster
    ///
    /// Downloads the kubeconfig and saves it to a file.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func getKubeconfig(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Get the selected cluster
        let cluster: Cluster?

        if tui.viewCoordinator.currentView == .clusterDetail {
            cluster = tui.viewCoordinator.selectedResource as? Cluster
        } else {
            let filtered = FilterUtils.filterClusters(
                tui.cacheManager.cachedClusters,
                query: tui.searchQuery
            )
            guard tui.viewCoordinator.selectedIndex < filtered.count else {
                tui.statusMessage = "No cluster selected"
                return
            }
            cluster = filtered[tui.viewCoordinator.selectedIndex]
        }

        guard let selectedCluster = cluster else {
            tui.statusMessage = "No cluster selected"
            return
        }

        // Check if cluster is ready
        guard selectedCluster.isActive else {
            tui.statusMessage = "Cluster must be active to download kubeconfig"
            return
        }

        tui.statusMessage = "Fetching kubeconfig for '\(selectedCluster.displayName)'..."

        do {
            let magnumService = await tui.client.magnum
            let kubeconfigContent = try await magnumService.getClusterConfig(id: selectedCluster.uuid)

            // Save to file
            let filename = "kubeconfig-\(selectedCluster.displayName).yaml"
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let kubeconfigPath = homeDir.appendingPathComponent(filename)

            try kubeconfigContent.write(to: kubeconfigPath, atomically: true, encoding: .utf8)

            tui.statusMessage = "Kubeconfig saved to ~/\(filename)"

            Logger.shared.logInfo("Kubeconfig downloaded for cluster", context: [
                "clusterUUID": selectedCluster.uuid,
                "clusterName": selectedCluster.displayName,
                "path": kubeconfigPath.path
            ])

        } catch {
            tui.statusMessage = "Failed to get kubeconfig: \(error.localizedDescription)"
            Logger.shared.logError("Failed to get kubeconfig: \(error)")
        }
    }

    /// Delete a cluster with confirmation dialog
    ///
    /// Shows a confirmation modal before deleting the selected cluster.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteClusterWithConfirmation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let filtered = FilterUtils.filterClusters(
            tui.cacheManager.cachedClusters,
            query: tui.searchQuery
        )

        guard tui.viewCoordinator.selectedIndex < filtered.count else {
            tui.statusMessage = "No cluster selected"
            return
        }

        let cluster = filtered[tui.viewCoordinator.selectedIndex]

        // Check if cluster is in a deletable state
        if let status = cluster.status?.uppercased(),
           status.contains("DELETE") {
            tui.statusMessage = "Cluster is already being deleted"
            return
        }

        // Show confirmation dialog
        guard await ViewUtils.confirmDelete(
            cluster.displayName,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Cluster deletion cancelled"
            return
        }

        tui.statusMessage = "Deleting cluster '\(cluster.displayName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            let magnumService = await tui.client.magnum
            try await magnumService.deleteCluster(id: cluster.uuid)

            // Update cache
            if let index = tui.cacheManager.cachedClusters.firstIndex(where: { $0.uuid == cluster.uuid }) {
                tui.cacheManager.cachedClusters.remove(at: index)
            }

            // Adjust selection index
            let newMaxIndex = max(0, filtered.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Cluster '\(cluster.displayName)' deletion initiated"
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            ViewUtils.setEnhancedStatusMessage(
                for: error,
                operation: "delete cluster",
                resourceType: "Cluster",
                resourceId: cluster.uuid,
                currentView: tui.viewCoordinator.currentView,
                enhancedErrorHandler: tui.enhancedErrorHandler,
                statusMessage: &tui.statusMessage
            )
            Logger.shared.logError("Failed to delete cluster: \(error)")
        } catch {
            tui.statusMessage = "Failed to delete cluster: \(error.localizedDescription)"
            Logger.shared.logError("Failed to delete cluster: \(error)")
        }
    }

    /// Navigate to cluster templates view
    internal func viewClusterTemplates() async {
        guard let tui = tui else { return }

        tui.viewCoordinator.previousView = tui.viewCoordinator.currentView
        tui.viewCoordinator.currentView = .clusterTemplates
        tui.viewCoordinator.selectedIndex = 0
        tui.viewCoordinator.scrollOffset = 0
    }

    /// Delete a cluster template with confirmation dialog
    ///
    /// Shows a confirmation modal before deleting the selected cluster template.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteClusterTemplateWithConfirmation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let filtered = FilterUtils.filterClusterTemplates(
            tui.cacheManager.cachedClusterTemplates,
            query: tui.searchQuery
        )

        guard tui.viewCoordinator.selectedIndex < filtered.count else {
            tui.statusMessage = "No cluster template selected"
            return
        }

        let template = filtered[tui.viewCoordinator.selectedIndex]

        // Show confirmation dialog
        guard await ViewUtils.confirmDelete(
            template.displayName,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Cluster template deletion cancelled"
            return
        }

        tui.statusMessage = "Deleting cluster template '\(template.displayName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            let magnumService = await tui.client.magnum
            try await magnumService.deleteClusterTemplate(id: template.uuid)

            // Update cache
            if let index = tui.cacheManager.cachedClusterTemplates.firstIndex(where: { $0.uuid == template.uuid }) {
                tui.cacheManager.cachedClusterTemplates.remove(at: index)
            }

            // Adjust selection index
            let newMaxIndex = max(0, filtered.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Cluster template '\(template.displayName)' deleted successfully"
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            ViewUtils.setEnhancedStatusMessage(
                for: error,
                operation: "delete cluster template",
                resourceType: "ClusterTemplate",
                resourceId: template.uuid,
                currentView: tui.viewCoordinator.currentView,
                enhancedErrorHandler: tui.enhancedErrorHandler,
                statusMessage: &tui.statusMessage
            )
            Logger.shared.logError("Failed to delete cluster template: \(error)")
        } catch {
            tui.statusMessage = "Failed to delete cluster template: \(error.localizedDescription)"
            Logger.shared.logError("Failed to delete cluster template: \(error)")
        }
    }

    /// Open the cluster template creation form
    ///
    /// Initializes the form state and navigates to the create view.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func createClusterTemplate(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Initialize the form
        let _ = tui.initializeClusterTemplateCreateForm()

        // Navigate to the create view
        tui.viewCoordinator.previousView = .clusterTemplates
        tui.viewCoordinator.currentView = .clusterTemplateCreate
    }
}
