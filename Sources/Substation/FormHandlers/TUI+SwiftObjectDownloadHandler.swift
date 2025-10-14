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

    internal func handleSwiftObjectDownloadInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = swiftObjectDownloadFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                swiftObjectDownloadFormState.nextField()
                swiftObjectDownloadForm.updateFromFormState(swiftObjectDownloadFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = swiftObjectDownloadFormState.getCurrentField() {
                switch currentField {
                case .text:
                    if !isFieldActive {
                        // Activate text field
                        swiftObjectDownloadFormState.activateCurrentField()
                        swiftObjectDownloadForm.updateFromFormState(swiftObjectDownloadFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Add space character
                        swiftObjectDownloadFormState.handleCharacterInput(" ")
                        swiftObjectDownloadForm.updateFromFormState(swiftObjectDownloadFormState)
                        await self.draw(screen: screen)
                    }
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                swiftObjectDownloadFormState.deactivateCurrentField()
                swiftObjectDownloadForm.updateFromFormState(swiftObjectDownloadFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = swiftObjectDownloadForm.validateForm()
                if !errors.isEmpty {
                    statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                    return
                }

                // Check if file already exists and confirm overwrite
                if swiftObjectDownloadForm.fileExists() {
                    let confirmed = await confirmObjectOverwrite(screen: screen)
                    if !confirmed {
                        statusMessage = "Download cancelled"
                        await self.draw(screen: screen)
                        return
                    }
                }

                await submitSwiftObjectDownload(screen: screen)
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                let handled = swiftObjectDownloadFormState.handleSpecialKey(ch)
                if handled {
                    swiftObjectDownloadForm.updateFromFormState(swiftObjectDownloadFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    swiftObjectDownloadFormState.previousField()
                } else {
                    swiftObjectDownloadFormState.nextField()
                }
                swiftObjectDownloadForm.updateFromFormState(swiftObjectDownloadFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            if isFieldActive {
                swiftObjectDownloadFormState.cancelCurrentField()
                swiftObjectDownloadForm.updateFromFormState(swiftObjectDownloadFormState)
                await self.draw(screen: screen)
            } else {
                // Cancel and return to object list
                self.changeView(to: .swiftContainerDetail, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE
            if isFieldActive {
                let handled = swiftObjectDownloadFormState.handleSpecialKey(ch)
                if handled {
                    swiftObjectDownloadForm.updateFromFormState(swiftObjectDownloadFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    swiftObjectDownloadFormState.handleCharacterInput(Character(scalar))
                    swiftObjectDownloadForm.updateFromFormState(swiftObjectDownloadFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        swiftObjectDownloadFormState = FormBuilderState(
            fields: swiftObjectDownloadForm.buildFields(
                selectedFieldId: swiftObjectDownloadFormState.getCurrentFieldId(),
                activeFieldId: swiftObjectDownloadFormState.getActiveFieldId(),
                formState: swiftObjectDownloadFormState
            ),
            preservingStateFrom: swiftObjectDownloadFormState
        )
    }

    private func confirmObjectOverwrite(screen: OpaquePointer?) async -> Bool {
        let _ = SwiftTUI.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftTUI.setNodelay(WindowHandle(screen), true)
        }

        let surface = SwiftTUI.surface(from: screen)
        let promptLine = screenRows - 2
        let promptBounds = Rect(x: 0, y: promptLine, width: screenCols, height: 1)

        // Display confirmation prompt
        let promptText = " File exists. Overwrite? Press Y to confirm, any other key to cancel: "
        let promptComponent = Text(promptText).warning()

        surface.clear(rect: promptBounds)
        await SwiftTUI.render(promptComponent, on: surface, in: promptBounds)

        let ch = SwiftTUI.getInput(WindowHandle(screen))

        // Clear prompt
        surface.clear(rect: promptBounds)

        // Only Y (both uppercase and lowercase) confirms overwrite
        return ch == Int32(89) || ch == Int32(121) // 'Y' or 'y'
    }

    private func submitSwiftObjectDownload(screen: OpaquePointer?) async {
        let destinationPath = swiftObjectDownloadForm.getFinalDestinationPath()
        let containerName = swiftObjectDownloadForm.containerName
        let objectName = swiftObjectDownloadForm.objectName

        statusMessage = "Downloading object '\(objectName)'..."
        await self.draw(screen: screen)

        do {
            // Download object data
            let data = try await client.swift.downloadObject(containerName: containerName, objectName: objectName)

            // Write file
            let fileURL = URL(fileURLWithPath: destinationPath)
            try data.write(to: fileURL)

            // Return to object list with success message
            statusMessage = "Successfully downloaded object '\(objectName)' to '\(destinationPath)'"
            changeView(to: .swiftContainerDetail, resetSelection: false)
            await self.draw(screen: screen)
        } catch {
            statusMessage = "Failed to download object: \(error.localizedDescription)"
            await self.draw(screen: screen)
        }
    }
}
