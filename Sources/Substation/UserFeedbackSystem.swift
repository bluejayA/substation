import Foundation
import SwiftNCurses
import OSClient

// Resolve Position namespace conflict by using fully qualified name
// UIPosition refers to SwiftNCurses.Position which uses Int32 coordinates
typealias UIPosition = Position

// MARK: - User Feedback System

/// Comprehensive user feedback and notification system
/// Thread-safe through MainActor isolation - all access must be from MainActor
@MainActor
public final class UserFeedbackSystem {
    public var currentNotifications: [Notification] = []
    public var currentModal: Modal?
    public var statusBarMessage: StatusMessage?

    private let maxNotifications = 5
    private let defaultNotificationDuration: TimeInterval = 5.0
    private var notificationTasks: [String: Task<Void, Never>] = [:]

    public init() {}

    // MARK: - Notification Management

    /// Show a success notification
    public func showSuccess(_ message: String, duration: TimeInterval? = nil) {
        let notification = Notification(
            id: UUID().uuidString,
            type: .success,
            title: "Success",
            message: message,
            duration: duration ?? defaultNotificationDuration
        )
        addNotification(notification)
    }

    /// Show an error notification
    public func showError(_ message: String, error: (any Error)? = nil, duration: TimeInterval? = nil) {
        let fullMessage: String
        if let error = error {
            fullMessage = "\(message): \(error.localizedDescription)"
        } else {
            fullMessage = message
        }
        let notification = Notification(
            id: UUID().uuidString,
            type: .error,
            title: "Error",
            message: fullMessage,
            duration: duration ?? (defaultNotificationDuration * 2) // Errors stay longer
        )
        addNotification(notification)
    }

    /// Show a warning notification
    public func showWarning(_ message: String, duration: TimeInterval? = nil) {
        let notification = Notification(
            id: UUID().uuidString,
            type: .warning,
            title: "Warning",
            message: message,
            duration: duration ?? defaultNotificationDuration
        )
        addNotification(notification)
    }

    /// Show an info notification
    public func showInfo(_ message: String, duration: TimeInterval? = nil) {
        let notification = Notification(
            id: UUID().uuidString,
            type: .info,
            title: "Info",
            message: message,
            duration: duration ?? defaultNotificationDuration
        )
        addNotification(notification)
    }

    /// Show a loading notification
    public func showLoading(_ message: String) -> String {
        let notification = Notification(
            id: UUID().uuidString,
            type: .loading,
            title: "Loading",
            message: message,
            duration: nil // Loading notifications don't auto-dismiss
        )
        addNotification(notification)
        return notification.id
    }

    /// Update a loading notification
    public func updateLoading(id: String, message: String) {
        if let index = currentNotifications.firstIndex(where: { $0.id == id }) {
            currentNotifications[index].message = message
        }
    }

    /// Dismiss a notification by ID
    public func dismissNotification(id: String) {
        currentNotifications.removeAll { $0.id == id }
        notificationTasks[id]?.cancel()
        notificationTasks.removeValue(forKey: id)
    }

    /// Dismiss all notifications
    public func dismissAllNotifications() {
        currentNotifications.removeAll()
        notificationTasks.values.forEach { $0.cancel() }
        notificationTasks.removeAll()
    }

    // MARK: - Modal Management

    /// Show a confirmation modal
    public func showConfirmation(
        title: String,
        message: String,
        confirmText: String = "Confirm",
        cancelText: String = "Cancel",
        destructive: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        currentModal = Modal(
            type: .confirmation(
                title: title,
                message: message,
                confirmText: confirmText,
                cancelText: cancelText,
                destructive: destructive,
                onConfirm: {
                    onConfirm()
                    self.currentModal = nil
                },
                onCancel: {
                    onCancel?()
                    self.currentModal = nil
                }
            )
        )
    }

    /// Show an input modal
    public func showInput(
        title: String,
        message: String,
        placeholder: String = "",
        initialValue: String = "",
        validator: ((String) -> String?)? = nil,
        onSubmit: @escaping (String) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        currentModal = Modal(
            type: .input(
                title: title,
                message: message,
                placeholder: placeholder,
                initialValue: initialValue,
                validator: validator,
                onSubmit: { value in
                    onSubmit(value)
                    self.currentModal = nil
                },
                onCancel: {
                    onCancel?()
                    self.currentModal = nil
                }
            )
        )
    }

    /// Show a selection modal
    public func showSelection<T>(
        title: String,
        message: String,
        options: [T],
        displayName: @escaping (T) -> String,
        onSelect: @escaping (T) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        currentModal = Modal(
            type: .selection(
                title: title,
                message: message,
                options: options.map { option in
                    SelectionOption(
                        id: UUID().uuidString,
                        label: displayName(option),
                        value: option
                    )
                },
                onSelect: { option in
                    if let value = option.value as? T {
                        onSelect(value)
                    }
                    self.currentModal = nil
                },
                onCancel: {
                    onCancel?()
                    self.currentModal = nil
                }
            )
        )
    }

    /// Show a progress modal
    public func showProgress(
        title: String,
        message: String,
        cancelable: Bool = false,
        onCancel: (() -> Void)? = nil
    ) -> ProgressController {
        let controller = ProgressController()
        currentModal = Modal(
            type: .progress(
                title: title,
                message: message,
                controller: controller,
                cancelable: cancelable,
                onCancel: {
                    onCancel?()
                    self.currentModal = nil
                }
            )
        )
        return controller
    }

    /// Dismiss current modal
    public func dismissModal() {
        currentModal = nil
    }

    // MARK: - Status Bar Management

    /// Set status bar message
    public func setStatusMessage(_ message: String, type: StatusMessage.MessageType = .info) {
        statusBarMessage = StatusMessage(message: message, type: type, timestamp: Date())
    }

    /// Clear status bar message
    public func clearStatusMessage() {
        statusBarMessage = nil
    }

    // MARK: - Private Methods

    private func addNotification(_ notification: Notification) {
        // Remove oldest notifications if we have too many
        while currentNotifications.count >= maxNotifications {
            if let oldest = currentNotifications.first {
                dismissNotification(id: oldest.id)
            }
        }

        currentNotifications.append(notification)

        // Auto-dismiss if duration is set
        if let duration = notification.duration {
            let task = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                self.dismissNotification(id: notification.id)
            }
            notificationTasks[notification.id] = task
        }
    }
}

// MARK: - Data Models

public struct Notification: Identifiable, Sendable {
    public let id: String
    public let type: NotificationType
    public let title: String
    public var message: String
    public let duration: TimeInterval?
    public let timestamp: Date

    public init(id: String, type: NotificationType, title: String, message: String, duration: TimeInterval?) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
        self.timestamp = Date()
    }

    public enum NotificationType: Sendable {
        case success, error, warning, info, loading
    }
}

public struct Modal {
    public let type: ModalType

    public enum ModalType {
        case confirmation(
            title: String,
            message: String,
            confirmText: String,
            cancelText: String,
            destructive: Bool,
            onConfirm: () -> Void,
            onCancel: () -> Void
        )
        case input(
            title: String,
            message: String,
            placeholder: String,
            initialValue: String,
            validator: ((String) -> String?)?,
            onSubmit: (String) -> Void,
            onCancel: () -> Void
        )
        case selection(
            title: String,
            message: String,
            options: [SelectionOption],
            onSelect: (SelectionOption) -> Void,
            onCancel: () -> Void
        )
        case progress(
            title: String,
            message: String,
            controller: ProgressController,
            cancelable: Bool,
            onCancel: () -> Void
        )
    }
}

public struct SelectionOption: Identifiable {
    public let id: String
    public let label: String
    public let value: Any
}

public struct StatusMessage {
    public let message: String
    public let type: MessageType
    public let timestamp: Date

    public enum MessageType {
        case info, success, warning, error
    }
}

@MainActor
public final class ProgressController: Sendable {
    public var progress: Double = 0.0
    public var message: String = ""
    public var isIndeterminate: Bool = false

    public func updateProgress(_ value: Double, message: String? = nil) {
        progress = max(0.0, min(1.0, value))
        if let message = message {
            self.message = message
        }
        isIndeterminate = false
    }

    public func setIndeterminate(_ message: String? = nil) {
        isIndeterminate = true
        if let message = message {
            self.message = message
        }
    }

    public func complete() {
        progress = 1.0
        isIndeterminate = false
    }
}

// MARK: - UI Components

/// Modal view component
public struct ModalView: Component, @unchecked Sendable {
    private let modal: Modal

    public init(modal: Modal) {
        self.modal = modal
    }

    public var intrinsicSize: Size {
        return Size(width: 60, height: 20)
    }

    @MainActor
    public func render(in context: DrawingContext) async {
        // Render semi-transparent background overlay
        await renderOverlay(in: context)

        // Center the modal
        let modalWidth: Int32 = min(60, context.bounds.size.width - 4)
        let modalHeight: Int32 = min(20, context.bounds.size.height - 4)
        let modalX = (context.bounds.size.width - modalWidth) / 2
        let modalY = (context.bounds.size.height - modalHeight) / 2

        let modalRect = Rect(
            origin: UIPosition(x: modalX, y: modalY),
            size: Size(width: modalWidth, height: modalHeight)
        )

        await renderModalContent(in: context.subContext(rect: modalRect))
    }

    private func renderOverlay(in context: DrawingContext) async {
        // Fill background with dim characters
        for y in 0..<context.bounds.size.height {
            for x in 0..<context.bounds.size.width {
                let pos = UIPosition(x: Int32(x), y: Int32(y))
                await context.surface.draw(at: context.absolutePosition(for: pos), character: "-", style: .secondary)
            }
        }
    }

    private func renderModalContent(in context: DrawingContext) async {
        // Draw modal border
        await drawModalBorder(in: context)

        switch modal.type {
        case .confirmation(let title, let message, let confirmText, let cancelText, let destructive, _, _):
            await renderConfirmationModal(
                in: context,
                title: title,
                message: message,
                confirmText: confirmText,
                cancelText: cancelText,
                destructive: destructive
            )

        case .input(let title, let message, let placeholder, let initialValue, _, _, _):
            await renderInputModal(
                in: context,
                title: title,
                message: message,
                placeholder: placeholder,
                initialValue: initialValue
            )

        case .selection(let title, let message, let options, _, _):
            await renderSelectionModal(
                in: context,
                title: title,
                message: message,
                options: options
            )

        case .progress(let title, let message, let controller, let cancelable, _):
            await renderProgressModal(
                in: context,
                title: title,
                message: message,
                controller: controller,
                cancelable: cancelable
            )
        }
    }

    private func drawModalBorder(in context: DrawingContext) async {
        let rect = context.bounds

        // Draw border
        for x in 0..<rect.size.width {
            await context.surface.draw(at: context.absolutePosition(for: UIPosition(x: Int32(x), y: 0)), character: "-", style: .border)
            await context.surface.draw(at: context.absolutePosition(for: UIPosition(x: Int32(x), y: rect.size.height - 1)), character: "-", style: .border)
        }

        for y in 0..<rect.size.height {
            await context.surface.draw(at: context.absolutePosition(for: UIPosition(x: 0, y: Int32(y))), character: "|", style: .border)
            await context.surface.draw(at: context.absolutePosition(for: UIPosition(x: rect.size.width - 1, y: Int32(y))), character: "|", style: .border)
        }

        // Corners
        await context.surface.draw(at: context.absolutePosition(for: UIPosition(x: 0, y: 0)), character: "+", style: .accent)
        await context.surface.draw(at: context.absolutePosition(for: UIPosition(x: rect.size.width - 1, y: 0)), character: "+", style: .accent)
        await context.surface.draw(at: context.absolutePosition(for: UIPosition(x: 0, y: rect.size.height - 1)), character: "+", style: .accent)
        await context.surface.draw(at: context.absolutePosition(for: UIPosition(x: rect.size.width - 1, y: rect.size.height - 1)), character: "+", style: .accent)

        // Fill background
        for y in 1..<(rect.size.height - 1) {
            for x in 1..<(rect.size.width - 1) {
                await context.surface.draw(at: context.absolutePosition(for: UIPosition(x: Int32(x), y: Int32(y))), character: " ", style: .primary)
            }
        }
    }

    private func renderConfirmationModal(
        in context: DrawingContext,
        title: String,
        message: String,
        confirmText: String,
        cancelText: String,
        destructive: Bool
    ) async {
        // Title
        let titleRect = Rect(origin: UIPosition(x: 2, y: 1), size: Size(width: context.bounds.size.width - 4, height: 1))
        let titleComponent = Text(title).accent().bold()
        await titleComponent.render(in: context.subContext(rect: titleRect))

        // Message
        let messageRect = Rect(origin: UIPosition(x: 2, y: 3), size: Size(width: context.bounds.size.width - 4, height: context.bounds.size.height - 8))
        let messageComponent = Text(message).primary()
        await messageComponent.render(in: context.subContext(rect: messageRect))

        // Buttons
        let buttonY = context.bounds.size.height - 3
        let confirmStyle: TextStyle = destructive ? .error : .success
        let confirmButtonText = "[ \(confirmText) ]"
        let cancelButtonText = "[ \(cancelText) ]"

        let confirmRect = Rect(origin: UIPosition(x: 2, y: buttonY), size: Size(width: Int32(confirmButtonText.count), height: 1))
        let confirmComponent = Text(confirmButtonText).styled(confirmStyle)
        await confirmComponent.render(in: context.subContext(rect: confirmRect))

        let cancelX = context.bounds.size.width - Int32(cancelButtonText.count) - 2
        let cancelRect = Rect(origin: UIPosition(x: cancelX, y: buttonY), size: Size(width: Int32(cancelButtonText.count), height: 1))
        let cancelComponent = Text(cancelButtonText).secondary()
        await cancelComponent.render(in: context.subContext(rect: cancelRect))
    }

    private func renderInputModal(
        in context: DrawingContext,
        title: String,
        message: String,
        placeholder: String,
        initialValue: String
    ) async {
        // Title
        let titleRect = Rect(origin: UIPosition(x: 2, y: 1), size: Size(width: context.bounds.size.width - 4, height: 1))
        let titleComponent = Text(title).accent().bold()
        await titleComponent.render(in: context.subContext(rect: titleRect))

        // Message
        let messageLines = message.components(separatedBy: .newlines)
        var currentRow: Int32 = 3
        for line in messageLines {
            let messageRect = Rect(origin: UIPosition(x: 2, y: currentRow), size: Size(width: context.bounds.size.width - 4, height: 1))
            let messageComponent = Text(line).muted()
            await messageComponent.render(in: context.subContext(rect: messageRect))
            currentRow += 1
        }

        // Input field background
        let inputY = currentRow + 1
        let inputRect = Rect(origin: UIPosition(x: 2, y: inputY), size: Size(width: context.bounds.size.width - 4, height: 3))
        let inputBorder = BorderedContainer {
            let _ = Text("")
        }
        await inputBorder.render(in: context.subContext(rect: inputRect))

        // Placeholder or current value
        let inputValue = initialValue.isEmpty ? placeholder : initialValue
        let inputValueRect = Rect(origin: UIPosition(x: 3, y: inputY + 1), size: Size(width: context.bounds.size.width - 6, height: 1))
        let inputValueComponent = Text(inputValue).secondary()
        await inputValueComponent.render(in: context.subContext(rect: inputValueRect))

        // Cursor indicator (simple blinking cursor simulation)
        let cursorRect = Rect(origin: UIPosition(x: Int32(3 + inputValue.count), y: inputY + 1), size: Size(width: 1, height: 1))
        let cursorComponent = Text("_").accent()
        await cursorComponent.render(in: context.subContext(rect: cursorRect))

        // Buttons
        let buttonY = context.bounds.size.height - 3

        // OK button
        let okButtonText = "[OK]"
        let okX = (context.bounds.size.width / 2) - Int32(okButtonText.count) - 2
        let okRect = Rect(origin: UIPosition(x: okX, y: buttonY), size: Size(width: Int32(okButtonText.count), height: 1))
        let okComponent = Text(okButtonText).accent().bold()
        await okComponent.render(in: context.subContext(rect: okRect))

        // Cancel button
        let cancelButtonText = "[Cancel]"
        let cancelX = (context.bounds.size.width / 2) + 2
        let cancelRect = Rect(origin: UIPosition(x: cancelX, y: buttonY), size: Size(width: Int32(cancelButtonText.count), height: 1))
        let cancelComponent = Text(cancelButtonText).secondary()
        await cancelComponent.render(in: context.subContext(rect: cancelRect))

        // Instructions
        let instructionY = buttonY + 2
        let instructions = "Enter: Submit - Esc: Cancel - Type to edit"
        let instructionX = (context.bounds.size.width - Int32(instructions.count)) / 2
        let instructionRect = Rect(origin: UIPosition(x: instructionX, y: instructionY), size: Size(width: Int32(instructions.count), height: 1))
        let instructionComponent = Text(instructions).muted()
        await instructionComponent.render(in: context.subContext(rect: instructionRect))
    }

    private func renderSelectionModal(
        in context: DrawingContext,
        title: String,
        message: String,
        options: [SelectionOption]
    ) async {
        // Title
        let titleRect = Rect(origin: UIPosition(x: 2, y: 1), size: Size(width: context.bounds.size.width - 4, height: 1))
        let titleComponent = Text(title).accent().bold()
        await titleComponent.render(in: context.subContext(rect: titleRect))

        // Message
        let messageLines = message.components(separatedBy: .newlines)
        var currentRow: Int32 = 3
        for line in messageLines {
            let messageRect = Rect(origin: UIPosition(x: 2, y: currentRow), size: Size(width: context.bounds.size.width - 4, height: 1))
            let messageComponent = Text(line).muted()
            await messageComponent.render(in: context.subContext(rect: messageRect))
            currentRow += 1
        }

        // Options list
        currentRow += 1
        let maxVisibleOptions = Int(context.bounds.size.height - currentRow - 5) // Leave space for buttons
        let visibleOptions = Array(options.prefix(maxVisibleOptions))

        // List border
        let listHeight = Int32(min(visibleOptions.count + 2, maxVisibleOptions + 2))
        let listRect = Rect(origin: UIPosition(x: 2, y: currentRow), size: Size(width: context.bounds.size.width - 4, height: listHeight))
        let listBorder = BorderedContainer {
            let _ = Text("")
        }
        await listBorder.render(in: context.subContext(rect: listRect))

        // Option items
        for (index, option) in visibleOptions.enumerated() {
            let optionY = currentRow + 1 + Int32(index)
            let isSelected = index == 0 // Default to first option selected

            // Selection indicator
            let indicator = isSelected ? ">> " : "   "
            let optionText = "\(indicator)\(option.label)"

            let optionRect = Rect(origin: UIPosition(x: 3, y: optionY), size: Size(width: context.bounds.size.width - 6, height: 1))
            let optionComponent = isSelected ? Text(optionText).accent().bold() : Text(optionText).primary()
            await optionComponent.render(in: context.subContext(rect: optionRect))
        }

        // Show scroll indicator if there are more options
        if options.count > maxVisibleOptions {
            let scrollText = "... (\(options.count - maxVisibleOptions) more)"
            let scrollY = currentRow + Int32(visibleOptions.count) + 1
            let scrollRect = Rect(origin: UIPosition(x: 3, y: scrollY), size: Size(width: context.bounds.size.width - 6, height: 1))
            let scrollComponent = Text(scrollText).muted()
            await scrollComponent.render(in: context.subContext(rect: scrollRect))
        }

        // Buttons
        let buttonY = context.bounds.size.height - 3

        // Select button
        let selectButtonText = "[Select]"
        let selectX = (context.bounds.size.width / 2) - Int32(selectButtonText.count) - 2
        let selectRect = Rect(origin: UIPosition(x: selectX, y: buttonY), size: Size(width: Int32(selectButtonText.count), height: 1))
        let selectComponent = Text(selectButtonText).accent().bold()
        await selectComponent.render(in: context.subContext(rect: selectRect))

        // Cancel button
        let cancelButtonText = "[Cancel]"
        let cancelX = (context.bounds.size.width / 2) + 2
        let cancelRect = Rect(origin: UIPosition(x: cancelX, y: buttonY), size: Size(width: Int32(cancelButtonText.count), height: 1))
        let cancelComponent = Text(cancelButtonText).secondary()
        await cancelComponent.render(in: context.subContext(rect: cancelRect))

        // Instructions
        let instructionY = buttonY + 2
        let instructions = "UP/DOWN: Navigate - Enter: Select - Esc: Cancel"
        let instructionX = (context.bounds.size.width - Int32(instructions.count)) / 2
        let instructionRect = Rect(origin: UIPosition(x: instructionX, y: instructionY), size: Size(width: Int32(instructions.count), height: 1))
        let instructionComponent = Text(instructions).muted()
        await instructionComponent.render(in: context.subContext(rect: instructionRect))
    }

    private func renderProgressModal(
        in context: DrawingContext,
        title: String,
        message: String,
        controller: ProgressController,
        cancelable: Bool
    ) async {
        // Title
        let titleRect = Rect(origin: UIPosition(x: 2, y: 1), size: Size(width: context.bounds.size.width - 4, height: 1))
        let titleComponent = Text(title).accent().bold()
        await titleComponent.render(in: context.subContext(rect: titleRect))

        // Progress bar
        let progressRect = Rect(
            origin: UIPosition(x: 2, y: context.bounds.size.height / 2),
            size: Size(width: context.bounds.size.width - 4, height: 1)
        )

        if await controller.isIndeterminate {
            // Render spinning indicator
            let spinChars = ["|", "/", "-", "\\"]
            let spinChar = spinChars[Int(Date().timeIntervalSince1970) % spinChars.count]
            let spinComponent = Text("\(spinChar) \(await controller.message)").accent()
            await spinComponent.render(in: context.subContext(rect: progressRect))
        } else {
            // Simple progress bar using text
            let totalWidth = Int(progressRect.size.width)
            let filledWidth = Int(Double(totalWidth) * (await controller.progress))
            let progressText = String(repeating: "#", count: filledWidth) + String(repeating: "-", count: totalWidth - filledWidth)
            let progressComponent = Text("[\(progressText)] \(Int((await controller.progress) * 100))%").accent()
            await progressComponent.render(in: context.subContext(rect: progressRect))
        }
    }
}

// MARK: - Error Handling Integration

/// Enhanced error handler that integrates with user feedback
///
/// This handler processes errors and converts them to user-friendly messages.
/// Error logging is handled separately by the callers using Logger.shared
/// to ensure logs go to the log file rather than the terminal screen.
public final class EnhancedErrorHandler {
    private let feedbackSystem: UserFeedbackSystem

    public init(feedbackSystem: UserFeedbackSystem) {
        self.feedbackSystem = feedbackSystem
    }

    /// Process an OpenStack error and return enhanced error information
    ///
    /// Converts an OpenStackError into an EnhancedError with user-friendly messaging.
    /// Note: Error logging should be handled by the caller using Logger.shared
    /// to avoid duplicate output to the terminal.
    ///
    /// - Parameters:
    ///   - error: The OpenStack error to process
    ///   - context: Context about where the error occurred
    /// - Returns: Enhanced error with user-friendly message and recovery options
    public func processOpenStackError(_ error: OpenStackError, context: ErrorContext) -> EnhancedError {
        let enhancedError = createEnhancedError(from: error, context: context)
        return enhancedError
    }

    /// Process a general error and return enhanced error information
    ///
    /// Converts any Error into an EnhancedError with user-friendly messaging.
    /// Note: Error logging should be handled by the caller using Logger.shared
    /// to avoid duplicate output to the terminal.
    ///
    /// - Parameters:
    ///   - error: The error to process
    ///   - context: Context about where the error occurred
    /// - Returns: Enhanced error with user-friendly message and recovery options
    public func processError(_ error: any Error, context: ErrorContext) -> EnhancedError {
        let enhancedError = createEnhancedError(from: error, context: context)
        return enhancedError
    }

    /// Show error banner to the user
    @MainActor
    public func showErrorBanner(_ error: EnhancedError, duration: TimeInterval = 5.0) {
        feedbackSystem.showError(error.userMessage, error: nil, duration: duration)
    }

    /// Create enhanced error from a general error
    private func createEnhancedError(from error: any Error, context: ErrorContext) -> EnhancedError {
        let userMessage: String
        let severity: ErrorSeverity
        let category: ErrorCategory
        let recoveryActions: [ErrorRecoveryAction] = []

        if let openStackError = error as? OpenStackError {
            switch openStackError {
            case .authenticationFailed:
                userMessage = "Authentication failed. Please check your credentials."
                severity = .critical
                category = .authentication
            case .networkError:
                userMessage = "Network connection error. Please check your connection."
                severity = .error
                category = .network
            case .httpError(let code, _):
                userMessage = "Server returned error code \(code). Please try again later."
                severity = code >= 500 ? .critical : .warning
                category = .server
            case .endpointNotFound:
                userMessage = "Service endpoint not found. Please check your configuration."
                severity = .error
                category = .configuration
            case .decodingError, .encodingError:
                userMessage = "Data processing error occurred. Please try again."
                severity = .warning
                category = .unknown
            case .configurationError:
                userMessage = "Configuration error. Please check your settings."
                severity = .error
                category = .configuration
            case .unexpectedResponse:
                userMessage = "Unexpected server response. Please try again."
                severity = .warning
                category = .server
            case .performanceEnhancementsNotAvailable:
                userMessage = "Performance enhancements are not available or not initialized."
                severity = .info
                category = .configuration
            case .missingRequiredField(let field):
                userMessage = "Missing required field: \(field). Please complete all required information."
                severity = .warning
                category = .configuration
            case .invalidResponse:
                userMessage = "Invalid response from server. Please try again."
                severity = .warning
                category = .server
            case .invalidURL:
                userMessage = "Invalid URL configuration. Please check your settings."
                severity = .error
                category = .configuration
            }
        } else {
            userMessage = "An unexpected error occurred: \(error.localizedDescription)"
            severity = .warning
            category = .unknown
        }

        return EnhancedError(
            originalError: error,
            category: category,
            severity: severity,
            userMessage: userMessage,
            technicalMessage: error.localizedDescription,
            recoveryActions: recoveryActions,
            context: context
        )
    }

    /// Handle an error with appropriate user feedback
    ///
    /// Note: Error logging should be handled by the caller using Logger.shared
    /// to avoid output to the terminal screen.
    ///
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Context string for error message
    ///   - showUser: Whether to show the error to the user
    @MainActor
    public func handle(_ error: any Error, context: String = "", showUser: Bool = true) {
        if showUser {
            let userMessage = getUserFriendlyMessage(for: error, context: context)
            feedbackSystem.showError(userMessage, error: error)
        }
    }

    /// Handle a recoverable error with retry option
    @MainActor
    public func handleRecoverable(
        _ error: any Error,
        context: String = "",
        onRetry: @escaping () async throws -> Void
    ) {
        let userMessage = getUserFriendlyMessage(for: error, context: context)

        feedbackSystem.showConfirmation(
            title: "Operation Failed",
            message: "\(userMessage)\n\nWould you like to retry?",
            confirmText: "Retry",
            cancelText: "Cancel"
        ) {
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await onRetry()
                    await MainActor.run {
                        self.feedbackSystem.showSuccess("Operation completed successfully")
                    }
                } catch {
                    await MainActor.run {
                        self.handle(error, context: context)
                    }
                }
            }
        }
    }

    private func getUserFriendlyMessage(for error: any Error, context: String) -> String {
        switch error {
        case OpenStackError.authenticationFailed:
            return "Authentication failed. Please check your credentials."

        case OpenStackError.endpointNotFound:
            return "Service endpoint not found. The OpenStack service may not be available."

        case OpenStackError.httpError(let code, _):
            switch code {
            case 401:
                return "Authentication required. Your session may have expired."
            case 403:
                return "Access denied. You don't have permission for this operation."
            case 404:
                return "Resource not found."
            case 429:
                return "Too many requests. Please wait and try again."
            case 500...599:
                return "Server error. The OpenStack service is experiencing issues."
            default:
                return "Request failed with error code \(code)."
            }

        case is URLError:
            return "Network connection failed. Please check your internet connection."

        default:
            let baseMessage = context.isEmpty ? "An unexpected error occurred" : "Error in \(context)"
            return "\(baseMessage): \(error.localizedDescription)"
        }
    }
}