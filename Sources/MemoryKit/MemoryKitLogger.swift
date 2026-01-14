import Foundation

// MARK: - Memory Kit Logging Protocol

/// Protocol for logging within MemoryKit.
///
/// Implementers must be Sendable to ensure thread-safe logging across
/// actor boundaries and concurrent operations.
public protocol MemoryKitLogger: Sendable {
    /// Logs a debug-level message.
    ///
    /// - Parameters:
    ///   - message: The log message
    ///   - context: Additional context as key-value pairs
    func logDebug(_ message: String, context: [String: Any])

    /// Logs an info-level message.
    ///
    /// - Parameters:
    ///   - message: The log message
    ///   - context: Additional context as key-value pairs
    func logInfo(_ message: String, context: [String: Any])

    /// Logs a warning-level message.
    ///
    /// - Parameters:
    ///   - message: The log message
    ///   - context: Additional context as key-value pairs
    func logWarning(_ message: String, context: [String: Any])

    /// Logs an error-level message.
    ///
    /// - Parameters:
    ///   - message: The log message
    ///   - context: Additional context as key-value pairs
    func logError(_ message: String, context: [String: Any])
}

// MARK: - Default Logger Implementation

/// Default logger implementation that can log to console or file.
///
/// This implementation is thread-safe and uses secure file operations
/// to prevent TOCTOU race conditions. Sensitive data in context is
/// automatically redacted.
public struct DefaultMemoryKitLogger: MemoryKitLogger {
    private let prefix: String
    private let logToFile: Bool
    private let logFileURL: URL?
    private static let fileWriteQueue = DispatchQueue(label: "MemoryKitLogger.fileWrite", qos: .utility)

    /// Keywords that indicate sensitive data that should be redacted.
    private static let sensitiveKeywords: Set<String> = [
        "password", "token", "secret", "key", "credential", "auth",
        "bearer", "api_key", "apikey", "private", "session"
    ]

    /// Creates a console-only logger.
    ///
    /// - Parameter prefix: Prefix for log messages (default: "[MemoryKit]")
    public init(prefix: String = "[MemoryKit]") {
        self.prefix = prefix
        self.logToFile = false
        self.logFileURL = nil
    }

    /// Creates a logger that optionally writes to the default log file.
    ///
    /// - Parameters:
    ///   - prefix: Prefix for log messages (default: "[MemoryKit]")
    ///   - logToFile: Whether to write logs to file
    public init(prefix: String = "[MemoryKit]", logToFile: Bool) {
        self.prefix = prefix
        self.logToFile = logToFile

        if logToFile {
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            self.logFileURL = homeURL.appendingPathComponent("substation.log")
        } else {
            self.logFileURL = nil
        }
    }

    /// Creates a logger that writes to a specific file URL.
    ///
    /// - Parameters:
    ///   - prefix: Prefix for log messages (default: "[MemoryKit]")
    ///   - logFileURL: URL of the log file
    public init(prefix: String = "[MemoryKit]", logFileURL: URL) {
        self.prefix = prefix
        self.logToFile = true
        self.logFileURL = logFileURL
    }

    /// Creates a logger that writes to a specific file path.
    ///
    /// - Parameters:
    ///   - prefix: Prefix for log messages (default: "[MemoryKit]")
    ///   - logFilePath: Path to the log file
    public init(prefix: String = "[MemoryKit]", logFilePath: String) {
        self.prefix = prefix
        self.logToFile = true
        self.logFileURL = URL(fileURLWithPath: logFilePath)
    }

    public func logDebug(_ message: String, context: [String: Any] = [:]) {
        log(level: "DEBUG", message: message, context: context)
    }

    public func logInfo(_ message: String, context: [String: Any] = [:]) {
        log(level: "INFO", message: message, context: context)
    }

    public func logWarning(_ message: String, context: [String: Any] = [:]) {
        log(level: "WARN", message: message, context: context)
    }

    public func logError(_ message: String, context: [String: Any] = [:]) {
        log(level: "ERROR", message: message, context: context)
    }

    /// Internal logging implementation.
    ///
    /// Uses ISO8601DateFormatter which is thread-safe, unlike DateFormatter.
    /// File operations avoid TOCTOU race conditions by not checking file existence.
    private func log(level: String, message: String, context: [String: Any]) {
        // Use ISO8601DateFormatter which is thread-safe (unlike DateFormatter)
        let timestamp = ISO8601DateFormatter.shared.string(from: Date())
        let contextString = context.isEmpty ? "" : " \(formatContext(context))"
        let logLine = "\(timestamp) \(prefix) [\(level)] \(message)\(contextString)"

        if logToFile, let logFileURL = logFileURL {
            // Write to file asynchronously
            Self.fileWriteQueue.async {
                let logEntry = Data((logLine + "\n").utf8)

                // Avoid TOCTOU: don't check if file exists, just try to open/create
                if let handle = FileHandle(forWritingAtPath: logFileURL.path) {
                    // File exists - append to it
                    defer { try? handle.close() }
                    do {
                        try handle.seekToEnd()
                        try handle.write(contentsOf: logEntry)
                    } catch {
                        // Fallback to console on error
                        print(logLine)
                    }
                } else {
                    // File doesn't exist - create with secure permissions
                    FileManager.default.createFile(
                        atPath: logFileURL.path,
                        contents: logEntry,
                        attributes: [.posixPermissions: 0o600]  // Owner read/write only
                    )
                }
            }
        } else {
            // Log to console
            print(logLine)
        }
    }

    /// Formats context dictionary for logging with sensitive data redaction.
    ///
    /// Keys containing sensitive keywords (password, token, secret, etc.)
    /// will have their values replaced with "[REDACTED]".
    ///
    /// - Parameter context: The context dictionary to format
    /// - Returns: A formatted string representation
    private func formatContext(_ context: [String: Any]) -> String {
        let pairs = context.map { key, value -> String in
            // Redact sensitive data to prevent information disclosure
            let lowerKey = key.lowercased()
            if Self.sensitiveKeywords.contains(where: { lowerKey.contains($0) }) {
                return "\(key)=[REDACTED]"
            }
            return "\(key)=\(value)"
        }
        return "{\(pairs.joined(separator: ", "))}"
    }
}

// MARK: - Silent Logger

/// Logger that does nothing - useful for testing or when logging is disabled.
public struct SilentMemoryKitLogger: MemoryKitLogger {
    /// Creates a silent logger.
    public init() {}

    public func logDebug(_ message: String, context: [String: Any] = [:]) {}
    public func logInfo(_ message: String, context: [String: Any] = [:]) {}
    public func logWarning(_ message: String, context: [String: Any] = [:]) {}
    public func logError(_ message: String, context: [String: Any] = [:]) {}
}

// MARK: - Logger Factory

/// Factory for creating MemoryKit loggers.
public enum MemoryKitLoggerFactory {
    /// Creates a logger that writes to a specific file path.
    ///
    /// - Parameters:
    ///   - logFilePath: Path to the log file
    ///   - prefix: Prefix for log messages (default: "[MemoryKit]")
    /// - Returns: A configured logger
    public static func fileLogger(logFilePath: String, prefix: String = "[MemoryKit]") -> any MemoryKitLogger {
        return DefaultMemoryKitLogger(prefix: prefix, logFilePath: logFilePath)
    }

    /// Creates a logger that writes to a specific file URL.
    ///
    /// - Parameters:
    ///   - logFileURL: URL of the log file
    ///   - prefix: Prefix for log messages (default: "[MemoryKit]")
    /// - Returns: A configured logger
    public static func fileLogger(logFileURL: URL, prefix: String = "[MemoryKit]") -> any MemoryKitLogger {
        return DefaultMemoryKitLogger(prefix: prefix, logFileURL: logFileURL)
    }

    /// Creates a console-only logger.
    ///
    /// - Parameter prefix: Prefix for log messages (default: "[MemoryKit]")
    /// - Returns: A configured logger
    public static func consoleLogger(prefix: String = "[MemoryKit]") -> any MemoryKitLogger {
        return DefaultMemoryKitLogger(prefix: prefix)
    }

    /// Creates a silent logger (no output).
    ///
    /// - Returns: A silent logger
    public static func silentLogger() -> any MemoryKitLogger {
        return SilentMemoryKitLogger()
    }

    /// Creates the default logger (silent - no output).
    ///
    /// - Returns: A silent logger
    public static func defaultLogger() -> any MemoryKitLogger {
        return SilentMemoryKitLogger()
    }
}

// MARK: - Thread-Safe Date Formatter

/// Thread-safe ISO8601 date formatter for logging.
///
/// ISO8601DateFormatter is documented as thread-safe, unlike DateFormatter.
/// The nonisolated(unsafe) annotation acknowledges that we're accessing shared
/// mutable state in a way that is known to be safe for this particular type.
private extension ISO8601DateFormatter {
    /// Shared thread-safe ISO8601 formatter instance.
    nonisolated(unsafe) static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
