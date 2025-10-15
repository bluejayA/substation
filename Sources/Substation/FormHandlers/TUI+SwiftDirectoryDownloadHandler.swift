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
                // Cancel and return to container list
                self.changeView(to: .swift, resetSelection: false)
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

        // Change view immediately to return to container list
        changeView(to: .swift, resetSelection: false)
        await self.draw(screen: screen)

        // Start background download
        startDownloadDirectory(
            destinationBasePath: destinationBasePath,
            containerName: containerName,
            directoryPath: directoryPath,
            preserveStructure: preserveStructure,
            objectsToDownload: objectsToDownload,
            screen: screen
        )
    }

    private func startDownloadDirectory(
        destinationBasePath: String,
        containerName: String,
        directoryPath: String,
        preserveStructure: Bool,
        objectsToDownload: [SwiftObject],
        screen: OpaquePointer?
    ) {
        // Cancel any existing download
        activeDownloadTask?.cancel()

        // Create operation tracker BEFORE starting the task so it shows up immediately
        let operation = SwiftBackgroundOperation(
            type: .download,
            containerName: containerName,
            objectName: nil, // Directory download - will show path
            localPath: destinationBasePath,
            totalBytes: 0 // Will be updated when objects are processed
        )
        swiftBackgroundOps.addOperation(operation)
        operation.status = .queued

        // Start background download task
        activeDownloadTask = Task { @MainActor in
            await downloadDirectoryInBackground(
                destinationBasePath: destinationBasePath,
                containerName: containerName,
                directoryPath: directoryPath,
                preserveStructure: preserveStructure,
                objectsToDownload: objectsToDownload,
                operation: operation,
                screen: screen
            )
            self.activeDownloadTask = nil
            self.activeDownloadMessage = nil
        }

        // Store task reference for cancellation
        operation.task = activeDownloadTask
    }

    private func downloadDirectoryInBackground(
        destinationBasePath: String,
        containerName: String,
        directoryPath: String,
        preserveStructure: Bool,
        objectsToDownload: [SwiftObject],
        operation: SwiftBackgroundOperation,
        screen: OpaquePointer?
    ) async {
        operation.status = .running
        activeDownloadMessage = "Preparing to download \(objectsToDownload.count) objects from '\(directoryPath)'..."

        do {
            // Create destination directory if it doesn't exist
            let fileManager = FileManager.default
            try fileManager.createDirectory(atPath: destinationBasePath, withIntermediateDirectories: true, attributes: nil)

            let totalFiles = objectsToDownload.count
            var successCount = 0
            var failedCount = 0
            var failedFiles: [String] = []

            // Calculate total bytes for overall progress
            var totalBytes: Int64 = 0
            for object in objectsToDownload {
                totalBytes += Int64(object.bytes)
            }

            // Update operation with total size and file count
            operation.totalBytes = totalBytes
            operation.filesTotal = totalFiles

            // Progress tracking actor for concurrent downloads
            let downloadProgress = SwiftTransferProgressTracker()

            // Concurrent download limit (avoid overwhelming the server)
            let maxConcurrentDownloads = 10

            // Use TaskGroup for concurrent downloads
            await withTaskGroup(of: (success: Bool, fileName: String, bytes: Int64, skipped: Bool).self) { group in
                var objectIterator = objectsToDownload.enumerated().makeIterator()
                var activeDownloads = 0
                var activeFileNames: Set<String> = []

                // Start initial batch of downloads
                while activeDownloads < maxConcurrentDownloads, let (_, object) = objectIterator.next() {
                    guard let objectName = object.name else { continue }
                    await downloadProgress.fileStarted(objectName)
                    activeFileNames.insert(objectName)
                    group.addTask {
                        await self.downloadSingleDirectoryObject(
                            object: object,
                            containerName: containerName,
                            directoryPath: directoryPath,
                            destinationBasePath: destinationBasePath,
                            preserveStructure: preserveStructure,
                            client: self.client
                        )
                    }
                    activeDownloads += 1
                }

                // Process results and start new downloads
                while let result = await group.next() {
                    // Check for cancellation
                    if operation.status == .cancelled {
                        group.cancelAll()
                        activeDownloadMessage = nil
                        statusMessage = "Directory download cancelled"
                        return
                    }

                    // Update progress based on result
                    activeFileNames.remove(result.fileName)
                    if result.success {
                        await downloadProgress.fileCompleted(result.fileName, bytes: result.bytes, skipped: result.skipped)
                    } else {
                        await downloadProgress.fileFailed(result.fileName)
                    }

                    // Update progress display
                    let progress = await downloadProgress.getProgress()
                    successCount = progress.completed
                    failedCount = progress.failed
                    failedFiles = progress.failedFiles

                    let downloadingList = activeFileNames.prefix(3).joined(separator: ", ")
                    let moreCount = max(0, activeFileNames.count - 3)
                    let downloadingText = moreCount > 0 ? "\(downloadingList) +\(moreCount) more" : downloadingList

                    let skipText = progress.skipped > 0 ? " (\(progress.skipped) skipped)" : ""
                    activeDownloadMessage = "Downloading \(progress.completed + progress.failed)/\(totalFiles)\(skipText): \(downloadingText)"

                    // Update operation progress
                    operation.progress = Double(progress.completed + progress.failed) / Double(totalFiles)
                    operation.bytesTransferred = progress.bytes
                    operation.filesSkipped = progress.skipped
                    operation.filesCompleted = progress.completed

                    // Trigger UI redraw
                    markNeedsRedraw()

                    // Start next download if available
                    if let (_, object) = objectIterator.next() {
                        guard let objectName = object.name else { continue }
                        await downloadProgress.fileStarted(objectName)
                        activeFileNames.insert(objectName)
                        group.addTask {
                            await self.downloadSingleDirectoryObject(
                                object: object,
                                containerName: containerName,
                                directoryPath: directoryPath,
                                destinationBasePath: destinationBasePath,
                                preserveStructure: preserveStructure,
                                client: self.client
                            )
                        }
                    }
                }
            }

            // Final progress update
            let finalProgress = await downloadProgress.getProgress()
            successCount = finalProgress.completed
            failedCount = finalProgress.failed
            failedFiles = finalProgress.failedFiles
            let skippedCount = finalProgress.skipped

            // Update operation with final counts
            operation.filesSkipped = skippedCount
            operation.filesCompleted = successCount

            // Mark operation as complete
            operation.markCompleted()
            operation.progress = 1.0
            operation.bytesTransferred = totalBytes

            // Show final status
            activeDownloadMessage = nil
            let itemText = SwiftTransferProgressTracker.formatItemCount(successCount)
            let skipText = SwiftTransferProgressTracker.formatSkipMessage(skipped: skippedCount)
            if failedCount == 0 {
                statusMessage = "Successfully downloaded \(itemText) from '\(directoryPath)' to '\(destinationBasePath)'\(skipText)"
            } else {
                statusMessage = "Downloaded \(itemText) from '\(directoryPath)'\(skipText) (\(failedCount) failed: \(failedFiles.joined(separator: ", ")))"
            }
        } catch {
            // Categorize error
            let transferError = TransferError.from(
                error: error,
                context: "directory download",
                filePath: destinationBasePath
            )

            operation.markFailed(error: transferError.userFacingMessage)
            activeDownloadMessage = nil
            statusMessage = "Failed to download directory: \(transferError.userFacingMessage)"
        }
    }

    private func downloadSingleDirectoryObject(
        object: SwiftObject,
        containerName: String,
        directoryPath: String,
        destinationBasePath: String,
        preserveStructure: Bool,
        client: OpenStackClient
    ) async -> (success: Bool, fileName: String, bytes: Int64, skipped: Bool) {
        guard let objectName = object.name else {
            return (success: false, fileName: "", bytes: 0, skipped: false)
        }

        do {
            // Check for cancellation before downloading
            try Task.checkCancellation()

            // Determine destination path
            let fileManager = FileManager.default
            let destinationPath: String
            if preserveStructure {
                // Preserve directory structure - use relative path from directory root
                let relativePath = objectName.hasPrefix(directoryPath) ? String(objectName.dropFirst(directoryPath.count)) : objectName
                destinationPath = "\(destinationBasePath)/\(relativePath)"
            } else {
                // Flatten structure - just use filename
                destinationPath = "\(destinationBasePath)/\(object.fileName)"
            }

            // Check if file already exists with same content (ETAG optimization)
            if let remoteEtag = object.hash, FileManager.default.fileExists(atPath: destinationPath) {
                do {
                    let fileURL = URL(fileURLWithPath: destinationPath)
                    let matches = try await FileHashUtility.localFileMatchesRemote(
                        localFileURL: fileURL,
                        remoteEtag: remoteEtag
                    )

                    if matches {
                        // File is identical - skip download
                        return (success: true, fileName: objectName, bytes: Int64(object.bytes), skipped: true)
                    }
                } catch {
                    // Error checking local file - proceed with download
                }
            }

            // Download object data
            let data = try await client.swift.downloadObject(containerName: containerName, objectName: objectName)

            // Create parent directory if needed
            if preserveStructure {
                let fileURL = URL(fileURLWithPath: destinationPath)
                let parentDirectory = fileURL.deletingLastPathComponent().path
                try fileManager.createDirectory(atPath: parentDirectory, withIntermediateDirectories: true, attributes: nil)
            }

            // Write file
            let fileURL = URL(fileURLWithPath: destinationPath)
            try data.write(to: fileURL)

            return (success: true, fileName: objectName, bytes: Int64(data.count), skipped: false)
        } catch is CancellationError {
            // Task was cancelled - return failure but don't log error
            return (success: false, fileName: objectName, bytes: 0, skipped: false)
        } catch {
            // Download failed - categorize error for logging
            let transferError = TransferError.from(
                error: error,
                context: "download",
                objectName: objectName
            )
            Logger.shared.logError("Failed to download object '\(objectName)': \(transferError.userFacingMessage)")
            return (success: false, fileName: objectName, bytes: 0, skipped: false)
        }
    }
}
