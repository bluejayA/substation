import Foundation
import MemoryKit

// MARK: - SwiftNCurses Logger Configuration

/// Default silent logger for SwiftNCurses when no logger is configured
private final class DefaultSwiftNCursesLogger: MemoryKitLogger, @unchecked Sendable {
    func logDebug(_ message: String, context: [String: Any]) {}
    func logInfo(_ message: String, context: [String: Any]) {}
    func logWarning(_ message: String, context: [String: Any]) {}
    func logError(_ message: String, context: [String: Any]) {}
}

/// Global configuration for SwiftNCurses logging
public class SwiftNCursesLoggerConfig: @unchecked Sendable {
    public static let shared = SwiftNCursesLoggerConfig()

    private var _logger: any MemoryKitLogger = DefaultSwiftNCursesLogger()

    private init() {}

    /// Configure the logger used by all SwiftNCurses components
    nonisolated public func configure(logger: any MemoryKitLogger) {
        _logger = logger
    }

    /// Get the current logger
    nonisolated public var logger: any MemoryKitLogger {
        return _logger
    }

    /// Create a SwiftNCursesMemoryManager with the configured logger
    nonisolated public func createMemoryManager(configuration: SwiftNCursesMemoryManager.Configuration? = nil) -> SwiftNCursesMemoryManager {
        let config = configuration ?? SwiftNCursesMemoryManager.Configuration(logger: _logger)
        return SwiftNCursesMemoryManager(configuration: config)
    }
}

/// Extension to SwiftNCurses main interface for logger configuration
extension SwiftNCurses {
    /// Configure logging for all SwiftNCurses components
    nonisolated public static func configureLogging(logger: any MemoryKitLogger) {
        SwiftNCursesLoggerConfig.shared.configure(logger: logger)
    }
}