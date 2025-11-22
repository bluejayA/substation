// Sources/Substation/Modules/Core/HotReloadManager.swift
import Foundation

// MARK: - Module State Types

/// State that can be preserved during a module hot-reload operation
///
/// This protocol allows modules to capture and restore their internal state
/// when being reloaded at runtime. Modules can store any serializable data
/// that needs to persist across the reload operation.
protocol ModuleState: Sendable {
    /// Unique identifier for the state type
    var stateIdentifier: String { get }

    /// Timestamp when the state was captured
    var capturedAt: Date { get }

    /// Version of the state format for compatibility checking
    var stateVersion: String { get }
}

/// Default implementation of module state for simple key-value storage
struct GenericModuleState: ModuleState, Sendable {
    /// Unique identifier for this state
    let stateIdentifier: String

    /// When the state was captured
    let capturedAt: Date

    /// State format version
    let stateVersion: String

    /// Generic key-value storage for state data
    let values: [String: String]

    /// Initialize a generic module state
    /// - Parameters:
    ///   - identifier: Unique identifier for this state
    ///   - version: State format version (default "1.0")
    ///   - values: Key-value pairs to store
    init(identifier: String, version: String = "1.0", values: [String: String] = [:]) {
        self.stateIdentifier = identifier
        self.capturedAt = Date()
        self.stateVersion = version
        self.values = values
    }
}

// MARK: - Hot Reload Result Types

/// Result of a hot-reload operation
enum HotReloadResult: Sendable {
    /// Reload completed successfully
    case success(moduleId: String, duration: TimeInterval)

    /// Reload failed with an error
    case failure(moduleId: String, error: HotReloadError)

    /// Reload was skipped (module does not support hot-reload)
    case skipped(moduleId: String, reason: String)
}

/// Errors that can occur during hot-reload operations
enum HotReloadError: Error, Sendable {
    /// Module does not exist in registry
    case moduleNotFound(String)

    /// Module does not support hot-reload
    case hotReloadNotSupported(String)

    /// Failed to save module state before reload
    case stateSaveFailed(String, String)

    /// Failed to restore module state after reload
    case stateRestoreFailed(String, String)

    /// Module configuration failed during reload
    case configurationFailed(String, String)

    /// Registry re-registration failed
    case registrationFailed(String, String)

    /// Dependency conflict prevents reload
    case dependencyConflict(String, [String])

    /// Version incompatibility detected
    case versionIncompatible(String, String, String)

    /// Reload operation timed out
    case timeout(String, TimeInterval)

    /// Generic reload failure
    case reloadFailed(String, String)
}

// MARK: - Hot Reload Configuration

/// Configuration options for hot-reload operations
struct HotReloadConfiguration: Sendable {
    /// Maximum time allowed for a single module reload
    let timeoutSeconds: TimeInterval

    /// Whether to preserve cache state during reload
    let preserveCache: Bool

    /// Whether to preserve user data during reload
    let preserveUserData: Bool

    /// Whether to re-register all registries during reload
    let reregisterRegistries: Bool

    /// Whether to force reload even if module reports not ready
    let forceReload: Bool

    /// Default configuration
    static let `default` = HotReloadConfiguration(
        timeoutSeconds: 30.0,
        preserveCache: true,
        preserveUserData: true,
        reregisterRegistries: true,
        forceReload: false
    )
}

// MARK: - HotReloadManager

/// Manages hot-reloading of modules at runtime
///
/// The HotReloadManager provides functionality to reload modules without
/// restarting the application. It handles:
/// - State preservation during reload
/// - Registry cleanup and re-registration
/// - Dependency order management
/// - Graceful degradation on failure
///
/// Usage:
/// ```swift
/// let result = await HotReloadManager.shared.reloadModule("servers")
/// switch result {
/// case .success(let moduleId, let duration):
///     print("Reloaded \(moduleId) in \(duration)s")
/// case .failure(let moduleId, let error):
///     print("Failed to reload \(moduleId): \(error)")
/// case .skipped(let moduleId, let reason):
///     print("Skipped \(moduleId): \(reason)")
/// }
/// ```
@MainActor
final class HotReloadManager {

    // MARK: - Singleton

    /// Shared singleton instance
    static let shared = HotReloadManager()

    // MARK: - Private Properties

    /// Reference to module registry
    private weak var moduleRegistry: ModuleRegistry?

    /// Reference to TUI for cache and state access
    private weak var tui: TUI?

    /// Stored module states during reload
    private var savedStates: [String: any ModuleState] = [:]

    /// Currently reloading module IDs
    private var reloadingModules: Set<String> = []

    /// Last reload results for status reporting
    private var lastReloadResults: [String: HotReloadResult] = [:]

    /// Reload operation history
    private var reloadHistory: [(Date, String, HotReloadResult)] = []

    /// Maximum history entries to keep
    private let maxHistoryEntries = 100

    // MARK: - Initialization

    /// Private initializer for singleton
    private init() {}

    /// Initialize the hot-reload manager with dependencies
    /// - Parameters:
    ///   - moduleRegistry: The module registry to manage
    ///   - tui: The TUI instance for state access
    func initialize(moduleRegistry: ModuleRegistry, tui: TUI) {
        self.moduleRegistry = moduleRegistry
        self.tui = tui
        Logger.shared.logInfo("[HotReloadManager] Initialized with module registry and TUI")
    }

    // MARK: - Public Reload Methods

    /// Reload a specific module by identifier
    /// - Parameters:
    ///   - identifier: The module identifier to reload
    ///   - configuration: Reload configuration options
    /// - Returns: Result of the reload operation
    func reloadModule(
        _ identifier: String,
        configuration: HotReloadConfiguration = .default
    ) async -> HotReloadResult {
        let startTime = Date()

        Logger.shared.logInfo("[HotReloadManager] Starting reload of module: \(identifier)")

        // Check if module exists
        guard let registry = moduleRegistry,
              let module = registry.module(for: identifier) else {
            let error = HotReloadError.moduleNotFound(identifier)
            let result = HotReloadResult.failure(moduleId: identifier, error: error)
            recordResult(identifier, result)
            return result
        }

        // Check if module supports hot-reload
        guard canReload(identifier) else {
            let result = HotReloadResult.skipped(
                moduleId: identifier,
                reason: "Module does not support hot-reload"
            )
            recordResult(identifier, result)
            return result
        }

        // Check if already reloading
        guard !reloadingModules.contains(identifier) else {
            let result = HotReloadResult.skipped(
                moduleId: identifier,
                reason: "Module is already being reloaded"
            )
            recordResult(identifier, result)
            return result
        }

        // Mark as reloading
        reloadingModules.insert(identifier)
        defer { reloadingModules.remove(identifier) }

        // Perform reload
        do {
            // Note: Timeout handling removed due to Sendable constraints
            // The reload operation runs on @MainActor
            try await self.performReload(
                module: module,
                identifier: identifier,
                configuration: configuration
            )

            let duration = Date().timeIntervalSince(startTime)
            let successResult = HotReloadResult.success(
                moduleId: identifier,
                duration: duration
            )
            recordResult(identifier, successResult)

            Logger.shared.logInfo(
                "[HotReloadManager] Successfully reloaded \(identifier) in \(String(format: "%.2f", duration))s"
            )

            return successResult

        } catch let error as HotReloadError {
            let result = HotReloadResult.failure(moduleId: identifier, error: error)
            recordResult(identifier, result)
            Logger.shared.logError("[HotReloadManager] Failed to reload \(identifier): \(error)")
            return result

        } catch {
            let reloadError = HotReloadError.reloadFailed(identifier, error.localizedDescription)
            let result = HotReloadResult.failure(moduleId: identifier, error: reloadError)
            recordResult(identifier, result)
            Logger.shared.logError("[HotReloadManager] Failed to reload \(identifier): \(error)")
            return result
        }
    }

    /// Reload all modules in dependency order
    /// - Parameter configuration: Reload configuration options
    /// - Returns: Array of reload results for all modules
    func reloadAll(
        configuration: HotReloadConfiguration = .default
    ) async -> [HotReloadResult] {
        guard let registry = moduleRegistry else {
            Logger.shared.logError("[HotReloadManager] Module registry not available")
            return []
        }

        let allModules = registry.allModules()
        Logger.shared.logInfo("[HotReloadManager] Starting reload of \(allModules.count) modules")

        // Sort modules by dependency order (modules with fewer dependencies first)
        let sortedModules = sortByDependencyOrder(allModules)

        var results: [HotReloadResult] = []

        for module in sortedModules {
            let result = await reloadModule(module.identifier, configuration: configuration)
            results.append(result)

            // Check for failures that might affect dependent modules
            if case .failure = result {
                // Check for dependent modules and skip them
                let dependentModules = findDependentModules(of: module.identifier)
                for depId in dependentModules {
                    let skipResult = HotReloadResult.skipped(
                        moduleId: depId,
                        reason: "Dependency '\(module.identifier)' failed to reload"
                    )
                    results.append(skipResult)
                    recordResult(depId, skipResult)
                }
            }
        }

        // Log summary
        let successCount = results.filter {
            if case .success = $0 { return true }
            return false
        }.count
        let failureCount = results.filter {
            if case .failure = $0 { return true }
            return false
        }.count
        let skippedCount = results.filter {
            if case .skipped = $0 { return true }
            return false
        }.count

        Logger.shared.logInfo(
            "[HotReloadManager] Reload complete: \(successCount) success, \(failureCount) failed, \(skippedCount) skipped"
        )

        return results
    }

    /// Check if a module supports hot-reload
    /// - Parameter identifier: The module identifier
    /// - Returns: True if the module can be hot-reloaded
    func canReload(_ identifier: String) -> Bool {
        guard let registry = moduleRegistry,
              let module = registry.module(for: identifier) else {
            return false
        }

        // Check if module implements HotReloadable protocol
        if let reloadable = module as? any HotReloadable {
            return reloadable.supportsHotReload
        }

        // Default: all modules support basic reload
        return true
    }

    // MARK: - State Management

    /// Create a state snapshot for a module
    /// - Parameter identifier: The module identifier
    /// - Returns: The saved state, or nil if state capture not supported
    func createStateSnapshot(_ identifier: String) async -> (any ModuleState)? {
        guard let registry = moduleRegistry,
              let module = registry.module(for: identifier) else {
            return nil
        }

        if let reloadable = module as? any HotReloadable {
            let state = await reloadable.prepareForReload()
            if let state = state {
                savedStates[identifier] = state
            }
            return state
        }

        return nil
    }

    /// Restore a state snapshot for a module
    /// - Parameters:
    ///   - identifier: The module identifier
    ///   - state: The state to restore
    /// - Returns: True if restoration was successful
    func restoreStateSnapshot(_ identifier: String, state: any ModuleState) async -> Bool {
        guard let registry = moduleRegistry,
              let module = registry.module(for: identifier) else {
            return false
        }

        if let reloadable = module as? any HotReloadable {
            return await reloadable.restoreFromReload(state)
        }

        return false
    }

    // MARK: - Status and History

    /// Get the last reload result for a module
    /// - Parameter identifier: The module identifier
    /// - Returns: The last reload result, if any
    func getLastReloadResult(_ identifier: String) -> HotReloadResult? {
        return lastReloadResults[identifier]
    }

    /// Get all reload history
    /// - Returns: Array of (timestamp, moduleId, result) tuples
    func getReloadHistory() -> [(Date, String, HotReloadResult)] {
        return reloadHistory
    }

    /// Get modules currently being reloaded
    /// - Returns: Set of module identifiers being reloaded
    func getReloadingModules() -> Set<String> {
        return reloadingModules
    }

    /// Clear all saved states and history
    func clearStateAndHistory() {
        savedStates.removeAll()
        lastReloadResults.removeAll()
        reloadHistory.removeAll()
        Logger.shared.logInfo("[HotReloadManager] Cleared all state and history")
    }

    // MARK: - Private Helper Methods

    /// Perform the actual reload operation
    private func performReload(
        module: any OpenStackModule,
        identifier: String,
        configuration: HotReloadConfiguration
    ) async throws {
        guard let _ = moduleRegistry,
              let _ = tui else {
            throw HotReloadError.reloadFailed(identifier, "Registry or TUI not available")
        }

        // Phase 1: Save state
        var savedState: (any ModuleState)?
        if let reloadable = module as? any HotReloadable {
            savedState = await reloadable.prepareForReload()
            if savedState != nil {
                Logger.shared.logDebug("[HotReloadManager] State saved for \(identifier)")
            }
        }

        // Phase 2: Cleanup registries for this module
        await cleanupModuleRegistrations(identifier)

        // Phase 3: Cleanup module
        await module.cleanup()

        // Phase 4: Re-configure module
        do {
            try await module.configure()
        } catch {
            // Attempt to restore previous state on failure
            if let state = savedState,
               let reloadable = module as? any HotReloadable {
                _ = await reloadable.restoreFromReload(state)
            }
            throw HotReloadError.configurationFailed(identifier, error.localizedDescription)
        }

        // Phase 5: Re-register views
        let views = module.registerViews()
        for view in views {
            ViewRegistry.shared.register(view)
        }

        // Phase 6: Re-register form handlers
        let forms = module.registerFormHandlers()
        for form in forms {
            FormRegistry.shared.register(form)
        }

        // Phase 7: Re-register data handlers
        let dataHandlers = module.registerDataRefreshHandlers()
        for handler in dataHandlers {
            DataRefreshRegistry.shared.register(handler)
        }

        // Phase 8: Re-register actions
        let actions = module.registerActions()
        ActionRegistry.shared.register(actions)

        // Phase 9: Restore state
        if let state = savedState,
           let reloadable = module as? any HotReloadable {
            let restored = await reloadable.restoreFromReload(state)
            if !restored {
                Logger.shared.logWarning("[HotReloadManager] State restoration failed for \(identifier)")
            } else {
                Logger.shared.logDebug("[HotReloadManager] State restored for \(identifier)")
            }
        }

        Logger.shared.logDebug("[HotReloadManager] Module \(identifier) reload complete")
    }

    /// Cleanup all registry entries for a specific module
    private func cleanupModuleRegistrations(_ identifier: String) async {
        // Note: Current registry implementations don't support selective removal
        // For a full implementation, registries would need removeForModule(identifier) methods
        // For now, we rely on re-registration overwriting existing entries

        Logger.shared.logDebug("[HotReloadManager] Cleaning up registrations for \(identifier)")
    }

    /// Sort modules by dependency order
    private func sortByDependencyOrder(_ modules: [any OpenStackModule]) -> [any OpenStackModule] {
        var sorted: [any OpenStackModule] = []
        var remaining = modules
        var iterations = 0
        let maxIterations = modules.count * 2

        while !remaining.isEmpty && iterations < maxIterations {
            iterations += 1

            for module in remaining {
                // Check if all dependencies are satisfied
                let dependenciesSatisfied = module.dependencies.allSatisfy { dep in
                    sorted.contains { $0.identifier == dep }
                }

                if dependenciesSatisfied {
                    sorted.append(module)
                    remaining.removeAll { $0.identifier == module.identifier }
                    break
                }
            }
        }

        // Add any remaining modules (with unresolved dependencies)
        sorted.append(contentsOf: remaining)

        return sorted
    }

    /// Find modules that depend on a given module
    private func findDependentModules(of identifier: String) -> [String] {
        guard let registry = moduleRegistry else { return [] }

        return registry.allModules()
            .filter { $0.dependencies.contains(identifier) }
            .map { $0.identifier }
    }

    /// Record a reload result
    private func recordResult(_ identifier: String, _ result: HotReloadResult) {
        lastReloadResults[identifier] = result
        reloadHistory.append((Date(), identifier, result))

        // Trim history if needed
        if reloadHistory.count > maxHistoryEntries {
            reloadHistory.removeFirst(reloadHistory.count - maxHistoryEntries)
        }
    }

    /// Execute an async operation with a timeout
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw HotReloadError.timeout("operation", seconds)
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - HotReloadable Protocol

/// Protocol for modules that support hot-reloading with state preservation
///
/// Modules can implement this protocol to enable advanced hot-reload features
/// including state preservation and restoration during reload operations.
@MainActor
protocol HotReloadable {
    /// Whether this module supports hot-reload
    ///
    /// Return false to prevent hot-reload attempts on this module.
    var supportsHotReload: Bool { get }

    /// Prepare for reload by capturing current state
    ///
    /// Called before the module is cleaned up and re-configured.
    /// Return nil if no state needs to be preserved.
    ///
    /// - Returns: The captured state, or nil
    func prepareForReload() async -> (any ModuleState)?

    /// Restore state after reload
    ///
    /// Called after the module has been re-configured with its registrations.
    /// The state parameter contains the data captured in prepareForReload().
    ///
    /// - Parameter state: The state to restore
    /// - Returns: True if restoration was successful
    func restoreFromReload(_ state: any ModuleState) async -> Bool
}

// MARK: - Default HotReloadable Implementation

extension HotReloadable {
    /// Default implementation supports hot-reload
    var supportsHotReload: Bool { true }

    /// Default implementation preserves no state
    func prepareForReload() async -> (any ModuleState)? { nil }

    /// Default implementation always succeeds (no state to restore)
    func restoreFromReload(_ state: any ModuleState) async -> Bool { true }
}

// MARK: - Reload Command Types

/// Represents a reload command from the command interface
struct ReloadCommand: Sendable {
    /// The type of reload operation
    enum ReloadType: Sendable {
        /// Reload all modules
        case all

        /// Reload a specific module
        case specific(String)
    }

    /// The reload operation type
    let type: ReloadType

    /// Configuration for the reload
    let configuration: HotReloadConfiguration

    /// Parse a reload command string
    /// - Parameter input: The command input (e.g., "reload" or "reload servers")
    /// - Returns: A parsed reload command
    static func parse(_ input: String) -> ReloadCommand? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()

        guard trimmed.hasPrefix("reload") else {
            return nil
        }

        let parts = trimmed.split(separator: " ", maxSplits: 1)

        if parts.count == 1 {
            // :reload - reload all
            return ReloadCommand(type: .all, configuration: .default)
        } else {
            // :reload <module> - reload specific
            let moduleId = String(parts[1]).trimmingCharacters(in: .whitespaces)
            return ReloadCommand(type: .specific(moduleId), configuration: .default)
        }
    }
}
