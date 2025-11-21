import Foundation

/// Categorized transfer errors for Swift object storage operations
enum TransferError: Error, Sendable {
    case network(underlying: any Error, context: String)
    case authentication(message: String)
    case fileSystem(path: String, underlying: any Error)
    case serverError(statusCode: Int, message: String?)
    case notFound(objectName: String)
    case cancelled
    case unknown(underlying: any Error)

    /// User-facing error message for display
    var userFacingMessage: String {
        switch self {
        case .network(let error, let context):
            return "Network error during \(context): \(error.localizedDescription)"
        case .authentication(let message):
            return "Permission denied: \(message)"
        case .fileSystem(let path, let error):
            return "File system error at '\(path)': \(error.localizedDescription)"
        case .serverError(let code, let message):
            if let msg = message {
                return "Server error (\(code)): \(msg)"
            } else {
                return "Server error (HTTP \(code))"
            }
        case .notFound(let objectName):
            return "Object not found: \(objectName)"
        case .cancelled:
            return "Operation cancelled"
        case .unknown(let error):
            return "Error: \(error.localizedDescription)"
        }
    }

    /// Short error category name for logging
    var categoryName: String {
        switch self {
        case .network:
            return "Network Error"
        case .authentication:
            return "Permission Denied"
        case .fileSystem:
            return "File System Error"
        case .serverError:
            return "Server Error"
        case .notFound:
            return "Not Found"
        case .cancelled:
            return "Cancelled"
        case .unknown:
            return "Unknown Error"
        }
    }

    /// Indicates whether this error is retryable
    /// Network and server errors are retryable; authentication and file system errors are not
    var isRetryable: Bool {
        switch self {
        case .network, .serverError:
            return true
        case .authentication, .fileSystem, .notFound, .cancelled, .unknown:
            return false
        }
    }

    /// Recommendation for handling this error
    var retryRecommendation: String {
        switch self {
        case .network:
            return "Check network connection and retry"
        case .serverError(let code, _):
            if code >= 500 && code < 600 {
                return "Server is experiencing issues, retry after a brief wait"
            } else {
                return "Server returned error, retry may help"
            }
        case .authentication:
            return "Check credentials and permissions"
        case .fileSystem:
            return "Verify file path and permissions"
        case .notFound:
            return "Object does not exist, verify object name"
        case .cancelled:
            return "Operation was cancelled by user"
        case .unknown:
            return "Check error details and retry if appropriate"
        }
    }

    /// Create TransferError from a generic Error with context
    static func from(error: any Error, context: String, filePath: String? = nil, objectName: String? = nil) -> TransferError {
        // Check for cancellation
        if error is CancellationError {
            return .cancelled
        }

        // Check for NSError with domain
        let nsError = error as NSError

        // File system errors
        if nsError.domain == NSCocoaErrorDomain {
            let path = filePath ?? objectName ?? "unknown"
            return .fileSystem(path: path, underlying: error)
        }

        // Check error description for common patterns
        let errorDesc = error.localizedDescription.lowercased()

        // Authentication errors
        if errorDesc.contains("unauthorized") || errorDesc.contains("forbidden") ||
           errorDesc.contains("permission") || errorDesc.contains("authentication") {
            return .authentication(message: error.localizedDescription)
        }

        // Not found errors
        if errorDesc.contains("not found") || errorDesc.contains("404") {
            return .notFound(objectName: objectName ?? "unknown")
        }

        // Server errors
        if errorDesc.contains("server error") || errorDesc.contains("500") ||
           errorDesc.contains("503") || errorDesc.contains("502") {
            return .serverError(statusCode: 500, message: error.localizedDescription)
        }

        // Network errors
        if errorDesc.contains("network") || errorDesc.contains("connection") ||
           errorDesc.contains("timeout") || errorDesc.contains("unreachable") {
            return .network(underlying: error, context: context)
        }

        // Default to unknown
        return .unknown(underlying: error)
    }
}
