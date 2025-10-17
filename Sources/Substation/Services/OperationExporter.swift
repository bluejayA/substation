import Foundation

// MARK: - Operation Exporter

/// Service for exporting operation history to various formats
@MainActor
final class OperationExporter {

    /// Export format options
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"

        var fileExtension: String {
            return rawValue.lowercased()
        }
    }

    /// Error types for export operations
    enum ExportError: Error, LocalizedError {
        case invalidPath
        case writeFailed(underlying: any Error)
        case noOperations

        var errorDescription: String? {
            switch self {
            case .invalidPath:
                return "Invalid export path specified"
            case .writeFailed(let error):
                return "Failed to write export file: \(error.localizedDescription)"
            case .noOperations:
                return "No operations to export"
            }
        }
    }

    /// Export operations to a file
    /// - Parameters:
    ///   - operations: Operations to export
    ///   - format: Export format (CSV or JSON)
    ///   - path: Destination file path
    ///   - includeActive: Whether to include active operations
    /// - Returns: Number of operations exported
    func exportOperations(
        _ operations: [SwiftBackgroundOperation],
        format: ExportFormat,
        to path: String,
        includeActive: Bool = false
    ) async throws -> Int {
        guard !operations.isEmpty else {
            throw ExportError.noOperations
        }

        // Filter out active operations if requested
        let exportableOps = includeActive ? operations : operations.filter { !$0.status.isActive }

        guard !exportableOps.isEmpty else {
            throw ExportError.noOperations
        }

        let fileURL = URL(fileURLWithPath: path)

        do {
            switch format {
            case .csv:
                try await exportToCSV(exportableOps, to: fileURL)
            case .json:
                try await exportToJSON(exportableOps, to: fileURL)
            }

            Logger.shared.logInfo("OperationExporter - Exported \(exportableOps.count) operations to \(format.rawValue)")
            return exportableOps.count
        } catch {
            Logger.shared.logError("OperationExporter - Export failed: \(error)")
            throw ExportError.writeFailed(underlying: error)
        }
    }

    // MARK: - CSV Export

    /// Export operations to CSV format
    private func exportToCSV(_ operations: [SwiftBackgroundOperation], to url: URL) async throws {
        var csv = buildCSVHeader() + "\n"

        for operation in operations {
            csv += buildCSVRow(for: operation) + "\n"
        }

        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Build CSV header row
    private func buildCSVHeader() -> String {
        return [
            "ID",
            "Type",
            "Status",
            "Resource/Object",
            "Container",
            "Resource Type",
            "Start Time",
            "End Time",
            "Duration (seconds)",
            "Progress (%)",
            "Bytes Transferred",
            "Total Bytes",
            "Transfer Rate (MB/s)",
            "Files Completed",
            "Files Total",
            "Files Skipped",
            "Items Completed",
            "Items Total",
            "Items Failed",
            "Error"
        ].map { escapeCSVField($0) }.joined(separator: ",")
    }

    /// Build CSV row for an operation
    private func buildCSVRow(for operation: SwiftBackgroundOperation) -> String {
        let endTime = operation.status.isActive ? "" : DateFormatter.substationExportFormatter.string(from: operation.endTime ?? Date())
        let duration = operation.status.isActive ? "" : String(format: "%.2f", operation.elapsedTime)
        let transferRate = operation.status == .running ? String(format: "%.2f", operation.transferRate) : ""
        let error = operation.error ?? ""

        return [
            operation.id.uuidString,
            operation.type.displayName,
            operation.status.displayName,
            operation.displayName,
            operation.containerName,
            operation.resourceType ?? "",
            DateFormatter.substationExportFormatter.string(from: operation.startTime),
            endTime,
            duration,
            String(operation.progressPercentage),
            String(operation.bytesTransferred),
            String(operation.totalBytes),
            transferRate,
            String(operation.filesCompleted),
            String(operation.filesTotal),
            String(operation.filesSkipped),
            String(operation.itemsCompleted),
            String(operation.itemsTotal),
            String(operation.itemsFailed),
            error
        ].map { escapeCSVField($0) }.joined(separator: ",")
    }

    /// Escape CSV field (handle commas, quotes, newlines)
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    // MARK: - JSON Export

    /// Export operations to JSON format
    private func exportToJSON(_ operations: [SwiftBackgroundOperation], to url: URL) async throws {
        let exportData = operations.map { operation in
            OperationExportData(from: operation)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportData)
        try data.write(to: url)
    }

    // MARK: - Export Data Structure

    /// Codable structure for JSON export
    @MainActor
    private struct OperationExportData: Codable {
        let id: String
        let type: String
        let status: String
        let resourceName: String
        let containerName: String
        let resourceType: String?
        let startTime: Date
        let endTime: Date?
        let durationSeconds: Double?
        let progressPercentage: Int
        let bytesTransferred: Int64
        let totalBytes: Int64
        let transferRateMBps: Double?
        let filesCompleted: Int
        let filesTotal: Int
        let filesSkipped: Int
        let itemsCompleted: Int
        let itemsTotal: Int
        let itemsFailed: Int
        let error: String?

        init(from operation: SwiftBackgroundOperation) {
            self.id = operation.id.uuidString
            self.type = operation.type.displayName
            self.status = operation.status.displayName
            self.resourceName = operation.displayName
            self.containerName = operation.containerName
            self.resourceType = operation.resourceType
            self.startTime = operation.startTime
            self.endTime = operation.status.isActive ? nil : operation.endTime
            self.durationSeconds = operation.status.isActive ? nil : operation.elapsedTime
            self.progressPercentage = operation.progressPercentage
            self.bytesTransferred = operation.bytesTransferred
            self.totalBytes = operation.totalBytes
            self.transferRateMBps = operation.status == .running ? operation.transferRate : nil
            self.filesCompleted = operation.filesCompleted
            self.filesTotal = operation.filesTotal
            self.filesSkipped = operation.filesSkipped
            self.itemsCompleted = operation.itemsCompleted
            self.itemsTotal = operation.itemsTotal
            self.itemsFailed = operation.itemsFailed
            self.error = operation.error
        }
    }

    // MARK: - Utility Methods

    /// Generate default filename for export
    func generateDefaultFilename(format: ExportFormat) -> String {
        let timestamp = DateFormatter.substationFilenameFormatter.string(from: Date())
        return "operations_export_\(timestamp).\(format.fileExtension)"
    }

    /// Validate export path
    func validatePath(_ path: String) -> Bool {
        let fileURL = URL(fileURLWithPath: path)
        let directory = fileURL.deletingLastPathComponent()
        return FileManager.default.fileExists(atPath: directory.path)
    }
}

// MARK: - DateFormatter Extensions for Export

extension DateFormatter {
    /// Formatter for exporting dates in ISO 8601 format with timezone
    static let substationExportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Formatter for generating filenames with timestamps
    static let substationFilenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
