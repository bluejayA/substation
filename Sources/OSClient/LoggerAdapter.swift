import Foundation
import MemoryKit

/// Adapter to bridge OpenStackClientLogger to MemoryKitLogger
public struct MemoryKitLoggerAdapter: MemoryKitLogger, Sendable {
    private let openStackLogger: any OpenStackClientLogger

    public init(openStackLogger: any OpenStackClientLogger) {
        self.openStackLogger = openStackLogger
    }

    public func logDebug(_ message: String, context: [String: Any]) {
        // Convert to sendable context by filtering safe types
        let sendableContext: [String: any Sendable] = context.compactMapValues { value in
            if let string = value as? String { return string }
            if let number = value as? Int { return number }
            if let double = value as? Double { return double }
            if let bool = value as? Bool { return bool }
            return String(describing: value) // Fallback to string representation
        }
        openStackLogger.logDebug(message, context: sendableContext)
    }

    public func logInfo(_ message: String, context: [String: Any]) {
        let sendableContext: [String: any Sendable] = context.compactMapValues { value in
            if let string = value as? String { return string }
            if let number = value as? Int { return number }
            if let double = value as? Double { return double }
            if let bool = value as? Bool { return bool }
            return String(describing: value)
        }
        openStackLogger.logInfo(message, context: sendableContext)
    }

    public func logWarning(_ message: String, context: [String: Any]) {
        // OpenStackClientLogger doesn't have logWarning, so use logInfo instead
        let sendableContext: [String: any Sendable] = context.compactMapValues { value in
            if let string = value as? String { return string }
            if let number = value as? Int { return number }
            if let double = value as? Double { return double }
            if let bool = value as? Bool { return bool }
            return String(describing: value)
        }
        openStackLogger.logInfo("[WARNING] \(message)", context: sendableContext)
    }

    public func logError(_ message: String, context: [String: Any]) {
        let sendableContext: [String: any Sendable] = context.compactMapValues { value in
            if let string = value as? String { return string }
            if let number = value as? Int { return number }
            if let double = value as? Double { return double }
            if let bool = value as? Bool { return bool }
            return String(describing: value)
        }
        openStackLogger.logError(message, context: sendableContext)
    }
}