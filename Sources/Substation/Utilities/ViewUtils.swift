import Foundation
import SwiftTUI
import OSClient

/// SwiftTUI-compatible utilities replacing direct ncurses operations
struct ViewUtils {
    /// Prompt for user input using SwiftTUI
    @MainActor static func prompt(_ text: String, screen: OpaquePointer?, screenRows: Int32) -> String? {
        let surface = SwiftTUI.surface(from: screen)
        let position = Position(x: 1, y: screenRows - 2)

        return SwiftTUI.showInputDialog(
            prompt: text,
            on: surface,
            at: position
        )
    }

    /// Confirm deletion using a centered modal dialog
    @MainActor static func confirmDelete(_ itemName: String, screen: OpaquePointer?, screenRows: Int32, screenCols: Int32) async -> Bool {
        return await ConfirmationModal.show(
            title: "Confirm Deletion",
            message: "Delete '\(itemName)'?",
            screen: screen,
            screenRows: screenRows,
            screenCols: screenCols
        )
    }

    /// Confirm operation with custom title and message
    @MainActor static func confirmOperation(title: String, message: String, details: [String] = [], screen: OpaquePointer?, screenRows: Int32, screenCols: Int32) async -> Bool {
        return await ConfirmationModal.show(
            title: title,
            message: message,
            details: details,
            screen: screen,
            screenRows: screenRows,
            screenCols: screenCols
        )
    }

    /// Creates a simple progress bar for display
    static func createProgressBar(progress: Double, width: Int) -> String {
        let filled = Int(progress * Double(width))
        let empty = width - filled
        return String(repeating: "=", count: filled) + String(repeating: "-", count: empty)
    }

    /// Truncates text to fit within the specified width
    static func truncateStatusText(_ text: String, maxWidth: Int) -> String {
        if text.count <= maxWidth {
            return text
        }
        return String(text.prefix(maxWidth - 3)) + "..."
    }

    /// Sets an enhanced status message using the error handler for better formatting
    @MainActor
    static func setEnhancedStatusMessage(
        for error: any Error,
        operation: String,
        resourceType: String? = nil,
        resourceId: String? = nil,
        currentView: ViewMode,
        enhancedErrorHandler: EnhancedErrorHandler,
        statusMessage: inout String?
    ) {
        let context = ErrorContext(
            operation: operation,
            resourceType: resourceType,
            resourceId: resourceId,
            view: currentView.title
        )

        let enhancedError = enhancedErrorHandler.processError(error, context: context)
        statusMessage = enhancedError.userMessage

        // Show error banner for critical errors
        if enhancedError.severity >= .error {
            enhancedErrorHandler.showErrorBanner(enhancedError, duration: 8.0)
        }
    }

    /// Sets an enhanced status message for OSClient errors specifically
    @MainActor
    static func setEnhancedStatusMessage(
        for error: OpenStackError,
        operation: String,
        resourceType: String? = nil,
        resourceId: String? = nil,
        currentView: ViewMode,
        enhancedErrorHandler: EnhancedErrorHandler,
        statusMessage: inout String?
    ) {
        let context = ErrorContext(
            operation: operation,
            resourceType: resourceType,
            resourceId: resourceId,
            view: currentView.title
        )

        let enhancedError = enhancedErrorHandler.processOpenStackError(error, context: context)
        statusMessage = enhancedError.userMessage

        // Show error banner for critical errors
        if enhancedError.severity >= .error {
            enhancedErrorHandler.showErrorBanner(enhancedError, duration: 8.0)
        }
    }
}