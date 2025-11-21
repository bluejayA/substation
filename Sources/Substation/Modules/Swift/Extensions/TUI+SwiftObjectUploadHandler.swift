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

    /// Handle input for Swift Object Upload form using universal handler
    internal func handleSwiftObjectUploadInput(_ ch: Int32, screen: OpaquePointer?) async {
        var localFormState = swiftObjectUploadFormState
        var localForm = swiftObjectUploadForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                self.swiftObjectUploadFormState = formState
                self.swiftObjectUploadForm = form
                await self.submitSwiftObjectUpload(screen: screen)
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
        swiftObjectUploadFormState = localFormState
        swiftObjectUploadForm = localForm
    }

    private func submitSwiftObjectUpload(screen: OpaquePointer?) async {
        let filePath = swiftObjectUploadForm.filePath.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let containerName = swiftObjectUploadForm.containerName

        // Change view immediately to return to container list
        changeView(to: .swift, resetSelection: false)
        await self.draw(screen: screen)

        // Check if path is a directory
        if swiftObjectUploadForm.isDirectory() {
            startUploadDirectory(path: filePath, containerName: containerName, screen: screen)
        } else {
            startUploadFile(path: filePath, containerName: containerName, screen: screen)
        }
    }

    private func startUploadFile(path: String, containerName: String, screen: OpaquePointer?) {
        // Cancel any existing upload
        activeUploadTask?.cancel()

        let objectName = swiftObjectUploadForm.getFinalObjectName()

        // Create operation tracker BEFORE starting the task so it shows up immediately
        let operation = SwiftBackgroundOperation(
            type: .upload,
            containerName: containerName,
            objectName: objectName,
            localPath: path,
            totalBytes: 0 // Will be updated when file is read
        )
        swiftBackgroundOps.addOperation(operation)
        operation.status = .queued

        // Start background upload task
        activeUploadTask = Task { @MainActor in
            await uploadFileInBackground(path: path, containerName: containerName, operation: operation, screen: screen)
            self.activeUploadTask = nil
            self.activeUploadMessage = nil
        }

        // Store task reference for cancellation
        operation.task = activeUploadTask
    }

    private func startUploadDirectory(path: String, containerName: String, screen: OpaquePointer?) {
        // Cancel any existing upload
        activeUploadTask?.cancel()

        // Create operation tracker BEFORE starting the task so it shows up immediately
        let operation = SwiftBackgroundOperation(
            type: .upload,
            containerName: containerName,
            objectName: nil, // Directory upload - will show path
            localPath: path,
            totalBytes: 0 // Will be updated when directory is scanned
        )
        swiftBackgroundOps.addOperation(operation)
        operation.status = .queued

        // Start background upload task
        activeUploadTask = Task { @MainActor in
            await uploadDirectoryInBackground(path: path, containerName: containerName, operation: operation, screen: screen)
            self.activeUploadTask = nil
            self.activeUploadMessage = nil
        }

        // Store task reference for cancellation
        operation.task = activeUploadTask
    }

    private func uploadFileInBackground(path: String, containerName: String, operation: SwiftBackgroundOperation, screen: OpaquePointer?) async {
        let objectName = operation.objectName ?? ""

        do {
            // Read file data
            let fileURL = URL(fileURLWithPath: path)

            // Get file size information first
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: path)
            let fileSize = (fileAttributes[.size] as? Int64) ?? 0
            let fileSizeFormatted = SwiftStorageHelpers.formatFileSize(fileSize)

            // Update operation with actual file size
            operation.totalBytes = fileSize
            operation.status = .running

            // Check if object already exists with same content
            activeUploadMessage = "Checking if '\(objectName)' already exists..."
            do {
                let metadata = try await client.swift.getObjectMetadata(containerName: containerName, objectName: objectName)

                // Object exists - check if ETAGs match
                if let remoteEtag = metadata.etag {
                    let matches = try await FileHashUtility.localFileMatchesRemote(
                        localFileURL: fileURL,
                        remoteEtag: remoteEtag
                    )

                    if matches {
                        // File is identical - skip upload
                        operation.filesSkipped = 1
                        operation.markCompleted()
                        operation.progress = 1.0
                        operation.bytesTransferred = fileSize

                        activeUploadMessage = nil
                        statusMessage = "Object '\(objectName)' already up to date (skipped)"
                        return
                    }
                }
            } catch {
                // Object doesn't exist or HEAD failed - proceed with upload
                // This is not an error condition
            }

            // Show initial status in background
            activeUploadMessage = "Uploading '\(objectName)' (\(fileSizeFormatted))..."

            // Read file data for upload
            let data = try Data(contentsOf: fileURL)

            // Detect content type
            let contentType = swiftObjectUploadForm.detectContentType()

            // Create upload request
            let request = UploadSwiftObjectRequest(
                containerName: containerName,
                objectName: objectName,
                data: data,
                contentType: contentType,
                metadata: [:],
                deleteAfter: nil,
                deleteAt: nil
            )

            // Shared state for upload completion
            actor UploadState {
                var isComplete = false
                var error: (any Error)?

                func markComplete() {
                    isComplete = true
                }

                func markFailed(_ error: any Error) {
                    self.error = error
                    isComplete = true
                }

                func checkStatus() -> (complete: Bool, error: (any Error)?) {
                    return (isComplete, error)
                }
            }

            let uploadState = UploadState()

            // Run upload in background task
            let uploadTask = Task {
                do {
                    // Check for cancellation before starting
                    try Task.checkCancellation()
                    try await client.swift.uploadObject(request: request)
                    await uploadState.markComplete()
                } catch is CancellationError {
                    // Task was cancelled - do not mark as failed
                    await uploadState.markComplete()
                } catch {
                    await uploadState.markFailed(error)
                }
            }

            // Store reference to inner upload task for proper cancellation
            operation.uploadTask = uploadTask

            // Monitor upload with animated status (non-blocking)
            var elapsed: TimeInterval = 0
            let updateInterval: TimeInterval = 0.3 // 300ms

            while true {
                // Check if operation was cancelled
                if operation.status == .cancelled {
                    activeUploadMessage = nil
                    statusMessage = "Upload cancelled: \(objectName)"
                    return
                }

                let status = await uploadState.checkStatus()

                if status.complete {
                    if let error = status.error {
                        throw error
                    }
                    break
                }

                // Update animated status without blocking
                elapsed += updateInterval
                let dots = String(repeating: ".", count: (Int(elapsed * 3) % 4))
                activeUploadMessage = "Uploading '\(objectName)' (\(fileSizeFormatted))\(dots)"

                // Update operation progress (estimate based on time)
                operation.progress = min(0.9, elapsed / 10.0) // Cap at 90% until complete
                operation.bytesTransferred = Int64(Double(fileSize) * operation.progress)

                // Trigger UI redraw to update operation detail view
                markNeedsRedraw()

                // Sleep to allow UI updates and avoid busy-waiting
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            }

            // Mark operation as complete
            operation.markCompleted()
            operation.progress = 1.0
            operation.bytesTransferred = Int64(fileSize)

            // Refresh object list for the current container
            if let currentContainer = viewCoordinator.swiftNavState.currentContainer {
                await dataManager.fetchSwiftObjects(containerName: currentContainer, priority: "interactive", forceRefresh: true)
            }

            // Show success
            activeUploadMessage = nil
            statusMessage = "Object '\(objectName)' uploaded successfully"
        } catch {
            // Categorize and log error
            let transferError = TransferError.from(
                error: error,
                context: "upload",
                objectName: objectName
            )

            // Mark operation as failed
            if let operation = swiftBackgroundOps.getAllOperations().first(where: { $0.objectName == objectName }) {
                operation.markFailed(error: transferError.userFacingMessage)
            }

            activeUploadMessage = nil
            statusMessage = "Failed to upload object: \(transferError.userFacingMessage)"
        }
    }

    private func uploadDirectoryInBackground(path: String, containerName: String, operation: SwiftBackgroundOperation, screen: OpaquePointer?) async {
        let prefix = swiftObjectUploadForm.prefix.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let recursive = swiftObjectUploadForm.recursive

        operation.status = .running
        activeUploadMessage = "Scanning directory '\(path)'..."

        do {
            // Get list of files to upload
            let filesToUpload = try collectFilesToUpload(directoryPath: path, recursive: recursive)

            if filesToUpload.isEmpty {
                activeUploadMessage = nil
                statusMessage = "No files found in directory"
                return
            }

            let totalFiles = filesToUpload.count
            var successCount = 0
            var failedCount = 0
            var failedFiles: [String] = []

            // Calculate total bytes for overall progress
            var totalBytes: Int64 = 0
            for fileInfo in filesToUpload {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fileInfo.url.path),
                   let fileSize = attrs[.size] as? Int64 {
                    totalBytes += fileSize
                }
            }

            // Update operation with total size and file count
            operation.totalBytes = totalBytes
            operation.filesTotal = totalFiles

            // Progress tracking actor for concurrent uploads
            let uploadProgress = SwiftTransferProgressTracker()

            // Concurrent upload limit (avoid overwhelming the server)
            let maxConcurrentUploads = 10

            // Use TaskGroup for concurrent uploads
            await withTaskGroup(of: (success: Bool, fileName: String, bytes: Int64, skipped: Bool).self) { group in
                var fileIterator = filesToUpload.enumerated().makeIterator()
                var activeUploads = 0
                var activeFileNames: Set<String> = []

                // Start initial batch of uploads
                while activeUploads < maxConcurrentUploads, let (index, fileInfo) = fileIterator.next() {
                    await uploadProgress.fileStarted(fileInfo.relativePath)
                    activeFileNames.insert(fileInfo.relativePath)
                    group.addTask {
                        await self.uploadSingleFile(
                            fileInfo: fileInfo,
                            index: index,
                            containerName: containerName,
                            prefix: prefix,
                            client: self.client
                        )
                    }
                    activeUploads += 1
                }

                // Process results and start new uploads
                while let result = await group.next() {
                    // Check for cancellation
                    if operation.status == .cancelled {
                        group.cancelAll()
                        activeUploadMessage = nil
                        statusMessage = "Directory upload cancelled"
                        return
                    }

                    // Update progress based on result
                    activeFileNames.remove(result.fileName)
                    if result.success {
                        await uploadProgress.fileCompleted(result.fileName, bytes: result.bytes, skipped: result.skipped)
                    } else {
                        await uploadProgress.fileFailed(result.fileName)
                    }

                    // Update progress display
                    let progress = await uploadProgress.getProgress()
                    successCount = progress.completed
                    failedCount = progress.failed
                    failedFiles = progress.failedFiles

                    let uploadingList = activeFileNames.prefix(3).joined(separator: ", ")
                    let moreCount = max(0, activeFileNames.count - 3)
                    let uploadingText = moreCount > 0 ? "\(uploadingList) +\(moreCount) more" : uploadingList

                    let skipText = progress.skipped > 0 ? " (\(progress.skipped) skipped)" : ""
                    activeUploadMessage = "Uploading \(progress.completed + progress.failed)/\(totalFiles)\(skipText): \(uploadingText)"

                    // Update operation progress
                    operation.progress = Double(progress.completed + progress.failed) / Double(totalFiles)
                    operation.bytesTransferred = progress.bytes
                    operation.filesSkipped = progress.skipped
                    operation.filesCompleted = progress.completed

                    // Trigger UI redraw
                    markNeedsRedraw()

                    // Start next upload if available
                    if let (index, fileInfo) = fileIterator.next() {
                        await uploadProgress.fileStarted(fileInfo.relativePath)
                        activeFileNames.insert(fileInfo.relativePath)
                        group.addTask {
                            await self.uploadSingleFile(
                                fileInfo: fileInfo,
                                index: index,
                                containerName: containerName,
                                prefix: prefix,
                                client: self.client
                            )
                        }
                    }
                }
            }

            // Final progress update
            let finalProgress = await uploadProgress.getProgress()
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

            // Refresh object list for the current container
            if let currentContainer = viewCoordinator.swiftNavState.currentContainer {
                await dataManager.fetchSwiftObjects(containerName: currentContainer, priority: "interactive", forceRefresh: true)
            }

            // Show final status
            activeUploadMessage = nil
            let itemText = SwiftTransferProgressTracker.formatItemCount(successCount, singular: "file", plural: "files")
            let skipText = SwiftTransferProgressTracker.formatSkipMessage(skipped: skippedCount)
            if failedCount == 0 {
                statusMessage = "Successfully uploaded \(itemText)\(skipText)"
            } else {
                statusMessage = "Uploaded \(itemText)\(skipText), \(failedCount) failed: \(failedFiles.joined(separator: ", "))"
            }
        } catch {
            // Categorize error
            let transferError = TransferError.from(
                error: error,
                context: "directory upload",
                filePath: path
            )

            activeUploadMessage = nil
            statusMessage = "Failed to upload directory: \(transferError.userFacingMessage)"
        }
    }

    private func uploadSingleFile(
        fileInfo: FileToUpload,
        index: Int,
        containerName: String,
        prefix: String,
        client: OpenStackClient
    ) async -> (success: Bool, fileName: String, bytes: Int64, skipped: Bool) {
        // Build object name
        let objectName: String
        if !prefix.isEmpty {
            objectName = "\(prefix)/\(fileInfo.relativePath)"
        } else {
            objectName = fileInfo.relativePath
        }

        do {
            // Check if object already exists with same content (ETAG optimization)
            do {
                let metadata = try await client.swift.getObjectMetadata(containerName: containerName, objectName: objectName)

                // Object exists - check if ETAGs match
                if let remoteEtag = metadata.etag {
                    let matches = try await FileHashUtility.localFileMatchesRemote(
                        localFileURL: fileInfo.url,
                        remoteEtag: remoteEtag
                    )

                    if matches {
                        // File is identical - skip upload
                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileInfo.url.path)[.size] as? Int64) ?? 0
                        return (success: true, fileName: fileInfo.relativePath, bytes: fileSize, skipped: true)
                    }
                }
            } catch {
                // Object doesn't exist or HEAD failed - proceed with upload
            }

            // Read file data
            let data = try Data(contentsOf: fileInfo.url)
            let fileSize = Int64(data.count)

            // Detect content type from file extension
            let contentType = detectContentType(for: fileInfo.url)

            // Create upload request
            let request = UploadSwiftObjectRequest(
                containerName: containerName,
                objectName: objectName,
                data: data,
                contentType: contentType,
                metadata: [:],
                deleteAfter: nil,
                deleteAt: nil
            )

            // Check for cancellation before uploading
            try Task.checkCancellation()

            // Upload the file
            try await client.swift.uploadObject(request: request)

            return (success: true, fileName: fileInfo.relativePath, bytes: fileSize, skipped: false)
        } catch is CancellationError {
            // Task was cancelled - return failure but don't log error
            return (success: false, fileName: fileInfo.relativePath, bytes: 0, skipped: false)
        } catch {
            // Upload failed
            return (success: false, fileName: fileInfo.relativePath, bytes: 0, skipped: false)
        }
    }

    private struct FileToUpload {
        let url: URL
        let relativePath: String
    }

    private func collectFilesToUpload(directoryPath: String, recursive: Bool) throws -> [FileToUpload] {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directoryPath)

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        ) else {
            throw NSError(domain: "SwiftObjectUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate directory"])
        }

        var filesToUpload: [FileToUpload] = []

        for case let fileURL as URL in enumerator {
            // Get file properties
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey])

            // Skip if not a regular file
            guard resourceValues.isRegularFile == true else { continue }

            // Skip hidden files (starting with .)
            if resourceValues.isHidden == true {
                continue
            }

            // Skip files that start with . in their name
            let fileName = fileURL.lastPathComponent
            if fileName.hasPrefix(".") {
                continue
            }

            // Calculate relative path from input directory
            // If user specified /path/to/mydir, and file is /path/to/mydir/sub/file.txt
            // We want: sub/file.txt (preserve subdirectory structure within the directory)

            // Ensure base path has trailing slash for proper matching
            let basePath = directoryURL.path.hasSuffix("/") ? directoryURL.path : directoryURL.path + "/"

            // Remove base path to get relative path
            guard fileURL.path.hasPrefix(basePath) else {
                // File is not under the directory (shouldn't happen with enumerator)
                continue
            }

            let relativePath = String(fileURL.path.dropFirst(basePath.count))

            filesToUpload.append(FileToUpload(url: fileURL, relativePath: relativePath))
        }

        return filesToUpload
    }

    private func detectContentType(for url: URL) -> String? {
        return SwiftStorageHelpers.detectContentType(for: url)
    }
}

// MARK: - SwiftObjectUploadForm Protocol Conformance

// SwiftObjectUploadForm already conforms to all required protocols
extension SwiftObjectUploadForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}

