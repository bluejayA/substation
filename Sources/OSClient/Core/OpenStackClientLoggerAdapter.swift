import Foundation
import MemoryKit

/// Adapter that bridges OpenStackClientLogger to MemoryKitLogger
internal struct OpenStackClientLoggerAdapter: MemoryKitLogger {
    private let clientLogger: any OpenStackClientLogger
    private let component: String

    internal init(clientLogger: any OpenStackClientLogger, component: String = "MemoryManager") {
        self.clientLogger = clientLogger
        self.component = component
    }

    func logDebug(_ message: String, context: [String: Any] = [:]) {
        // OpenStackClientLogger doesn't have debug level, use info instead
        let sendableContext = convertContext(context)
        clientLogger.logInfo("[DEBUG][\(component)] \(message)", context: sendableContext)
    }

    func logInfo(_ message: String, context: [String: Any] = [:]) {
        let sendableContext = convertContext(context)
        clientLogger.logInfo("[\(component)] \(message)", context: sendableContext)
    }

    func logWarning(_ message: String, context: [String: Any] = [:]) {
        // OpenStackClientLogger doesn't have warning level, use info instead
        let sendableContext = convertContext(context)
        clientLogger.logInfo("[WARN][\(component)] \(message)", context: sendableContext)
    }

    func logError(_ message: String, context: [String: Any] = [:]) {
        let sendableContext = convertContext(context)
        clientLogger.logError("[\(component)] \(message)", context: sendableContext)
    }

    private func convertContext(_ context: [String: Any]) -> [String: any Sendable] {
        var sendableContext: [String: any Sendable] = [:]
        for (key, value) in context {
            // Convert common types to sendable equivalents
            switch value {
            case let stringValue as String:
                sendableContext[key] = stringValue
            case let intValue as Int:
                sendableContext[key] = intValue
            case let doubleValue as Double:
                sendableContext[key] = doubleValue
            case let boolValue as Bool:
                sendableContext[key] = boolValue
            default:
                sendableContext[key] = String(describing: value)
            }
        }
        return sendableContext
    }
}