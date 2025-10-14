import Foundation

// MARK: - Upload Task Models

/// Represents the state of an upload task
public enum UploadState: Sendable, Equatable {
    case queued
    case uploading
    case completed
    case failed(String)
    case cancelled

    public var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .uploading: return "Uploading"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .queued, .uploading:
            return false
        }
    }

    // Custom Equatable implementation to handle associated values
    public static func == (lhs: UploadState, rhs: UploadState) -> Bool {
        switch (lhs, rhs) {
        case (.queued, .queued),
             (.uploading, .uploading),
             (.completed, .completed),
             (.cancelled, .cancelled):
            return true
        case (.failed(let lhsMsg), .failed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

/// Progress information for an upload task
public struct UploadProgress: Sendable, Equatable {
    public let bytesUploaded: Int64
    public let totalBytes: Int64
    public let speed: Double // bytes per second
    public let estimatedTimeRemaining: TimeInterval?

    public init(
        bytesUploaded: Int64,
        totalBytes: Int64,
        speed: Double,
        estimatedTimeRemaining: TimeInterval?
    ) {
        self.bytesUploaded = bytesUploaded
        self.totalBytes = totalBytes
        self.speed = speed
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }

    public var percentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(bytesUploaded) / Double(totalBytes)
    }

    public var formattedSpeed: String {
        let kb = speed / 1024.0
        let mb = kb / 1024.0

        if mb >= 1.0 {
            return String(format: "%.2f MB/s", mb)
        } else {
            return String(format: "%.2f KB/s", kb)
        }
    }
}

/// Result of an upload operation
public enum UploadResult: Sendable, Equatable {
    case success
    case failure(String)
    case cancelled
}

/// Represents a single upload task
public struct UploadTask: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let containerName: String
    public let objectName: String
    public let localPath: String
    public let fileSize: Int64
    public var state: UploadState
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        containerName: String,
        objectName: String,
        localPath: String,
        fileSize: Int64,
        state: UploadState = .queued,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.containerName = containerName
        self.objectName = objectName
        self.localPath = localPath
        self.fileSize = fileSize
        self.state = state
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    public var fileName: String {
        return (localPath as NSString).lastPathComponent
    }

    public var formattedFileSize: String {
        let bytes = Double(fileSize)
        let kb = bytes / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0

        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.2f KB", kb)
        }
    }

    public var duration: TimeInterval? {
        guard let startedAt = startedAt else { return nil }
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }
}

/// Combined task and progress information for display
public struct UploadTaskProgress: Sendable, Equatable {
    public let task: UploadTask
    public let progress: UploadProgress

    public init(task: UploadTask, progress: UploadProgress) {
        self.task = task
        self.progress = progress
    }
}
