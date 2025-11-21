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
        return UserDefaults.standard.bool(forKey: "useModuleSystem")
        #endif
    }

    /// Which modules are enabled (default: all 14 modules)
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
        // All 14 modules enabled by default
        return [
            "barbican", "swift", "keypairs", "servergroups",
            "flavors", "images", "securitygroups", "networks",
            "subnets", "volumes", "servers", "routers",
            "floatingips", "ports"
        ]
    }

    /// Clear all modules (for testing)
    static func clearModules() {
        // This is a no-op for environment-based flags
        // Used in tests to reset state
    }
}
