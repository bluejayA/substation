import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Swift Container Download Input Handler (Universal Pattern)

@MainActor
extension TUI {

    /// Handles input for the Swift container download form using the universal handler
    ///
    /// This handler manages the container download form which allows users to specify
    /// a destination path for downloading all objects in a Swift storage container.
    /// It supports concurrent downloads with progress tracking and includes a confirmation
    /// modal when the destination directory already exists.
    ///
    /// - Parameters:
    ///   - ch: The input character code from ncurses
    ///   - screen: The ncurses screen pointer for rendering
    internal func handleSwiftContainerDownloadInput(_ ch: Int32, screen: OpaquePointer?) async {
        var localFormState = swiftContainerDownloadFormState
        var localForm = swiftContainerDownloadForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Validation
                let errors = form.validateForm()
                if !errors.isEmpty {
                    self.statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    return
                }

                // Confirmation modal if directory exists
                if form.directoryExists() {
                    let confirmed = await ConfirmationModal.show(
                        title: "Overwrite Existing Directory",
                        message: "The target directory already exists. Do you want to overwrite the files?",
                        details: ["This action may overwrite existing files"],
                        screen: screen,
                        screenRows: self.screenRows,
                        screenCols: self.screenCols
                    )

                    if !confirmed {
                        self.statusMessage = "Download cancelled"
                        return
                    }
                }

                // Start background operation
                self.swiftContainerDownloadFormState = formState
                self.swiftContainerDownloadForm = form
                await self.submitSwiftContainerDownload(screen: screen)
            },
            onCancel: {
                self.changeView(to: .swift, resetSelection: false)
            }
        )

        // Rebuild form state to reflect any changes
        localFormState = FormBuilderState(
            fields: localForm.buildFields(
                selectedFieldId: localFormState.getCurrentFieldId(),
                activeFieldId: localFormState.getActiveFieldId(),
                formState: localFormState
            ),
            preservingStateFrom: localFormState
        )

        // Update actor-isolated properties
        swiftContainerDownloadFormState = localFormState
        swiftContainerDownloadForm = localForm
    }

    private func submitSwiftContainerDownload(screen: OpaquePointer?) async {
        let destinationPath = swiftContainerDownloadForm.getFinalDestinationPath()
        let containerName = swiftContainerDownloadForm.containerName

        // Change view immediately to return to container list
        changeView(to: .swift, resetSelection: false)
        await self.draw(screen: screen)

        // Start background download
        startDownloadContainer(destinationPath: destinationPath, containerName: containerName, screen: screen)
    }

    private func startDownloadContainer(destinationPath: String, containerName: String, screen: OpaquePointer?) {
        // Cancel any existing download
        activeDownloadTask?.cancel()

        // Create operation tracker BEFORE starting the task so it shows up immediately
        let operation = SwiftBackgroundOperation(
            type: .download,
            containerName: containerName,
            objectName: nil, // Container download - will show path
            localPath: destinationPath,
            totalBytes: 0 // Will be updated when objects are fetched
        )
        swiftBackgroundOps.addOperation(operation)
        operation.status = .queued

        // Start background download task
        activeDownloadTask = Task { @MainActor in
            await downloadContainerInBackground(destinationPath: destinationPath, containerName: containerName, operation: operation, screen: screen)
            self.activeDownloadTask = nil
            self.activeDownloadMessage = nil
        }

        // Store task reference for cancellation
        operation.task = activeDownloadTask
    }

    private func downloadContainerInBackground(destinationPath: String, containerName: String, operation: SwiftBackgroundOperation, screen: OpaquePointer?) async {
        let preserveStructure = swiftContainerDownloadForm.preserveDirectoryStructure

        operation.status = .running
        activeDownloadMessage = "Fetching objects from container '\(containerName)'..."

        do {
            // Fetch all objects in the container
            let objects = try await client.swift.listObjects(containerName: containerName)

            if objects.isEmpty {
                activeDownloadMessage = nil
                statusMessage = "Container '\(containerName)' is empty"
                operation.markCompleted()
                return
            }

            // Create destination directory
            let fileManager = FileManager.default
            try fileManager.createDirectory(atPath: destinationPath, withIntermediateDirectories: true, attributes: nil)

            let totalFiles = objects.count
            var successCount = 0
            var failedCount = 0
            var failedFiles: [String] = []

            // Calculate total bytes for overall progress
            var totalBytes: Int64 = 0
            for object in objects {
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
                var objectIterator = objects.enumerated().makeIterator()
                var activeDownloads = 0
                var activeFileNames: Set<String> = []

                // Start initial batch of downloads
                while activeDownloads < maxConcurrentDownloads, let (_, object) = objectIterator.next() {
                    guard let objectName = object.name else { continue }
                    await downloadProgress.fileStarted(objectName)
                    activeFileNames.insert(objectName)
                    group.addTask {
                        await self.downloadSingleObject(
                            objectName: objectName,
                            containerName: containerName,
                            destinationPath: destinationPath,
                            preserveStructure: preserveStructure,
                            objectBytes: Int64(object.bytes),
                            objectHash: object.hash,
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
                        statusMessage = "Container download cancelled"
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
                            await self.downloadSingleObject(
                                objectName: objectName,
                                containerName: containerName,
                                destinationPath: destinationPath,
                                preserveStructure: preserveStructure,
                                objectBytes: Int64(object.bytes),
                                objectHash: object.hash,
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
                statusMessage = "Successfully downloaded \(itemText) from '\(containerName)' to '\(destinationPath)'\(skipText)"
            } else {
                statusMessage = "Downloaded \(itemText) from '\(containerName)'\(skipText) (\(failedCount) failed: \(failedFiles.joined(separator: ", ")))"
            }
        } catch {
            // Categorize error
            let transferError = TransferError.from(
                error: error,
                context: "container download",
                filePath: destinationPath
            )

            operation.markFailed(error: transferError.userFacingMessage)
            activeDownloadMessage = nil
            statusMessage = "Failed to download container: \(transferError.userFacingMessage)"
        }
    }

    private func downloadSingleObject(
        objectName: String,
        containerName: String,
        destinationPath: String,
        preserveStructure: Bool,
        objectBytes: Int64,
        objectHash: String?,
        client: OpenStackClient
    ) async -> (success: Bool, fileName: String, bytes: Int64, skipped: Bool) {
        do {
            // Check for cancellation before downloading
            try Task.checkCancellation()

            // Determine file path based on preserve structure setting
            let fileManager = FileManager.default
            let filePath: String
            if preserveStructure && objectName.contains("/") {
                // Create subdirectories for objects with path separators
                filePath = (destinationPath as NSString).appendingPathComponent(objectName)
            } else {
                // Flatten directory structure - use only the last component
                let fileName = (objectName as NSString).lastPathComponent
                filePath = (destinationPath as NSString).appendingPathComponent(fileName)
            }

            // Check if file already exists with same content (ETAG optimization)
            if let remoteEtag = objectHash, FileManager.default.fileExists(atPath: filePath) {
                do {
                    let fileURL = URL(fileURLWithPath: filePath)
                    let matches = try await FileHashUtility.localFileMatchesRemote(
                        localFileURL: fileURL,
                        remoteEtag: remoteEtag
                    )

                    if matches {
                        // File is identical - skip download
                        return (success: true, fileName: objectName, bytes: objectBytes, skipped: true)
                    }
                } catch {
                    // Error checking local file - proceed with download
                }
            }

            // Download object data
            let data = try await client.swift.downloadObject(containerName: containerName, objectName: objectName)

            // Create subdirectory if needed
            if preserveStructure && objectName.contains("/") {
                let fileURL = URL(fileURLWithPath: filePath)
                let subdirectory = fileURL.deletingLastPathComponent().path
                try fileManager.createDirectory(atPath: subdirectory, withIntermediateDirectories: true, attributes: nil)
            }

            // Write file
            let fileURL = URL(fileURLWithPath: filePath)
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

// MARK: - SwiftContainerDownloadForm Protocol Conformance

// SwiftContainerDownloadForm naturally conforms to all three protocols through its
// existing methods: updateFromFormState, buildFields, and validateForm
extension SwiftContainerDownloadForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
