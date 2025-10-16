import Foundation

/// Represents a background operation (Swift storage or resource bulk operation)
@MainActor
final class SwiftBackgroundOperation: Identifiable {
    let id: UUID
    let type: OperationType
    let containerName: String
    let objectName: String?
    let localPath: String
    let startTime: Date
    var status: OperationStatus
    var progress: Double
    var bytesTransferred: Int64
    var totalBytes: Int64
    var filesSkipped: Int
    var filesCompleted: Int
    var filesTotal: Int
    var error: String?
    var task: Task<Void, Never>?
    var uploadTask: Task<Void, Never>?

    // Resource bulk operation fields
    let resourceType: String?
    var itemsTotal: Int
    var itemsCompleted: Int
    var itemsFailed: Int

    enum OperationType {
        case upload
        case download
        case delete
        case bulkDelete

        var displayName: String {
            switch self {
            case .upload: return "Upload"
            case .download: return "Download"
            case .delete: return "Delete"
            case .bulkDelete: return "Bulk Delete"
            }
        }
    }

    enum OperationStatus {
        case queued
        case running
        case completed
        case failed
        case cancelled

        var displayName: String {
            switch self {
            case .queued: return "Queued"
            case .running: return "Running"
            case .completed: return "Completed"
            case .failed: return "Failed"
            case .cancelled: return "Canceled"
            }
        }

        var isActive: Bool {
            switch self {
            case .queued, .running: return true
            case .completed, .failed, .cancelled: return false
            }
        }
    }

    /// Initialize for Swift storage operations
    init(
        type: OperationType,
        containerName: String,
        objectName: String?,
        localPath: String,
        totalBytes: Int64
    ) {
        self.id = UUID()
        self.type = type
        self.containerName = containerName
        self.objectName = objectName
        self.localPath = localPath
        self.startTime = Date()
        self.status = .queued
        self.progress = 0.0
        self.bytesTransferred = 0
        self.totalBytes = totalBytes
        self.filesSkipped = 0
        self.filesCompleted = 0
        self.filesTotal = 0
        self.resourceType = nil
        self.itemsTotal = 0
        self.itemsCompleted = 0
        self.itemsFailed = 0
    }

    /// Initialize for resource bulk operations
    init(
        type: OperationType,
        resourceType: String,
        itemsTotal: Int
    ) {
        self.id = UUID()
        self.type = type
        self.containerName = ""
        self.objectName = nil
        self.localPath = ""
        self.startTime = Date()
        self.status = .queued
        self.progress = 0.0
        self.bytesTransferred = 0
        self.totalBytes = 0
        self.filesSkipped = 0
        self.filesCompleted = 0
        self.filesTotal = 0
        self.resourceType = resourceType
        self.itemsTotal = itemsTotal
        self.itemsCompleted = 0
        self.itemsFailed = 0
    }

    var displayName: String {
        if let resourceType = resourceType {
            return resourceType
        } else if let objName = objectName {
            return objName
        } else {
            return localPath
        }
    }

    var progressPercentage: Int {
        return Int(progress * 100)
    }

    private(set) var endTime: Date?

    var elapsedTime: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        }
        return Date().timeIntervalSince(startTime)
    }

    var formattedElapsedTime: String {
        let elapsed = Int(elapsedTime)
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var transferRate: Double {
        guard elapsedTime > 0 else { return 0 }
        return Double(bytesTransferred) / elapsedTime / 1024 / 1024
    }

    var formattedTransferRate: String {
        return String(format: "%.2f MB/s", transferRate)
    }

    var formattedBytesTransferred: String {
        let mb = Double(bytesTransferred) / 1024 / 1024
        return String(format: "%.2f MB", mb)
    }

    var formattedTotalBytes: String {
        let mb = Double(totalBytes) / 1024 / 1024
        return String(format: "%.2f MB", mb)
    }

    func cancel() {
        task?.cancel()
        uploadTask?.cancel()
        status = .cancelled
        if endTime == nil {
            endTime = Date()
        }
    }

    func markCompleted() {
        status = .completed
        if endTime == nil {
            endTime = Date()
        }
    }

    func markFailed(error: String) {
        self.error = error
        status = .failed
        if endTime == nil {
            endTime = Date()
        }
    }
}

/// Manager for tracking background operations (Swift storage and resource bulk operations)
@MainActor
final class SwiftBackgroundOperationsManager {
    private var operations: [UUID: SwiftBackgroundOperation] = [:]

    func addOperation(_ operation: SwiftBackgroundOperation) {
        operations[operation.id] = operation
    }

    func removeOperation(id: UUID) {
        operations.removeValue(forKey: id)
    }

    func getOperation(id: UUID) -> SwiftBackgroundOperation? {
        return operations[id]
    }

    func getAllOperations() -> [SwiftBackgroundOperation] {
        return Array(operations.values).sorted { $0.startTime > $1.startTime }
    }

    func getActiveOperations() -> [SwiftBackgroundOperation] {
        return operations.values.filter { $0.status.isActive }.sorted { $0.startTime > $1.startTime }
    }

    func getCompletedOperations() -> [SwiftBackgroundOperation] {
        return operations.values.filter { !$0.status.isActive }.sorted { $0.startTime > $1.startTime }
    }

    func clearCompleted() {
        operations = operations.filter { $0.value.status.isActive }
    }

    func cancelAll() {
        for operation in operations.values where operation.status.isActive {
            operation.cancel()
        }
    }

    var activeCount: Int {
        return operations.values.filter { $0.status.isActive }.count
    }

    var completedCount: Int {
        return operations.values.filter { !$0.status.isActive }.count
    }
}
