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

    // MARK: - Virtual Scroll Manager Persistence

    /// Persisted VirtualScrollManager for efficient rendering of large lists
    /// This is preserved across renders to avoid recreation overhead
    internal var virtualScrollManager: VirtualScrollManager<SwiftTreeItem>?

    /// Track the last data hash to detect when manager needs updating
    private var lastDataHash: Int = 0

    /// Track the last viewport height to detect config changes
    private var lastViewportHeight: Int = 0

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
        clearVirtualScrollManager()
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

    // MARK: - Virtual Scroll Manager Management

    /// Get or create a VirtualScrollManager for the current data
    ///
    /// - Parameters:
    ///   - items: The filtered items to display
    ///   - viewportHeight: The current viewport height
    /// - Returns: A configured VirtualScrollManager, reused if data hasn't changed
    internal func getOrCreateVirtualScrollManager(
        for items: [SwiftTreeItem],
        viewportHeight: Int
    ) -> VirtualScrollManager<SwiftTreeItem> {
        // Calculate a simple hash based on item count and first/last item IDs
        // This is faster than hashing all items
        var hasher = Hasher()
        hasher.combine(items.count)
        if let first = items.first {
            hasher.combine(first.id)
        }
        if let last = items.last {
            hasher.combine(last.id)
        }
        // Include path in hash to detect navigation changes
        hasher.combine(currentPathString)
        let dataHash = hasher.finalize()

        // Check if we can reuse the existing manager
        if let existingManager = virtualScrollManager,
           dataHash == lastDataHash,
           viewportHeight == lastViewportHeight {
            Logger.shared.logDebug("SwiftNavigationState - Reusing VirtualScrollManager (items: \(items.count))")
            return existingManager
        }

        // Create new manager with updated configuration
        let config = VirtualScrollConfig(
            viewportHeight: viewportHeight,
            bufferSize: 10,
            minimumItemHeight: 1,
            maxRenderItems: 50,
            scrollSensitivity: 1.0
        )

        let manager = VirtualScrollManager<SwiftTreeItem>(config: config)
        manager.updateData(items)

        // Store for reuse
        virtualScrollManager = manager
        lastDataHash = dataHash
        lastViewportHeight = viewportHeight

        Logger.shared.logDebug("SwiftNavigationState - Created new VirtualScrollManager (items: \(items.count), viewport: \(viewportHeight))")
        return manager
    }

    /// Clear the VirtualScrollManager when navigation changes
    internal func clearVirtualScrollManager() {
        virtualScrollManager = nil
        lastDataHash = 0
        lastViewportHeight = 0
        Logger.shared.logDebug("SwiftNavigationState - Cleared VirtualScrollManager")
    }

    /// Check if VirtualScrollManager needs to be updated
    ///
    /// - Parameters:
    ///   - itemCount: Current number of items
    ///   - viewportHeight: Current viewport height
    /// - Returns: true if the manager needs to be recreated
    internal func needsManagerUpdate(itemCount: Int, viewportHeight: Int) -> Bool {
        guard virtualScrollManager != nil else { return true }
        return viewportHeight != lastViewportHeight
    }
}
