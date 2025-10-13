import Foundation

// MARK: - Swift Container Models

public struct SwiftContainer: Codable, Sendable, ResourceIdentifiable, Identifiable {
    public let name: String?
    public let count: Int
    public let bytes: Int
    public let lastModified: Date?
    public let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case name
        case count
        case bytes
        case lastModified = "last_modified"
    }

    public init(
        name: String?,
        count: Int = 0,
        bytes: Int = 0,
        lastModified: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.count = count
        self.bytes = bytes
        self.lastModified = lastModified
        self.metadata = metadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decodeIfPresent(String.self, forKey: .name)
        count = try container.decode(Int.self, forKey: .count)
        bytes = try container.decode(Int.self, forKey: .bytes)
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified)

        // Metadata is typically in response headers, not JSON body
        metadata = [:]
    }

    // MARK: - ResourceIdentifiable

    public var id: String {
        return name ?? ""
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? "Unknown"
    }

    public var objectCount: Int {
        return count
    }

    public var sizeBytes: Int {
        return bytes
    }

    public var sizeMB: Double {
        return Double(bytes) / 1024.0 / 1024.0
    }

    public var sizeGB: Double {
        return Double(bytes) / 1024.0 / 1024.0 / 1024.0
    }

    public var isEmpty: Bool {
        return count == 0
    }

    public var formattedSize: String {
        return formatBytes(bytes)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        let tb = gb * 1024.0

        let size = Double(bytes)

        if size >= tb {
            return String(format: "%.2f TB", size / tb)
        } else if size >= gb {
            return String(format: "%.2f GB", size / gb)
        } else if size >= mb {
            return String(format: "%.2f MB", size / mb)
        } else if size >= kb {
            return String(format: "%.2f KB", size / kb)
        } else {
            return "\(bytes) B"
        }
    }
}

// MARK: - Swift Object Models

public struct SwiftObject: Codable, Sendable, ResourceIdentifiable, Identifiable {
    public let name: String?
    public let bytes: Int
    public let contentType: String?
    public let hash: String?
    public let lastModified: Date?
    public let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case name
        case bytes
        case contentType = "content_type"
        case hash
        case lastModified = "last_modified"
    }

    public init(
        name: String?,
        bytes: Int = 0,
        contentType: String? = nil,
        hash: String? = nil,
        lastModified: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.bytes = bytes
        self.contentType = contentType
        self.hash = hash
        self.lastModified = lastModified
        self.metadata = metadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decodeIfPresent(String.self, forKey: .name)
        bytes = try container.decode(Int.self, forKey: .bytes)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        hash = try container.decodeIfPresent(String.self, forKey: .hash)
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified)

        // Metadata is typically in response headers, not JSON body
        metadata = [:]
    }

    // MARK: - ResourceIdentifiable

    public var id: String {
        return name ?? ""
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? "Unknown"
    }

    public var fileName: String {
        guard let name = name else { return "Unknown" }
        return (name as NSString).lastPathComponent
    }

    public var fileExtension: String? {
        guard let name = name else { return nil }
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? nil : ext
    }

    public var sizeBytes: Int {
        return bytes
    }

    public var sizeMB: Double {
        return Double(bytes) / 1024.0 / 1024.0
    }

    public var sizeGB: Double {
        return Double(bytes) / 1024.0 / 1024.0 / 1024.0
    }

    public var formattedSize: String {
        return formatBytes(bytes)
    }

    public var isLargeObject: Bool {
        // Objects larger than 5GB are considered large objects in Swift
        return bytes > 5 * 1024 * 1024 * 1024
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        let tb = gb * 1024.0

        let size = Double(bytes)

        if size >= tb {
            return String(format: "%.2f TB", size / tb)
        } else if size >= gb {
            return String(format: "%.2f GB", size / gb)
        } else if size >= mb {
            return String(format: "%.2f MB", size / mb)
        } else if size >= kb {
            return String(format: "%.2f KB", size / kb)
        } else {
            return "\(bytes) B"
        }
    }
}

// MARK: - Swift Request Models

public struct CreateSwiftContainerRequest: Sendable {
    public let name: String
    public let metadata: [String: String]
    public let readACL: String?
    public let writeACL: String?

    public init(
        name: String,
        metadata: [String: String] = [:],
        readACL: String? = nil,
        writeACL: String? = nil
    ) {
        self.name = name
        self.metadata = metadata
        self.readACL = readACL
        self.writeACL = writeACL
    }
}

public struct UpdateSwiftContainerMetadataRequest: Sendable {
    public let metadata: [String: String]
    public let removeMetadataKeys: [String]

    public init(
        metadata: [String: String] = [:],
        removeMetadataKeys: [String] = []
    ) {
        self.metadata = metadata
        self.removeMetadataKeys = removeMetadataKeys
    }
}

public struct UploadSwiftObjectRequest: Sendable {
    public let containerName: String
    public let objectName: String
    public let data: Data
    public let contentType: String?
    public let metadata: [String: String]
    public let deleteAfter: Int?
    public let deleteAt: Date?

    public init(
        containerName: String,
        objectName: String,
        data: Data,
        contentType: String? = nil,
        metadata: [String: String] = [:],
        deleteAfter: Int? = nil,
        deleteAt: Date? = nil
    ) {
        self.containerName = containerName
        self.objectName = objectName
        self.data = data
        self.contentType = contentType
        self.metadata = metadata
        self.deleteAfter = deleteAfter
        self.deleteAt = deleteAt
    }
}

public struct UpdateSwiftObjectMetadataRequest: Sendable {
    public let metadata: [String: String]
    public let removeMetadataKeys: [String]
    public let contentType: String?

    public init(
        metadata: [String: String] = [:],
        removeMetadataKeys: [String] = [],
        contentType: String? = nil
    ) {
        self.metadata = metadata
        self.removeMetadataKeys = removeMetadataKeys
        self.contentType = contentType
    }
}

public struct CopySwiftObjectRequest: Sendable {
    public let sourceContainer: String
    public let sourceObject: String
    public let destinationContainer: String
    public let destinationObject: String
    public let metadata: [String: String]
    public let freshMetadata: Bool

    public init(
        sourceContainer: String,
        sourceObject: String,
        destinationContainer: String,
        destinationObject: String,
        metadata: [String: String] = [:],
        freshMetadata: Bool = false
    ) {
        self.sourceContainer = sourceContainer
        self.sourceObject = sourceObject
        self.destinationContainer = destinationContainer
        self.destinationObject = destinationObject
        self.metadata = metadata
        self.freshMetadata = freshMetadata
    }
}

// MARK: - Swift Response Models

public struct SwiftContainerListResponse: Sendable {
    public let containers: [SwiftContainer]

    public init(containers: [SwiftContainer]) {
        self.containers = containers
    }
}

public struct SwiftObjectListResponse: Sendable {
    public let objects: [SwiftObject]

    public init(objects: [SwiftObject]) {
        self.objects = objects
    }
}

public struct SwiftContainerMetadataResponse: Sendable {
    public let containerName: String
    public let objectCount: Int
    public let bytesUsed: Int
    public let metadata: [String: String]
    public let readACL: String?
    public let writeACL: String?

    public init(
        containerName: String,
        objectCount: Int,
        bytesUsed: Int,
        metadata: [String: String],
        readACL: String? = nil,
        writeACL: String? = nil
    ) {
        self.containerName = containerName
        self.objectCount = objectCount
        self.bytesUsed = bytesUsed
        self.metadata = metadata
        self.readACL = readACL
        self.writeACL = writeACL
    }
}

public struct SwiftObjectMetadataResponse: Sendable {
    public let objectName: String
    public let contentLength: Int
    public let contentType: String?
    public let etag: String?
    public let lastModified: Date?
    public let metadata: [String: String]

    public init(
        objectName: String,
        contentLength: Int,
        contentType: String? = nil,
        etag: String? = nil,
        lastModified: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.objectName = objectName
        self.contentLength = contentLength
        self.contentType = contentType
        self.etag = etag
        self.lastModified = lastModified
        self.metadata = metadata
    }
}

// MARK: - Bulk Operation Models

public struct BulkDeleteRequest: Sendable {
    public let containerName: String?
    public let objectNames: [String]

    public init(containerName: String? = nil, objectNames: [String]) {
        self.containerName = containerName
        self.objectNames = objectNames
    }
}

public struct BulkDeleteResponse: Codable, Sendable {
    public let numberNotFound: Int
    public let numberDeleted: Int
    public let errors: [[String]]
    public let responseStatus: String
    public let responseBody: String

    enum CodingKeys: String, CodingKey {
        case numberNotFound = "Number Not Found"
        case numberDeleted = "Number Deleted"
        case errors = "Errors"
        case responseStatus = "Response Status"
        case responseBody = "Response Body"
    }

    public init(
        numberNotFound: Int = 0,
        numberDeleted: Int = 0,
        errors: [[String]] = [],
        responseStatus: String = "",
        responseBody: String = ""
    ) {
        self.numberNotFound = numberNotFound
        self.numberDeleted = numberDeleted
        self.errors = errors
        self.responseStatus = responseStatus
        self.responseBody = responseBody
    }
}

public struct BulkUploadResult: Sendable {
    public let successCount: Int
    public let failureCount: Int
    public let totalCount: Int
    public let errors: [BulkUploadError]

    public init(
        successCount: Int,
        failureCount: Int,
        totalCount: Int,
        errors: [BulkUploadError] = []
    ) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.totalCount = totalCount
        self.errors = errors
    }

    public var successRate: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(successCount) / Double(totalCount)
    }
}

public struct BulkUploadError: Sendable {
    public let objectName: String
    public let error: String

    public init(objectName: String, error: String) {
        self.objectName = objectName
        self.error = error
    }
}

// MARK: - Large Object Support (Dynamic Large Objects - DLO / Static Large Objects - SLO)

public struct SwiftSegmentInfo: Sendable {
    public let segmentContainer: String
    public let segmentPrefix: String
    public let segmentSize: Int
    public let totalSegments: Int

    public init(
        segmentContainer: String,
        segmentPrefix: String,
        segmentSize: Int,
        totalSegments: Int
    ) {
        self.segmentContainer = segmentContainer
        self.segmentPrefix = segmentPrefix
        self.segmentSize = segmentSize
        self.totalSegments = totalSegments
    }
}

// MARK: - Account Info Models

public struct SwiftAccountInfo: Sendable {
    public let containerCount: Int
    public let objectCount: Int
    public let bytesUsed: Int
    public let metadata: [String: String]

    public init(
        containerCount: Int,
        objectCount: Int,
        bytesUsed: Int,
        metadata: [String: String] = [:]
    ) {
        self.containerCount = containerCount
        self.objectCount = objectCount
        self.bytesUsed = bytesUsed
        self.metadata = metadata
    }

    public var formattedSize: String {
        return formatBytes(bytesUsed)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        let tb = gb * 1024.0

        let size = Double(bytes)

        if size >= tb {
            return String(format: "%.2f TB", size / tb)
        } else if size >= gb {
            return String(format: "%.2f GB", size / gb)
        } else if size >= mb {
            return String(format: "%.2f MB", size / mb)
        } else if size >= kb {
            return String(format: "%.2f KB", size / kb)
        } else {
            return "\(bytes) B"
        }
    }
}

// MARK: - Error Types

public enum SwiftError: Error, LocalizedError {
    case containerNotFound(String)
    case objectNotFound(String)
    case containerNotEmpty(String)
    case quotaExceeded
    case objectTooLarge(Int)
    case invalidObjectName(String)
    case invalidContainerName(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case bulkOperationFailed(String)
    case metadataUpdateFailed(String)
    case unauthorized
    case serviceUnavailable

    public var errorDescription: String? {
        switch self {
        case .containerNotFound(let name):
            return "Container not found: \(name)"
        case .objectNotFound(let name):
            return "Object not found: \(name)"
        case .containerNotEmpty(let name):
            return "Container not empty: \(name)"
        case .quotaExceeded:
            return "Storage quota exceeded"
        case .objectTooLarge(let size):
            return "Object too large: \(size) bytes"
        case .invalidObjectName(let name):
            return "Invalid object name: \(name)"
        case .invalidContainerName(let name):
            return "Invalid container name: \(name)"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .bulkOperationFailed(let reason):
            return "Bulk operation failed: \(reason)"
        case .metadataUpdateFailed(let reason):
            return "Metadata update failed: \(reason)"
        case .unauthorized:
            return "Unauthorized access to Swift object storage"
        case .serviceUnavailable:
            return "Swift object storage service unavailable"
        }
    }
}
