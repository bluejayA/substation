import Foundation

/// Result structure for transfer progress queries
struct TransferProgress: Sendable {
    let completed: Int
    let failed: Int
    let skipped: Int
    let bytes: Int64
    let failedFiles: [String]
    let active: Set<String>
    let errorSummary: [String: Int]
}

/// Actor-based progress tracker for Swift upload/download operations
/// Provides thread-safe progress tracking for concurrent file transfers
actor SwiftTransferProgressTracker {
    private var completedCount = 0
    private var failedCount = 0
    private var skippedCount = 0
    private var failedFiles: [String] = []
    private var completedBytes: Int64 = 0
    private var currentlyProcessing: Set<String> = []
    private var errorsByCategory: [String: Int] = [:]
    private var detailedErrors: [(file: String, category: String, message: String)] = []

    /// Mark a file as started
    func fileStarted(_ fileName: String) {
        currentlyProcessing.insert(fileName)
    }

    /// Mark a file as completed successfully
    /// - Parameters:
    ///   - fileName: Name of the completed file
    ///   - bytes: Number of bytes transferred
    ///   - skipped: Whether the file was skipped due to ETAG match
    func fileCompleted(_ fileName: String, bytes: Int64, skipped: Bool) {
        currentlyProcessing.remove(fileName)
        completedCount += 1
        completedBytes += bytes
        if skipped {
            skippedCount += 1
        }
    }

    /// Mark a file as failed
    /// - Parameters:
    ///   - fileName: Name of the failed file
    ///   - error: Optional TransferError for error categorization
    func fileFailed(_ fileName: String, error: TransferError? = nil) {
        currentlyProcessing.remove(fileName)
        failedCount += 1
        failedFiles.append(fileName)

        if let transferError = error {
            let category = transferError.categoryName
            errorsByCategory[category, default: 0] += 1
            detailedErrors.append((file: fileName, category: category, message: transferError.userFacingMessage))
        } else {
            errorsByCategory["Unknown Error", default: 0] += 1
            detailedErrors.append((file: fileName, category: "Unknown Error", message: "Unknown error"))
        }
    }

    /// Get current progress snapshot
    func getProgress() -> TransferProgress {
        return TransferProgress(
            completed: completedCount,
            failed: failedCount,
            skipped: skippedCount,
            bytes: completedBytes,
            failedFiles: failedFiles,
            active: currentlyProcessing,
            errorSummary: errorsByCategory
        )
    }

    /// Get error summary as a dictionary of category name to count
    func getErrorSummary() -> [String: Int] {
        return errorsByCategory
    }

    /// Get detailed error report for logging
    func getDetailedErrorReport() -> String {
        guard !detailedErrors.isEmpty else {
            return "No errors recorded"
        }

        var report = "Transfer Error Report:\n"
        report += "Total errors: \(detailedErrors.count)\n\n"

        // Group errors by category
        let groupedErrors = Dictionary(grouping: detailedErrors) { $0.category }

        for (category, errors) in groupedErrors.sorted(by: { $0.key < $1.key }) {
            report += "\(category) (\(errors.count)):\n"
            for error in errors {
                report += "  - \(error.file): \(error.message)\n"
            }
            report += "\n"
        }

        return report
    }

    /// Reset tracker for reuse
    func reset() {
        completedCount = 0
        failedCount = 0
        skippedCount = 0
        failedFiles = []
        completedBytes = 0
        currentlyProcessing = []
        errorsByCategory = [:]
        detailedErrors = []
    }
}

/// Formatting utilities for transfer progress messages
extension SwiftTransferProgressTracker {
    /// Format item count with proper pluralization
    static func formatItemCount(_ count: Int, singular: String = "object", plural: String = "objects") -> String {
        return "\(count) \(count == 1 ? singular : plural)"
    }

    /// Format skip count message
    static func formatSkipMessage(skipped: Int, reason: String = "already up to date") -> String {
        guard skipped > 0 else { return "" }
        return " (\(skipped) skipped - \(reason))"
    }

    /// Format error summary for status messages
    /// Example: "3 network errors, 2 not found"
    static func formatErrorSummary(_ errorSummary: [String: Int]) -> String {
        guard !errorSummary.isEmpty else { return "" }

        let parts = errorSummary.sorted(by: { $0.key < $1.key }).map { category, count in
            "\(count) \(category.lowercased())\(count == 1 ? "" : "s")"
        }

        return parts.joined(separator: ", ")
    }

    /// Format complete status message with errors
    /// Example: "Downloaded 95 objects (3 network errors, 2 not found)"
    static func formatStatusWithErrors(completed: Int, errorSummary: [String: Int], operation: String = "Processed") -> String {
        var message = "\(operation) \(formatItemCount(completed))"

        let errorMsg = formatErrorSummary(errorSummary)
        if !errorMsg.isEmpty {
            message += " (\(errorMsg))"
        }

        return message
    }
}
