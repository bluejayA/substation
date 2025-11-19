// Sources/Substation/Modules/Core/ModuleRegistry.swift
import Foundation

/// Central registry for managing all loaded modules
@MainActor
final class ModuleRegistry {
    static let shared = ModuleRegistry()

    private var modules: [String: any OpenStackModule] = [:]
    private var loadOrder: [String] = []
    private weak var tui: TUI?

    private init() {}

    /// Initialize registry with TUI context
    func initialize(with tui: TUI) async throws {
        self.tui = tui
        Logger.shared.logInfo("[ModuleRegistry] Initializing module system")

        if FeatureFlags.useModuleSystem {
            try await loadCoreModules()
        } else {
            Logger.shared.logInfo("[ModuleRegistry] Module system disabled by feature flag")
        }
    }

    /// Register a module
    func register(_ module: any OpenStackModule) async throws {
        // Validate dependencies
        for dep in module.dependencies {
            guard modules[dep] != nil else {
                throw ModuleError.missingDependency("Module '\(module.identifier)' requires '\(dep)' but it is not loaded")
            }
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
    }

    /// Load all core modules in dependency order
    private func loadCoreModules() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI not set")
        }

        let enabledModules = FeatureFlags.enabledModules
        Logger.shared.logInfo("[ModuleRegistry] Loading \(enabledModules.count) enabled modules")

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
