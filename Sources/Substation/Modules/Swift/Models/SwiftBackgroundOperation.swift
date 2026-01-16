// Sources/Substation/Modules/Swift/Models/SwiftBackgroundOperation.swift
//
// DEPRECATED: This file exists for backwards compatibility only.
// Use BackgroundOperation from Sources/Substation/Framework/BackgroundOperations/ instead.

import Foundation

// MARK: - Legacy Compatibility Extensions

extension BackgroundOperation {
    /// Legacy property for Swift storage container name
    ///
    /// Maps to resourceContext for backwards compatibility
    var containerName: String {
        return resourceContext ?? ""
    }

    /// Legacy property for Swift storage object name
    ///
    /// Maps to resourceName for backwards compatibility
    var objectName: String? {
        // Only return for storage operations
        if type.category == .storage {
            return resourceName
        }
        return nil
    }

    /// Legacy property for local file path
    ///
    /// Maps to resourceName for backwards compatibility
    var localPath: String {
        return resourceName
    }

    /// Legacy task property alias
    var uploadTask: Task<Void, Never>? {
        get { return secondaryTask }
        set { secondaryTask = newValue }
    }

    /// Legacy convenience initializer for Swift storage operations
    ///
    /// - Parameters:
    ///   - type: Operation type
    ///   - containerName: Swift container name
    ///   - objectName: Object name (optional)
    ///   - localPath: Local file path
    ///   - totalBytes: Total bytes to transfer
    convenience init(
        type: BackgroundOperationType,
        containerName: String,
        objectName: String?,
        localPath: String,
        totalBytes: Int64
    ) {
        self.init(
            type: type,
            resourceName: objectName ?? localPath,
            resourceContext: containerName,
            totalBytes: totalBytes
        )
    }

    /// Legacy convenience initializer for resource bulk operations
    ///
    /// - Parameters:
    ///   - type: Operation type
    ///   - resourceType: Type of resource (e.g., "Volumes")
    ///   - itemsTotal: Total items to process
    convenience init(
        type: BackgroundOperationType,
        resourceType: String,
        itemsTotal: Int
    ) {
        self.init(
            type: type,
            resourceType: resourceType,
            resourceName: resourceType,
            itemsTotal: itemsTotal
        )
    }
}
