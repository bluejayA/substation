// Sources/Substation/Framework/BackgroundOperations/BackgroundOperation.swift
import Foundation

// MARK: - Operation Category

/// Categories of background operations for grouping and filtering
public enum OperationCategory: String, CaseIterable, Sendable {
    case storage = "Storage"
    case compute = "Compute"
    case network = "Network"
    case volume = "Volume"
    case image = "Image"
    case general = "General"

    /// Icon representation for the category
    var icon: String {
        switch self {
        case .storage: return "S"
        case .compute: return "C"
        case .network: return "N"
        case .volume: return "V"
        case .image: return "I"
        case .general: return "G"
        }
    }
}

// MARK: - Operation Type

/// Types of background operations that can be performed
public enum BackgroundOperationType: Sendable {
    // Storage operations (Swift object storage)
    case upload
    case download
    case delete

    // Bulk operations
    case bulkDelete
    case bulkCreate
    case bulkUpdate

    // Volume operations
    case volumeCreate
    case volumeDelete
    case cascadingDelete
    case volumeAttach
    case volumeDetach

    // Server operations
    case serverCreate
    case serverDelete
    case serverReboot

    // Network operations
    case networkCreate
    case routerCreate
    case floatingIPAssign

    // Image operations
    case imageUpload
    case imageDownload

    // Generic
    case custom(String)

    /// Human-readable display name for the operation type
    public var displayName: String {
        switch self {
        case .upload: return "Upload"
        case .download: return "Download"
        case .delete: return "Delete"
        case .bulkDelete: return "Bulk Delete"
        case .bulkCreate: return "Bulk Create"
        case .bulkUpdate: return "Bulk Update"
        case .volumeCreate: return "Volume Create"
        case .volumeDelete: return "Volume Delete"
        case .cascadingDelete: return "Cascading Delete"
        case .volumeAttach: return "Volume Attach"
        case .volumeDetach: return "Volume Detach"
        case .serverCreate: return "Server Create"
        case .serverDelete: return "Server Delete"
        case .serverReboot: return "Server Reboot"
        case .networkCreate: return "Network Create"
        case .routerCreate: return "Router Create"
        case .floatingIPAssign: return "Floating IP Assign"
        case .imageUpload: return "Image Upload"
        case .imageDownload: return "Image Download"
        case .custom(let name): return name
        }
    }

    /// Category this operation belongs to
    public var category: OperationCategory {
        switch self {
        case .upload, .download, .delete:
            return .storage
        case .bulkDelete, .bulkCreate, .bulkUpdate:
            return .general
        case .volumeCreate, .volumeDelete, .cascadingDelete, .volumeAttach, .volumeDetach:
            return .volume
        case .serverCreate, .serverDelete, .serverReboot:
            return .compute
        case .networkCreate, .routerCreate, .floatingIPAssign:
            return .network
        case .imageUpload, .imageDownload:
            return .image
        case .custom:
            return .general
        }
    }

    /// Whether this operation type tracks byte-level progress
    public var tracksBytes: Bool {
        switch self {
        case .upload, .download, .imageUpload, .imageDownload:
            return true
        default:
            return false
        }
    }

    /// Whether this operation type tracks item counts
    public var tracksItems: Bool {
        switch self {
        case .bulkDelete, .bulkCreate, .bulkUpdate, .cascadingDelete:
            return true
        default:
            return false
        }
    }
}

// MARK: - Operation Status

/// Status of a background operation
public enum BackgroundOperationStatus: Sendable {
    case queued
    case running
    case completed
    case failed
    case cancelled

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Canceled"
        }
    }

    /// Whether the operation is still active (not terminal)
    public var isActive: Bool {
        switch self {
        case .queued, .running: return true
        case .completed, .failed, .cancelled: return false
        }
    }

    /// Whether the operation completed successfully
    public var isSuccess: Bool {
        return self == .completed
    }
}

// MARK: - Background Operation

/// Represents a background operation that can be tracked and managed
///
/// This class provides a generic model for tracking long-running operations
/// across different modules including storage transfers, bulk operations,
/// volume management, and more.
@MainActor
public final class BackgroundOperation: Identifiable {
    // MARK: - Core Properties

    /// Unique identifier for the operation
    public let id: UUID

    /// Type of operation being performed
    public let type: BackgroundOperationType

    /// When the operation was started
    public let startTime: Date

    /// Current status of the operation
    public var status: BackgroundOperationStatus

    /// Overall progress from 0.0 to 1.0
    public var progress: Double

    /// Error message if the operation failed
    public var error: String?

    // MARK: - Resource Information

    /// Human-readable name for the resource being operated on
    public let resourceName: String

    /// Type of resource (e.g., "Volume", "Server", "Container")
    public let resourceType: String?

    /// Additional context about the resource (e.g., container name, path)
    public let resourceContext: String?

    // MARK: - Byte Transfer Tracking (for storage operations)

    /// Bytes transferred so far
    public var bytesTransferred: Int64

    /// Total bytes to transfer
    public var totalBytes: Int64

    // MARK: - Item Tracking (for bulk operations)

    /// Total items to process
    public var itemsTotal: Int

    /// Items successfully completed
    public var itemsCompleted: Int

    /// Items that failed
    public var itemsFailed: Int

    /// Items skipped (e.g., already exists)
    public var itemsSkipped: Int

    // MARK: - File Tracking (for multi-file operations)

    /// Total files to process
    public var filesTotal: Int

    /// Files completed
    public var filesCompleted: Int

    /// Files skipped
    public var filesSkipped: Int

    // MARK: - Task Management

    /// Primary task for the operation
    public var task: Task<Void, Never>?

    /// Secondary task (e.g., for upload operations)
    public var secondaryTask: Task<Void, Never>?

    // MARK: - Timing

    /// When the operation ended (nil if still running)
    public private(set) var endTime: Date?

    // MARK: - Initialization

    /// Initialize a background operation for storage transfers
    ///
    /// - Parameters:
    ///   - type: The type of operation
    ///   - resourceName: Name of the resource (e.g., object name, file path)
    ///   - resourceContext: Context like container name
    ///   - totalBytes: Total bytes to transfer
    public init(
        type: BackgroundOperationType,
        resourceName: String,
        resourceContext: String? = nil,
        totalBytes: Int64 = 0
    ) {
        self.id = UUID()
        self.type = type
        self.startTime = Date()
        self.status = .queued
        self.progress = 0.0
        self.resourceName = resourceName
        self.resourceType = nil
        self.resourceContext = resourceContext
        self.bytesTransferred = 0
        self.totalBytes = totalBytes
        self.itemsTotal = 0
        self.itemsCompleted = 0
        self.itemsFailed = 0
        self.itemsSkipped = 0
        self.filesTotal = 0
        self.filesCompleted = 0
        self.filesSkipped = 0
    }

    /// Initialize a background operation for resource bulk operations
    ///
    /// - Parameters:
    ///   - type: The type of operation
    ///   - resourceType: Type of resource being operated on (e.g., "Volume", "Server")
    ///   - resourceName: Name of the specific resource
    ///   - itemsTotal: Total items to process
    public init(
        type: BackgroundOperationType,
        resourceType: String,
        resourceName: String,
        itemsTotal: Int
    ) {
        self.id = UUID()
        self.type = type
        self.startTime = Date()
        self.status = .queued
        self.progress = 0.0
        self.resourceName = resourceName
        self.resourceType = resourceType
        self.resourceContext = nil
        self.bytesTransferred = 0
        self.totalBytes = 0
        self.itemsTotal = itemsTotal
        self.itemsCompleted = 0
        self.itemsFailed = 0
        self.itemsSkipped = 0
        self.filesTotal = 0
        self.filesCompleted = 0
        self.filesSkipped = 0
    }

    // MARK: - Deinitialization

    /// Clean up Task references when the operation is deallocated
    deinit {
        task?.cancel()
        secondaryTask?.cancel()
    }

    // MARK: - Computed Properties

    /// Display name for the operation
    public var displayName: String {
        if let resourceType = resourceType {
            return "\(resourceType): \(resourceName)"
        }
        return resourceName
    }

    /// Progress as a percentage (0-100)
    public var progressPercentage: Int {
        return Int(progress * 100)
    }

    /// Elapsed time since operation started
    public var elapsedTime: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        }
        return Date().timeIntervalSince(startTime)
    }

    /// Formatted elapsed time (M:SS)
    public var formattedElapsedTime: String {
        let elapsed = Int(elapsedTime)
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Transfer rate in MB/s (for byte-tracking operations)
    public var transferRate: Double {
        guard elapsedTime > 0 else { return 0 }
        return Double(bytesTransferred) / elapsedTime / 1024 / 1024
    }

    /// Formatted transfer rate
    public var formattedTransferRate: String {
        return String(format: "%.2f MB/s", transferRate)
    }

    /// Formatted bytes transferred
    public var formattedBytesTransferred: String {
        let mb = Double(bytesTransferred) / 1024 / 1024
        return String(format: "%.2f MB", mb)
    }

    /// Formatted total bytes
    public var formattedTotalBytes: String {
        let mb = Double(totalBytes) / 1024 / 1024
        return String(format: "%.2f MB", mb)
    }

    /// Summary of items processed (for item-tracking operations)
    public var itemsSummary: String {
        if itemsFailed > 0 {
            return "\(itemsCompleted)/\(itemsTotal) (\(itemsFailed) failed)"
        }
        return "\(itemsCompleted)/\(itemsTotal)"
    }

    // MARK: - State Management

    /// Cancel the operation
    public func cancel() {
        task?.cancel()
        secondaryTask?.cancel()
        status = .cancelled
        if endTime == nil {
            endTime = Date()
        }
    }

    /// Mark the operation as completed successfully
    public func markCompleted() {
        status = .completed
        progress = 1.0
        if endTime == nil {
            endTime = Date()
        }
    }

    /// Mark the operation as failed with an error message
    ///
    /// - Parameter error: Description of what went wrong
    public func markFailed(error: String) {
        self.error = error
        status = .failed
        if endTime == nil {
            endTime = Date()
        }
    }

    /// Update progress based on items completed
    public func updateItemProgress() {
        if itemsTotal > 0 {
            progress = Double(itemsCompleted) / Double(itemsTotal)
        }
    }

    /// Update progress based on bytes transferred
    public func updateByteProgress() {
        if totalBytes > 0 {
            progress = Double(bytesTransferred) / Double(totalBytes)
        }
    }
}

// MARK: - Background Operations Manager

/// Manager for tracking and coordinating background operations
///
/// Provides centralized management of all background operations across
/// the application, including querying, filtering, and cleanup.
@MainActor
public final class BackgroundOperationsManager {
    // MARK: - Storage

    private var operations: [UUID: BackgroundOperation] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Operation Management

    /// Add a new operation to be tracked
    ///
    /// - Parameter operation: The operation to track
    public func addOperation(_ operation: BackgroundOperation) {
        operations[operation.id] = operation
    }

    /// Remove an operation from tracking
    ///
    /// - Parameter id: ID of the operation to remove
    public func removeOperation(id: UUID) {
        operations.removeValue(forKey: id)
    }

    /// Get a specific operation by ID
    ///
    /// - Parameter id: ID of the operation
    /// - Returns: The operation if found
    public func getOperation(id: UUID) -> BackgroundOperation? {
        return operations[id]
    }

    // MARK: - Querying

    /// Get all operations sorted by start time (newest first)
    ///
    /// - Returns: Array of all operations
    public func getAllOperations() -> [BackgroundOperation] {
        return Array(operations.values).sorted { $0.startTime > $1.startTime }
    }

    /// Get only active (queued or running) operations
    ///
    /// - Returns: Array of active operations
    public func getActiveOperations() -> [BackgroundOperation] {
        return operations.values
            .filter { $0.status.isActive }
            .sorted { $0.startTime > $1.startTime }
    }

    /// Get only completed (finished, failed, or cancelled) operations
    ///
    /// - Returns: Array of completed operations
    public func getCompletedOperations() -> [BackgroundOperation] {
        return operations.values
            .filter { !$0.status.isActive }
            .sorted { $0.startTime > $1.startTime }
    }

    /// Get operations filtered by category
    ///
    /// - Parameter category: The category to filter by
    /// - Returns: Array of operations in that category
    public func getOperations(category: OperationCategory) -> [BackgroundOperation] {
        return operations.values
            .filter { $0.type.category == category }
            .sorted { $0.startTime > $1.startTime }
    }

    /// Get operations filtered by type
    ///
    /// - Parameter type: The operation type to filter by
    /// - Returns: Array of operations of that type
    public func getOperations(type: BackgroundOperationType) -> [BackgroundOperation] {
        return operations.values
            .filter { $0.type.displayName == type.displayName }
            .sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Cleanup

    /// Remove all completed operations
    public func clearCompleted() {
        operations = operations.filter { $0.value.status.isActive }
    }

    /// Cancel all active operations
    public func cancelAll() {
        for operation in operations.values where operation.status.isActive {
            operation.cancel()
        }
    }

    // MARK: - Statistics

    /// Number of currently active operations
    public var activeCount: Int {
        return operations.values.filter { $0.status.isActive }.count
    }

    /// Number of completed operations (success, failed, or cancelled)
    public var completedCount: Int {
        return operations.values.filter { !$0.status.isActive }.count
    }

    /// Total number of tracked operations
    public var totalCount: Int {
        return operations.count
    }

    /// Number of failed operations
    public var failedCount: Int {
        return operations.values.filter { $0.status == .failed }.count
    }
}

// MARK: - Type Aliases for Backwards Compatibility

/// Backwards compatibility alias for SwiftBackgroundOperation
public typealias SwiftBackgroundOperation = BackgroundOperation

/// Backwards compatibility alias for SwiftBackgroundOperationsManager
public typealias SwiftBackgroundOperationsManager = BackgroundOperationsManager
