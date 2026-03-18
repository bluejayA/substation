// Sources/Substation/Core/FeatureFlags.swift
import Foundation

/// Feature flags for gradual module system rollout
struct FeatureFlags {
    /// Enable/disable entire module system
    /// Default: true (module system enabled by default)
    static var useModuleSystem: Bool {
        #if DEBUG
        if let envValue = ProcessInfo.processInfo.environment["USE_MODULE_SYSTEM"] {
            return envValue.lowercased() != "false"
        }
        return true  // Module system enabled by default
        #else
        // Check if key exists - bool(forKey:) returns false for missing keys
        // but we want to default to true when not explicitly set
        if UserDefaults.standard.object(forKey: "useModuleSystem") != nil {
            return UserDefaults.standard.bool(forKey: "useModuleSystem")
        }
        return true  // Module system enabled by default
        #endif
    }

    /// Which modules are enabled (default: all available modules)
    static var enabledModules: Set<String> {
        #if DEBUG
        if let enabled = ProcessInfo.processInfo.environment["ENABLED_MODULES"] {
            // Parse comma-separated list from environment
            let moduleList = enabled.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            return Set(moduleList)
        }
        #else
        if let stored = UserDefaults.standard.array(forKey: "enabledModules") as? [String] {
            return Set(stored)
        }
        #endif
        // Modules enabled by default (excludes disabledByDefault modules)
        return ModuleCatalog.defaultEnabledModuleIdentifiers
    }

    /// Clear all modules (for testing)
    static func clearModules() {
        // This is a no-op for environment-based flags
        // Used in tests to reset state
    }
}
