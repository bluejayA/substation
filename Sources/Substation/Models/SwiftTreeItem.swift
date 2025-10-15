import Foundation
import OSClient

// MARK: - Swift Tree Item
// Represents items in a hierarchical tree structure for Swift object storage navigation.
// Supports both virtual directories (inferred from object paths with slashes) and actual objects.

public enum SwiftTreeItem: Identifiable, Sendable {
    case directory(name: String, objectCount: Int, totalBytes: Int)
    case object(SwiftObject)

    // MARK: - Identifiable

    public var id: String {
        switch self {
        case .directory(let name, _, _):
            return "dir:\(name)"
        case .object(let obj):
            return "obj:\(obj.id)"
        }
    }

    // MARK: - Display Properties

    public var displayName: String {
        switch self {
        case .directory(let name, _, _):
            return name
        case .object(let obj):
            return obj.fileName
        }
    }

    public var fullName: String {
        switch self {
        case .directory(let name, _, _):
            return name
        case .object(let obj):
            return obj.name ?? "Unknown"
        }
    }

    public var isDirectory: Bool {
        switch self {
        case .directory:
            return true
        case .object:
            return false
        }
    }

    public var statusIcon: String {
        switch self {
        case .directory:
            return "[D]"
        case .object(let obj):
            return obj.isLargeObject ? "[L]" : "[O]"
        }
    }

    public var sizeDisplay: String {
        switch self {
        case .directory(_, _, let totalBytes):
            return formatBytes(totalBytes)
        case .object(let obj):
            return obj.formattedSize
        }
    }

    public var itemCount: String {
        switch self {
        case .directory(_, let count, _):
            return "\(count) items"
        case .object:
            return "-"
        }
    }

    public var contentType: String {
        switch self {
        case .directory:
            return "Directory"
        case .object(let obj):
            return obj.contentType ?? "Unknown"
        }
    }

    public var lastModified: Date? {
        switch self {
        case .directory:
            return nil
        case .object(let obj):
            return obj.lastModified
        }
    }

    // MARK: - Sorting

    /// Sort tree items: directories first (alphabetically), then objects (alphabetically)
    public static func sortItems(_ items: [SwiftTreeItem]) -> [SwiftTreeItem] {
        return items.sorted { lhs, rhs in
            // Directories always come before objects
            if lhs.isDirectory && !rhs.isDirectory {
                return true
            } else if !lhs.isDirectory && rhs.isDirectory {
                return false
            }

            // Within the same type, sort alphabetically by display name (case-insensitive)
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    // MARK: - Tree Building

    /// Build a tree structure from a flat list of objects at a specific path level
    /// - Parameters:
    ///   - objects: All objects in the container
    ///   - currentPath: The current path prefix (e.g., "dir1/dir2/")
    /// - Returns: Array of tree items (directories and objects) at the current level
    public static func buildTree(from objects: [SwiftObject], currentPath: String) -> [SwiftTreeItem] {
        var directories: [String: (count: Int, bytes: Int)] = [:]
        var currentLevelObjects: [SwiftObject] = []

        Logger.shared.logDebug("Building tree for path: '\(currentPath)' from \(objects.count) objects")

        for object in objects {
            guard let objectName = object.name else {
                Logger.shared.logDebug("Skipping object with nil name")
                continue
            }

            // Skip objects not in current path
            if !currentPath.isEmpty && !objectName.hasPrefix(currentPath) {
                continue
            }

            // Get relative path (remove current path prefix)
            let relativePath = currentPath.isEmpty ? objectName : String(objectName.dropFirst(currentPath.count))

            // Check if this object is in a subdirectory
            if let slashIndex = relativePath.firstIndex(of: "/") {
                // Object is in a subdirectory - extract directory name
                let directoryName = String(relativePath[..<slashIndex])

                // Accumulate directory stats
                if directories[directoryName] != nil {
                    directories[directoryName]?.count += 1
                    directories[directoryName]?.bytes += object.bytes
                } else {
                    directories[directoryName] = (count: 1, bytes: object.bytes)
                }
            } else {
                // Object is at current level (no more slashes)
                currentLevelObjects.append(object)
            }
        }

        Logger.shared.logDebug("Found \(directories.count) directories and \(currentLevelObjects.count) objects at current level")

        // Convert to tree items
        var items: [SwiftTreeItem] = []

        // Add directories
        for (name, stats) in directories {
            items.append(.directory(name: name, objectCount: stats.count, totalBytes: stats.bytes))
        }

        // Add objects
        for object in currentLevelObjects {
            items.append(.object(object))
        }

        // Sort and return
        let sortedItems = sortItems(items)
        Logger.shared.logDebug("Returning \(sortedItems.count) sorted tree items")
        return sortedItems
    }

    /// Filter tree items by search query
    /// - Parameters:
    ///   - items: Tree items to filter
    ///   - query: Search query string (case-insensitive)
    /// - Returns: Filtered tree items
    public static func filterItems(_ items: [SwiftTreeItem], query: String?) -> [SwiftTreeItem] {
        guard let query = query, !query.isEmpty else {
            return items
        }

        let lowercaseQuery = query.lowercased()
        return items.filter { item in
            item.displayName.lowercased().contains(lowercaseQuery)
        }
    }

    /// Get all objects in a directory, optionally including subdirectories
    /// - Parameters:
    ///   - directoryPath: The directory path (e.g., "photos/vacation/")
    ///   - allObjects: All objects in the container
    ///   - recursive: Whether to include objects in subdirectories
    /// - Returns: Array of objects within the directory
    public static func getObjectsInDirectory(
        directoryPath: String,
        allObjects: [SwiftObject],
        recursive: Bool
    ) -> [SwiftObject] {
        var objectsInDirectory: [SwiftObject] = []

        Logger.shared.logDebug("Getting objects in directory: '\(directoryPath)', recursive: \(recursive)")

        for object in allObjects {
            guard let objectName = object.name else {
                continue
            }

            // Check if object is in this directory
            if !objectName.hasPrefix(directoryPath) {
                continue
            }

            // Get relative path (remove directory prefix)
            let relativePath = String(objectName.dropFirst(directoryPath.count))

            if recursive {
                // Include all objects in directory and subdirectories
                objectsInDirectory.append(object)
            } else {
                // Only include objects directly in this directory (no slashes in relative path)
                if !relativePath.contains("/") {
                    objectsInDirectory.append(object)
                }
            }
        }

        Logger.shared.logDebug("Found \(objectsInDirectory.count) objects in directory '\(directoryPath)'")
        return objectsInDirectory
    }

    // MARK: - Helper Methods

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

// MARK: - Extensions

extension SwiftTreeItem: Equatable {
    public static func == (lhs: SwiftTreeItem, rhs: SwiftTreeItem) -> Bool {
        switch (lhs, rhs) {
        case (.directory(let lName, let lCount, let lBytes), .directory(let rName, let rCount, let rBytes)):
            return lName == rName && lCount == rCount && lBytes == rBytes
        case (.object(let lObj), .object(let rObj)):
            return lObj.id == rObj.id
        default:
            return false
        }
    }
}

extension SwiftTreeItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .directory(let name, let count, let bytes):
            hasher.combine("dir")
            hasher.combine(name)
            hasher.combine(count)
            hasher.combine(bytes)
        case .object(let obj):
            hasher.combine("obj")
            hasher.combine(obj.id)
        }
    }
}
