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
                    let confirmed = await ConfirmationModal.show(
                        title: "Overwrite Existing File",
                        message: "The target file already exists. Do you want to overwrite it?",
                        details: [
                            "File: \(swiftObjectDownloadForm.getFinalDestinationPath())",
                            "This action will replace the existing file"
                        ],
                        screen: screen,
                        screenRows: screenRows,
                        screenCols: screenCols
                    )

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
                // Cancel and return to container list
                self.changeView(to: .swift, resetSelection: false)
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


    private func submitSwiftObjectDownload(screen: OpaquePointer?) async {
        let destinationPath = swiftObjectDownloadForm.getFinalDestinationPath()
        let containerName = swiftObjectDownloadForm.containerName
        let objectName = swiftObjectDownloadForm.objectName

        statusMessage = "Checking object '\(objectName)'..."
        await self.draw(screen: screen)

        do {
            // Get object metadata to check ETAG
            let metadata = try await client.swift.getObjectMetadata(containerName: containerName, objectName: objectName)

            // Check if file already exists locally with same content
            let fileURL = URL(fileURLWithPath: destinationPath)
            if FileManager.default.fileExists(atPath: destinationPath), let remoteEtag = metadata.etag {
                do {
                    let matches = try await FileHashUtility.localFileMatchesRemote(
                        localFileURL: fileURL,
                        remoteEtag: remoteEtag
                    )

                    if matches {
                        // File is identical - skip download
                        statusMessage = "Object '\(objectName)' already exists with same content (skipped)"
                        changeView(to: .swift, resetSelection: false)
                        await self.draw(screen: screen)
                        return
                    }
                } catch {
                    // Error checking local file - proceed with download
                }
            }

            // Download object data
            statusMessage = "Downloading object '\(objectName)'..."
            await self.draw(screen: screen)

            let data = try await client.swift.downloadObject(containerName: containerName, objectName: objectName)

            // Write file
            try data.write(to: fileURL)

            // Return to container list with success message
            statusMessage = "Successfully downloaded object '\(objectName)' to '\(destinationPath)'"
            changeView(to: .swift, resetSelection: false)
            await self.draw(screen: screen)
        } catch {
            // Categorize error
            let transferError = TransferError.from(
                error: error,
                context: "download",
                objectName: objectName
            )

            statusMessage = "Failed to download object: \(transferError.userFacingMessage)"
            await self.draw(screen: screen)
        }
    }
}
