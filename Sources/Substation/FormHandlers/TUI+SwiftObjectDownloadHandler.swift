import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses

@MainActor
extension TUI {

    /// Handle input for Swift object download form using the universal handler
    internal func handleSwiftObjectDownloadInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = swiftObjectDownloadFormState
        var localForm = swiftObjectDownloadForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.swiftObjectDownloadFormState = formState
                self.swiftObjectDownloadForm = form
                await self.confirmAndSubmitSwiftObjectDownload(screen: screen)
            },
            onCancel: {
                self.changeView(to: .swift, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        swiftObjectDownloadFormState = localFormState
        swiftObjectDownloadForm = localForm
    }

    /// Confirm and submit Swift object download
    private func confirmAndSubmitSwiftObjectDownload(screen: OpaquePointer?) async {
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

// MARK: - SwiftObjectDownloadForm Protocol Conformance

// SwiftObjectDownloadForm already has all required methods
extension SwiftObjectDownloadForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
