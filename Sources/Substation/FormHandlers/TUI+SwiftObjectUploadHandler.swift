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

    internal func handleSwiftObjectUploadInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = swiftObjectUploadFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                swiftObjectUploadFormState.nextField()
                swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = swiftObjectUploadFormState.getCurrentField() {
                switch currentField {
                case .checkbox:
                    // Checkboxes toggle directly without activation
                    swiftObjectUploadFormState.toggleCurrentField()
                    swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                    await self.draw(screen: screen)
                case .text:
                    if !isFieldActive {
                        // Activate text field
                        swiftObjectUploadFormState.activateCurrentField()
                        swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Add space character
                        swiftObjectUploadFormState.handleCharacterInput(" ")
                        swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                        await self.draw(screen: screen)
                    }
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                swiftObjectUploadFormState.deactivateCurrentField()
                swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = swiftObjectUploadForm.validateForm()
                if !errors.isEmpty {
                    statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                    return
                }

                await submitSwiftObjectUpload(screen: screen)
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                let handled = swiftObjectUploadFormState.handleSpecialKey(ch)
                if handled {
                    swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    swiftObjectUploadFormState.previousField()
                } else {
                    swiftObjectUploadFormState.nextField()
                }
                swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            if isFieldActive {
                swiftObjectUploadFormState.cancelCurrentField()
                swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                await self.draw(screen: screen)
            } else {
                // Cancel and return to object list
                self.changeView(to: .swiftContainerDetail, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE
            if isFieldActive {
                let handled = swiftObjectUploadFormState.handleSpecialKey(ch)
                if handled {
                    swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    swiftObjectUploadFormState.handleCharacterInput(Character(scalar))
                    swiftObjectUploadForm.updateFromFormState(swiftObjectUploadFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        swiftObjectUploadFormState = FormBuilderState(
            fields: swiftObjectUploadForm.buildFields(
                selectedFieldId: swiftObjectUploadFormState.getCurrentFieldId(),
                activeFieldId: swiftObjectUploadFormState.getActiveFieldId(),
                formState: swiftObjectUploadFormState
            ),
            preservingStateFrom: swiftObjectUploadFormState
        )
    }

    private func submitSwiftObjectUpload(screen: OpaquePointer?) async {
        let filePath = swiftObjectUploadForm.filePath.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let containerName = swiftObjectUploadForm.containerName

        // Check if path is a directory
        if swiftObjectUploadForm.isDirectory() {
            await uploadDirectory(path: filePath, containerName: containerName, screen: screen)
        } else {
            await uploadFile(path: filePath, containerName: containerName, screen: screen)
        }
    }

    private func uploadFile(path: String, containerName: String, screen: OpaquePointer?) async {
        let objectName = swiftObjectUploadForm.getFinalObjectName()

        // Change view to show object list during upload
        changeView(to: .swiftContainerDetail, resetSelection: false)
        await self.draw(screen: screen)

        do {
            // Read file data
            let fileURL = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: fileURL)

            // Get file size information
            let fileSize = data.count
            let fileSizeMB = Double(fileSize) / (1024 * 1024)

            // Show initial status
            statusMessage = String(format: "Uploading '\(objectName)' (%.2f MB)...", fileSizeMB)
            await self.draw(screen: screen)

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
            Task {
                do {
                    try await client.swift.uploadObject(request: request)
                    await uploadState.markComplete()
                } catch {
                    await uploadState.markFailed(error)
                }
            }

            // Monitor upload with animated status
            var elapsed: TimeInterval = 0
            let updateInterval: TimeInterval = 0.3 // 300ms

            while true {
                let status = await uploadState.checkStatus()

                if status.complete {
                    if let error = status.error {
                        throw error
                    }
                    break
                }

                // Update animated status
                elapsed += updateInterval
                let dots = String(repeating: ".", count: (Int(elapsed * 3) % 4))
                statusMessage = String(format: "Uploading '\(objectName)' (%.2f MB)\(dots)", fileSizeMB)
                await self.draw(screen: screen)

                // Sleep to allow UI updates and avoid busy-waiting
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            }

            // Refresh object list for the current container
            if let currentContainer = swiftNavState.currentContainer {
                await dataManager.fetchSwiftObjects(containerName: currentContainer, priority: "interactive", forceRefresh: true)
            }

            // Show success
            statusMessage = "Object '\(objectName)' uploaded successfully"
            await self.draw(screen: screen)
        } catch {
            statusMessage = "Failed to upload object: \(error.localizedDescription)"
            await self.draw(screen: screen)
        }
    }

    private func drawUploadProgress(
        screen: OpaquePointer?,
        fileName: String,
        currentBytes: Int64,
        totalBytes: Int64,
        overallProgress: Double
    ) async {
        guard let screen = screen else { return }

        // Calculate display values
        let mbCurrent = Double(currentBytes) / (1024 * 1024)
        let mbTotal = Double(totalBytes) / (1024 * 1024)
        let percentage = Int(overallProgress * 100)

        // Update status message
        statusMessage = String(format: "Uploading: %d%% (%.2f MB / %.2f MB)", percentage, mbCurrent, mbTotal)

        // Create progress bar component
        let progressBarWidth = min(60, Int(screenCols) - 10)
        let progressBar = ProgressBar(
            progress: overallProgress,
            label: fileName,
            width: progressBarWidth,
            showPercentage: true
        )

        // Draw progress bar near bottom of screen
        let surface = SwiftTUI.surface(from: screen)
        let progressY = screenRows - 5
        let progressBounds = Rect(
            x: 2,
            y: progressY,
            width: screenCols - 4,
            height: 3
        )

        await SwiftTUI.render(progressBar.build(), on: surface, in: progressBounds)

        // Update the screen immediately
        SwiftTUI.doupdate()

        // Also trigger a full redraw to ensure visibility
        await self.draw(screen: screen)
    }

    private func uploadDirectory(path: String, containerName: String, screen: OpaquePointer?) async {
        let prefix = swiftObjectUploadForm.prefix.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let recursive = swiftObjectUploadForm.recursive

        statusMessage = "Scanning directory '\(path)'..."
        await self.draw(screen: screen)

        do {
            // Get list of files to upload
            let filesToUpload = try collectFilesToUpload(directoryPath: path, recursive: recursive)

            if filesToUpload.isEmpty {
                statusMessage = "No files found in directory"
                await self.draw(screen: screen)
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

            // Upload each file with progress tracking
            for (index, fileInfo) in filesToUpload.enumerated() {
                let currentFile = index + 1

                // Build object name
                let objectName: String
                if !prefix.isEmpty {
                    objectName = "\(prefix)/\(fileInfo.relativePath)"
                } else {
                    objectName = fileInfo.relativePath
                }

                do {
                    // Read file data
                    let data = try Data(contentsOf: fileInfo.url)
                    let fileSize = Int64(data.count)

                    // Show progress for this file
                    statusMessage = "Uploading file \(currentFile) of \(totalFiles): \(fileInfo.relativePath)"

                    // Draw multi-file progress
                    await drawMultiFileProgress(
                        screen: screen,
                        currentFile: currentFile,
                        totalFiles: totalFiles,
                        currentFileName: fileInfo.relativePath,
                        currentFileBytes: fileSize,
                        totalBytes: totalBytes
                    )

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

                    // Upload with background task and status updates
                    actor FileUploadState {
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

                    let uploadState = FileUploadState()

                    // Run upload in background
                    Task {
                        do {
                            try await client.swift.uploadObject(request: request)
                            await uploadState.markComplete()
                        } catch {
                            await uploadState.markFailed(error)
                        }
                    }

                    // Monitor upload with animated status
                    var elapsed: TimeInterval = 0
                    let updateInterval: TimeInterval = 0.3

                    while true {
                        let status = await uploadState.checkStatus()

                        if status.complete {
                            if let error = status.error {
                                throw error
                            }
                            break
                        }

                        // Update animated status
                        elapsed += updateInterval
                        let dots = String(repeating: ".", count: (Int(elapsed * 3) % 4))
                        statusMessage = "Uploading \(currentFile)/\(totalFiles): \(fileInfo.relativePath)\(dots)"
                        await self.draw(screen: screen)

                        try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                    }

                    successCount += 1
                } catch {
                    failedCount += 1
                    failedFiles.append(fileInfo.relativePath)
                }
            }

            // Refresh object list for the current container
            if let currentContainer = swiftNavState.currentContainer {
                await dataManager.fetchSwiftObjects(containerName: currentContainer, priority: "interactive", forceRefresh: true)
            }

            // Show final status
            if failedCount == 0 {
                statusMessage = "Successfully uploaded \(successCount) files"
            } else {
                statusMessage = "Uploaded \(successCount) files, \(failedCount) failed: \(failedFiles.joined(separator: ", "))"
            }

            // Return to object list
            changeView(to: .swiftContainerDetail, resetSelection: false)
            await self.draw(screen: screen)
        } catch {
            statusMessage = "Failed to upload directory: \(error.localizedDescription)"
            await self.draw(screen: screen)
        }
    }

    private func drawMultiFileProgress(
        screen: OpaquePointer?,
        currentFile: Int,
        totalFiles: Int,
        currentFileName: String,
        currentFileBytes: Int64,
        totalBytes: Int64
    ) async {
        guard let screen = screen else { return }

        // Create file progress info
        let fileInfo = FileProgressInfo(
            currentFile: currentFile,
            totalFiles: totalFiles,
            currentFileName: currentFileName,
            currentFileBytes: currentFileBytes,
            totalBytes: totalBytes
        )

        // Create multi-file progress bar component
        let progressBarWidth = min(60, Int(screenCols) - 10)
        let progressBar = MultiFileProgressBar(
            fileInfo: fileInfo,
            width: progressBarWidth
        )

        // Draw progress bar near bottom of screen
        let surface = SwiftTUI.surface(from: screen)
        let progressY = screenRows - 7
        let progressBounds = Rect(
            x: 2,
            y: progressY,
            width: screenCols - 4,
            height: 5
        )

        await SwiftTUI.render(progressBar.build(), on: surface, in: progressBounds)

        // Update the screen
        SwiftTUI.doupdate()
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
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "txt": return "text/plain"
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "zip": return "application/zip"
        case "tar": return "application/x-tar"
        case "gz": return "application/gzip"
        case "mp3": return "audio/mpeg"
        case "mp4": return "video/mp4"
        case "avi": return "video/x-msvideo"
        default: return "application/octet-stream"
        }
    }
}
