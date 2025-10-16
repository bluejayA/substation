import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftTUI

@MainActor
extension TUI {

    /// Handle input for Swift directory metadata form using the universal handler
    internal func handleSwiftDirectoryMetadataInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = swiftDirectoryMetadataFormState
        var localForm = swiftDirectoryMetadataForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.swiftDirectoryMetadataFormState = formState
                self.swiftDirectoryMetadataForm = form
                await self.submitSwiftDirectoryMetadata(screen: screen)
            },
            onCancel: {
                self.changeView(to: .swiftContainerDetail, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        swiftDirectoryMetadataFormState = localFormState
        swiftDirectoryMetadataForm = localForm
    }

    private func submitSwiftDirectoryMetadata(screen: OpaquePointer?) async {
        let containerName = swiftDirectoryMetadataForm.containerName
        let directoryPath = swiftDirectoryMetadataForm.directoryPath
        let recursive = swiftDirectoryMetadataForm.recursive

        // Get all objects in the container
        guard let allObjects = cachedSwiftObjects else {
            statusMessage = "Failed to load objects for container '\(containerName)'"
            await self.draw(screen: screen)
            return
        }

        // Get objects in the directory
        let objectsToUpdate = SwiftTreeItem.getObjectsInDirectory(
            directoryPath: directoryPath,
            allObjects: allObjects,
            recursive: recursive
        )

        if objectsToUpdate.isEmpty {
            statusMessage = "No objects found in directory '\(directoryPath)'"
            changeView(to: .swiftContainerDetail, resetSelection: false)
            await self.draw(screen: screen)
            return
        }

        statusMessage = "Updating metadata for \(objectsToUpdate.count) objects..."
        await self.draw(screen: screen)

        // Build update request
        let contentType = swiftDirectoryMetadataForm.contentType.trimmingCharacters(in: .whitespacesAndNewlines)

        let request = UpdateSwiftObjectMetadataRequest(
            metadata: [:],
            removeMetadataKeys: [],
            contentType: contentType.isEmpty ? nil : contentType
        )

        // Update each object
        var successCount = 0
        var failureCount = 0

        for (index, object) in objectsToUpdate.enumerated() {
            guard let objectName = object.name else {
                failureCount += 1
                continue
            }

            statusMessage = "Updating object \(index + 1) of \(objectsToUpdate.count): \(objectName)"
            await self.draw(screen: screen)

            do {
                try await client.swift.updateObjectMetadata(
                    containerName: containerName,
                    objectName: objectName,
                    request: request
                )
                successCount += 1
            } catch {
                Logger.shared.logError("Failed to update metadata for object '\(objectName)': \(error)")
                failureCount += 1
            }
        }

        // Refresh object list
        await dataManager.refreshAllData()

        // Return to object list with summary
        if failureCount == 0 {
            statusMessage = "Successfully updated \(successCount) objects"
        } else {
            statusMessage = "Updated \(successCount) objects (\(failureCount) failed)"
        }

        changeView(to: .swiftContainerDetail, resetSelection: false)
        await self.draw(screen: screen)
    }
}

// MARK: - SwiftDirectoryMetadataForm Protocol Conformance

// SwiftDirectoryMetadataForm already has all required methods
extension SwiftDirectoryMetadataForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
