// Sources/Substation/Modules/Swift/Extensions/SwiftModule+Actions.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Action Registration

extension SwiftModule {
    /// Register all Swift actions with the ActionRegistry
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register delete container action
        actions.append(ModuleActionRegistration(
            identifier: "swift.deleteContainer",
            title: "Delete Container",
            keybinding: "d",
            viewModes: [.swift],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteSwiftContainer(screen: screen)
            },
            description: "Delete the selected Swift container",
            requiresConfirmation: true,
            category: .storage
        ))

        // Register delete object action
        actions.append(ModuleActionRegistration(
            identifier: "swift.deleteObject",
            title: "Delete Object",
            keybinding: "d",
            viewModes: [.swiftContainerDetail],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteSwiftObject(screen: screen)
            },
            description: "Delete the selected Swift object or directory",
            requiresConfirmation: true,
            category: .storage
        ))

        return actions
    }
}

// MARK: - Swift Action Implementations

extension SwiftModule {
    /// Delete the selected Swift container
    ///
    /// Prompts for confirmation before deleting the container and all its objects.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteSwiftContainer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == ViewMode.swift else { return }

        let filteredContainers = tui.searchQuery?.isEmpty ?? true ? tui.cacheManager.cachedSwiftContainers : tui.cacheManager.cachedSwiftContainers.filter { container in
            container.name?.lowercased().contains(tui.searchQuery?.lowercased() ?? "") ?? false
        }

        guard tui.viewCoordinator.selectedIndex < filteredContainers.count else {
            tui.statusMessage = "No container selected"
            return
        }

        let container = filteredContainers[tui.viewCoordinator.selectedIndex]
        guard let containerName = container.name else {
            tui.statusMessage = "Container has no name"
            return
        }

        // Check if container has objects
        let objectCount = container.count
        let hasObjects = objectCount > 0

        // Show appropriate confirmation based on whether container has objects
        let confirmed: Bool
        if hasObjects {
            confirmed = await ConfirmationModal.show(
                title: "Delete Container with Objects",
                message: "Delete '\(containerName)' and all its contents?",
                details: [
                    "This container contains \(objectCount) object(s)",
                    "All objects will be deleted first",
                    "Then the container will be deleted",
                    "This action cannot be undone"
                ],
                screen: screen,
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            )
        } else {
            confirmed = await ViewUtils.confirmDelete(containerName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols)
        }

        guard confirmed else {
            tui.statusMessage = "Container deletion cancelled"
            return
        }

        // Create background operation
        let operation = SwiftBackgroundOperation(
            type: .delete,
            containerName: containerName,
            objectName: nil,
            localPath: "",
            totalBytes: 0
        )
        tui.swiftBackgroundOps.addOperation(operation)
        operation.status = SwiftBackgroundOperation.OperationStatus.queued

        // Start background deletion task
        let deleteTask = Task { @MainActor in
            await deleteContainerInBackground(containerName: containerName, hasObjects: hasObjects, objectCount: objectCount, operation: operation)
        }
        operation.task = deleteTask

        tui.statusMessage = "Container deletion started in background: \(containerName)"
        Logger.shared.logUserAction("container_delete_started", details: [
            "containerName": containerName,
            "hasObjects": hasObjects,
            "objectCount": objectCount
        ])
    }

    /// Delete the selected Swift object or directory
    ///
    /// Prompts for confirmation before deleting the object or all objects in a directory.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteSwiftObject(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == ViewMode.swiftContainerDetail else { return }
        guard let containerName = tui.viewCoordinator.swiftNavState.currentContainer else {
            tui.statusMessage = "No container selected"
            return
        }
        guard let objects = tui.cacheManager.cachedSwiftObjects else {
            tui.statusMessage = "No objects loaded"
            return
        }

        // Build tree items to determine if we're deleting a directory or object
        let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
        let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)
        let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery)

        guard tui.viewCoordinator.selectedIndex < filteredItems.count else {
            tui.statusMessage = "No item selected"
            return
        }

        let selectedItem = filteredItems[tui.viewCoordinator.selectedIndex]

        // Check if this is a directory or an object
        switch selectedItem {
        case .directory(let dirName, _, _):
            // Deleting a directory - need to delete all objects with this prefix
            let directoryPath = currentPath + dirName + "/"
            let objectsInDirectory = SwiftTreeItem.getObjectsInDirectory(
                directoryPath: directoryPath,
                allObjects: objects,
                recursive: true
            )

            guard !objectsInDirectory.isEmpty else {
                tui.statusMessage = "Directory is empty"
                return
            }

            // Confirm directory deletion
            let confirmed = await ConfirmationModal.show(
                title: "Delete Directory",
                message: "Delete '\(dirName)' and all its contents?",
                details: [
                    "This directory contains \(objectsInDirectory.count) object(s)",
                    "All objects will be deleted",
                    "This action cannot be undone"
                ],
                screen: screen,
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            )

            guard confirmed else {
                tui.statusMessage = "Directory deletion cancelled"
                return
            }

            // Create background operation for directory deletion
            let operation = SwiftBackgroundOperation(
                type: .delete,
                containerName: containerName,
                objectName: dirName,
                localPath: directoryPath,
                totalBytes: Int64(objectsInDirectory.count)
            )
            tui.swiftBackgroundOps.addOperation(operation)
            operation.status = SwiftBackgroundOperation.OperationStatus.queued

            // Start background deletion task
            let deleteTask = Task { @MainActor in
                await deleteDirectoryInBackground(
                    containerName: containerName,
                    directoryPath: directoryPath,
                    objects: objectsInDirectory,
                    operation: operation
                )
            }
            operation.task = deleteTask

            tui.statusMessage = "Directory deletion started in background: \(dirName)"
            Logger.shared.logUserAction("directory_delete_started", details: [
                "containerName": containerName,
                "directory": dirName,
                "objectCount": objectsInDirectory.count
            ])

        case .object(let swiftObject):
            // Deleting a single object
            guard let objectName = swiftObject.name else {
                tui.statusMessage = "Object has no name"
                return
            }

            guard await ViewUtils.confirmDelete(objectName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
                tui.statusMessage = "Object deletion cancelled"
                return
            }

            // Create background operation for single object deletion
            let operation = SwiftBackgroundOperation(
                type: .delete,
                containerName: containerName,
                objectName: objectName,
                localPath: "",
                totalBytes: 1
            )
            tui.swiftBackgroundOps.addOperation(operation)
            operation.status = SwiftBackgroundOperation.OperationStatus.queued

            // Start background deletion task
            let deleteTask = Task { @MainActor in
                await deleteSingleObjectInBackground(
                    containerName: containerName,
                    objectName: objectName,
                    operation: operation
                )
            }
            operation.task = deleteTask

            tui.statusMessage = "Object deletion started in background: \(objectName)"
            Logger.shared.logUserAction("object_delete_started", details: [
                "containerName": containerName,
                "objectName": objectName
            ])
        }
    }

    // MARK: - Background Operation Helpers

    /// Delete a container and its objects in the background
    ///
    /// - Parameters:
    ///   - containerName: Name of the container to delete
    ///   - hasObjects: Whether the container has objects
    ///   - objectCount: Number of objects in the container
    ///   - operation: The background operation tracking this deletion
    private func deleteContainerInBackground(containerName: String, hasObjects: Bool, objectCount: Int, operation: SwiftBackgroundOperation) async {
        guard let tui = tui else { return }
        operation.status = SwiftBackgroundOperation.OperationStatus.running

        do {
            // If container has objects, delete them first
            if hasObjects {
                // Fetch objects
                let objects = try await tui.client.swift.listObjects(containerName: containerName)
                let totalObjects = objects.count

                // Update operation total
                operation.totalBytes = Int64(totalObjects)

                var deletedCount = 0
                var failedCount = 0

                // Use TaskGroup for concurrent object deletion
                await withTaskGroup(of: (success: Bool, objectName: String).self) { group in
                    let maxConcurrentDeletes = 10
                    var objectIterator = objects.makeIterator()
                    var activeDeletes = 0

                    // Start initial batch
                    while activeDeletes < maxConcurrentDeletes, let object = objectIterator.next() {
                        guard let objectName = object.name else { continue }
                        group.addTask {
                            do {
                                try Task.checkCancellation()
                                try await tui.client.swift.deleteObject(containerName: containerName, objectName: objectName)
                                return (success: true, objectName: objectName)
                            } catch is CancellationError {
                                return (success: false, objectName: objectName)
                            } catch {
                                Logger.shared.logError("Failed to delete object '\(objectName)': \(error)")
                                return (success: false, objectName: objectName)
                            }
                        }
                        activeDeletes += 1
                    }

                    // Process results and start new deletes
                    while let result = await group.next() {
                        // Check for cancellation
                        if operation.status == SwiftBackgroundOperation.OperationStatus.cancelled {
                            group.cancelAll()
                            tui.statusMessage = "Container deletion cancelled"
                            return
                        }

                        if result.success {
                            deletedCount += 1
                        } else {
                            failedCount += 1
                        }

                        // Update progress
                        operation.progress = Double(deletedCount + failedCount) / Double(totalObjects)
                        operation.bytesTransferred = Int64(deletedCount + failedCount)
                        tui.markNeedsRedraw()

                        // Start next delete if available
                        if let object = objectIterator.next() {
                            guard let objectName = object.name else { continue }
                            group.addTask {
                                do {
                                    try Task.checkCancellation()
                                    try await tui.client.swift.deleteObject(containerName: containerName, objectName: objectName)
                                    return (success: true, objectName: objectName)
                                } catch is CancellationError {
                                    return (success: false, objectName: objectName)
                                } catch {
                                    Logger.shared.logError("Failed to delete object '\(objectName)': \(error)")
                                    return (success: false, objectName: objectName)
                                }
                            }
                        }
                    }
                }

                if failedCount > 0 {
                    Logger.shared.logWarning("Deleted \(deletedCount) objects, \(failedCount) failed")
                }
            }

            // Check for cancellation before deleting container
            if operation.status == SwiftBackgroundOperation.OperationStatus.cancelled {
                tui.statusMessage = "Container deletion cancelled"
                return
            }

            // Now delete the container
            try await tui.client.swift.deleteContainer(containerName: containerName)

            // Mark operation as completed
            operation.markCompleted()
            operation.progress = 1.0
            tui.statusMessage = "Container '\(containerName)' deleted successfully"
            tui.markNeedsRedraw()

            // Refresh container cache from server
            let containers = try await tui.client.swift.listContainers()
            tui.cacheManager.cachedSwiftContainers = containers

            Logger.shared.logUserAction("container_deleted", details: [
                "containerName": containerName,
                "objectsDeleted": operation.bytesTransferred
            ])
        } catch {
            operation.markFailed(error: error.localizedDescription)
            tui.statusMessage = "Failed to delete container '\(containerName)': \(error.localizedDescription)"
            tui.markNeedsRedraw()
            Logger.shared.logError("Container deletion failed: \(error)")
        }
    }

    /// Delete a single object in the background
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - objectName: Name of the object to delete
    ///   - operation: The background operation tracking this deletion
    private func deleteSingleObjectInBackground(containerName: String, objectName: String, operation: SwiftBackgroundOperation) async {
        guard let tui = tui else { return }
        operation.status = SwiftBackgroundOperation.OperationStatus.running

        do {
            // Check for cancellation
            if operation.status == SwiftBackgroundOperation.OperationStatus.cancelled {
                tui.statusMessage = "Object deletion cancelled"
                return
            }

            try await tui.client.swift.deleteObject(containerName: containerName, objectName: objectName)

            // Mark operation as completed
            operation.markCompleted()
            operation.progress = 1.0
            tui.statusMessage = "Object '\(objectName)' deleted successfully"
            tui.markNeedsRedraw()

            // Refresh object cache from server
            await self.fetchSwiftObjects(containerName: containerName, priority: "interactive", forceRefresh: true)

            Logger.shared.logUserAction("object_deleted", details: [
                "containerName": containerName,
                "objectName": objectName
            ])
        } catch {
            operation.markFailed(error: error.localizedDescription)
            tui.statusMessage = "Failed to delete object '\(objectName)': \(error.localizedDescription)"
            tui.markNeedsRedraw()
            Logger.shared.logError("Object deletion failed: \(error)")
        }
    }

    /// Delete a directory (all objects with prefix) in the background
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - directoryPath: Path prefix of the directory
    ///   - objects: List of objects to delete
    ///   - operation: The background operation tracking this deletion
    private func deleteDirectoryInBackground(containerName: String, directoryPath: String, objects: [SwiftObject], operation: SwiftBackgroundOperation) async {
        guard let tui = tui else { return }
        operation.status = SwiftBackgroundOperation.OperationStatus.running

        let totalObjects = objects.count
        var deletedCount = 0
        var failedCount = 0

        // Use TaskGroup for concurrent object deletion
        await withTaskGroup(of: (success: Bool, objectName: String).self) { group in
            let maxConcurrentDeletes = 10
            var objectIterator = objects.makeIterator()
            var activeDeletes = 0

            // Start initial batch
            while activeDeletes < maxConcurrentDeletes, let object = objectIterator.next() {
                guard let objectName = object.name else { continue }
                group.addTask {
                    do {
                        try Task.checkCancellation()
                        try await tui.client.swift.deleteObject(containerName: containerName, objectName: objectName)
                        return (success: true, objectName: objectName)
                    } catch is CancellationError {
                        return (success: false, objectName: objectName)
                    } catch {
                        Logger.shared.logError("Failed to delete object '\(objectName)': \(error)")
                        return (success: false, objectName: objectName)
                    }
                }
                activeDeletes += 1
            }

            // Process results and start new deletes
            while let result = await group.next() {
                // Check for cancellation
                if operation.status == SwiftBackgroundOperation.OperationStatus.cancelled {
                    group.cancelAll()
                    tui.statusMessage = "Directory deletion cancelled"
                    return
                }

                if result.success {
                    deletedCount += 1
                } else {
                    failedCount += 1
                }

                // Update progress
                operation.progress = Double(deletedCount + failedCount) / Double(totalObjects)
                operation.bytesTransferred = Int64(deletedCount + failedCount)
                tui.markNeedsRedraw()

                // Start next delete if available
                if let object = objectIterator.next() {
                    guard let objectName = object.name else { continue }
                    group.addTask {
                        do {
                            try Task.checkCancellation()
                            try await tui.client.swift.deleteObject(containerName: containerName, objectName: objectName)
                            return (success: true, objectName: objectName)
                        } catch is CancellationError {
                            return (success: false, objectName: objectName)
                        } catch {
                            Logger.shared.logError("Failed to delete object '\(objectName)': \(error)")
                            return (success: false, objectName: objectName)
                        }
                    }
                }
            }
        }

        // Mark operation as completed
        operation.markCompleted()
        operation.progress = 1.0

        if failedCount > 0 {
            tui.statusMessage = "Directory deleted with \(deletedCount) objects (\(failedCount) failed)"
        } else {
            tui.statusMessage = "Directory deleted successfully (\(deletedCount) objects)"
        }

        tui.markNeedsRedraw()

        // Refresh object cache from server
        await self.fetchSwiftObjects(containerName: containerName, priority: "interactive", forceRefresh: true)

        Logger.shared.logUserAction("directory_deleted", details: [
            "containerName": containerName,
            "directoryPath": directoryPath,
            "objectsDeleted": deletedCount,
            "objectsFailed": failedCount
        ])
    }
}
