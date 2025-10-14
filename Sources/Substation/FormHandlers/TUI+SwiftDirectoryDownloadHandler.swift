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

    internal func handleSwiftDirectoryDownloadInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = swiftDirectoryDownloadFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                swiftDirectoryDownloadFormState.nextField()
                swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = swiftDirectoryDownloadFormState.getCurrentField() {
                switch currentField {
                case .text:
                    if !isFieldActive {
                        // Activate text field
                        swiftDirectoryDownloadFormState.activateCurrentField()
                        swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Add space character
                        swiftDirectoryDownloadFormState.handleCharacterInput(" ")
                        swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                        await self.draw(screen: screen)
                    }
                case .checkbox:
                    if !isFieldActive {
                        // Toggle checkbox
                        swiftDirectoryDownloadFormState.toggleCurrentField()
                        swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                        await self.draw(screen: screen)
                    }
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                swiftDirectoryDownloadFormState.deactivateCurrentField()
                swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = swiftDirectoryDownloadForm.validateForm()
                if !errors.isEmpty {
                    statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                    return
                }

                await submitSwiftDirectoryDownload(screen: screen)
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                let handled = swiftDirectoryDownloadFormState.handleSpecialKey(ch)
                if handled {
                    swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    swiftDirectoryDownloadFormState.previousField()
                } else {
                    swiftDirectoryDownloadFormState.nextField()
                }
                swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            if isFieldActive {
                swiftDirectoryDownloadFormState.cancelCurrentField()
                swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                await self.draw(screen: screen)
            } else {
                // Cancel and return to object list
                self.changeView(to: .swiftContainerDetail, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE
            if isFieldActive {
                let handled = swiftDirectoryDownloadFormState.handleSpecialKey(ch)
                if handled {
                    swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    swiftDirectoryDownloadFormState.handleCharacterInput(Character(scalar))
                    swiftDirectoryDownloadForm.updateFromFormState(swiftDirectoryDownloadFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        swiftDirectoryDownloadFormState = FormBuilderState(
            fields: swiftDirectoryDownloadForm.buildFields(
                selectedFieldId: swiftDirectoryDownloadFormState.getCurrentFieldId(),
                activeFieldId: swiftDirectoryDownloadFormState.getActiveFieldId(),
                formState: swiftDirectoryDownloadFormState
            ),
            preservingStateFrom: swiftDirectoryDownloadFormState
        )
    }

    private func submitSwiftDirectoryDownload(screen: OpaquePointer?) async {
        let destinationBasePath = swiftDirectoryDownloadForm.getFinalDestinationPath()
        let containerName = swiftDirectoryDownloadForm.containerName
        let directoryPath = swiftDirectoryDownloadForm.directoryPath
        let preserveStructure = swiftDirectoryDownloadForm.preserveStructure

        // Get all objects in the container
        guard let allObjects = cachedSwiftObjects else {
            statusMessage = "No objects available for download"
            await self.draw(screen: screen)
            return
        }

        // Get all objects within this directory
        let objectsToDownload = SwiftTreeItem.getObjectsInDirectory(
            directoryPath: directoryPath,
            allObjects: allObjects,
            recursive: true
        )

        if objectsToDownload.isEmpty {
            statusMessage = "No objects found in directory '\(directoryPath)'"
            await self.draw(screen: screen)
            return
        }

        let totalObjects = objectsToDownload.count
        statusMessage = "Downloading \(totalObjects) objects from directory '\(directoryPath)'..."
        await self.draw(screen: screen)

        // Create destination directory if it doesn't exist
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(atPath: destinationBasePath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            statusMessage = "Failed to create destination directory: \(error.localizedDescription)"
            await self.draw(screen: screen)
            return
        }

        // Download each object
        var successCount = 0
        var failCount = 0

        for (index, object) in objectsToDownload.enumerated() {
            guard let objectName = object.name else {
                failCount += 1
                continue
            }

            // Update progress
            statusMessage = "Downloading object \(index + 1) of \(totalObjects): \(object.fileName)"
            await self.draw(screen: screen)

            do {
                // Download object data
                let data = try await client.swift.downloadObject(containerName: containerName, objectName: objectName)

                // Determine destination path
                let destinationPath: String
                if preserveStructure {
                    // Preserve directory structure - use relative path from directory root
                    let relativePath = objectName.hasPrefix(directoryPath) ? String(objectName.dropFirst(directoryPath.count)) : objectName
                    destinationPath = "\(destinationBasePath)/\(relativePath)"

                    // Create subdirectories if needed
                    let fileURL = URL(fileURLWithPath: destinationPath)
                    let parentDirectory = fileURL.deletingLastPathComponent().path
                    try fileManager.createDirectory(atPath: parentDirectory, withIntermediateDirectories: true, attributes: nil)
                } else {
                    // Flatten structure - just use filename
                    destinationPath = "\(destinationBasePath)/\(object.fileName)"
                }

                // Write file
                let fileURL = URL(fileURLWithPath: destinationPath)
                try data.write(to: fileURL)

                successCount += 1
            } catch {
                Logger.shared.logError("Failed to download object '\(objectName)': \(error)")
                failCount += 1
            }
        }

        // Return to object list with summary
        if failCount == 0 {
            statusMessage = "Successfully downloaded \(successCount) objects to '\(destinationBasePath)'"
        } else {
            statusMessage = "Downloaded \(successCount) objects (\(failCount) failed) to '\(destinationBasePath)'"
        }
        changeView(to: .swiftContainerDetail, resetSelection: false)
        await self.draw(screen: screen)
    }
}
