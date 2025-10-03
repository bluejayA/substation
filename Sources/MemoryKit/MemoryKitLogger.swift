import Foundation

// MARK: - Memory Kit Logging Protocol

/// Protocol for logging within MemoryKit
public protocol MemoryKitLogger: Sendable {
    func logDebug(_ message: String, context: [String: Any])
    func logInfo(_ message: String, context: [String: Any])
    func logWarning(_ message: String, context: [String: Any])
    func logError(_ message: String, context: [String: Any])
}

// MARK: - Default Logger Implementation

/// Default logger implementation that can log to console or file
public struct DefaultMemoryKitLogger: MemoryKitLogger {
    private let prefix: String
    private let logToFile: Bool
    private let logFileURL: URL?
    private static let fileWriteQueue = DispatchQueue(label: "MemoryKitLogger.fileWrite", qos: .utility)

    public init(prefix: String = "[MemoryKit]") {
        self.prefix = prefix
        self.logToFile = false
        self.logFileURL = nil
    }

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

    public init(prefix: String = "[MemoryKit]", logFileURL: URL) {
        self.prefix = prefix
        self.logToFile = true
        self.logFileURL = logFileURL
    }

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

    private func log(level: String, message: String, context: [String: Any]) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        let contextString = context.isEmpty ? "" : " \(formatContext(context))"
        let logLine = "\(timestamp) \(prefix) [\(level)] \(message)\(contextString)"

        if logToFile, let logFileURL = logFileURL {
            // Write to file asynchronously with reduced overhead
            Self.fileWriteQueue.async {
                do {
                    let logEntry = logLine + "\n"
                    if FileManager.default.fileExists(atPath: logFileURL.path) {
                        let fileHandle = try FileHandle(forWritingTo: logFileURL)
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(Data(logEntry.utf8))
                        fileHandle.closeFile()
                    } else {
                        try logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
                    }
                } catch {
                    // Fallback to console if file logging fails
                    print(logLine)
                }
            }
        } else {
            // Log to console
            print(logLine)
        }
    }

    private func formatContext(_ context: [String: Any]) -> String {
        let pairs = context.map { "\($0.key)=\($0.value)" }
        return "{\(pairs.joined(separator: ", "))}"
    }
}

// MARK: - Silent Logger

/// Logger that does nothing - useful for testing or when logging is disabled
public struct SilentMemoryKitLogger: MemoryKitLogger {
    public init() {}

    public func logDebug(_ message: String, context: [String: Any] = [:]) {}
    public func logInfo(_ message: String, context: [String: Any] = [:]) {}
    public func logWarning(_ message: String, context: [String: Any] = [:]) {}
    public func logError(_ message: String, context: [String: Any] = [:]) {}
}

// MARK: - Shared Logger Instance

/// Factory for creating MemoryKit loggers
public enum MemoryKitLoggerFactory {
    /// Create a logger that writes to a specific file path
    public static func fileLogger(logFilePath: String, prefix: String = "[MemoryKit]") -> any MemoryKitLogger {
        return DefaultMemoryKitLogger(prefix: prefix, logFilePath: logFilePath)
    }

    /// Create a logger that writes to a specific file URL
    public static func fileLogger(logFileURL: URL, prefix: String = "[MemoryKit]") -> any MemoryKitLogger {
        return DefaultMemoryKitLogger(prefix: prefix, logFileURL: logFileURL)
    }

    /// Create a console logger
    public static func consoleLogger(prefix: String = "[MemoryKit]") -> any MemoryKitLogger {
        return DefaultMemoryKitLogger(prefix: prefix)
    }

    /// Create a silent logger (no output)
    public static func silentLogger() -> any MemoryKitLogger {
        return SilentMemoryKitLogger()
    }

    /// Create a default logger (silent - no output)
    public static func defaultLogger() -> any MemoryKitLogger {
        return SilentMemoryKitLogger()
    }
}

private extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}