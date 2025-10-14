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

    internal func handleSwiftContainerDownloadInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = swiftContainerDownloadFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                swiftContainerDownloadFormState.nextField()
                swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = swiftContainerDownloadFormState.getCurrentField() {
                switch currentField {
                case .text:
                    if !isFieldActive {
                        // Activate text field
                        swiftContainerDownloadFormState.activateCurrentField()
                        swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Add space character
                        swiftContainerDownloadFormState.handleCharacterInput(" ")
                        swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                        await self.draw(screen: screen)
                    }
                case .checkbox:
                    if !isFieldActive {
                        // Toggle checkbox
                        swiftContainerDownloadFormState.toggleCurrentCheckbox()
                        swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                        await self.draw(screen: screen)
                    }
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                swiftContainerDownloadFormState.deactivateCurrentField()
                swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = swiftContainerDownloadForm.validateForm()
                if !errors.isEmpty {
                    statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                    return
                }

                // Check if directory already exists and confirm overwrite
                if swiftContainerDownloadForm.directoryExists() {
                    let confirmed = await confirmOverwrite(screen: screen)
                    if !confirmed {
                        statusMessage = "Download cancelled"
                        await self.draw(screen: screen)
                        return
                    }
                }

                await submitSwiftContainerDownload(screen: screen)
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                let handled = swiftContainerDownloadFormState.handleSpecialKey(ch)
                if handled {
                    swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    swiftContainerDownloadFormState.previousField()
                } else {
                    swiftContainerDownloadFormState.nextField()
                }
                swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            if isFieldActive {
                swiftContainerDownloadFormState.cancelCurrentField()
                swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                await self.draw(screen: screen)
            } else {
                // Cancel and return to container list
                self.changeView(to: .swift, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE
            if isFieldActive {
                let handled = swiftContainerDownloadFormState.handleSpecialKey(ch)
                if handled {
                    swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    swiftContainerDownloadFormState.handleCharacterInput(Character(scalar))
                    swiftContainerDownloadForm.updateFromFormState(swiftContainerDownloadFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        swiftContainerDownloadFormState = FormBuilderState(
            fields: swiftContainerDownloadForm.buildFields(
                selectedFieldId: swiftContainerDownloadFormState.getCurrentFieldId(),
                activeFieldId: swiftContainerDownloadFormState.getActiveFieldId(),
                formState: swiftContainerDownloadFormState
            ),
            preservingStateFrom: swiftContainerDownloadFormState
        )
    }

    private func confirmOverwrite(screen: OpaquePointer?) async -> Bool {
        let _ = SwiftTUI.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftTUI.setNodelay(WindowHandle(screen), true)
        }

        let surface = SwiftTUI.surface(from: screen)
        let promptLine = screenRows - 2
        let promptBounds = Rect(x: 0, y: promptLine, width: screenCols, height: 1)

        // Display confirmation prompt
        let promptText = " Directory exists. Overwrite files? Press Y to confirm, any other key to cancel: "
        let promptComponent = Text(promptText).warning()

        surface.clear(rect: promptBounds)
        await SwiftTUI.render(promptComponent, on: surface, in: promptBounds)

        let ch = SwiftTUI.getInput(WindowHandle(screen))

        // Clear prompt
        surface.clear(rect: promptBounds)

        // Only Y (both uppercase and lowercase) confirms overwrite
        return ch == Int32(89) || ch == Int32(121) // 'Y' or 'y'
    }

    private func submitSwiftContainerDownload(screen: OpaquePointer?) async {
        let destinationPath = swiftContainerDownloadForm.getFinalDestinationPath()
        let containerName = swiftContainerDownloadForm.containerName
        let preserveStructure = swiftContainerDownloadForm.preserveDirectoryStructure

        statusMessage = "Fetching objects from container '\(containerName)'..."
        await self.draw(screen: screen)

        do {
            // Fetch all objects in the container
            let objects = try await client.swift.listObjects(containerName: containerName)

            if objects.isEmpty {
                statusMessage = "Container '\(containerName)' is empty"
                changeView(to: .swift, resetSelection: false)
                await self.draw(screen: screen)
                return
            }

            // Create destination directory
            let fileManager = FileManager.default
            try fileManager.createDirectory(atPath: destinationPath, withIntermediateDirectories: true, attributes: nil)

            statusMessage = "Downloading \(objects.count) object(s) from '\(containerName)'..."
            await self.draw(screen: screen)

            var successCount = 0
            var failedCount = 0

            // Download each object
            for (index, object) in objects.enumerated() {
                guard let objectName = object.name else {
                    failedCount += 1
                    continue
                }

                // Update progress
                statusMessage = "Downloading object \(index + 1) of \(objects.count): \(objectName)"
                await self.draw(screen: screen)

                do {
                    // Download object data
                    let data = try await client.swift.downloadObject(containerName: containerName, objectName: objectName)

                    // Determine file path based on preserve structure setting
                    let filePath: String
                    if preserveStructure && objectName.contains("/") {
                        // Create subdirectories for objects with path separators
                        filePath = (destinationPath as NSString).appendingPathComponent(objectName)
                        let fileURL = URL(fileURLWithPath: filePath)
                        let subdirectory = fileURL.deletingLastPathComponent().path
                        try fileManager.createDirectory(atPath: subdirectory, withIntermediateDirectories: true, attributes: nil)
                    } else {
                        // Flatten directory structure - use only the last component
                        let fileName = (objectName as NSString).lastPathComponent
                        filePath = (destinationPath as NSString).appendingPathComponent(fileName)
                    }

                    // Write file
                    let fileURL = URL(fileURLWithPath: filePath)
                    try data.write(to: fileURL)

                    successCount += 1
                } catch {
                    failedCount += 1
                    Logger.shared.logError("Failed to download object '\(objectName)': \(error)")
                }
            }

            // Return to container list with summary
            if failedCount == 0 {
                statusMessage = "Successfully downloaded \(successCount) object(s) from '\(containerName)' to '\(destinationPath)'"
            } else {
                statusMessage = "Downloaded \(successCount) object(s) from '\(containerName)' (\(failedCount) failed)"
            }
            changeView(to: .swift, resetSelection: false)
            await self.draw(screen: screen)
        } catch {
            statusMessage = "Failed to download container: \(error.localizedDescription)"
            await self.draw(screen: screen)
        }
    }
}
