// Sources/Substation/Modules/Core/LazyModuleLoader.swift
import Foundation

/// Priority levels for module loading
///
/// Higher priority modules are loaded first in the background queue.
enum ModuleLoadPriority: Int, Comparable {
    /// Critical modules needed for core functionality
    case critical = 100
    /// High priority modules frequently accessed
    case high = 75
    /// Normal priority for standard modules
    case normal = 50
    /// Low priority for rarely used modules
    case low = 25
    /// Background priority for optional modules
    case background = 0

    static func < (lhs: ModuleLoadPriority, rhs: ModuleLoadPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Module loading request with priority and timing
struct ModuleLoadRequest: Sendable {
    /// Module identifier to load
    let identifier: String
    /// Load priority
    let priority: ModuleLoadPriority
    /// Time request was created
    let requestTime: Date
    /// Whether this is a background preload
    let isPreload: Bool
}

/// Memory usage information for a module
struct ModuleMemoryUsage: Sendable {
    /// Module identifier
    let identifier: String
    /// Estimated memory in bytes
    let estimatedBytes: Int
    /// Number of registered views
    let viewCount: Int
    /// Number of registered actions
    let actionCount: Int
    /// Number of registered forms
    let formCount: Int
    /// Time of measurement
    let timestamp: Date
}

/// Statistics for lazy loading operations
struct LazyLoadStatistics: Sendable {
    /// Total number of load requests
    let totalRequests: Int
    /// Number of on-demand loads
    let onDemandLoads: Int
    /// Number of preloads completed
    let preloadsCompleted: Int
    /// Average load time in milliseconds
    let averageLoadTimeMs: Double
    /// Peak queue depth
    let peakQueueDepth: Int
    /// Total memory tracked in bytes
    let totalMemoryBytes: Int
}

/// Lazy module loader that loads modules on-demand with background preloading
///
/// This class manages module loading with the following features:
/// - On-demand loading when modules are first accessed
/// - Background preloading of likely-needed modules
/// - Priority-based loading queue
/// - Memory usage tracking per module
///
/// Example usage:
/// ```swift
/// let loader = LazyModuleLoader.shared
/// try await loader.initialize(with: tui)
/// try await loader.loadModule("servers")
/// ```
@MainActor
final class LazyModuleLoader {
    /// Shared singleton instance
    static let shared = LazyModuleLoader()

    // MARK: - Private Properties

    /// Modules that have been loaded
    private var loadedModules: Set<String> = []

    /// Modules currently being loaded
    private var loadingModules: Set<String> = []

    /// Priority queue for pending loads
    private var loadQueue: [ModuleLoadRequest] = []

    /// Memory usage per module
    private var memoryUsage: [String: ModuleMemoryUsage] = [:]

    /// Load timing history for statistics
    private var loadTimings: [String: TimeInterval] = [:]

    /// TUI reference for module creation
    private weak var tui: TUI?

    /// Whether the loader has been initialized
    private var isInitialized: Bool = false

    /// Peak queue depth for statistics
    private var peakQueueDepth: Int = 0

    /// Total on-demand load count
    private var onDemandLoadCount: Int = 0

    /// Total preload count
    private var preloadCount: Int = 0

    /// Background preloading task
    private var preloadTask: Task<Void, Never>?

    // MARK: - Module Priority Configuration

    /// Default priorities for modules based on usage patterns
    private let defaultPriorities: [String: ModuleLoadPriority] = [
        "servers": .critical,
        "networks": .critical,
        "volumes": .high,
        "images": .high,
        "flavors": .high,
        "keypairs": .normal,
        "securitygroups": .normal,
        "floatingips": .normal,
        "subnets": .normal,
        "routers": .normal,
        "ports": .low,
        "barbican": .low,
        "swift": .low,
        "servergroups": .background
    ]

    // MARK: - Initialization

    private init() {}

    /// Initialize the lazy loader with TUI context
    ///
    /// - Parameter tui: The TUI instance for module creation
    func initialize(with tui: TUI) async {
        self.tui = tui
        isInitialized = true
        Logger.shared.logInfo("[LazyModuleLoader] Initialized")
    }

    // MARK: - Public API

    /// Load a module by identifier
    ///
    /// This method loads a module on-demand if not already loaded.
    /// If the module is already loading, it waits for completion.
    ///
    /// - Parameter identifier: The module identifier to load
    /// - Throws: ModuleError if loading fails
    func loadModule(_ identifier: String) async throws {
        guard isInitialized else {
            throw ModuleError.invalidState("LazyModuleLoader not initialized")
        }

        // Already loaded
        if loadedModules.contains(identifier) {
            Logger.shared.logDebug("[LazyModuleLoader] Module already loaded: \(identifier)")
            return
        }

        // Wait if already loading
        if loadingModules.contains(identifier) {
            Logger.shared.logDebug("[LazyModuleLoader] Waiting for module to load: \(identifier)")
            try await waitForModule(identifier)
            return
        }

        // Track as on-demand load
        onDemandLoadCount += 1

        let startTime = Date().timeIntervalSinceReferenceDate
        try await performLoad(identifier)
        let loadTime = Date().timeIntervalSinceReferenceDate - startTime

        loadTimings[identifier] = loadTime
        Logger.shared.logPerformance("LazyModuleLoader.loadModule.\(identifier)", duration: loadTime)
    }

    /// Check if a module is loaded
    ///
    /// - Parameter identifier: The module identifier
    /// - Returns: True if the module is loaded
    func isModuleLoaded(_ identifier: String) -> Bool {
        return loadedModules.contains(identifier)
    }

    /// Enqueue a module for background preloading
    ///
    /// - Parameters:
    ///   - identifier: The module identifier
    ///   - priority: Load priority (optional, uses default if not specified)
    func enqueuePreload(_ identifier: String, priority: ModuleLoadPriority? = nil) {
        guard !loadedModules.contains(identifier) && !loadingModules.contains(identifier) else {
            return
        }

        // Check if already in queue
        if loadQueue.contains(where: { $0.identifier == identifier }) {
            return
        }

        let effectivePriority = priority ?? defaultPriorities[identifier] ?? .normal
        let request = ModuleLoadRequest(
            identifier: identifier,
            priority: effectivePriority,
            requestTime: Date(),
            isPreload: true
        )

        loadQueue.append(request)
        loadQueue.sort { $0.priority > $1.priority }

        peakQueueDepth = max(peakQueueDepth, loadQueue.count)

        Logger.shared.logDebug(
            "[LazyModuleLoader] Enqueued preload: \(identifier) (priority: \(effectivePriority))"
        )
    }

    /// Start background preloading of queued modules
    func startBackgroundPreloading() {
        guard preloadTask == nil else { return }

        preloadTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                await self.processPreloadQueue()
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms between loads
            }
        }

        Logger.shared.logInfo("[LazyModuleLoader] Started background preloading")
    }

    /// Stop background preloading
    func stopBackgroundPreloading() {
        preloadTask?.cancel()
        preloadTask = nil
        Logger.shared.logInfo("[LazyModuleLoader] Stopped background preloading")
    }

    /// Preload modules that are likely to be needed based on current view
    ///
    /// - Parameter viewMode: The current view mode
    func preloadForView(_ viewMode: ViewMode) {
        let relatedModules = predictNeededModules(for: viewMode)

        for moduleId in relatedModules {
            enqueuePreload(moduleId)
        }

        if !relatedModules.isEmpty {
            Logger.shared.logDebug(
                "[LazyModuleLoader] Enqueued \(relatedModules.count) modules for view: \(viewMode)"
            )
        }
    }

    /// Get memory usage for a specific module
    ///
    /// - Parameter identifier: The module identifier
    /// - Returns: Memory usage information or nil if not tracked
    func getMemoryUsage(for identifier: String) -> ModuleMemoryUsage? {
        return memoryUsage[identifier]
    }

    /// Get total tracked memory usage
    ///
    /// - Returns: Total memory in bytes
    func getTotalMemoryUsage() -> Int {
        return memoryUsage.values.reduce(0) { $0 + $1.estimatedBytes }
    }

    /// Get loading statistics
    ///
    /// - Returns: Statistics about lazy loading operations
    func getStatistics() -> LazyLoadStatistics {
        let totalRequests = onDemandLoadCount + preloadCount
        let avgLoadTime: Double
        if loadTimings.isEmpty {
            avgLoadTime = 0
        } else {
            avgLoadTime = (loadTimings.values.reduce(0, +) / Double(loadTimings.count)) * 1000
        }

        return LazyLoadStatistics(
            totalRequests: totalRequests,
            onDemandLoads: onDemandLoadCount,
            preloadsCompleted: preloadCount,
            averageLoadTimeMs: avgLoadTime,
            peakQueueDepth: peakQueueDepth,
            totalMemoryBytes: getTotalMemoryUsage()
        )
    }

    /// Unload a module to free memory
    ///
    /// - Parameter identifier: The module identifier to unload
    func unloadModule(_ identifier: String) async {
        guard loadedModules.contains(identifier) else { return }

        await ModuleRegistry.shared.unload(identifier)
        loadedModules.remove(identifier)
        memoryUsage.removeValue(forKey: identifier)
        loadTimings.removeValue(forKey: identifier)

        Logger.shared.logInfo("[LazyModuleLoader] Unloaded module: \(identifier)")
    }

    /// Clear all loaded modules and reset state
    func clear() {
        stopBackgroundPreloading()
        loadedModules.removeAll()
        loadingModules.removeAll()
        loadQueue.removeAll()
        memoryUsage.removeAll()
        loadTimings.removeAll()
        peakQueueDepth = 0
        onDemandLoadCount = 0
        preloadCount = 0

        Logger.shared.logInfo("[LazyModuleLoader] Cleared all state")
    }

    // MARK: - Private Methods

    /// Perform the actual module load
    private func performLoad(_ identifier: String) async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        loadingModules.insert(identifier)
        defer { loadingModules.remove(identifier) }

        // Create and register the module
        let module = try createModule(identifier, tui: tui)
        try await ModuleRegistry.shared.register(module)

        // Track memory usage
        trackMemoryUsage(for: module)

        loadedModules.insert(identifier)
        Logger.shared.logInfo("[LazyModuleLoader] Loaded module: \(identifier)")
    }

    /// Create a module instance by identifier
    private func createModule(_ identifier: String, tui: TUI) throws -> any OpenStackModule {
        switch identifier {
        case "barbican":
            return BarbicanModule(tui: tui)
        case "swift":
            return SwiftModule(tui: tui)
        case "keypairs":
            return KeyPairsModule(tui: tui)
        case "servergroups":
            return ServerGroupsModule(tui: tui)
        case "flavors":
            return FlavorsModule(tui: tui)
        case "images":
            return ImagesModule(tui: tui)
        case "securitygroups":
            return SecurityGroupsModule(tui: tui)
        case "volumes":
            return VolumesModule(tui: tui)
        case "networks":
            return NetworksModule(tui: tui)
        case "subnets":
            return SubnetsModule(tui: tui)
        case "routers":
            return RoutersModule(tui: tui)
        case "floatingips":
            return FloatingIPsModule(tui: tui)
        case "ports":
            return PortsModule(tui: tui)
        case "servers":
            return ServersModule(tui: tui)
        default:
            throw ModuleError.invalidState("Unknown module identifier: \(identifier)")
        }
    }

    /// Wait for a module that is currently loading
    private func waitForModule(_ identifier: String) async throws {
        let maxWaitTime: TimeInterval = 30.0
        let checkInterval: UInt64 = 50_000_000 // 50ms

        let startTime = Date().timeIntervalSinceReferenceDate

        while loadingModules.contains(identifier) {
            if Date().timeIntervalSinceReferenceDate - startTime > maxWaitTime {
                throw ModuleError.invalidState("Timeout waiting for module: \(identifier)")
            }
            try await Task.sleep(nanoseconds: checkInterval)
        }

        if !loadedModules.contains(identifier) {
            throw ModuleError.invalidState("Module failed to load: \(identifier)")
        }
    }

    /// Process the preload queue
    private func processPreloadQueue() async {
        guard !loadQueue.isEmpty else { return }
        let request = loadQueue.removeFirst()

        // Skip if already loaded or loading
        if loadedModules.contains(request.identifier) || loadingModules.contains(request.identifier) {
            return
        }

        do {
            let startTime = Date().timeIntervalSinceReferenceDate
            try await performLoad(request.identifier)
            let loadTime = Date().timeIntervalSinceReferenceDate - startTime

            loadTimings[request.identifier] = loadTime
            preloadCount += 1

            Logger.shared.logPerformance(
                "LazyModuleLoader.preload.\(request.identifier)",
                duration: loadTime
            )
        } catch {
            Logger.shared.logError(
                "[LazyModuleLoader] Preload failed for \(request.identifier)",
                error: error
            )
        }
    }

    /// Track memory usage for a loaded module
    private func trackMemoryUsage(for module: any OpenStackModule) {
        let views = module.registerViews()
        let forms = module.registerFormHandlers()
        let actions = module.registerActions()

        // Estimate memory based on registered components
        // This is a rough estimate based on typical component sizes
        let estimatedBytes =
            (views.count * 2048) +    // ~2KB per view
            (forms.count * 1024) +    // ~1KB per form
            (actions.count * 512) +   // ~512B per action
            4096                       // Base module overhead

        let usage = ModuleMemoryUsage(
            identifier: module.identifier,
            estimatedBytes: estimatedBytes,
            viewCount: views.count,
            actionCount: actions.count,
            formCount: forms.count,
            timestamp: Date()
        )

        memoryUsage[module.identifier] = usage
    }

    /// Predict modules that might be needed based on current view
    private func predictNeededModules(for viewMode: ViewMode) -> [String] {
        var predictions: [String] = []

        // Predict based on view mode patterns
        switch viewMode {
        case .servers, .serverDetail, .serverCreate:
            predictions = ["networks", "images", "flavors", "keypairs", "volumes", "securitygroups"]
        case .networks, .networkDetail:
            predictions = ["subnets", "routers", "ports", "floatingips"]
        case .volumes, .volumeDetail:
            predictions = ["servers"]
        case .floatingIPs, .floatingIPDetail:
            predictions = ["servers", "ports"]
        case .securityGroups, .securityGroupDetail:
            predictions = ["servers"]
        case .subnets, .subnetDetail:
            predictions = ["networks", "routers"]
        case .routers, .routerDetail:
            predictions = ["networks", "subnets"]
        default:
            break
        }

        // Filter out already loaded modules
        return predictions.filter { !loadedModules.contains($0) }
    }
}
