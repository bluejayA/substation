import Foundation

// MARK: - Region Configuration

public enum RegionConfig: Codable, Sendable {
    case single(String)
    case multiple([String])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            self = .single(string)
        } else if let array = try? container.decode([String].self) {
            self = .multiple(array)
        } else {
            throw DecodingError.typeMismatch(RegionConfig.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected String or [String] for region_name"
            ))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let string):
            try container.encode(string)
        case .multiple(let array):
            try container.encode(array)
        }
    }

    /// Get the primary (first) region name
    public var primaryRegion: String? {
        switch self {
        case .single(let region):
            let trimmed = region.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .multiple(let regions):
            return regions.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Get all region names
    public var allRegions: [String] {
        switch self {
        case .single(let region):
            return [region]
        case .multiple(let regions):
            return regions
        }
    }
}

// MARK: - Cloud Configuration Models

public struct CloudsConfig: Codable, Sendable {
    public let clouds: [String: CloudConfig]

    public init(clouds: [String: CloudConfig]) {
        self.clouds = clouds
    }
}

public struct CloudConfig: Codable, Sendable {
    public let auth: AuthConfig
    public let region_name: RegionConfig?
    public let interface: String?
    public let identity_api_version: String?
    public let compute_api_version: String?
    public let network_api_version: String?
    public let volume_api_version: String?
    public let image_api_version: String?
    public let object_store_api_version: String?
    public let load_balancer_api_version: String?
    public let orchestration_api_version: String?
    public let dns_api_version: String?
    public let key_manager_api_version: String?
    public let baremetal_api_version: String?

    // Service type overrides
    public let volume_service_type: String?
    public let compute_service_type: String?
    public let network_service_type: String?

    // Additional service configuration
    public let disable_vendor_agent: [String]?
    public let floating_ip_source: String?
    public let nat_destination: String?

    // Authentication timing configuration
    public let auth_type: String?
    public let auth_methods: [String]?

    // Performance optimization
    public let use_direct_access: Bool?
    public let split_loggers: Bool?

    /// Get the primary region name (first if array, single if string)
    public var primaryRegionName: String? {
        return region_name?.primaryRegion
    }

    /// Get all available region names
    public var allRegionNames: [String] {
        return region_name?.allRegions ?? []
    }

    enum CodingKeys: String, CodingKey {
        case auth
        case region_name, interface
        case identity_api_version, compute_api_version, network_api_version
        case volume_api_version, image_api_version, object_store_api_version
        case load_balancer_api_version, orchestration_api_version, dns_api_version
        case key_manager_api_version, baremetal_api_version
        case volume_service_type, compute_service_type, network_service_type
        case disable_vendor_agent, floating_ip_source, nat_destination
        case auth_type, auth_methods
        case use_direct_access, split_loggers
    }
}

public struct AuthConfig: Codable, Sendable {
    // Core authentication fields
    public let auth_url: String
    public let username: String?
    public let password: String?
    public let project_name: String?
    public let project_domain_name: String?
    public let user_domain_name: String?

    // Application credential fields
    public let application_credential_id: String?
    public let application_credential_secret: String?
    public let application_credential_name: String?

    // Alternative authentication fields
    public let user_id: String?
    public let project_id: String?
    public let project_domain_id: String?
    public let user_domain_id: String?
    public let token: String?

    // Federation and SAML fields
    public let identity_provider: String?
    public let `protocol`: String?
    public let mapped_local_user: String?

    // System-scope authentication
    public let system_scope: String?

    // Multi-factor authentication
    public let passcode: String?
    public let totp: String?

    // SSL/TLS configuration
    public let verify: String?
    public let cacert: String?
    public let cert: String?
    public let key: String?
    public let insecure: Bool?

    enum CodingKeys: String, CodingKey {
        case auth_url
        case username, password
        case project_name, project_domain_name, user_domain_name
        case application_credential_id, application_credential_secret, application_credential_name
        case user_id, project_id, project_domain_id, user_domain_id
        case token
        case identity_provider, `protocol`, mapped_local_user
        case system_scope
        case passcode, totp
        case verify, cacert, cert, key, insecure
    }
}

// MARK: - Cloud Configuration Manager

public final class CloudConfigManager: @unchecked Sendable {
    private let enhancedParser = EnhancedYAMLParser()
    private let authManager = AuthenticationManager()
    private let credentialStorage = SecureCredentialStorage()
    private let defaultPath: String

    public init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        self.defaultPath = "\(homeDir)/.config/openstack/clouds.yaml"
    }

    public func loadCloudsConfig(path: String? = nil) async throws -> CloudsConfig {
        let configPath = path ?? defaultPath

        guard FileManager.default.fileExists(atPath: configPath) else {
            throw CloudConfigError.fileNotFound(configPath)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))

        // Use enhanced parser only
        return try await enhancedParser.parse(data)
    }

    public func listAvailableClouds(path: String? = nil) async throws -> [String] {
        let config = try await loadCloudsConfig(path: path)
        return Array(config.clouds.keys).sorted()
    }

    public func getCloudConfig(_ cloudName: String, path: String? = nil) async throws -> CloudConfig {
        let config = try await loadCloudsConfig(path: path)

        guard let cloudConfig = config.clouds[cloudName] else {
            throw CloudConfigError.cloudNotFound(cloudName, availableClouds: Array(config.clouds.keys))
        }

        return cloudConfig
    }

    // MARK: - Enhanced Configuration Methods

    /// Validate a cloud configuration for completeness and correctness
    public func validateCloudConfig(_ cloudName: String, path: String? = nil) async throws -> [String] {
        let config = try await loadCloudsConfig(path: path)

        guard let cloudConfig = config.clouds[cloudName] else {
            throw CloudConfigError.cloudNotFound(cloudName, availableClouds: Array(config.clouds.keys))
        }

        return await authManager.validateAuthConfiguration(cloudConfig.auth)
    }

    /// Get the determined authentication method for a cloud
    public func getAuthenticationMethod(_ cloudName: String, path: String? = nil) async throws -> AuthenticationManager.DeterminedAuthMethod? {
        let cloudConfig = try await getCloudConfig(cloudName, path: path)
        return await authManager.determineAuthMethod(from: cloudConfig.auth)
    }

    /// Store sensitive credential data securely
    public func storeCredential(key: String, value: String) async throws {
        try await credentialStorage.store(value, for: key)
    }

    /// Retrieve sensitive credential data securely
    public func retrieveCredential(key: String) async throws -> String? {
        return try await credentialStorage.retrieve(for: key)
    }

    /// Clear stored credential data
    public func clearCredentials() async {
        await credentialStorage.clearAll()
    }

    /// Check if credential exists
    public func credentialExists(key: String) async -> Bool {
        return await credentialStorage.exists(for: key)
    }

    /// Get all stored credential keys
    public func getAllCredentialKeys() async -> [String] {
        return await credentialStorage.getAllKeys()
    }

    /// Check if a cloud configuration has environment variable dependencies
    public func hasEnvironmentVariables(_ cloudName: String, path: String? = nil) async throws -> Bool {
        let configPath = path ?? defaultPath

        guard FileManager.default.fileExists(atPath: configPath) else {
            return false
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        guard let yamlString = String(data: data, encoding: .utf8) else {
            return false
        }

        // Simple check for environment variable patterns
        return yamlString.contains("$")
    }

    /// Get detailed information about a cloud configuration
    public func getCloudInfo(_ cloudName: String, path: String? = nil) async throws -> CloudInfo {
        let cloudConfig = try await getCloudConfig(cloudName, path: path)
        let validationErrors = await authManager.validateAuthConfiguration(cloudConfig.auth)
        let authMethod = await authManager.determineAuthMethod(from: cloudConfig.auth)
        let hasEnvVars = try await hasEnvironmentVariables(cloudName, path: path)

        return CloudInfo(
            name: cloudName,
            config: cloudConfig,
            authenticationMethod: authMethod,
            validationErrors: validationErrors,
            hasEnvironmentVariables: hasEnvVars
        )
    }
}

// MARK: - Cloud Information

public struct CloudInfo: Sendable {
    public let name: String
    public let config: CloudConfig
    public let authenticationMethod: AuthenticationManager.DeterminedAuthMethod?
    public let validationErrors: [String]
    public let hasEnvironmentVariables: Bool

    public init(name: String, config: CloudConfig, authenticationMethod: AuthenticationManager.DeterminedAuthMethod?, validationErrors: [String], hasEnvironmentVariables: Bool) {
        self.name = name
        self.config = config
        self.authenticationMethod = authenticationMethod
        self.validationErrors = validationErrors
        self.hasEnvironmentVariables = hasEnvironmentVariables
    }
}

// MARK: - Errors

public enum CloudConfigError: Error, Sendable {
    case fileNotFound(String)
    case cloudNotFound(String, availableClouds: [String])
    case invalidConfiguration(String)
    case missingRequiredField(String)
    case environmentVariableNotFound(String)
    case validationFailed([String])
    case unsupportedAuthenticationMethod
    case yamlParsingError(String)
    case networkError(String)
    case permissionDenied(String)
    case configurationCorrupted(String)
    case authenticationMethodConflict([String])
    case unsupportedFeature(String)
    case configurationVersionMismatch(expected: String, found: String)
    case secureStorageError(String)
    case environmentSetupError(String)
}

extension CloudConfigError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "clouds.yaml file not found at: \(path). Please ensure the file exists and is accessible."
        case .cloudNotFound(let cloud, let available):
            let suggestion = available.isEmpty
                ? "No clouds are configured in the file."
                : "Available clouds: \(available.joined(separator: ", "))"
            return "Cloud '\(cloud)' not found in configuration. \(suggestion)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message). Please check your clouds.yaml syntax."
        case .missingRequiredField(let field):
            return "Missing required field: \(field). This field is mandatory for authentication."
        case .environmentVariableNotFound(let variable):
            return "Required environment variable '\(variable)' not found. Please set this variable or provide the value directly in clouds.yaml."
        case .validationFailed(let errors):
            let errorList = errors.map { "- \($0)" }.joined(separator: "\n")
            return "Configuration validation failed:\n\(errorList)"
        case .unsupportedAuthenticationMethod:
            return "Unsupported authentication method in configuration. Please use one of: password, application credentials, token, or multi-factor authentication."
        case .yamlParsingError(let message):
            return "YAML parsing error: \(message). Please check your clouds.yaml syntax and formatting."
        case .networkError(let message):
            return "Network error while loading configuration: \(message). Please check your internet connection."
        case .permissionDenied(let path):
            return "Permission denied accessing file: \(path). Please check file permissions."
        case .configurationCorrupted(let message):
            return "Configuration file appears to be corrupted: \(message). Please restore from backup or recreate the file."
        case .authenticationMethodConflict(let conflictingMethods):
            let methodList = conflictingMethods.joined(separator: ", ")
            return "Multiple conflicting authentication methods detected: \(methodList). Please use only one authentication method per cloud."
        case .unsupportedFeature(let feature):
            return "Unsupported feature: \(feature). This feature may require a newer version of the application."
        case .configurationVersionMismatch(let expected, let found):
            return "Configuration version mismatch. Expected version \(expected), found version \(found). Please update your configuration file."
        case .secureStorageError(let message):
            return "Secure storage error: \(message). Credentials may not be properly encrypted or stored."
        case .environmentSetupError(let message):
            return "Environment setup error: \(message). Please check your system environment."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .fileNotFound(let path):
            return "Create a clouds.yaml file at \(path) or specify a different path using --config option."
        case .cloudNotFound(_, let available):
            if available.isEmpty {
                return "Add cloud configurations to your clouds.yaml file."
            } else {
                return "Use one of the available clouds: \(available.joined(separator: ", "))"
            }
        case .invalidConfiguration:
            return "Validate your YAML syntax using an online YAML validator or text editor with YAML support."
        case .missingRequiredField(let field):
            return "Add the required field '\(field)' to your cloud configuration."
        case .environmentVariableNotFound(let variable):
            return "Set the environment variable: export \(variable)=your_value"
        case .validationFailed:
            return "Review and fix the validation errors listed above."
        case .yamlParsingError:
            return "Check for proper indentation, quotes, and YAML structure. Refer to OpenStack clouds.yaml documentation."
        case .permissionDenied(let path):
            return "Run: chmod 600 \(path) to set proper permissions for the configuration file."
        case .authenticationMethodConflict:
            return "Remove conflicting authentication methods and use only one per cloud configuration."
        case .configurationCorrupted:
            return "Restore from backup or recreate the clouds.yaml file using the OpenStack documentation."
        default:
            return nil
        }
    }

    public var failureReason: String? {
        switch self {
        case .fileNotFound:
            return "The specified configuration file does not exist."
        case .cloudNotFound:
            return "The requested cloud configuration was not found."
        case .invalidConfiguration:
            return "The configuration file contains invalid data."
        case .validationFailed:
            return "The configuration failed validation checks."
        case .yamlParsingError:
            return "The YAML file could not be parsed."
        case .permissionDenied:
            return "Insufficient permissions to access the file."
        case .authenticationMethodConflict:
            return "Multiple authentication methods are conflicting."
        default:
            return nil
        }
    }
}