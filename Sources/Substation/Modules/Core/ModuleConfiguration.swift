// Sources/Substation/Modules/Core/ModuleConfiguration.swift
import Foundation

// MARK: - Configuration Value Types

/// Represents a configuration value with type safety and source tracking
///
/// ConfigurationValue wraps a value with metadata about where it came from,
/// enabling debugging and override precedence tracking.
public struct ConfigurationValue<T: Sendable>: Sendable {
    /// The actual configuration value
    public let value: T

    /// Source of this configuration value
    public let source: ConfigurationSource

    /// Create a configuration value with explicit source
    /// - Parameters:
    ///   - value: The configuration value
    ///   - source: Where this value originated
    public init(value: T, source: ConfigurationSource) {
        self.value = value
        self.source = source
    }
}

/// Source of a configuration value for debugging and precedence
public enum ConfigurationSource: Sendable, CustomStringConvertible {
    /// Value from default configuration
    case defaultValue
    /// Value loaded from configuration file
    case file(String)
    /// Value overridden by environment variable
    case environment(String)
    /// Value set programmatically at runtime
    case runtime

    public var description: String {
        switch self {
        case .defaultValue:
            return "default"
        case .file(let path):
            return "file:\(path)"
        case .environment(let variable):
            return "env:\(variable)"
        case .runtime:
            return "runtime"
        }
    }
}

// MARK: - Configuration Schema

/// Schema definition for module configuration validation
///
/// Defines expected keys, types, and constraints for module configuration.
public struct ConfigurationSchema: Sendable {
    /// Schema entries defining valid configuration keys
    public let entries: [SchemaEntry]

    /// Create a configuration schema
    /// - Parameter entries: Array of schema entries
    public init(entries: [SchemaEntry]) {
        self.entries = entries
    }

    /// A single entry in a configuration schema
    /// Note: Uses @unchecked Sendable because defaultValue is Any? which cannot conform to Sendable
    /// This is safe because SchemaEntry is immutable after initialization
    public struct SchemaEntry: @unchecked Sendable {
        /// Configuration key name
        public let key: String
        /// Expected value type
        public let valueType: ValueType
        /// Whether this key is required
        public let required: Bool
        /// Default value if not specified
        public let defaultValue: Any?
        /// Human-readable description
        public let description: String

        /// Create a schema entry
        /// - Parameters:
        ///   - key: Configuration key name
        ///   - valueType: Expected value type
        ///   - required: Whether this key is required
        ///   - defaultValue: Default value if not specified
        ///   - description: Human-readable description
        public init(
            key: String,
            valueType: ValueType,
            required: Bool = false,
            defaultValue: Any? = nil,
            description: String = ""
        ) {
            self.key = key
            self.valueType = valueType
            self.required = required
            self.defaultValue = defaultValue
            self.description = description
        }
    }

    /// Supported configuration value types
    public enum ValueType: Sendable {
        case string
        case int
        case double
        case bool
        case stringArray
        case dictionary
    }
}

// MARK: - Module Configuration

/// Configuration for a single module
///
/// Contains all configuration values for a module with their sources.
public struct ModuleConfig: Sendable {
    /// Module identifier
    public let moduleId: String

    /// Whether the module is enabled
    public var enabled: ConfigurationValue<Bool>

    /// Module-specific configuration values
    public var values: [String: ConfigurationValueHolder]

    /// Create module configuration
    /// - Parameters:
    ///   - moduleId: Module identifier
    ///   - enabled: Whether module is enabled
    ///   - values: Module-specific configuration values
    public init(
        moduleId: String,
        enabled: ConfigurationValue<Bool>,
        values: [String: ConfigurationValueHolder] = [:]
    ) {
        self.moduleId = moduleId
        self.enabled = enabled
        self.values = values
    }

    /// Get a string value
    /// - Parameter key: Configuration key
    /// - Returns: String value if exists and is correct type
    public func getString(_ key: String) -> String? {
        guard let holder = values[key], case .string(let value) = holder.value else {
            return nil
        }
        return value
    }

    /// Get an integer value
    /// - Parameter key: Configuration key
    /// - Returns: Integer value if exists and is correct type
    public func getInt(_ key: String) -> Int? {
        guard let holder = values[key], case .int(let value) = holder.value else {
            return nil
        }
        return value
    }

    /// Get a double value
    /// - Parameter key: Configuration key
    /// - Returns: Double value if exists and is correct type
    public func getDouble(_ key: String) -> Double? {
        guard let holder = values[key], case .double(let value) = holder.value else {
            return nil
        }
        return value
    }

    /// Get a boolean value
    /// - Parameter key: Configuration key
    /// - Returns: Boolean value if exists and is correct type
    public func getBool(_ key: String) -> Bool? {
        guard let holder = values[key], case .bool(let value) = holder.value else {
            return nil
        }
        return value
    }

    /// Get a string array value
    /// - Parameter key: Configuration key
    /// - Returns: String array if exists and is correct type
    public func getStringArray(_ key: String) -> [String]? {
        guard let holder = values[key], case .stringArray(let value) = holder.value else {
            return nil
        }
        return value
    }
}

/// Type-erased configuration value holder
public struct ConfigurationValueHolder: Sendable {
    /// The wrapped value
    public let value: ConfigValue
    /// Source of this value
    public let source: ConfigurationSource

    /// Create a value holder
    /// - Parameters:
    ///   - value: The configuration value
    ///   - source: Source of the value
    public init(value: ConfigValue, source: ConfigurationSource) {
        self.value = value
        self.source = source
    }
}

/// Type-safe configuration value container
public enum ConfigValue: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])
    case dictionary([String: String])
}

// MARK: - Global Configuration

/// Global configuration settings
///
/// Contains application-wide settings that apply to all modules.
public struct GlobalConfig: Sendable {
    /// Default refresh interval in seconds
    public var refreshInterval: ConfigurationValue<Int>

    /// Cache size limit in megabytes
    public var cacheSizeMB: ConfigurationValue<Int>

    /// Log level setting
    public var logLevel: ConfigurationValue<String>

    /// Whether to enable performance metrics
    public var enableMetrics: ConfigurationValue<Bool>

    /// Create global configuration with defaults
    public init() {
        self.refreshInterval = ConfigurationValue(value: 30, source: .defaultValue)
        self.cacheSizeMB = ConfigurationValue(value: 100, source: .defaultValue)
        self.logLevel = ConfigurationValue(value: "info", source: .defaultValue)
        self.enableMetrics = ConfigurationValue(value: false, source: .defaultValue)
    }
}

// MARK: - Configuration Manager

/// Manages application and module configuration
///
/// ModuleConfigurationManager is responsible for:
/// - Loading configuration from files (YAML or JSON)
/// - Applying environment variable overrides
/// - Providing default values
/// - Validating configuration schemas
/// - Hot-reloading configuration changes
@MainActor
public final class ModuleConfigurationManager {

    // MARK: - Singleton

    /// Shared configuration manager instance
    public static let shared = ModuleConfigurationManager()

    // MARK: - Properties

    /// Global configuration settings
    private(set) var globalConfig: GlobalConfig

    /// Per-module configuration
    private var moduleConfigs: [String: ModuleConfig] = [:]

    /// Path to loaded configuration file
    private(set) var loadedConfigPath: String?

    /// Configuration file modification date for hot-reload
    private var configFileModificationDate: Date?

    /// Registered module schemas for validation
    private var moduleSchemas: [String: ConfigurationSchema] = [:]

    /// Configuration load errors
    private(set) var loadErrors: [String] = []

    /// Configuration warnings
    private(set) var loadWarnings: [String] = []

    // MARK: - Initialization

    private init() {
        self.globalConfig = GlobalConfig()
    }

    // MARK: - Configuration Loading

    /// Load configuration from default path
    ///
    /// Attempts to load from ~/.config/substation/modules.yaml first,
    /// then falls back to modules.json if YAML not found.
    /// - Throws: ConfigurationError if loading fails critically
    public func loadConfiguration() throws {
        loadErrors.removeAll()
        loadWarnings.removeAll()

        let yamlPath = "\(AppConstants.configDirectory)/modules.yaml"
        let jsonPath = "\(AppConstants.configDirectory)/modules.json"

        if FileManager.default.fileExists(atPath: yamlPath) {
            try loadFromFile(path: yamlPath)
        } else if FileManager.default.fileExists(atPath: jsonPath) {
            try loadFromFile(path: jsonPath)
        } else {
            Logger.shared.logInfo(
                "No configuration file found, using defaults",
                context: ["yaml_path": yamlPath, "json_path": jsonPath]
            )
            applyDefaults()
        }

        // Apply environment variable overrides
        applyEnvironmentOverrides()

        Logger.shared.logInfo("Configuration loaded", context: [
            "source": loadedConfigPath ?? "defaults",
            "modules": moduleConfigs.count,
            "warnings": loadWarnings.count,
            "errors": loadErrors.count
        ])
    }

    /// Load configuration from a specific file path
    /// - Parameter path: Path to configuration file
    /// - Throws: ConfigurationError if file cannot be read or parsed
    public func loadFromFile(path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConfigurationError.fileNotFound(path)
        }

        let url = URL(fileURLWithPath: path)

        do {
            let data = try Data(contentsOf: url)
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            configFileModificationDate = attributes[.modificationDate] as? Date

            if path.hasSuffix(".yaml") || path.hasSuffix(".yml") {
                try parseYAML(data, path: path)
            } else if path.hasSuffix(".json") {
                try parseJSON(data, path: path)
            } else {
                throw ConfigurationError.unsupportedFormat(path)
            }

            loadedConfigPath = path
        } catch let error as ConfigurationError {
            throw error
        } catch {
            throw ConfigurationError.readFailed(path, error)
        }
    }

    /// Reload configuration from previously loaded file
    /// - Returns: True if configuration was reloaded
    @discardableResult
    public func reloadConfiguration() throws -> Bool {
        guard let path = loadedConfigPath else {
            try loadConfiguration()
            return true
        }

        // Check if file has been modified
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let newModDate = attributes[.modificationDate] as? Date else {
            return false
        }

        if let oldModDate = configFileModificationDate, newModDate <= oldModDate {
            return false
        }

        // Reload
        moduleConfigs.removeAll()
        globalConfig = GlobalConfig()

        try loadFromFile(path: path)
        applyEnvironmentOverrides()

        Logger.shared.logInfo("Configuration reloaded", context: [
            "path": path
        ])

        return true
    }

    // MARK: - Configuration Access

    /// Get configuration for a specific module
    /// - Parameter moduleId: Module identifier
    /// - Returns: Module configuration if available
    public func configuration(for moduleId: String) -> ModuleConfig? {
        return moduleConfigs[moduleId]
    }

    /// Check if a module is enabled
    /// - Parameter moduleId: Module identifier
    /// - Returns: True if module is enabled (defaults to true)
    public func isModuleEnabled(_ moduleId: String) -> Bool {
        return moduleConfigs[moduleId]?.enabled.value ?? true
    }

    /// Get all loaded module configurations
    /// - Returns: Dictionary of module configurations
    public func allModuleConfigurations() -> [String: ModuleConfig] {
        return moduleConfigs
    }

    /// Get configuration value for a module
    /// - Parameters:
    ///   - key: Configuration key
    ///   - moduleId: Module identifier
    /// - Returns: Configuration value holder if exists
    public func getValue(_ key: String, for moduleId: String) -> ConfigurationValueHolder? {
        return moduleConfigs[moduleId]?.values[key]
    }

    // MARK: - Schema Management

    /// Register a configuration schema for a module
    /// - Parameters:
    ///   - schema: Configuration schema
    ///   - moduleId: Module identifier
    public func registerSchema(_ schema: ConfigurationSchema, for moduleId: String) {
        moduleSchemas[moduleId] = schema
        Logger.shared.logDebug("Registered configuration schema for \(moduleId)", context: [
            "entries": schema.entries.count
        ])
    }

    /// Validate configuration against registered schema
    /// - Parameter moduleId: Module identifier to validate
    /// - Returns: Array of validation error messages
    public func validateConfiguration(for moduleId: String) -> [String] {
        guard let schema = moduleSchemas[moduleId] else {
            return []
        }

        guard let config = moduleConfigs[moduleId] else {
            // Check for required entries
            return schema.entries
                .filter { $0.required }
                .map { "Missing required configuration: \($0.key)" }
        }

        var errors: [String] = []

        // Check required entries
        for entry in schema.entries where entry.required {
            if config.values[entry.key] == nil {
                errors.append("Missing required configuration: \(entry.key)")
            }
        }

        // Check unknown keys
        for key in config.values.keys {
            if !schema.entries.contains(where: { $0.key == key }) {
                loadWarnings.append("Unknown configuration key '\(key)' for module '\(moduleId)'")
            }
        }

        return errors
    }

    // MARK: - Configuration Updates

    /// Set a configuration value at runtime
    /// - Parameters:
    ///   - value: Configuration value
    ///   - key: Configuration key
    ///   - moduleId: Module identifier
    public func setValue(_ value: ConfigValue, for key: String, moduleId: String) {
        if moduleConfigs[moduleId] == nil {
            moduleConfigs[moduleId] = ModuleConfig(
                moduleId: moduleId,
                enabled: ConfigurationValue(value: true, source: .runtime)
            )
        }

        moduleConfigs[moduleId]?.values[key] = ConfigurationValueHolder(
            value: value,
            source: .runtime
        )
    }

    /// Set module enabled state at runtime
    /// - Parameters:
    ///   - enabled: Whether module is enabled
    ///   - moduleId: Module identifier
    public func setModuleEnabled(_ enabled: Bool, moduleId: String) {
        if moduleConfigs[moduleId] == nil {
            moduleConfigs[moduleId] = ModuleConfig(
                moduleId: moduleId,
                enabled: ConfigurationValue(value: enabled, source: .runtime)
            )
        } else {
            moduleConfigs[moduleId]?.enabled = ConfigurationValue(
                value: enabled,
                source: .runtime
            )
        }
    }

    // MARK: - Configuration Display

    /// Get human-readable configuration summary
    /// - Returns: Configuration summary string
    public func configurationSummary() -> String {
        var lines: [String] = []

        lines.append("=== Module Configuration ===")
        lines.append("")

        // Source
        if let path = loadedConfigPath {
            lines.append("Source: \(path)")
        } else {
            lines.append("Source: defaults")
        }
        lines.append("")

        // Global settings
        lines.append("Global Settings:")
        lines.append("  refresh_interval: \(globalConfig.refreshInterval.value)s (\(globalConfig.refreshInterval.source))")
        lines.append("  cache_size_mb: \(globalConfig.cacheSizeMB.value) (\(globalConfig.cacheSizeMB.source))")
        lines.append("  log_level: \(globalConfig.logLevel.value) (\(globalConfig.logLevel.source))")
        lines.append("  enable_metrics: \(globalConfig.enableMetrics.value) (\(globalConfig.enableMetrics.source))")
        lines.append("")

        // Module configurations
        lines.append("Module Configurations:")
        if moduleConfigs.isEmpty {
            lines.append("  (no module-specific configuration)")
        } else {
            for (moduleId, config) in moduleConfigs.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(moduleId):")
                lines.append("    enabled: \(config.enabled.value) (\(config.enabled.source))")
                for (key, holder) in config.values.sorted(by: { $0.key < $1.key }) {
                    let valueStr = formatConfigValue(holder.value)
                    lines.append("    \(key): \(valueStr) (\(holder.source))")
                }
            }
        }

        // Warnings
        if !loadWarnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in loadWarnings {
                lines.append("  - \(warning)")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Get configuration summary for a specific module
    /// - Parameter moduleId: Module identifier
    /// - Returns: Module configuration summary string
    public func moduleSummary(_ moduleId: String) -> String {
        guard let config = moduleConfigs[moduleId] else {
            return "No configuration for module '\(moduleId)'"
        }

        var lines: [String] = []
        lines.append("=== Configuration for \(moduleId) ===")
        lines.append("")
        lines.append("enabled: \(config.enabled.value) (\(config.enabled.source))")

        if config.values.isEmpty {
            lines.append("")
            lines.append("(no module-specific settings)")
        } else {
            lines.append("")
            for (key, holder) in config.values.sorted(by: { $0.key < $1.key }) {
                let valueStr = formatConfigValue(holder.value)
                lines.append("\(key): \(valueStr)")
                lines.append("  source: \(holder.source)")
            }
        }

        // Schema info
        if let schema = moduleSchemas[moduleId] {
            lines.append("")
            lines.append("Schema:")
            for entry in schema.entries {
                let reqStr = entry.required ? "(required)" : "(optional)"
                lines.append("  \(entry.key): \(entry.valueType) \(reqStr)")
                if !entry.description.isEmpty {
                    lines.append("    \(entry.description)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Methods

    private func applyDefaults() {
        // Global defaults are already set in init
        // Module defaults come from module schemas
        for (moduleId, schema) in moduleSchemas {
            var values: [String: ConfigurationValueHolder] = [:]

            for entry in schema.entries {
                if let defaultValue = entry.defaultValue {
                    if let configValue = convertToConfigValue(defaultValue, type: entry.valueType) {
                        values[entry.key] = ConfigurationValueHolder(
                            value: configValue,
                            source: .defaultValue
                        )
                    }
                }
            }

            if !values.isEmpty || moduleConfigs[moduleId] == nil {
                if moduleConfigs[moduleId] == nil {
                    moduleConfigs[moduleId] = ModuleConfig(
                        moduleId: moduleId,
                        enabled: ConfigurationValue(value: true, source: .defaultValue),
                        values: values
                    )
                } else {
                    // Merge defaults with existing
                    for (key, value) in values where moduleConfigs[moduleId]?.values[key] == nil {
                        moduleConfigs[moduleId]?.values[key] = value
                    }
                }
            }
        }
    }

    private func applyEnvironmentOverrides() {
        let env = ProcessInfo.processInfo.environment

        // Global overrides
        if let value = env["SUBSTATION_REFRESH_INTERVAL"], let intValue = Int(value) {
            globalConfig.refreshInterval = ConfigurationValue(
                value: intValue,
                source: .environment("SUBSTATION_REFRESH_INTERVAL")
            )
        }

        if let value = env["SUBSTATION_CACHE_SIZE_MB"], let intValue = Int(value) {
            globalConfig.cacheSizeMB = ConfigurationValue(
                value: intValue,
                source: .environment("SUBSTATION_CACHE_SIZE_MB")
            )
        }

        if let value = env["SUBSTATION_LOG_LEVEL"] {
            globalConfig.logLevel = ConfigurationValue(
                value: value.lowercased(),
                source: .environment("SUBSTATION_LOG_LEVEL")
            )
        }

        if let value = env["SUBSTATION_ENABLE_METRICS"] {
            let boolValue = value.lowercased() == "true" || value == "1"
            globalConfig.enableMetrics = ConfigurationValue(
                value: boolValue,
                source: .environment("SUBSTATION_ENABLE_METRICS")
            )
        }

        // Module-specific overrides
        // Format: SUBSTATION_MODULE_<MODULE_ID>_<KEY>=value
        // Example: SUBSTATION_MODULE_SERVERS_REFRESH_INTERVAL=15
        for (key, value) in env {
            guard key.hasPrefix("SUBSTATION_MODULE_") else { continue }

            let parts = key.dropFirst("SUBSTATION_MODULE_".count).split(separator: "_", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let moduleId = String(parts[0]).lowercased()
            let configKey = String(parts[1]).lowercased()

            // Special handling for enabled
            if configKey == "enabled" {
                let enabled = value.lowercased() == "true" || value == "1"
                if moduleConfigs[moduleId] == nil {
                    moduleConfigs[moduleId] = ModuleConfig(
                        moduleId: moduleId,
                        enabled: ConfigurationValue(value: enabled, source: .environment(key))
                    )
                } else {
                    moduleConfigs[moduleId]?.enabled = ConfigurationValue(
                        value: enabled,
                        source: .environment(key)
                    )
                }
                continue
            }

            // General config value
            let configValue = parseEnvironmentValue(value)
            if moduleConfigs[moduleId] == nil {
                moduleConfigs[moduleId] = ModuleConfig(
                    moduleId: moduleId,
                    enabled: ConfigurationValue(value: true, source: .defaultValue)
                )
            }

            moduleConfigs[moduleId]?.values[configKey] = ConfigurationValueHolder(
                value: configValue,
                source: .environment(key)
            )
        }
    }

    private func parseEnvironmentValue(_ value: String) -> ConfigValue {
        // Try to parse as int
        if let intValue = Int(value) {
            return .int(intValue)
        }

        // Try to parse as double
        if let doubleValue = Double(value) {
            return .double(doubleValue)
        }

        // Try to parse as bool
        let lower = value.lowercased()
        if lower == "true" || lower == "false" {
            return .bool(lower == "true")
        }

        // Try to parse as array (comma-separated)
        if value.contains(",") {
            let items = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            return .stringArray(items)
        }

        // Default to string
        return .string(value)
    }

    private func parseYAML(_ data: Data, path: String) throws {
        // Simple YAML parser for our configuration format
        // For production, consider using a proper YAML library
        guard let content = String(data: data, encoding: .utf8) else {
            throw ConfigurationError.parseFailed(path, "Invalid UTF-8 encoding")
        }

        var currentSection: String?
        var currentModule: String?
        var currentModuleValues: [String: ConfigurationValueHolder] = [:]
        var currentModuleEnabled: Bool = true

        let lines = content.components(separatedBy: .newlines)

        for (lineNum, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Count leading spaces for indentation
            let leadingSpaces = line.prefix(while: { $0 == " " }).count

            // Top-level keys
            if leadingSpaces == 0 && trimmed.hasSuffix(":") {
                // Save previous module if any
                if let module = currentModule {
                    moduleConfigs[module] = ModuleConfig(
                        moduleId: module,
                        enabled: ConfigurationValue(value: currentModuleEnabled, source: .file(path)),
                        values: currentModuleValues
                    )
                    currentModuleValues = [:]
                    currentModuleEnabled = true
                }
                currentModule = nil

                let key = String(trimmed.dropLast())
                currentSection = key
                continue
            }

            // Module name (under "modules:")
            if currentSection == "modules" && leadingSpaces == 2 && trimmed.hasSuffix(":") {
                // Save previous module
                if let module = currentModule {
                    moduleConfigs[module] = ModuleConfig(
                        moduleId: module,
                        enabled: ConfigurationValue(value: currentModuleEnabled, source: .file(path)),
                        values: currentModuleValues
                    )
                    currentModuleValues = [:]
                    currentModuleEnabled = true
                }

                currentModule = String(trimmed.dropLast())
                continue
            }

            // Key-value pair
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                var valueStr = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                // Remove inline comments
                if let commentIndex = valueStr.firstIndex(of: "#") {
                    valueStr = String(valueStr[..<commentIndex]).trimmingCharacters(in: .whitespaces)
                }

                // Global section
                if currentSection == "global" {
                    parseGlobalValue(key: key, value: valueStr, path: path)
                    continue
                }

                // Module section
                if currentSection == "modules" && currentModule != nil {
                    if key == "enabled" {
                        currentModuleEnabled = valueStr.lowercased() == "true"
                    } else {
                        let configValue = parseYAMLValue(valueStr)
                        currentModuleValues[key] = ConfigurationValueHolder(
                            value: configValue,
                            source: .file(path)
                        )
                    }
                    continue
                }
            }

            // Array items (starts with "- ")
            if trimmed.hasPrefix("- ") {
                let item = String(trimmed.dropFirst(2))
                // Handle array values in current context
                // This is simplified - full YAML needs more complex handling
                Logger.shared.logDebug("Array item at line \(lineNum + 1): \(item)", context: [:])
            }
        }

        // Save last module
        if let module = currentModule {
            moduleConfigs[module] = ModuleConfig(
                moduleId: module,
                enabled: ConfigurationValue(value: currentModuleEnabled, source: .file(path)),
                values: currentModuleValues
            )
        }
    }

    private func parseJSON(_ data: Data, path: String) throws {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ConfigurationError.parseFailed(path, "Root must be a dictionary")
            }

            // Parse global section
            if let global = json["global"] as? [String: Any] {
                for (key, value) in global {
                    parseGlobalValue(key: key, value: value, path: path)
                }
            }

            // Parse modules section
            if let modules = json["modules"] as? [String: Any] {
                for (moduleId, moduleConfig) in modules {
                    guard let config = moduleConfig as? [String: Any] else {
                        loadWarnings.append("Invalid configuration for module '\(moduleId)'")
                        continue
                    }

                    var values: [String: ConfigurationValueHolder] = [:]
                    var enabled = true

                    for (key, value) in config {
                        if key == "enabled" {
                            if let boolValue = value as? Bool {
                                enabled = boolValue
                            } else if let intValue = value as? Int {
                                enabled = intValue != 0
                            }
                        } else {
                            if let configValue = convertAnyToConfigValue(value) {
                                values[key] = ConfigurationValueHolder(
                                    value: configValue,
                                    source: .file(path)
                                )
                            }
                        }
                    }

                    moduleConfigs[moduleId] = ModuleConfig(
                        moduleId: moduleId,
                        enabled: ConfigurationValue(value: enabled, source: .file(path)),
                        values: values
                    )
                }
            }
        } catch let error as ConfigurationError {
            throw error
        } catch {
            throw ConfigurationError.parseFailed(path, error.localizedDescription)
        }
    }

    private func parseGlobalValue(key: String, value: Any, path: String) {
        switch key {
        case "refresh_interval":
            if let intValue = value as? Int {
                globalConfig.refreshInterval = ConfigurationValue(value: intValue, source: .file(path))
            } else if let strValue = value as? String, let intValue = Int(strValue) {
                globalConfig.refreshInterval = ConfigurationValue(value: intValue, source: .file(path))
            }
        case "cache_size_mb":
            if let intValue = value as? Int {
                globalConfig.cacheSizeMB = ConfigurationValue(value: intValue, source: .file(path))
            } else if let strValue = value as? String, let intValue = Int(strValue) {
                globalConfig.cacheSizeMB = ConfigurationValue(value: intValue, source: .file(path))
            }
        case "log_level":
            if let strValue = value as? String {
                globalConfig.logLevel = ConfigurationValue(value: strValue.lowercased(), source: .file(path))
            }
        case "enable_metrics":
            if let boolValue = value as? Bool {
                globalConfig.enableMetrics = ConfigurationValue(value: boolValue, source: .file(path))
            } else if let strValue = value as? String {
                globalConfig.enableMetrics = ConfigurationValue(
                    value: strValue.lowercased() == "true",
                    source: .file(path)
                )
            }
        default:
            loadWarnings.append("Unknown global configuration key: \(key)")
        }
    }

    private func parseYAMLValue(_ value: String) -> ConfigValue {
        // Boolean
        let lower = value.lowercased()
        if lower == "true" || lower == "false" || lower == "yes" || lower == "no" {
            return .bool(lower == "true" || lower == "yes")
        }

        // Integer
        if let intValue = Int(value) {
            return .int(intValue)
        }

        // Double
        if let doubleValue = Double(value) {
            return .double(doubleValue)
        }

        // Array (inline format: [a, b, c])
        if value.hasPrefix("[") && value.hasSuffix("]") {
            let inner = String(value.dropFirst().dropLast())
            let items = inner.split(separator: ",").map {
                String($0).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
            return .stringArray(items)
        }

        // String (remove quotes if present)
        var strValue = value
        if (strValue.hasPrefix("\"") && strValue.hasSuffix("\"")) ||
           (strValue.hasPrefix("'") && strValue.hasSuffix("'")) {
            strValue = String(strValue.dropFirst().dropLast())
        }

        return .string(strValue)
    }

    private func convertAnyToConfigValue(_ value: Any) -> ConfigValue? {
        if let strValue = value as? String {
            return .string(strValue)
        }
        if let intValue = value as? Int {
            return .int(intValue)
        }
        if let doubleValue = value as? Double {
            return .double(doubleValue)
        }
        if let boolValue = value as? Bool {
            return .bool(boolValue)
        }
        if let arrayValue = value as? [String] {
            return .stringArray(arrayValue)
        }
        if let dictValue = value as? [String: String] {
            return .dictionary(dictValue)
        }
        return nil
    }

    private func convertToConfigValue(_ value: Any, type: ConfigurationSchema.ValueType) -> ConfigValue? {
        switch type {
        case .string:
            return .string(String(describing: value))
        case .int:
            if let intValue = value as? Int {
                return .int(intValue)
            }
            return nil
        case .double:
            if let doubleValue = value as? Double {
                return .double(doubleValue)
            }
            return nil
        case .bool:
            if let boolValue = value as? Bool {
                return .bool(boolValue)
            }
            return nil
        case .stringArray:
            if let arrayValue = value as? [String] {
                return .stringArray(arrayValue)
            }
            return nil
        case .dictionary:
            if let dictValue = value as? [String: String] {
                return .dictionary(dictValue)
            }
            return nil
        }
    }

    private func formatConfigValue(_ value: ConfigValue) -> String {
        switch value {
        case .string(let s):
            return s
        case .int(let i):
            return String(i)
        case .double(let d):
            return String(d)
        case .bool(let b):
            return b ? "true" : "false"
        case .stringArray(let arr):
            return "[\(arr.joined(separator: ", "))]"
        case .dictionary(let dict):
            let items = dict.map { "\($0.key)=\($0.value)" }
            return "{\(items.joined(separator: ", "))}"
        }
    }
}

// MARK: - Configuration Errors

/// Errors that can occur during configuration loading
public enum ConfigurationError: Error, LocalizedError {
    case fileNotFound(String)
    case readFailed(String, any Error)
    case parseFailed(String, String)
    case unsupportedFormat(String)
    case validationFailed(String, [String])
    case invalidValue(String, String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Configuration file not found: \(path)"
        case .readFailed(let path, let error):
            return "Failed to read configuration file '\(path)': \(error.localizedDescription)"
        case .parseFailed(let path, let message):
            return "Failed to parse configuration file '\(path)': \(message)"
        case .unsupportedFormat(let path):
            return "Unsupported configuration format: \(path)"
        case .validationFailed(let module, let errors):
            return "Configuration validation failed for '\(module)': \(errors.joined(separator: ", "))"
        case .invalidValue(let key, let message):
            return "Invalid configuration value for '\(key)': \(message)"
        }
    }
}
