import Foundation
import OSClient

/// Simplified error handling wrapper for OpenStack operations
///
/// This service provides a thin wrapper around EnhancedErrorHandler to simplify
/// error handling patterns across service layers and eliminate redundant catch blocks.
@MainActor
final class OperationErrorHandler {
    private let enhancedHandler: EnhancedErrorHandler

    init(enhancedHandler: EnhancedErrorHandler) {
        self.enhancedHandler = enhancedHandler
    }

    /// Handle an error from an operation and return a user-friendly message
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - operation: Description of the operation (e.g., "create server", "delete network")
    ///   - resourceType: Type of resource (e.g., "server", "network")
    ///   - resourceId: Optional resource ID
    ///   - view: Current view context
    /// - Returns: A user-friendly error message
    func handleError(
        _ error: any Error,
        operation: String,
        resourceType: String,
        resourceId: String? = nil,
        view: String
    ) -> String {
        let context = ErrorContext(
            operation: operation,
            resourceType: resourceType,
            resourceId: resourceId ?? "unknown",
            view: view
        )

        // Use existing EnhancedErrorHandler for sophisticated error processing
        let enhancedError = enhancedHandler.processError(error, context: context)
        return enhancedError.userMessage
    }

    /// Simplified error handler for common operations
    func handle(_ error: any Error, operation: String) -> String {
        let context = ErrorContext(
            operation: operation,
            resourceType: "resource",
            resourceId: "unknown",
            view: "operation"
        )

        let enhancedError = enhancedHandler.processError(error, context: context)
        return enhancedError.userMessage
    }
}
