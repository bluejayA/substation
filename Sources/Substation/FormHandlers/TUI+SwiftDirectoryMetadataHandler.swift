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

    internal func handleSwiftDirectoryMetadataInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = swiftDirectoryMetadataFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                swiftDirectoryMetadataFormState.nextField()
                swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = swiftDirectoryMetadataFormState.getCurrentField() {
                switch currentField {
                case .text:
                    if !isFieldActive {
                        // Activate text field
                        swiftDirectoryMetadataFormState.activateCurrentField()
                        swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Add space character
                        swiftDirectoryMetadataFormState.handleCharacterInput(" ")
                        swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                        await self.draw(screen: screen)
                    }
                case .checkbox:
                    // Toggle checkbox
                    swiftDirectoryMetadataFormState.toggleCurrentCheckbox()
                    swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                    await self.draw(screen: screen)
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                swiftDirectoryMetadataFormState.deactivateCurrentField()
                swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = swiftDirectoryMetadataForm.validateForm()
                if !errors.isEmpty {
                    statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                    return
                }

                await submitSwiftDirectoryMetadata(screen: screen)
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                let handled = swiftDirectoryMetadataFormState.handleSpecialKey(ch)
                if handled {
                    swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    swiftDirectoryMetadataFormState.previousField()
                } else {
                    swiftDirectoryMetadataFormState.nextField()
                }
                swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            if isFieldActive {
                swiftDirectoryMetadataFormState.cancelCurrentField()
                swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                await self.draw(screen: screen)
            } else {
                // Cancel and return to object list
                self.changeView(to: .swiftContainerDetail, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE
            if isFieldActive {
                let handled = swiftDirectoryMetadataFormState.handleSpecialKey(ch)
                if handled {
                    swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    swiftDirectoryMetadataFormState.handleCharacterInput(Character(scalar))
                    swiftDirectoryMetadataForm.updateFromFormState(swiftDirectoryMetadataFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        swiftDirectoryMetadataFormState = FormBuilderState(
            fields: swiftDirectoryMetadataForm.buildFields(
                selectedFieldId: swiftDirectoryMetadataFormState.getCurrentFieldId(),
                activeFieldId: swiftDirectoryMetadataFormState.getActiveFieldId(),
                formState: swiftDirectoryMetadataFormState
            ),
            preservingStateFrom: swiftDirectoryMetadataFormState
        )
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
