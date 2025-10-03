import Foundation
import Crypto

// MARK: - Enhanced Configuration Models

public struct EnhancedAuthConfig: Codable, Sendable {
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

    // Additional authentication fields
    public let user_id: String?
    public let project_id: String?
    public let project_domain_id: String?
    public let user_domain_id: String?
    public let token: String?

    // Security and SSL fields
    public let verify: Bool?
    public let cert: String?
    public let key: String?
    public let cacert: String?
    public let insecure: Bool?

    enum CodingKeys: String, CodingKey {
        case auth_url
        case username, password
        case project_name, project_domain_name, user_domain_name
        case application_credential_id, application_credential_secret, application_credential_name
        case user_id, project_id, project_domain_id, user_domain_id
        case token
        case verify, cert, key, cacert, insecure
    }
}

// MARK: - YAML String Processor

public struct YAMLValueProcessor {

    /// Process a raw YAML value, handling quotes, escapes, and environment variables
    public func processValue(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespaces)

        // Check for quoted strings first
        if let quoted = extractQuotedString(trimmed) {
            return quoted
        }

        // Process environment variables in unquoted strings
        if containsEnvironmentVariable(trimmed) {
            return expandEnvironmentVariables(trimmed)
        }

        return trimmed
    }

    private func extractQuotedString(_ value: String) -> String? {
        // Handle single quoted strings - no escape processing except ''
        if value.hasPrefix("'") && value.hasSuffix("'") && value.count > 1 {
            let content = String(value.dropFirst().dropLast())
            return content.replacingOccurrences(of: "''", with: "'")
        }

        // Handle double quoted strings - full escape processing
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count > 1 {
            let content = String(value.dropFirst().dropLast())
            return processDoubleQuotedEscapes(content)
        }

        return nil
    }

    private func processDoubleQuotedEscapes(_ content: String) -> String {
        var result = ""
        let chars = Array(content)
        var i = 0

        while i < chars.count {
            if chars[i] == "\\" && i + 1 < chars.count {
                let next = chars[i + 1]
                switch next {
                case "n":
                    result.append("\n")
                    i += 2
                case "t":
                    result.append("\t")
                    i += 2
                case "r":
                    result.append("\r")
                    i += 2
                case "\\":
                    result.append("\\")
                    i += 2
                case "\"":
                    result.append("\"")
                    i += 2
                case "'":
                    result.append("'")
                    i += 2
                case "0":
                    result.append("\0")
                    i += 2
                case "x" where i + 3 < chars.count:
                    // Handle hex escapes (ASCII only per project rules)
                    let hex = String(chars[(i+2)...(i+3)])
                    if let value = Int(hex, radix: 16), value < 128 {
                        result.append(Character(UnicodeScalar(value)!))
                        i += 4
                    } else {
                        result.append(chars[i])
                        i += 1
                    }
                default:
                    // Unknown escape, keep as-is
                    result.append(chars[i])
                    i += 1
                }
            } else {
                result.append(chars[i])
                i += 1
            }
        }

        // Process environment variables in the escaped string
        if containsEnvironmentVariable(result) {
            return expandEnvironmentVariables(result)
        }

        return result
    }

    private func containsEnvironmentVariable(_ value: String) -> Bool {
        return value.contains("$")
    }

    private func expandEnvironmentVariables(_ value: String) -> String {
        var result = value

        // Process ${VAR} format with advanced features
        let bracePattern = #"\$\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: bracePattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))

            // Process matches in reverse to maintain correct indices
            for match in matches.reversed() {
                let fullRange = match.range
                let varRange = match.range(at: 1)

                if let swiftRange = Range(fullRange, in: result),
                   let varSwiftRange = Range(varRange, in: result) {
                    let varExpression = String(result[varSwiftRange])
                    let replacement = processVariableExpression(varExpression)
                    result.replaceSubrange(swiftRange, with: replacement)
                }
            }
        }

        // Process simple $VAR format
        let simplePattern = #"\$([A-Za-z_][A-Za-z0-9_]*)"#
        if let regex = try? NSRegularExpression(pattern: simplePattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                let fullRange = match.range
                let varRange = match.range(at: 1)

                if let swiftRange = Range(fullRange, in: result),
                   let varSwiftRange = Range(varRange, in: result) {
                    let varName = String(result[varSwiftRange])
                    let replacement = ProcessInfo.processInfo.environment[varName] ?? ""
                    result.replaceSubrange(swiftRange, with: replacement)
                }
            }
        }

        return result
    }

    private func processVariableExpression(_ expression: String) -> String {
        // Handle ${VAR:-default} - use default if var is unset or empty
        if let colonDashRange = expression.range(of: ":-") {
            let varName = String(expression[..<colonDashRange.lowerBound])
            let defaultValue = String(expression[colonDashRange.upperBound...])

            if let value = ProcessInfo.processInfo.environment[varName], !value.isEmpty {
                return value
            } else {
                return defaultValue
            }
        }

        // Handle ${VAR:?error} - error if var is unset
        if let colonQuestionRange = expression.range(of: ":?") {
            let varName = String(expression[..<colonQuestionRange.lowerBound])
            let errorMessage = String(expression[colonQuestionRange.upperBound...])

            guard let value = ProcessInfo.processInfo.environment[varName], !value.isEmpty else {
                // Return empty for now, should throw in production
                print("ERROR: Required environment variable '\(varName)' is not set: \(errorMessage)")
                return ""
            }
            return value
        }

        // Handle ${VAR:+alternate} - use alternate if var is set
        if let colonPlusRange = expression.range(of: ":+") {
            let varName = String(expression[..<colonPlusRange.lowerBound])
            let alternateValue = String(expression[colonPlusRange.upperBound...])

            if ProcessInfo.processInfo.environment[varName] != nil {
                return alternateValue
            } else {
                return ""
            }
        }

        // Simple variable substitution
        return ProcessInfo.processInfo.environment[expression] ?? ""
    }
}

// MARK: - Enhanced YAML Parser

public actor EnhancedYAMLParser {
    private let valueProcessor = YAMLValueProcessor()

    enum ParserState {
        case initial
        case inClouds
        case inCloud(name: String)
        case inAuth(cloudName: String)
        case inMultilineValue(key: String, style: MultilineStyle, indent: Int)

        var canTransitionToNewCloud: Bool {
            switch self {
            case .inClouds, .inCloud, .inAuth:
                return true
            default:
                return false
            }
        }
    }

    enum MultilineStyle {
        case literal    // |
        case folded     // >
        case literalStrip  // |-
        case literalKeep   // |+
        case foldedStrip   // >-
        case foldedKeep    // >+
    }

    public init() {}

    func parse(_ data: Data) async throws -> CloudsConfig {
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw CloudConfigError.invalidConfiguration("Unable to decode YAML as UTF-8")
        }

        var clouds: [String: CloudConfig] = [:]
        let lines = yamlString.components(separatedBy: .newlines)

        var currentCloud: String?
        var currentAuth: [String: String] = [:]
        var currentConfig: [String: String] = [:]
        var currentRegions: [String] = []
        var isParsingRegionArray = false
        var state: ParserState = .initial

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                i += 1
                continue
            }

            let indent = line.prefix(while: { $0 == " " }).count

            // Handle multiline values
            if case .inMultilineValue(let key, let style, let baseIndent) = state {
                if indent > baseIndent || (indent == baseIndent && trimmedLine.hasPrefix("-")) {
                    // Continue collecting multiline value
                    let (value, linesConsumed) = await collectMultilineValue(
                        lines: lines,
                        startIndex: i,
                        style: style,
                        baseIndent: baseIndent
                    )
                    currentAuth[key] = value
                    i += linesConsumed
                    state = .inAuth(cloudName: currentCloud ?? "")
                    continue
                } else {
                    // Multiline value ended, process current line normally
                    state = .inAuth(cloudName: currentCloud ?? "")
                }
            }

            // Check for new cloud at any point (highest priority)
            if indent == 2 && trimmedLine.hasSuffix(":") && state.canTransitionToNewCloud {
                // Save previous cloud if exists
                if let cloudName = currentCloud {
                    clouds[cloudName] = try await createCloudConfig(
                        from: currentConfig,
                        auth: currentAuth,
                        regions: currentRegions
                    )
                }

                // Start new cloud
                currentCloud = String(trimmedLine.dropLast())
                currentAuth = [:]
                currentConfig = [:]
                currentRegions = []
                isParsingRegionArray = false
                state = .inCloud(name: currentCloud!)
                i += 1
                continue
            }

            // State machine for parsing
            switch state {
            case .initial:
                if trimmedLine == "clouds:" {
                    state = .inClouds
                }

            case .inClouds:
                // New clouds are handled above
                break

            case .inCloud(let name):
                if indent == 4 && trimmedLine == "auth:" {
                    state = .inAuth(cloudName: name)
                } else if indent == 4 && trimmedLine == "region_name:" {
                    // Check next line to see if it's an array
                    if i + 1 < lines.count {
                        let nextLine = lines[i + 1]
                        let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                        if nextTrimmed.hasPrefix("- ") {
                            // This is an array
                            isParsingRegionArray = true
                            currentRegions = []
                        } else {
                            // This is a single value on the same line
                            let parts = trimmedLine.split(separator: ":", maxSplits: 1)
                            if parts.count > 1 {
                                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                                currentConfig["region_name"] = valueProcessor.processValue(value)
                            }
                        }
                    }
                } else if indent > 4 && isParsingRegionArray && trimmedLine.hasPrefix("- ") {
                    // Parse array item (allow flexible indentation)
                    let regionValue = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    let processedValue = valueProcessor.processValue(regionValue)
                    currentRegions.append(processedValue)
                } else if indent <= 4 && isParsingRegionArray {
                    // End of region array, process current line normally
                    isParsingRegionArray = false
                    // Handle current line as regular config
                    if trimmedLine.contains(":") {
                        let (key, value) = await parseKeyValue(trimmedLine)
                        currentConfig[key] = value
                    }
                } else if indent == 4 && trimmedLine.contains(":") {
                    let (key, value) = await parseKeyValue(trimmedLine)
                    currentConfig[key] = value
                }

            case .inAuth(let cloudName):
                if indent == 4 && trimmedLine != "auth:" && trimmedLine.contains(":") {
                    // Back to cloud level
                    state = .inCloud(name: cloudName)
                    // Process this line in the cloud context (don't parse as key-value here)
                    // The next iteration will handle it properly in .inCloud state
                    i -= 1 // Reprocess this line in the correct state
                } else if indent == 6 && trimmedLine.contains(":") {
                    let parts = trimmedLine.split(separator: ":", maxSplits: 1)
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)

                    if parts.count > 1 {
                        let rawValue = String(parts[1]).trimmingCharacters(in: .whitespaces)

                        // Check for multiline indicators
                        if let multilineStyle = detectMultilineStyle(rawValue) {
                            state = .inMultilineValue(key: key, style: multilineStyle, indent: indent)
                        } else {
                            // Process single line value
                            let value = valueProcessor.processValue(rawValue)
                            currentAuth[key] = value
                        }
                    }
                }

            case .inMultilineValue:
                // Handled above
                break
            }

            i += 1
        }

        // Save the last cloud
        if let cloudName = currentCloud {
            clouds[cloudName] = try await createCloudConfig(
                from: currentConfig,
                auth: currentAuth,
                regions: currentRegions
            )
        }

        return CloudsConfig(clouds: clouds)
    }

    private func parseKeyValue(_ line: String) async -> (String, String) {
        let parts = line.split(separator: ":", maxSplits: 1)
        let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let rawValue = parts.count > 1 ? String(parts[1]) : ""
        let value = valueProcessor.processValue(rawValue)
        return (key, value)
    }

    private func detectMultilineStyle(_ value: String) -> MultilineStyle? {
        switch value {
        case "|": return .literal
        case ">": return .folded
        case "|-": return .literalStrip
        case "|+": return .literalKeep
        case ">-": return .foldedStrip
        case ">+": return .foldedKeep
        default: return nil
        }
    }

    private func collectMultilineValue(
        lines: [String],
        startIndex: Int,
        style: MultilineStyle,
        baseIndent: Int
    ) async -> (String, Int) {
        var result = ""
        var linesConsumed = 0
        var i = startIndex + 1

        while i < lines.count {
            let line = lines[i]
            let indent = line.prefix(while: { $0 == " " }).count

            // Check if this line belongs to the multiline value
            if indent > baseIndent || (line.trimmingCharacters(in: .whitespaces).isEmpty && i + 1 < lines.count) {
                let content = String(line.dropFirst(min(indent, baseIndent + 2)))

                switch style {
                case .literal, .literalStrip, .literalKeep:
                    if !result.isEmpty {
                        result.append("\n")
                    }
                    result.append(content)

                case .folded, .foldedStrip, .foldedKeep:
                    if !result.isEmpty && !content.isEmpty {
                        result.append(" ")
                    } else if !result.isEmpty && content.isEmpty {
                        result.append("\n")
                    }
                    result.append(content)
                }

                linesConsumed += 1
                i += 1
            } else {
                break
            }
        }

        // Apply chomping
        switch style {
        case .literalStrip, .foldedStrip:
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        case .literalKeep, .foldedKeep:
            // Keep trailing newlines
            break
        default:
            // Default: clip (single trailing newline)
            result = result.trimmingCharacters(in: .whitespaces)
        }

        return (result, linesConsumed)
    }

    private func parseBool(_ value: String?) -> Bool? {
        guard let value = value else { return nil }
        let lower = value.lowercased()
        if lower == "true" || lower == "yes" || lower == "1" { return true }
        if lower == "false" || lower == "no" || lower == "0" { return false }
        return nil
    }

    private func createCloudConfig(from config: [String: String], auth: [String: String], regions: [String] = []) async throws -> CloudConfig {
        guard let authUrl = auth["auth_url"] else {
            throw CloudConfigError.missingRequiredField("auth_url")
        }

        let authConfig = AuthConfig(
            auth_url: authUrl,
            username: auth["username"],
            password: auth["password"],
            project_name: auth["project_name"],
            project_domain_name: auth["project_domain_name"],
            user_domain_name: auth["user_domain_name"],
            application_credential_id: auth["application_credential_id"],
            application_credential_secret: auth["application_credential_secret"],
            application_credential_name: nil,
            user_id: auth["user_id"],
            project_id: auth["project_id"],
            project_domain_id: auth["project_domain_id"],
            user_domain_id: auth["user_domain_id"],
            token: auth["token"],
            identity_provider: auth["identity_provider"],
            protocol: auth["protocol"],
            mapped_local_user: auth["mapped_local_user"],
            system_scope: auth["system_scope"],
            passcode: auth["passcode"],
            totp: auth["totp"],
            verify: auth["verify"],
            cacert: auth["cacert"],
            cert: auth["cert"],
            key: auth["key"],
            insecure: parseBool(auth["insecure"])
        )

        // Handle region_name conversion to RegionConfig
        let regionConfig: RegionConfig?
        if !regions.isEmpty {
            // Use parsed array regions
            regionConfig = .multiple(regions)
        } else if let regionString = config["region_name"] {
            // Use single region from config
            regionConfig = .single(regionString)
        } else {
            regionConfig = nil
        }

        return CloudConfig(
            auth: authConfig,
            region_name: regionConfig,
            interface: config["interface"],
            identity_api_version: config["identity_api_version"],
            compute_api_version: nil,
            network_api_version: nil,
            volume_api_version: nil,
            image_api_version: nil,
            object_store_api_version: nil,
            load_balancer_api_version: nil,
            orchestration_api_version: nil,
            dns_api_version: nil,
            key_manager_api_version: nil,
            baremetal_api_version: nil,
            volume_service_type: nil,
            compute_service_type: nil,
            network_service_type: nil,
            disable_vendor_agent: nil,
            floating_ip_source: nil,
            nat_destination: nil,
            auth_type: nil,
            auth_methods: nil,
            use_direct_access: nil,
            split_loggers: nil
        )
    }
}

// MARK: - Authentication Manager

public actor AuthenticationManager {

    public enum DeterminedAuthMethod: Sendable {
        case password(username: String, password: String, projectName: String, userDomain: String, projectDomain: String)
        case applicationCredentialById(id: String, secret: String, projectName: String)
        case applicationCredentialByName(name: String, secret: String, userId: String?, username: String?, userDomain: String?, projectName: String)
        case token(token: String, projectName: String?, projectId: String?)
    }

    public init() {}

    func determineAuthMethod(from auth: AuthConfig, projectNameFallback: String? = nil) -> DeterminedAuthMethod? {
        // Priority 1: Token-based authentication with system scope
        // Note: System scope not supported in current enum, fall through to simple token auth

        // Priority 2: Federated authentication (simplified to token auth for compatibility)
        if let token = auth.token,
           auth.identity_provider != nil,
           auth.`protocol` != nil {
            return .token(
                token: token,
                projectName: auth.project_name ?? projectNameFallback,
                projectId: auth.project_id
            )
        }

        // Priority 3: Simple token authentication
        if let token = auth.token {
            return .token(
                token: token,
                projectName: auth.project_name ?? projectNameFallback,
                projectId: auth.project_id
            )
        }

        // Priority 4: Application Credential by ID
        if let id = auth.application_credential_id,
           let secret = auth.application_credential_secret {
            // For application credentials, try to use project_name from config,
            // but allow fallback to projectNameFallback or empty string as last resort
            let projectName = auth.project_name ?? projectNameFallback ?? ""
            return .applicationCredentialById(
                id: id,
                secret: secret,
                projectName: projectName
            )
        }

        // Priority 5: Application Credential by Name
        if let name = auth.application_credential_name,
           let secret = auth.application_credential_secret {
            // For application credentials, try to use project_name from config,
            // but allow fallback to projectNameFallback or empty string as last resort
            let projectName = auth.project_name ?? projectNameFallback ?? ""
            return .applicationCredentialByName(
                name: name,
                secret: secret,
                userId: auth.user_id,
                username: auth.username,
                userDomain: auth.user_domain_name,
                projectName: projectName
            )
        }

        // Priority 6: Multi-factor authentication (fallback to regular password auth)
        if let username = auth.username,
           let password = auth.password,
           (auth.passcode != nil || auth.totp != nil) {
            let projectName = auth.project_name ?? projectNameFallback ?? "default"
            let userDomain = auth.user_domain_name ?? "Default"
            let projectDomain = auth.project_domain_name ?? "Default"

            return .password(
                username: username,
                password: password,
                projectName: projectName,
                userDomain: userDomain,
                projectDomain: projectDomain
            )
        }

        // Priority 7: Password authentication with user ID (fallback to regular password auth)
        if let userId = auth.user_id,
           let password = auth.password {
            let projectName = auth.project_name ?? projectNameFallback ?? "default"
            let userDomain = auth.user_domain_name ?? "Default"
            let projectDomain = auth.project_domain_name ?? "Default"

            return .password(
                username: userId,
                password: password,
                projectName: projectName,
                userDomain: userDomain,
                projectDomain: projectDomain
            )
        }

        // Priority 8: Standard password authentication
        if let username = auth.username,
           let password = auth.password {
            let projectName = auth.project_name ?? projectNameFallback ?? "default"
            let userDomain = auth.user_domain_name ?? "Default"
            let projectDomain = auth.project_domain_name ?? "Default"

            return .password(
                username: username,
                password: password,
                projectName: projectName,
                userDomain: userDomain,
                projectDomain: projectDomain
            )
        }

        return nil
    }

    func validateAuthConfiguration(_ auth: AuthConfig) -> [String] {
        var errors: [String] = []

        // Check for auth_url
        if auth.auth_url.isEmpty {
            errors.append("auth_url is required")
        }

        // Validate URL format
        guard URL(string: auth.auth_url) != nil else {
            errors.append("auth_url must be a valid URL")
            return errors // Return early if URL is invalid
        }

        // Check for at least one authentication method
        let hasPassword = auth.username != nil && auth.password != nil
        let hasPasswordWithUserId = auth.user_id != nil && auth.password != nil
        let hasAppCredById = auth.application_credential_id != nil && auth.application_credential_secret != nil
        let hasAppCredByName = auth.application_credential_name != nil && auth.application_credential_secret != nil
        let hasToken = auth.token != nil
        let hasMultifactorAuth = auth.username != nil && auth.password != nil && (auth.passcode != nil || auth.totp != nil)

        let hasAnyAuthMethod = hasPassword || hasPasswordWithUserId || hasAppCredById || hasAppCredByName || hasToken || hasMultifactorAuth

        if !hasAnyAuthMethod {
            errors.append("No valid authentication method found. Provide one of: username/password, application credentials, token, or multi-factor authentication")
        }

        // Validate specific authentication method requirements
        if hasPassword || hasMultifactorAuth {
            if auth.username?.isEmpty == true {
                errors.append("username cannot be empty when using password authentication")
            }
            if auth.password?.isEmpty == true {
                errors.append("password cannot be empty when using password authentication")
            }
        }

        if hasPasswordWithUserId {
            if auth.user_id?.isEmpty == true {
                errors.append("user_id cannot be empty when using user ID authentication")
            }
            if auth.password?.isEmpty == true {
                errors.append("password cannot be empty when using user ID authentication")
            }
        }

        if hasAppCredById {
            if auth.application_credential_id?.isEmpty == true {
                errors.append("application_credential_id cannot be empty")
            }
            if auth.application_credential_secret?.isEmpty == true {
                errors.append("application_credential_secret cannot be empty")
            }
        }

        if hasAppCredByName {
            if auth.application_credential_name?.isEmpty == true {
                errors.append("application_credential_name cannot be empty")
            }
            if auth.application_credential_secret?.isEmpty == true {
                errors.append("application_credential_secret cannot be empty")
            }
            // For app cred by name, need either username or user_id
            if auth.username == nil && auth.user_id == nil {
                errors.append("Either username or user_id is required when using application credential by name")
            }
        }

        if hasToken {
            if auth.token?.isEmpty == true {
                errors.append("token cannot be empty when using token authentication")
            }
        }

        // Validate federated authentication
        if auth.identity_provider != nil || auth.`protocol` != nil {
            if auth.token == nil {
                errors.append("token is required for federated authentication")
            }
            if auth.identity_provider?.isEmpty == true {
                errors.append("identity_provider cannot be empty for federated authentication")
            }
            if auth.`protocol`?.isEmpty == true {
                errors.append("protocol cannot be empty for federated authentication")
            }
        }

        // Validate system scope
        if auth.system_scope != nil {
            if auth.token == nil {
                errors.append("token is required for system-scoped authentication")
            }
            if auth.project_name != nil || auth.project_id != nil {
                errors.append("project_name and project_id should not be specified with system scope")
            }
        }

        // Validate project information for non-system scoped auth
        if auth.system_scope == nil {
            // Application credentials are already scoped to a project, no additional scoping required
            let needsProject = !hasAppCredById && !hasAppCredByName
            if needsProject && auth.project_name == nil && auth.project_id == nil {
                errors.append("Either project_name or project_id is required for project-scoped authentication")
            }
        }

        // Validate multi-factor authentication specifics
        if hasMultifactorAuth {
            if auth.passcode != nil && auth.totp != nil {
                errors.append("Cannot specify both passcode and totp for multi-factor authentication")
            }
        }

        // Validate SSL/TLS configuration
        if let insecure = auth.insecure, insecure {
            if auth.verify != nil && auth.verify != "false" && auth.verify != "0" {
                errors.append("Cannot set insecure=true and verify at the same time")
            }
        }

        if auth.cert != nil && auth.key == nil {
            errors.append("key is required when cert is specified for client certificate authentication")
        }

        if auth.key != nil && auth.cert == nil {
            errors.append("cert is required when key is specified for client certificate authentication")
        }

        return errors
    }
}

// MARK: - Secure Credential Storage

public actor SecureCredentialStorage {
    private var credentials: [String: Data] = [:]
    private var encryptionKey: Data?

    public init() {
        // Generate encryption key will be done lazily
        self.encryptionKey = nil
    }

    func store(_ value: String, for key: String) async throws {
        guard let valueData = value.data(using: .utf8) else {
            throw CloudConfigError.secureStorageError("Failed to encode credential data")
        }

        do {
            let encryptedData = try encryptData(valueData)
            credentials[key] = encryptedData
        } catch {
            throw CloudConfigError.secureStorageError("Failed to encrypt credential: \(error.localizedDescription)")
        }
    }

    func retrieve(for key: String) async throws -> String? {
        guard let encryptedData = credentials[key] else { return nil }

        do {
            let decryptedData = try decryptData(encryptedData)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            throw CloudConfigError.secureStorageError("Failed to decrypt credential: \(error.localizedDescription)")
        }
    }

    func clear(for key: String) async {
        credentials.removeValue(forKey: key)
    }

    func clearAll() async {
        // Securely overwrite memory before clearing
        for (key, var data) in credentials {
            data.withUnsafeMutableBytes { bytes in
                if let baseAddress = bytes.baseAddress {
                    memset(baseAddress, 0, bytes.count)
                }
            }
            credentials[key] = data
        }
        credentials.removeAll()
    }

    func exists(for key: String) async -> Bool {
        return credentials[key] != nil
    }

    func getAllKeys() async -> [String] {
        return Array(credentials.keys)
    }

    // MARK: - Private Helper Methods

    private func generateEncryptionKey() -> Data {
        var keyData = Data(count: 32) // 256-bit key
        keyData.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            arc4random_buf(baseAddress, bytes.count)
        }
        return keyData
    }

    private func encryptData(_ data: Data) throws -> Data {
        // Use AES-256-GCM encryption for secure in-memory storage
        if encryptionKey == nil {
            encryptionKey = generateEncryptionKey()
        }

        guard let key = encryptionKey else {
            throw CloudConfigError.secureStorageError("Encryption key not available")
        }

        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        guard let combined = sealedBox.combined else {
            throw CloudConfigError.secureStorageError("Failed to create encrypted data")
        }
        return combined
    }

    private func decryptData(_ encryptedData: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw CloudConfigError.secureStorageError("Encryption key not available")
        }

        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    deinit {
        // Secure cleanup - overwrite sensitive data
        for (_, var data) in credentials {
            data.withUnsafeMutableBytes { bytes in
                if let baseAddress = bytes.baseAddress {
                    memset(baseAddress, 0, bytes.count)
                }
            }
        }

        // Clear encryption key
        if var key = encryptionKey {
            key.withUnsafeMutableBytes { bytes in
                if let baseAddress = bytes.baseAddress {
                    memset(baseAddress, 0, bytes.count)
                }
            }
        }

        credentials.removeAll()
        encryptionKey = nil
    }
}

// MARK: - Environment Variable Manager

public actor EnvironmentVariableManager {
    public init() {}

    /// Validate that all required environment variables are available
    public func validateEnvironmentVariables(in yamlContent: String) throws -> [String] {
        let envVarPattern = #"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?"#
        guard let regex = try? NSRegularExpression(pattern: envVarPattern) else {
            throw CloudConfigError.environmentSetupError("Failed to create environment variable regex")
        }

        let nsString = yamlContent as NSString
        let matches = regex.matches(in: yamlContent, range: NSRange(location: 0, length: nsString.length))

        var missingVars: [String] = []
        var foundVars = Set<String>()

        for match in matches {
            if match.numberOfRanges > 1 {
                let varRange = match.range(at: 1)
                if let swiftRange = Range(varRange, in: yamlContent) {
                    let varName = String(yamlContent[swiftRange])
                    if !foundVars.contains(varName) {
                        foundVars.insert(varName)
                        if ProcessInfo.processInfo.environment[varName] == nil {
                            missingVars.append(varName)
                        }
                    }
                }
            }
        }

        return missingVars
    }

    /// Get environment variable with validation
    public func getEnvironmentVariable(_ name: String, required: Bool = true) throws -> String? {
        let value = ProcessInfo.processInfo.environment[name]

        if required && value == nil {
            throw CloudConfigError.environmentVariableNotFound(name)
        }

        return value
    }

    /// Validate environment variable names
    public func validateEnvironmentVariableName(_ name: String) -> Bool {
        let namePattern = #"^[A-Za-z_][A-Za-z0-9_]*$"#
        guard let regex = try? NSRegularExpression(pattern: namePattern) else {
            return false
        }

        let range = NSRange(location: 0, length: name.utf16.count)
        return regex.firstMatch(in: name, options: [], range: range) != nil
    }

    /// Get all OpenStack-related environment variables
    public func getOpenStackEnvironmentVariables() -> [String: String] {
        let osPrefix = "OS_"
        let environment = ProcessInfo.processInfo.environment

        return environment.compactMapValues { value in
            return value // All values are returned; filtering happens by key
        }.filter { key, _ in
            key.hasPrefix(osPrefix)
        }
    }

    /// Check if environment variables are properly set for OpenStack
    public func validateOpenStackEnvironment() -> [String] {
        var warnings: [String] = []
        let environment = ProcessInfo.processInfo.environment

        // Common OpenStack environment variables
        let commonVars = [
            "OS_AUTH_URL", "OS_USERNAME", "OS_PASSWORD", "OS_PROJECT_NAME",
            "OS_USER_DOMAIN_NAME", "OS_PROJECT_DOMAIN_NAME", "OS_REGION_NAME"
        ]

        let applicationCredVars = [
            "OS_APPLICATION_CREDENTIAL_ID", "OS_APPLICATION_CREDENTIAL_SECRET"
        ]

        let hasPasswordAuth = commonVars.prefix(4).allSatisfy { environment[$0] != nil }
        let hasAppCredAuth = applicationCredVars.allSatisfy { environment[$0] != nil }

        if !hasPasswordAuth && !hasAppCredAuth {
            warnings.append("No complete authentication method found in environment variables")
        }

        // Check for deprecated variables
        let deprecatedVars = [
            "OS_TENANT_NAME": "Use OS_PROJECT_NAME instead",
            "OS_TENANT_ID": "Use OS_PROJECT_ID instead"
        ]

        for (deprecated, suggestion) in deprecatedVars {
            if environment[deprecated] != nil {
                warnings.append("Deprecated environment variable '\(deprecated)' found. \(suggestion)")
            }
        }

        return warnings
    }
}