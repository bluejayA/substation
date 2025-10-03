import Foundation
import MemoryKit

// MARK: - SwiftTUI Logger Configuration

/// Default silent logger for SwiftTUI when no logger is configured
private final class DefaultSwiftTUILogger: MemoryKitLogger, @unchecked Sendable {
    func logDebug(_ message: String, context: [String: Any]) {}
    func logInfo(_ message: String, context: [String: Any]) {}
    func logWarning(_ message: String, context: [String: Any]) {}
    func logError(_ message: String, context: [String: Any]) {}
}

/// Global configuration for SwiftTUI logging
public class SwiftTUILoggerConfig: @unchecked Sendable {
    public static let shared = SwiftTUILoggerConfig()

    private var _logger: any MemoryKitLogger = DefaultSwiftTUILogger()

    private init() {}

    /// Configure the logger used by all SwiftTUI components
    nonisolated public func configure(logger: any MemoryKitLogger) {
        _logger = logger
    }

    /// Get the current logger
    nonisolated public var logger: any MemoryKitLogger {
        return _logger
    }

    /// Create a SwiftTUIMemoryManager with the configured logger
    nonisolated public func createMemoryManager(configuration: SwiftTUIMemoryManager.Configuration? = nil) -> SwiftTUIMemoryManager {
        let config = configuration ?? SwiftTUIMemoryManager.Configuration(logger: _logger)
        return SwiftTUIMemoryManager(configuration: config)
    }
}

/// Extension to SwiftTUI main interface for logger configuration
extension SwiftTUI {
    /// Configure logging for all SwiftTUI components
    nonisolated public static func configureLogging(logger: any MemoryKitLogger) {
        SwiftTUILoggerConfig.shared.configure(logger: logger)
    }
}