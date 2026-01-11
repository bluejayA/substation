// Sources/Substation/Modules/Core/ModuleCatalog.swift
import Foundation

/// Catalog of all available OpenStack modules
///
/// Provides a central registry of module metadata without instantiating modules.
/// Used by FeatureFlags to determine available modules and by ModuleRegistry
/// to load modules in the correct dependency order.
enum ModuleCatalog {

    /// Module definition containing metadata for registration
    struct ModuleDefinition {
        /// Unique identifier for the module
        let identifier: String

        /// Human-readable display name
        let displayName: String

        /// Module dependencies (identifiers of required modules)
        let dependencies: [String]

        /// Load phase for dependency ordering
        let phase: LoadPhase
    }

    /// Load phases for dependency ordering
    enum LoadPhase: Int, Comparable {
        /// No dependencies - load first
        case independent = 1

        /// Depends on networks - load second
        case networkDependent = 2

        /// Multiple dependencies - load last
        case multiDependent = 3

        static func < (lhs: LoadPhase, rhs: LoadPhase) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    /// All available module definitions
    ///
    /// This is the single source of truth for available modules.
    /// When adding a new module, add its definition here.
    static let availableModules: [ModuleDefinition] = [
        // Phase 1: Independent modules (no dependencies)
        ModuleDefinition(
            identifier: "barbican",
            displayName: "Key Manager (Barbican)",
            dependencies: [],
            phase: .independent
        ),
        ModuleDefinition(
            identifier: "swift",
            displayName: "Object Storage (Swift)",
            dependencies: [],
            phase: .independent
        ),
        ModuleDefinition(
            identifier: "keypairs",
            displayName: "Key Pairs",
            dependencies: [],
            phase: .independent
        ),
        ModuleDefinition(
            identifier: "servergroups",
            displayName: "Server Groups",
            dependencies: [],
            phase: .independent
        ),
        ModuleDefinition(
            identifier: "flavors",
            displayName: "Flavors",
            dependencies: [],
            phase: .independent
        ),
        ModuleDefinition(
            identifier: "hypervisors",
            displayName: "Hypervisors",
            dependencies: [],
            phase: .independent
        ),
        ModuleDefinition(
            identifier: "images",
            displayName: "Images",
            dependencies: [],
            phase: .independent
        ),
        ModuleDefinition(
            identifier: "securitygroups",
            displayName: "Security Groups",
            dependencies: [],
            phase: .independent
        ),
        ModuleDefinition(
            identifier: "volumes",
            displayName: "Volumes",
            dependencies: [],
            phase: .independent
        ),
        ModuleDefinition(
            identifier: "magnum",
            displayName: "Container Infra (Magnum)",
            dependencies: [],
            phase: .independent
        ),

        // Phase 2: Network-dependent modules
        ModuleDefinition(
            identifier: "networks",
            displayName: "Networks",
            dependencies: [],
            phase: .networkDependent
        ),
        ModuleDefinition(
            identifier: "subnets",
            displayName: "Subnets",
            dependencies: ["networks"],
            phase: .networkDependent
        ),
        ModuleDefinition(
            identifier: "routers",
            displayName: "Routers",
            dependencies: ["networks"],
            phase: .networkDependent
        ),
        ModuleDefinition(
            identifier: "floatingips",
            displayName: "Floating IPs",
            dependencies: ["networks"],
            phase: .networkDependent
        ),
        ModuleDefinition(
            identifier: "ports",
            displayName: "Ports",
            dependencies: ["networks"],
            phase: .networkDependent
        ),

        // Phase 3: Multi-dependent modules
        ModuleDefinition(
            identifier: "servers",
            displayName: "Servers",
            dependencies: ["networks", "images", "flavors", "keypairs", "volumes", "securitygroups"],
            phase: .multiDependent
        )
    ]

    /// All available module identifiers
    ///
    /// Returns the set of all module identifiers from the catalog.
    /// Used by FeatureFlags as the default set of enabled modules.
    static var allModuleIdentifiers: Set<String> {
        return Set(availableModules.map { $0.identifier })
    }

    /// Get module definition by identifier
    ///
    /// - Parameter identifier: The module identifier
    /// - Returns: The module definition, or nil if not found
    static func definition(for identifier: String) -> ModuleDefinition? {
        return availableModules.first { $0.identifier == identifier }
    }

    /// Get modules sorted by load phase
    ///
    /// Returns modules in dependency order for safe loading.
    static var modulesByLoadOrder: [ModuleDefinition] {
        return availableModules.sorted { $0.phase < $1.phase }
    }

    /// Total number of available modules
    static var moduleCount: Int {
        return availableModules.count
    }
}
