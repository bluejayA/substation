// Sources/Substation/Modules/Core/ModuleRegistry.swift
import Foundation

/// Central registry for managing all loaded modules
@MainActor
final class ModuleRegistry {
    static let shared = ModuleRegistry()

    private var modules: [String: any OpenStackModule] = [:]
    private var loadOrder: [String] = []
    private weak var tui: TUI?

    /// Mapping from ViewMode to module identifier for dynamic navigation routing
    private var viewModeToModule: [ViewMode: String] = [:]

    private init() {}

    /// Initialize registry with TUI context
    func initialize(with tui: TUI) async throws {
        self.tui = tui
        Logger.shared.logInfo("[ModuleRegistry] Initializing module system")

        if FeatureFlags.useModuleSystem {
            // Load configuration before loading modules
            do {
                try ModuleConfigurationManager.shared.loadConfiguration()
                Logger.shared.logInfo("[ModuleRegistry] Module configuration loaded")
            } catch {
                Logger.shared.logWarning(
                    "[ModuleRegistry] Failed to load configuration, using defaults",
                    context: ["error": String(describing: error)]
                )
            }

            try await loadCoreModules()
        } else {
            Logger.shared.logInfo("[ModuleRegistry] Module system disabled by feature flag")
        }
    }

    /// Register a module
    func register(_ module: any OpenStackModule) async throws {
        // Check if module is enabled in configuration
        let configManager = ModuleConfigurationManager.shared
        if !configManager.isModuleEnabled(module.identifier) {
            Logger.shared.logInfo(
                "[ModuleRegistry] Module '\(module.identifier)' is disabled in configuration, skipping"
            )
            return
        }

        // Validate dependencies
        for dep in module.dependencies {
            guard modules[dep] != nil else {
                throw ModuleError.missingDependency("Module '\(module.identifier)' requires '\(dep)' but it is not loaded")
            }
        }

        // Register configuration schema
        let schema = module.configurationSchema
        if !schema.entries.isEmpty {
            configManager.registerSchema(schema, for: module.identifier)
        }

        // Load module configuration
        let moduleConfig = configManager.configuration(for: module.identifier)
        module.loadConfiguration(moduleConfig)

        // Validate configuration against schema
        let validationErrors = configManager.validateConfiguration(for: module.identifier)
        if !validationErrors.isEmpty {
            Logger.shared.logWarning(
                "[ModuleRegistry] Configuration validation warnings for '\(module.identifier)'",
                context: ["errors": validationErrors.joined(separator: "; ")]
            )
        }

        // Configure module
        do {
            try await module.configure()
        } catch {
            throw ModuleError.configurationFailed("Failed to configure module '\(module.identifier)': \(error)")
        }

        // Store module
        modules[module.identifier] = module
        loadOrder.append(module.identifier)

        Logger.shared.logInfo("[ModuleRegistry] Registered module: \(module.identifier) (\(module.displayName))")

        // Register module components with TUI
        await integrateModule(module)
    }

    /// Integrate module with TUI
    private func integrateModule(_ module: any OpenStackModule) async {
        // Register views
        let views = module.registerViews()
        for view in views {
            ViewRegistry.shared.register(view)
        }

        // Register form handlers
        let forms = module.registerFormHandlers()
        for form in forms {
            FormRegistry.shared.register(form)
        }

        // Register data handlers
        let dataHandlers = module.registerDataRefreshHandlers()
        for handler in dataHandlers {
            DataRefreshRegistry.shared.register(handler)
        }

        // Register actions
        let actions = module.registerActions()
        ActionRegistry.shared.register(actions)

        if !actions.isEmpty {
            Logger.shared.logDebug("[ModuleRegistry] Registered \(actions.count) actions for \(module.identifier)", context: [:])
        }

        // Register view mode mappings for dynamic navigation routing
        let handledViews = module.handledViewModes
        for viewMode in handledViews {
            viewModeToModule[viewMode] = module.identifier
        }

        if !handledViews.isEmpty {
            Logger.shared.logDebug("[ModuleRegistry] Registered \(handledViews.count) view modes for \(module.identifier)", context: [:])
        }
    }

    /// Get navigation provider for a specific view mode
    ///
    /// Dynamically routes to the appropriate module based on registered view modes.
    /// This eliminates the need for hardcoded switch statements in TUI.swift.
    ///
    /// - Parameter viewMode: The current view mode
    /// - Returns: The navigation provider for the module that handles this view, or nil
    func navigationProvider(for viewMode: ViewMode) -> (any ModuleNavigationProvider)? {
        guard let moduleIdentifier = viewModeToModule[viewMode],
              let module = modules[moduleIdentifier] else {
            return nil
        }
        return module.navigationProvider
    }

    /// Get module by identifier
    func module(for identifier: String) -> (any OpenStackModule)? {
        return modules[identifier]
    }

    /// Get all loaded modules
    func allModules() -> [(any OpenStackModule)] {
        return loadOrder.compactMap { modules[$0] }
    }

    /// Unload a module
    func unload(_ identifier: String) async {
        guard let module = modules[identifier] else { return }
        await module.cleanup()

        // Remove view mode mappings for this module
        let handledViews = module.handledViewModes
        for viewMode in handledViews {
            viewModeToModule.removeValue(forKey: viewMode)
        }

        modules.removeValue(forKey: identifier)
        loadOrder.removeAll { $0 == identifier }
        Logger.shared.logInfo("[ModuleRegistry] Unloaded module: \(identifier)")
    }

    /// Health check all modules
    func healthCheckAll() async -> [String: ModuleHealthStatus] {
        var results: [String: ModuleHealthStatus] = [:]
        for (id, module) in modules {
            results[id] = await module.healthCheck()
        }
        return results
    }

    /// Clear all modules (for testing)
    func clear() {
        modules.removeAll()
        loadOrder.removeAll()
        viewModeToModule.removeAll()
    }

    // MARK: - Hot Reload Support

    /// Reload a specific module by identifier
    ///
    /// This method performs a hot-reload of the specified module, preserving
    /// state where possible and re-registering all components with the TUI.
    ///
    /// - Parameters:
    ///   - identifier: The module identifier to reload
    ///   - configuration: Optional reload configuration
    /// - Returns: Result of the reload operation
    func reloadModule(
        _ identifier: String,
        configuration: HotReloadConfiguration = .default
    ) async -> HotReloadResult {
        Logger.shared.logInfo("[ModuleRegistry] Reload requested for module: \(identifier)")

        // Ensure hot-reload manager is initialized
        if let tui = tui {
            HotReloadManager.shared.initialize(moduleRegistry: self, tui: tui)
        }

        return await HotReloadManager.shared.reloadModule(identifier, configuration: configuration)
    }

    /// Reload all modules in dependency order
    ///
    /// This method performs a hot-reload of all registered modules, respecting
    /// dependency order to ensure modules are reloaded after their dependencies.
    ///
    /// - Parameter configuration: Optional reload configuration
    /// - Returns: Array of reload results for all modules
    func reloadAll(
        configuration: HotReloadConfiguration = .default
    ) async -> [HotReloadResult] {
        Logger.shared.logInfo("[ModuleRegistry] Reload all modules requested")

        // Ensure hot-reload manager is initialized
        if let tui = tui {
            HotReloadManager.shared.initialize(moduleRegistry: self, tui: tui)
        }

        return await HotReloadManager.shared.reloadAll(configuration: configuration)
    }

    /// Check if a module supports hot-reload
    ///
    /// - Parameter identifier: The module identifier to check
    /// - Returns: True if the module can be hot-reloaded
    func canReload(_ identifier: String) -> Bool {
        return HotReloadManager.shared.canReload(identifier)
    }

    /// Create a state snapshot for a module before operations
    ///
    /// This can be used to save state before potentially destructive operations.
    ///
    /// - Parameter identifier: The module identifier
    /// - Returns: The saved state, or nil if not supported
    func createStateSnapshot(_ identifier: String) async -> (any ModuleState)? {
        return await HotReloadManager.shared.createStateSnapshot(identifier)
    }

    /// Restore a state snapshot for a module
    ///
    /// - Parameters:
    ///   - identifier: The module identifier
    ///   - state: The state to restore
    /// - Returns: True if restoration was successful
    func restoreStateSnapshot(_ identifier: String, state: any ModuleState) async -> Bool {
        return await HotReloadManager.shared.restoreStateSnapshot(identifier, state: state)
    }

    /// Get reload status for all modules
    ///
    /// - Returns: Dictionary mapping module identifiers to their last reload result
    func getReloadStatus() -> [String: HotReloadResult] {
        var status: [String: HotReloadResult] = [:]
        for identifier in loadOrder {
            if let result = HotReloadManager.shared.getLastReloadResult(identifier) {
                status[identifier] = result
            }
        }
        return status
    }

    /// Load all core modules in dependency order
    private func loadCoreModules() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI not set")
        }

        let enabledModules = FeatureFlags.enabledModules
        Logger.shared.logInfo("[ModuleRegistry] Loading \(enabledModules.count) enabled modules")

        // Register standard batch operation builders before loading modules
        // This enables the decentralized batch operation building system
        registerStandardBatchOperationBuilders()
        Logger.shared.logInfo(
            "[ModuleRegistry] Registered standard batch operation builders"
        )

        // Phase 1: Load modules with no dependencies

        // Security modules
        if enabledModules.contains("barbican") {
            let module = BarbicanModule(tui: tui)
            try await register(module)
        }

        // Object storage
        if enabledModules.contains("swift") {
            let module = SwiftModule(tui: tui)
            try await register(module)
        }

        // Compute resources (no dependencies)
        if enabledModules.contains("keypairs") {
            let module = KeyPairsModule(tui: tui)
            try await register(module)
        }

        if enabledModules.contains("servergroups") {
            let module = ServerGroupsModule(tui: tui)
            try await register(module)
        }

        if enabledModules.contains("flavors") {
            let module = FlavorsModule(tui: tui)
            try await register(module)
        }

        if enabledModules.contains("images") {
            let module = ImagesModule(tui: tui)
            try await register(module)
        }

        // Security groups (no dependencies)
        if enabledModules.contains("securitygroups") {
            let module = SecurityGroupsModule(tui: tui)
            try await register(module)
        }

        // Storage (no dependencies)
        if enabledModules.contains("volumes") {
            let module = VolumesModule(tui: tui)
            try await register(module)
        }

        // Phase 2: Load modules that depend on Networks

        // Networks module (dependency for Subnets, Routers, FloatingIPs, Ports)
        if enabledModules.contains("networks") {
            let module = NetworksModule(tui: tui)
            try await register(module)
        }

        // Subnets depends on Networks
        if enabledModules.contains("subnets") {
            let module = SubnetsModule(tui: tui)
            try await register(module)
        }

        // Routers depends on Networks
        if enabledModules.contains("routers") {
            let module = RoutersModule(tui: tui)
            try await register(module)
        }

        // FloatingIPs depends on Networks
        if enabledModules.contains("floatingips") {
            let module = FloatingIPsModule(tui: tui)
            try await register(module)
        }

        // Ports depends on Networks
        if enabledModules.contains("ports") {
            let module = PortsModule(tui: tui)
            try await register(module)
        }

        // Phase 3: Load modules with multiple dependencies

        // Servers depends on networks, images, flavors, keypairs, volumes, securitygroups
        if enabledModules.contains("servers") {
            let module = ServersModule(tui: tui)
            try await register(module)
        }

        Logger.shared.logInfo("[ModuleRegistry] Successfully loaded \(modules.count) modules")
    }
}
