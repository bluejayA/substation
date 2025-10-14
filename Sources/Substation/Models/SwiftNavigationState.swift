import Foundation

// MARK: - Swift Navigation State
// Tracks the current navigation context for hierarchical Swift object storage browsing.
// This state is independent from selectedResource to avoid race conditions.

@MainActor
public final class SwiftNavigationState {

    // MARK: - Properties

    /// The current container being browsed (nil when at container list level)
    private(set) var currentContainer: String?

    /// The current path within the container (empty array when at container root)
    /// Each element represents a directory level
    /// Example: ["dir1", "dir2"] represents path "dir1/dir2/"
    private(set) var currentPath: [String]

    /// Full path string with trailing slash (e.g., "dir1/dir2/")
    public var currentPathString: String {
        guard !currentPath.isEmpty else { return "" }
        return currentPath.joined(separator: "/") + "/"
    }

    /// Breadcrumb display for UI (e.g., "Container: mycontainer > dir1 > dir2")
    public var breadcrumb: String {
        guard let container = currentContainer else {
            return "Containers"
        }

        if currentPath.isEmpty {
            return "Container: \(container)"
        }

        return "Container: \(container) > " + currentPath.joined(separator: " > ")
    }

    /// Whether we are at the container list level
    public var isAtContainerList: Bool {
        return currentContainer == nil
    }

    /// Whether we are at the container root level
    public var isAtContainerRoot: Bool {
        return currentContainer != nil && currentPath.isEmpty
    }

    /// Depth of current navigation (0 = container list, 1 = container root, 2+ = subdirectories)
    public var depth: Int {
        if currentContainer == nil {
            return 0
        } else if currentPath.isEmpty {
            return 1
        } else {
            return 1 + currentPath.count
        }
    }

    // MARK: - Initialization

    public init() {
        self.currentContainer = nil
        self.currentPath = []

        Logger.shared.logDebug("SwiftNavigationState initialized")
    }

    // MARK: - Navigation Methods

    /// Navigate into a container (from container list)
    public func navigateIntoContainer(_ containerName: String) {
        Logger.shared.logDebug("Navigating into container: \(containerName)")
        self.currentContainer = containerName
        self.currentPath = []
    }

    /// Navigate into a directory (within current container)
    public func navigateIntoDirectory(_ directoryName: String) {
        guard currentContainer != nil else {
            Logger.shared.logWarning("Cannot navigate into directory without a current container")
            return
        }

        Logger.shared.logDebug("Navigating into directory: \(directoryName), current path: \(currentPathString)")
        currentPath.append(directoryName)
        Logger.shared.logDebug("New path: \(currentPathString)")
    }

    /// Navigate up one level
    /// - Returns: true if navigation occurred, false if already at top level
    @discardableResult
    public func navigateUp() -> Bool {
        if !currentPath.isEmpty {
            // Navigate up one directory level
            let removed = currentPath.removeLast()
            Logger.shared.logDebug("Navigated up from directory: \(removed), new path: \(currentPathString)")
            return true
        } else if currentContainer != nil {
            // Navigate back to container list
            Logger.shared.logDebug("Navigated up from container: \(currentContainer ?? "unknown") to container list")
            currentContainer = nil
            return true
        } else {
            // Already at top level
            Logger.shared.logDebug("Already at top level (container list)")
            return false
        }
    }

    /// Reset navigation to container list
    public func reset() {
        Logger.shared.logDebug("Resetting navigation to container list")
        currentContainer = nil
        currentPath = []
    }

    /// Reset to container root (keeps container, clears path)
    public func resetToContainerRoot() {
        guard currentContainer != nil else {
            Logger.shared.logWarning("Cannot reset to container root without a current container")
            return
        }

        Logger.shared.logDebug("Resetting to container root: \(currentContainer ?? "unknown")")
        currentPath = []
    }

    /// Get the prefix for filtering objects in current path
    /// Returns the path with trailing slash, or empty string if at container root
    public func getObjectPrefix() -> String {
        return currentPathString
    }

    // MARK: - State Queries

    /// Check if we can navigate up
    public func canNavigateUp() -> Bool {
        return currentContainer != nil || !currentPath.isEmpty
    }

    /// Get display title for current view
    public func getTitle() -> String {
        if currentContainer == nil {
            return "Swift Containers"
        } else if currentPath.isEmpty {
            return "Objects in Container: \(currentContainer ?? "Unknown")"
        } else {
            return "Objects in: \(breadcrumb)"
        }
    }
}
