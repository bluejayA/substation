// Sources/Substation/Framework/ModuleOrchestrator.swift
import Foundation

/// Manages module system lifecycle
/// Handles module registration, initialization, and feature flag checking
@MainActor
final class ModuleOrchestrator {

    // MARK: - Properties

    /// The module registry (nil if module system failed to initialize)
    private(set) var moduleRegistry: ModuleRegistry?

    /// Whether the module system is enabled and loaded
    var isModuleSystemActive: Bool {
        return moduleRegistry != nil
    }

    // MARK: - Initialization

    init() {
        // Registry will be initialized later when TUI is available
    }

    /// Initialize the module system with a TUI reference
    /// - Parameter tui: The TUI instance to initialize with
    /// - Throws: ModuleError if initialization fails
    func initialize(with tui: TUI) async throws {
        guard FeatureFlags.useModuleSystem else {
            Logger.shared.logDebug("Module system disabled via FeatureFlags")
            return
        }

        Logger.shared.logInfo("Initializing module system...")

        do {
            try await ModuleRegistry.shared.initialize(with: tui)
            moduleRegistry = ModuleRegistry.shared

            let allModules = ModuleRegistry.shared.allModules()
            Logger.shared.logInfo("Module system initialized: \(allModules.count) modules loaded")
        } catch {
            Logger.shared.logError("Failed to initialize module system", context: [
                "error": String(describing: error)
            ])
            // Module system is optional, continue without it
            moduleRegistry = nil
            throw error
        }
    }

    // MARK: - Module Access

    /// Get all loaded modules
    /// - Returns: Array of all registered OpenStack modules
    func allModules() -> [any OpenStackModule] {
        return moduleRegistry?.allModules() ?? []
    }

    /// Get a specific module by identifier
    /// - Parameter identifier: The unique identifier of the module
    /// - Returns: The module if found, nil otherwise
    func module(identifier: String) -> (any OpenStackModule)? {
        return moduleRegistry?.module(for: identifier)
    }

    /// Get module count
    var moduleCount: Int {
        return moduleRegistry?.allModules().count ?? 0
    }

    // MARK: - Module Operations

    /// Reload all modules
    /// - Parameter tui: The TUI instance to reload with
    /// - Throws: ModuleError if reinitialization fails
    func reloadModules(with tui: TUI) async throws {
        moduleRegistry = nil
        try await initialize(with: tui)
    }

    /// Check module health for all loaded modules
    /// - Returns: Dictionary mapping module identifiers to their health status
    func checkModuleHealth() async -> [String: ModuleHealthStatus] {
        guard let registry = moduleRegistry else {
            return [:]
        }

        var results: [String: ModuleHealthStatus] = [:]
        for module in registry.allModules() {
            results[module.identifier] = await module.healthCheck()
        }
        return results
    }

    /// Unload a specific module
    /// - Parameter identifier: The unique identifier of the module to unload
    func unloadModule(identifier: String) async {
        await moduleRegistry?.unload(identifier)
    }

    /// Clear all modules from the registry
    func clearAllModules() {
        moduleRegistry?.clear()
        moduleRegistry = nil
    }
}
