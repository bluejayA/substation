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

            // Optimistic cache update - remove deleted object from cache immediately
            await tui.cacheManager.removeSwiftObject(withName: objectName, forContainer: containerName)

            // Adjust selection if we deleted the last item
            if let objects = tui.cacheManager.cachedSwiftObjects {
                let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
                let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)
                let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery)
                if tui.viewCoordinator.selectedIndex >= filteredItems.count && filteredItems.count > 0 {
                    tui.viewCoordinator.selectedIndex = filteredItems.count - 1
                } else if filteredItems.isEmpty {
                    tui.viewCoordinator.selectedIndex = 0
                }
            }

            tui.markNeedsRedraw()

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

        // Optimistic cache update - remove all deleted objects from cache
        let deletedObjectNames = Set(objects.compactMap { $0.name })
        await tui.cacheManager.removeSwiftObjects(withNames: deletedObjectNames, forContainer: containerName)

        // Adjust selection if we deleted items
        if let cachedObjects = tui.cacheManager.cachedSwiftObjects {
            let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: cachedObjects, currentPath: currentPath)
            let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery)
            if tui.viewCoordinator.selectedIndex >= filteredItems.count && filteredItems.count > 0 {
                tui.viewCoordinator.selectedIndex = filteredItems.count - 1
            } else if filteredItems.isEmpty {
                tui.viewCoordinator.selectedIndex = 0
            }
        }

        tui.markNeedsRedraw()

        Logger.shared.logUserAction("directory_deleted", details: [
            "containerName": containerName,
            "directoryPath": directoryPath,
            "objectsDeleted": deletedCount,
            "objectsFailed": failedCount
        ])
    }
}

// MARK: - Swift View Input Handlers

extension SwiftModule {
    /// Show container metadata in a detail view
    ///
    /// - Parameters:
    ///   - container: The container to show metadata for
    ///   - screen: The ncurses screen pointer
    internal func showContainerMetadata(container: SwiftContainer, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard let containerName = container.name else {
            tui.statusMessage = "Invalid container"
            return
        }

        // Fetch container metadata
        var metadata: SwiftContainerMetadataResponse? = nil
        do {
            metadata = try await tui.client.swift.getContainerMetadata(containerName: containerName)
        } catch {
            Logger.shared.logDebug("Failed to fetch container metadata: \(error.localizedDescription)")
        }

        // Build sections for detail view
        var sections: [DetailSection] = []

        // Basic info section
        var basicItems: [DetailItem] = [
            .field(label: "Name", value: containerName)
        ]
        basicItems.append(.field(label: "Object Count", value: "\(container.count)"))
        let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(container.bytes), countStyle: .file)
        basicItems.append(.field(label: "Total Size", value: formattedSize))
        sections.append(DetailSection(title: "Container Information", items: basicItems))

        // Metadata section if available
        if let meta = metadata {
            var metaItems: [DetailItem] = []
            if let readACL = meta.readACL, !readACL.isEmpty {
                metaItems.append(.field(label: "Read ACL", value: readACL))
            }
            if let writeACL = meta.writeACL, !writeACL.isEmpty {
                metaItems.append(.field(label: "Write ACL", value: writeACL))
            }
            if !metaItems.isEmpty {
                sections.append(DetailSection(title: "Access Control", items: metaItems))
            }

            // Custom metadata from metadata dictionary
            if !meta.metadata.isEmpty {
                var customItems: [DetailItem] = []
                for (key, value) in meta.metadata.sorted(by: { $0.key < $1.key }) {
                    customItems.append(.field(label: key, value: value))
                }
                sections.append(DetailSection(title: "Custom Metadata", items: customItems))
            }
        }

        // Show detail view
        let detailView = DetailView(
            title: "Container: \(containerName)",
            sections: sections,
            helpText: "Press ESC or ENTER to close"
        )

        // Draw the detail view
        await detailView.draw(
            screen: screen,
            startRow: 2,
            startCol: 2,
            width: tui.screenCols - 4,
            height: tui.screenRows - 4
        )
        SwiftNCurses.refresh(WindowHandle(screen))

        // Wait for user to dismiss
        var done = false
        while !done {
            let ch = SwiftNCurses.getInput(WindowHandle(screen))
            if ch == 27 || ch == 10 || ch == Int32(UInt8(ascii: "q")) {  // ESC, ENTER, or q
                done = true
            }
        }

        // Redraw the main view
        tui.renderCoordinator.needsRedraw = true
        await tui.draw(screen: screen)
    }

    /// Handle web access management for the selected container
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func handleManageContainerWebAccess(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .swift else { return }

        // Filter containers based on search query to match displayed list
        let filteredContainers: [SwiftContainer]
        if let query = tui.searchQuery, !query.isEmpty {
            filteredContainers = tui.cacheManager.cachedSwiftContainers.filter {
                $0.name?.localizedCaseInsensitiveContains(query) ?? false
            }
        } else {
            filteredContainers = tui.cacheManager.cachedSwiftContainers
        }

        guard tui.viewCoordinator.selectedIndex < filteredContainers.count else {
            tui.statusMessage = "No container selected"
            return
        }

        let container = filteredContainers[tui.viewCoordinator.selectedIndex]
        guard let containerName = container.name else {
            tui.statusMessage = "Invalid container"
            return
        }

        // Fetch current metadata to check web access status
        do {
            let metadata = try await tui.client.swift.getContainerMetadata(containerName: containerName)

            // Get Swift storage URL
            let swiftEndpoint: String
            do {
                swiftEndpoint = try await tui.client.coreClient.getEndpoint(for: "object-store")
            } catch {
                tui.statusMessage = "Could not determine Swift endpoint"
                return
            }

            // Load form with metadata and endpoint
            tui.swiftContainerWebAccessForm.loadFromMetadata(metadata, swiftEndpoint: swiftEndpoint)

            // Initialize form state
            tui.swiftContainerWebAccessFormState = FormBuilderState(
                fields: tui.swiftContainerWebAccessForm.buildFields(
                    selectedFieldId: "webAccessEnabled",
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )

            // Navigate to web access form
            tui.changeView(to: .swiftContainerWebAccess, resetSelection: false)
        } catch {
            tui.statusMessage = "Failed to load web access form: \(error.localizedDescription)"
        }
    }

    /// Handle metadata management for the selected container
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func handleManageContainerMetadata(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .swift else { return }

        // Filter containers based on search query to match displayed list
        let filteredContainers: [SwiftContainer]
        if let query = tui.searchQuery, !query.isEmpty {
            filteredContainers = tui.cacheManager.cachedSwiftContainers.filter {
                $0.name?.localizedCaseInsensitiveContains(query) ?? false
            }
        } else {
            filteredContainers = tui.cacheManager.cachedSwiftContainers
        }

        guard tui.viewCoordinator.selectedIndex < filteredContainers.count else {
            tui.statusMessage = "No container selected"
            return
        }

        let container = filteredContainers[tui.viewCoordinator.selectedIndex]
        guard let containerName = container.name else {
            tui.statusMessage = "Invalid container"
            return
        }

        // Fetch current metadata
        do {
            let metadata = try await tui.client.swift.getContainerMetadata(containerName: containerName)

            // Initialize form with current metadata
            tui.swiftContainerMetadataForm = SwiftContainerMetadataForm()
            tui.swiftContainerMetadataForm.loadFromMetadata(metadata)

            // Initialize form state
            tui.swiftContainerMetadataFormState = FormBuilderState(
                fields: tui.swiftContainerMetadataForm.buildFields(
                    selectedFieldId: "readACL",
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )

            // Navigate to metadata form
            tui.changeView(to: .swiftContainerMetadata, resetSelection: false)
        } catch {
            tui.statusMessage = "Failed to load metadata: \(error.localizedDescription)"
        }
    }

    /// Handle metadata management for tree items (objects and directories)
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func handleSwiftTreeItemMetadata(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .swiftContainerDetail else { return }

        guard let containerName = tui.viewCoordinator.swiftNavState.currentContainer else {
            tui.statusMessage = "No container selected"
            return
        }

        guard let allObjects = tui.cacheManager.cachedSwiftObjects else {
            tui.statusMessage = "No objects loaded"
            return
        }

        // Build tree from objects
        let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
        let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)

        guard tui.viewCoordinator.selectedIndex < treeItems.count else {
            tui.statusMessage = "No item selected"
            return
        }

        let selectedItem = treeItems[tui.viewCoordinator.selectedIndex]

        switch selectedItem {
        case .object(let object):
            // Handle individual object metadata
            guard let objectName = object.name else {
                tui.statusMessage = "Invalid object"
                return
            }

            // Fetch current metadata
            do {
                let metadata = try await tui.client.swift.getObjectMetadata(
                    containerName: containerName,
                    objectName: objectName
                )

                // Initialize form with current metadata
                tui.swiftObjectMetadataForm = SwiftObjectMetadataForm()
                tui.swiftObjectMetadataForm.loadFromMetadata(containerName: containerName, metadata: metadata)

                // Initialize form state
                tui.swiftObjectMetadataFormState = FormBuilderState(
                    fields: tui.swiftObjectMetadataForm.buildFields(
                        selectedFieldId: "contentType",
                        activeFieldId: nil,
                        formState: FormBuilderState(fields: [])
                    )
                )

                // Navigate to metadata form
                tui.changeView(to: .swiftObjectMetadata, resetSelection: false)
            } catch {
                tui.statusMessage = "Failed to load metadata: \(error.localizedDescription)"
            }

        case .directory(let name, _, _):
            // Handle directory metadata (bulk update)
            let fullDirectoryPath = currentPath + name + "/"

            // Initialize directory metadata form
            tui.swiftDirectoryMetadataForm = SwiftDirectoryMetadataForm()
            tui.swiftDirectoryMetadataForm.initializeForDirectory(
                containerName: containerName,
                directoryPath: fullDirectoryPath
            )

            // Initialize form state
            tui.swiftDirectoryMetadataFormState = FormBuilderState(
                fields: tui.swiftDirectoryMetadataForm.buildFields(
                    selectedFieldId: "contentType",
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )

            // Navigate to directory metadata form
            tui.changeView(to: .swiftDirectoryMetadata, resetSelection: false)
        }
    }

    /// Handle upload object to container
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func handleUploadObjectToContainer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let containerName: String

        if tui.viewCoordinator.currentView == .swift {
            // Called from container list - get selected container
            // Filter containers based on search query to match displayed list
            let filteredContainers: [SwiftContainer]
            if let query = tui.searchQuery, !query.isEmpty {
                filteredContainers = tui.cacheManager.cachedSwiftContainers.filter {
                    $0.name?.localizedCaseInsensitiveContains(query) ?? false
                }
            } else {
                filteredContainers = tui.cacheManager.cachedSwiftContainers
            }

            guard tui.viewCoordinator.selectedIndex < filteredContainers.count else {
                tui.statusMessage = "No container selected"
                return
            }

            let container = filteredContainers[tui.viewCoordinator.selectedIndex]
            guard let name = container.name else {
                tui.statusMessage = "Invalid container"
                return
            }
            containerName = name

        } else if tui.viewCoordinator.currentView == .swiftContainerDetail {
            // Called from inside a container - use current container from navigation state
            guard let currentContainer = tui.viewCoordinator.swiftNavState.currentContainer else {
                tui.statusMessage = "No container context"
                return
            }
            containerName = currentContainer

        } else {
            tui.statusMessage = "Upload not available from this view"
            return
        }

        // Initialize upload form
        tui.swiftObjectUploadForm = SwiftObjectUploadForm()
        tui.swiftObjectUploadForm.containerName = containerName

        // Initialize form state
        tui.swiftObjectUploadFormState = FormBuilderState(
            fields: tui.swiftObjectUploadForm.buildFields(
                selectedFieldId: "filePath",
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            )
        )

        // Navigate to upload form
        tui.changeView(to: .swiftObjectUpload, resetSelection: false)
    }

    /// Handle download container
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func handleDownloadContainer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .swift else { return }

        // Filter containers based on search query to match displayed list
        let filteredContainers: [SwiftContainer]
        if let query = tui.searchQuery, !query.isEmpty {
            filteredContainers = tui.cacheManager.cachedSwiftContainers.filter {
                $0.name?.localizedCaseInsensitiveContains(query) ?? false
            }
        } else {
            filteredContainers = tui.cacheManager.cachedSwiftContainers
        }

        guard tui.viewCoordinator.selectedIndex < filteredContainers.count else {
            tui.statusMessage = "No container selected"
            return
        }

        let container = filteredContainers[tui.viewCoordinator.selectedIndex]
        guard let containerName = container.name else {
            tui.statusMessage = "Invalid container"
            return
        }

        // Initialize download form
        tui.swiftContainerDownloadForm = SwiftContainerDownloadForm()
        tui.swiftContainerDownloadForm.containerName = containerName
        tui.swiftContainerDownloadForm.destinationPath = "./\(containerName)/"

        // Initialize form state
        tui.swiftContainerDownloadFormState = FormBuilderState(
            fields: tui.swiftContainerDownloadForm.buildFields(
                selectedFieldId: "destinationPath",
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            )
        )

        // Navigate to download form
        tui.changeView(to: .swiftContainerDownload, resetSelection: false)
    }

    /// Handle download object or directory
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func handleDownloadObject(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .swiftContainerDetail else { return }

        guard let containerName = tui.viewCoordinator.swiftNavState.currentContainer else {
            tui.statusMessage = "No container selected"
            return
        }

        guard let allObjects = tui.cacheManager.cachedSwiftObjects else {
            tui.statusMessage = "No objects loaded"
            return
        }

        // Build tree from objects
        let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
        let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)

        // Apply search filter if present
        let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery?.isEmpty ?? true ? nil : tui.searchQuery)

        guard tui.viewCoordinator.selectedIndex < filteredItems.count else {
            tui.statusMessage = "No item selected"
            return
        }

        let selectedItem = filteredItems[tui.viewCoordinator.selectedIndex]

        switch selectedItem {
        case .object(let object):
            // Download single object
            guard let objectName = object.name else {
                tui.statusMessage = "Invalid object"
                return
            }

            // Extract just the filename from the full path
            let fileName: String
            if let lastSlash = objectName.lastIndex(of: "/") {
                fileName = String(objectName[objectName.index(after: lastSlash)...])
            } else {
                fileName = objectName
            }

            // Initialize download form
            tui.swiftObjectDownloadForm = SwiftObjectDownloadForm()
            tui.swiftObjectDownloadForm.containerName = containerName
            tui.swiftObjectDownloadForm.objectName = objectName
            tui.swiftObjectDownloadForm.destinationPath = "./\(fileName)"

            // Initialize form state
            tui.swiftObjectDownloadFormState = FormBuilderState(
                fields: tui.swiftObjectDownloadForm.buildFields(
                    selectedFieldId: "destinationPath",
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )

            // Navigate to object download form
            tui.changeView(to: .swiftObjectDownload, resetSelection: false)

        case .directory(let directoryName, _, _):
            // Download entire directory
            let fullDirectoryPath = currentPath + directoryName + "/"

            // Initialize directory download form
            tui.swiftDirectoryDownloadForm = SwiftDirectoryDownloadForm()
            tui.swiftDirectoryDownloadForm.containerName = containerName
            tui.swiftDirectoryDownloadForm.directoryPath = fullDirectoryPath
            tui.swiftDirectoryDownloadForm.destinationPath = "./\(directoryName)/"
            tui.swiftDirectoryDownloadForm.preserveStructure = true

            // Initialize form state
            tui.swiftDirectoryDownloadFormState = FormBuilderState(
                fields: tui.swiftDirectoryDownloadForm.buildFields(
                    selectedFieldId: "destinationPath",
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )

            // Navigate to directory download form
            tui.changeView(to: .swiftDirectoryDownload, resetSelection: false)
        }
    }
}
