import Foundation

/// Thread-safe state container
final class LockedState<T>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()

    init(_ initialValue: T) {
        _value = initialValue
    }

    func withValue<R>(_ action: (inout T) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try action(&_value)
    }
}

/// Internal state for the Logger
struct LoggerState {
    var isDebugEnabled = false
    var logFileURL: URL?
}

/// A comprehensive logging system that writes to a file in the user's home directory
/// when debug mode is enabled. Supports structured logging, timing, and performance tracking.
public final class Logger: Sendable {
    public static let shared = Logger()

    private let state = LockedState<LoggerState>(LoggerState())
    private let queue = DispatchQueue(label: "com.substation.logger", qos: .utility)
    private let dateFormatter: DateFormatter

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone.current
    }

    /// Configure the logger with debug mode and set up log file
    public func configure(debugEnabled: Bool) {
        state.withValue { state in
            state.isDebugEnabled = debugEnabled
            if debugEnabled {
                setupLogFile(state: &state)
            }
        }
    }

    private func setupLogFile(state: inout LoggerState) {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        state.logFileURL = homeURL.appendingPathComponent("substation.log")

        // Create or clear the log file
        guard let logFileURL = state.logFileURL else { return }

        // check if file exists, if not, create it and throw error if it fails. If it exists, do nothing.
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            let fileCreated = FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
            if !fileCreated {
                print("Warning: Failed to create log file at \(logFileURL.path)")
            }
        }
    }

    /// Log an info level message
    public func logInfo(_ message: String, context: [String: any Sendable] = [:]) {
        guard state.withValue({ $0.isDebugEnabled }) else { return }
        log(level: "INFO", message: message, context: context)
    }

    /// Log a debug level message (only when debug is enabled)
    public func logDebug(_ message: String, context: [String: any Sendable] = [:]) {
        guard state.withValue({ $0.isDebugEnabled }) else { return }
        log(level: "DEBUG", message: message, context: context)
    }

    /// Log an error level message
    public func logError(_ message: String, error: (any Error)? = nil, context: [String: any Sendable] = [:]) {
        var fullMessage = message
        var fullContext = context
        if let error = error {
            fullMessage += " - Error: \(error.localizedDescription)"
            fullContext["error_type"] = String(describing: type(of: error))
        }
        log(level: "ERROR", message: fullMessage, context: fullContext)
    }

    /// Log a warning level message
    public func logWarning(_ message: String, context: [String: any Sendable] = [:]) {
        guard state.withValue({ $0.isDebugEnabled }) else { return }
        log(level: "WARNING", message: message, context: context)
    }

    /// Log a performance measurement
    public func logPerformance(_ operation: String, duration: TimeInterval, context: [String: any Sendable] = [:]) {
        guard state.withValue({ $0.isDebugEnabled }) else { return }
        var perfContext = context
        perfContext["duration_ms"] = String(format: "%.2f", duration * 1000)
        perfContext["duration_s"] = String(format: "%.3f", duration)

        let level: String
        let message: String

        // Classify performance based on operation type
        if operation.contains("API") || operation.contains("fetch") {
            // API calls
            if duration > 2.0 {
                level = "WARNING"
                message = "SLOW API: \(operation) took \(String(format: "%.3f", duration))s"
            } else if duration > 1.0 {
                level = "INFO"
                message = "API: \(operation) took \(String(format: "%.3f", duration))s"
            } else {
                level = "DEBUG"
                message = "API: \(operation) took \(String(format: "%.3f", duration))s"
            }
        } else if operation.contains("render") || operation.contains("draw") {
            // UI rendering
            if duration > 0.150 {
                level = "WARNING"
                message = "SLOW RENDER: \(operation) took \(String(format: "%.1f", duration * 1000))ms"
            } else if duration > 0.050 {
                level = "DEBUG"
                message = "RENDER: \(operation) took \(String(format: "%.1f", duration * 1000))ms"
            } else {
                level = "DEBUG"
                message = "RENDER: \(operation) took \(String(format: "%.1f", duration * 1000))ms"
            }
        } else {
            // General operations
            if duration > 1.0 {
                level = "INFO"
                message = "PERF: \(operation) took \(String(format: "%.3f", duration))s"
            } else {
                level = "DEBUG"
                message = "PERF: \(operation) took \(String(format: "%.3f", duration))s"
            }
        }

        log(level: level, message: message, context: perfContext)
    }

    /// Log user interaction
    public func logUserAction(_ action: String, details: [String: any Sendable] = [:]) {
        guard state.withValue({ $0.isDebugEnabled }) else { return }
        var context = details
        context["action_type"] = "user_interaction"
        log(level: "INFO", message: "USER: \(action)", context: context)
    }

    /// Log navigation events
    public func logNavigation(_ from: String, to: String, details: [String: any Sendable] = [:]) {
        guard state.withValue({ $0.isDebugEnabled }) else { return }
        var context = details
        context["from_view"] = from
        context["to_view"] = to
        context["action_type"] = "navigation"
        log(level: "INFO", message: "NAV: \(from) -> \(to)", context: context)
    }

    /// Log API call details
    public func logAPICall(_ method: String, url: String, statusCode: Int? = nil, duration: TimeInterval? = nil) {
        guard state.withValue({ $0.isDebugEnabled }) else { return }
        var context: [String: any Sendable] = [
            "http_method": method,
            "url": url,
            "action_type": "api_call"
        ]

        if let statusCode = statusCode {
            context["status_code"] = statusCode
        }

        if let duration = duration {
            context["duration_ms"] = String(format: "%.2f", duration * 1000)
        }

        let level: String
        if let statusCode = statusCode {
            if statusCode >= 400 {
                level = "ERROR"
            } else if statusCode >= 300 {
                level = "WARNING"
            } else {
                level = "DEBUG"
            }
        } else {
            level = "DEBUG"
        }

        let durationStr = duration.map { " (\(String(format: "%.2f", $0 * 1000))ms)" } ?? ""
        let statusStr = statusCode.map { " -> \($0)" } ?? ""
        log(level: level, message: "API: \(method) \(url)\(statusStr)\(durationStr)", context: context)
    }

    private func log(level: String, message: String, context: [String: any Sendable] = [:]) {
        // Only log to file when wiretap (debug mode) is enabled
        let logFileURL = state.withValue { state -> URL? in
            guard state.isDebugEnabled else { return nil }
            return state.logFileURL
        }

        guard let logFileURL = logFileURL else {
            return
        }

        let timestamp = dateFormatter.string(from: Date())

        // Build log entry with optional context
        var logEntry = "[\(timestamp)] [\(level)] \(message)"

        if !context.isEmpty {
            let contextStr = context
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            logEntry += " [\(contextStr)]"
        }

        logEntry += "\n"

        let entryToWrite = logEntry  // Capture the value before async block

        queue.async {
            do {
                if FileManager.default.fileExists(atPath: logFileURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: logFileURL)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(Data(entryToWrite.utf8))
                    fileHandle.closeFile()
                } else {
                    try entryToWrite.write(to: logFileURL, atomically: true, encoding: .utf8)
                }
            } catch {
                // If logging fails, we can't do much about it
                // to avoid infinite recursion
            }
        }
    }

    /// Convenience method to log application startup
    public func logStartup(_ message: String) {
        logInfo("=== APPLICATION STARTUP ===")
        logInfo(message)
    }

    /// Convenience method to log application shutdown
    public func logShutdown(_ message: String) {
        logInfo(message)
        logInfo("=== APPLICATION SHUTDOWN ===")
    }

    /// Measure and log the execution time of a closure
    public func measureTime<T>(_ operation: String, context: [String: any Sendable] = [:], _ closure: () throws -> T) rethrows -> T {
        let startTime = Date().timeIntervalSinceReferenceDate
        let result = try closure()
        let duration = Date().timeIntervalSinceReferenceDate - startTime
        logPerformance(operation, duration: duration, context: context)
        return result
    }

    /// Measure and log the execution time of an async closure
    public func measureTime<T>(_ operation: String, context: [String: any Sendable] = [:], _ closure: () async throws -> T) async rethrows -> T {
        let startTime = Date().timeIntervalSinceReferenceDate
        let result = try await closure()
        let duration = Date().timeIntervalSinceReferenceDate - startTime
        logPerformance(operation, duration: duration, context: context)
        return result
    }

    /// Check if debug logging is enabled
    public var debugEnabled: Bool {
        return state.withValue { $0.isDebugEnabled }
    }
}