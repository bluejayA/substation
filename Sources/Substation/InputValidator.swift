import Foundation

/// Centralized input validation utility for security and data integrity
public struct InputValidator: Sendable {

    // MARK: - Security Patterns

    /// SQL injection patterns to detect and reject
    private static let sqlInjectionPatterns = [
        #"(?i)(union\s+select)"#,
        #"(?i)(insert\s+into)"#,
        #"(?i)(delete\s+from)"#,
        #"(?i)(drop\s+table)"#,
        #"(?i)(update\s+\w+\s+set)"#,
        #"(?i)(select\s+.*\s+from)"#,
        #"(?i)(exec\s*\()"#,
        #"(?i)(execute\s*\()"#,
        #"(?i)(script\s*>)"#,
        #"(?i)(javascript\s*:)"#,
        #"(?i)(on\w+\s*=)"#,
        #"(['\"];?\s*--)"#,
        #"(['\"];?\s*#)"#,
        #"(;\s*drop)"#
    ]

    /// Command injection patterns to detect and reject
    private static let commandInjectionPatterns = [
        #"[;&|`$]"#,
        #"\$\([^)]*\)"#,
        #"`[^`]*`"#,
        #">\s*/dev/"#,
        #"<\s*/dev/"#,
        #"\|\s*\w+"#
    ]

    /// Path traversal patterns to detect and reject
    private static let pathTraversalPatterns = [
        #"\.\./|\.\.\\|\.\.%2[fF]"#,
        #"%2e%2e[/\\]"#,
        #"(?:^|/)\.\.(?:$|/)"#
    ]

    // MARK: - Validation Methods

    /// Validate input for SQL injection patterns
    public static func validateNoSQLInjection(_ input: String) -> InputValidationResult {
        for pattern in sqlInjectionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil {
                return .invalid("Input contains potentially dangerous SQL patterns")
            }
        }
        return .valid
    }

    /// Validate input for command injection patterns
    public static func validateNoCommandInjection(_ input: String) -> InputValidationResult {
        for pattern in commandInjectionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil {
                return .invalid("Input contains potentially dangerous command characters")
            }
        }
        return .valid
    }

    /// Validate input for path traversal patterns
    public static func validateNoPathTraversal(_ input: String) -> InputValidationResult {
        for pattern in pathTraversalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil {
                return .invalid("Input contains path traversal patterns")
            }
        }
        return .valid
    }

    /// Validate string length to prevent buffer overflow conditions
    public static func validateLength(_ input: String, min: Int = 0, max: Int = 255) -> InputValidationResult {
        let length = input.count

        if length < min {
            return .invalid("Input must be at least \(min) characters")
        }

        if length > max {
            return .invalid("Input must not exceed \(max) characters")
        }

        return .valid
    }

    /// Validate input contains only allowed characters
    public static func validateCharacterSet(_ input: String, allowed: CharacterSet) -> InputValidationResult {
        if input.rangeOfCharacter(from: allowed.inverted) != nil {
            return .invalid("Input contains disallowed characters")
        }
        return .valid
    }

    /// Comprehensive validation for general text input
    public static func validateTextInput(_ input: String, maxLength: Int = 255) -> [String] {
        var errors: [String] = []

        // Check length
        switch validateLength(input, max: maxLength) {
        case .invalid(let error):
            errors.append(error)
        case .valid:
            break
        }

        // Check for SQL injection
        switch validateNoSQLInjection(input) {
        case .invalid(let error):
            errors.append(error)
        case .valid:
            break
        }

        // Check for command injection
        switch validateNoCommandInjection(input) {
        case .invalid(let error):
            errors.append(error)
        case .valid:
            break
        }

        return errors
    }

    /// Comprehensive validation for name fields (servers, networks, etc)
    public static func validateNameField(_ name: String, maxLength: Int = 255) -> [String] {
        var errors: [String] = []

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if empty
        if trimmed.isEmpty {
            errors.append("Name is required")
            return errors
        }

        // Check length
        switch validateLength(trimmed, min: 1, max: maxLength) {
        case .invalid(let error):
            errors.append(error)
        case .valid:
            break
        }

        // Validate character set for OpenStack resource names
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@._- ")
        switch validateCharacterSet(trimmed, allowed: allowedCharacters) {
        case .invalid:
            errors.append("Name can only contain letters, numbers, spaces, and @._- characters")
        case .valid:
            break
        }

        // Check for security patterns
        errors.append(contentsOf: validateTextInput(trimmed, maxLength: maxLength))

        return errors
    }

    /// Validate description fields with more permissive rules
    public static func validateDescriptionField(_ description: String, maxLength: Int = 1024) -> [String] {
        var errors: [String] = []

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check length
        switch validateLength(trimmed, max: maxLength) {
        case .invalid(let error):
            errors.append(error)
        case .valid:
            break
        }

        // Check for dangerous patterns
        switch validateNoSQLInjection(trimmed) {
        case .invalid(let error):
            errors.append(error)
        case .valid:
            break
        }

        switch validateNoCommandInjection(trimmed) {
        case .invalid(let error):
            errors.append(error)
        case .valid:
            break
        }

        return errors
    }

    /// Validate numeric input
    public static func validateNumericInput(_ input: String, min: Int? = nil, max: Int? = nil) -> [String] {
        var errors: [String] = []

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's a valid integer
        guard let value = Int(trimmed) else {
            errors.append("Must be a valid number")
            return errors
        }

        // Check minimum
        if let min = min, value < min {
            errors.append("Must be at least \(min)")
        }

        // Check maximum
        if let max = max, value > max {
            errors.append("Must be \(max) or less")
        }

        return errors
    }

    /// Validate IP address format
    public static func validateIPAddress(_ input: String) -> [String] {
        var errors: [String] = []

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // IPv4 pattern
        let ipv4Pattern = #"^(\d{1,3}\.){3}\d{1,3}$"#

        // IPv6 pattern (simplified)
        let ipv6Pattern = #"^([0-9a-fA-F]{0,4}:){7}[0-9a-fA-F]{0,4}$"#

        let isIPv4 = (try? NSRegularExpression(pattern: ipv4Pattern, options: []))?.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
        let isIPv6 = (try? NSRegularExpression(pattern: ipv6Pattern, options: []))?.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil

        if !isIPv4 && !isIPv6 {
            errors.append("Must be a valid IP address")
        }

        // For IPv4, validate each octet
        if isIPv4 {
            let octets = trimmed.split(separator: ".")
            for octet in octets {
                if let value = Int(octet), value > 255 {
                    errors.append("Invalid IPv4 address: octet values must be 0-255")
                    break
                }
            }
        }

        return errors
    }

    /// Validate CIDR notation
    public static func validateCIDR(_ input: String) -> [String] {
        var errors: [String] = []

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: "/")

        guard components.count == 2 else {
            errors.append("Must be in CIDR notation (e.g., 192.168.1.0/24)")
            return errors
        }

        // Validate IP address part
        errors.append(contentsOf: validateIPAddress(String(components[0])))

        // Validate prefix length
        if let prefixLength = Int(components[1]) {
            if prefixLength < 0 || prefixLength > 128 {
                errors.append("CIDR prefix must be between 0 and 128")
            }
        } else {
            errors.append("CIDR prefix must be a valid number")
        }

        return errors
    }
}

// MARK: - Input Validation Result

public enum InputValidationResult: Sendable {
    case valid
    case invalid(String)
}
