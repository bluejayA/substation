import Foundation
import OSClient

// MARK: - Error Categories and Classifications

/// Categorizes errors for user-friendly handling
public enum ErrorCategory: Equatable {
    case authentication
    case authorization
    case network
    case quota
    case validation
    case timeout
    case resource
    case configuration
    case server
    case unknown

    var userFriendlyDescription: String {
        switch self {
        case .authentication:
            return "Authentication Problem"
        case .authorization:
            return "Permission Denied"
        case .network:
            return "Network Issue"
        case .quota:
            return "Resource Limit Exceeded"
        case .validation:
            return "Input Validation Error"
        case .timeout:
            return "Operation Timed Out"
        case .resource:
            return "Resource Unavailable"
        case .configuration:
            return "Configuration Error"
        case .server:
            return "Server Error"
        case .unknown:
            return "Unexpected Error"
        }
    }
}

/// Severity level for errors
public enum ErrorSeverity: Int, Comparable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3

    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Recovery action suggestions for errors
public struct ErrorRecoveryAction {
    let title: String
    let description: String
    let actionType: ActionType
    let isAutomatable: Bool

    enum ActionType {
        case retry
        case refresh
        case navigate(to: String)
        case configure(setting: String)
        case contact
        case documentation
        case custom(action: () async -> Void)
    }
}

/// Enhanced error information with user-friendly details
public struct EnhancedError {
    let originalError: any Error
    let category: ErrorCategory
    let severity: ErrorSeverity
    let userMessage: String
    let technicalMessage: String
    let recoveryActions: [ErrorRecoveryAction]
    let context: ErrorContext
    let timestamp: Date
    let errorId: String

    init(originalError: any Error, category: ErrorCategory, severity: ErrorSeverity,
         userMessage: String, technicalMessage: String? = nil,
         recoveryActions: [ErrorRecoveryAction] = [], context: ErrorContext) {
        self.originalError = originalError
        self.category = category
        self.severity = severity
        self.userMessage = userMessage
        self.technicalMessage = technicalMessage ?? originalError.localizedDescription
        self.recoveryActions = recoveryActions
        self.context = context
        self.timestamp = Date()
        self.errorId = UUID().uuidString.prefix(8).lowercased()
    }
}

/// Context information for error handling
public struct ErrorContext {
    let operation: String
    let resourceType: String?
    let resourceId: String?
    let view: String
    let userId: String?
    let additionalInfo: [String: String]

    init(operation: String, resourceType: String? = nil, resourceId: String? = nil,
         view: String = "unknown", userId: String? = nil, additionalInfo: [String: String] = [:]) {
        self.operation = operation
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.view = view
        self.userId = userId
        self.additionalInfo = additionalInfo
    }
}


// MARK: - Error Analysis Result

/// Result of error pattern analysis
public struct ErrorAnalysis {
    let totalErrors: Int
    let mostFrequentCategory: ErrorCategory
    let problemOperation: String?
    let averageSeverity: ErrorSeverity
    let suggestions: [String]
}