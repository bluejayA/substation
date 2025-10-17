import Foundation
import CNCurses

// MARK: - Dialog Components

/// SwiftNCurses-compatible input dialog component
public struct InputDialog: Component {
    private let prompt: String
    private let maxLength: Int

    public init(prompt: String, maxLength: Int = 255) {
        self.prompt = prompt
        self.maxLength = maxLength
    }

    public var intrinsicSize: Size {
        return Size(width: Int32(max(prompt.count + 10, 40)), height: 3)
    }

    @MainActor public func render(in context: DrawingContext) async {
        let promptText = Text(prompt, style: .secondary)
        await promptText.render(in: context)
    }

    /// Get user input using SwiftNCurses surface management
    @MainActor public static func getInput(
        prompt: String,
        surface: any Surface,
        position: Position,
        maxLength: Int = 255
    ) -> String? {
        return surface.getStringInput(at: position, prompt: prompt, maxLength: maxLength)
    }
}

/// SwiftNCurses-compatible confirmation dialog component
public struct ConfirmationDialog: Component {
    private let message: String
    private let confirmKey: String
    private let cancelKey: String

    public init(message: String, confirmKey: String = "Y", cancelKey: String = "N") {
        self.message = message
        self.confirmKey = confirmKey
        self.cancelKey = cancelKey
    }

    public var intrinsicSize: Size {
        let fullMessage = "\(message) [\(confirmKey)/\(cancelKey)]"
        return Size(width: Int32(fullMessage.count), height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        let fullMessage = "\(message) [\(confirmKey)/\(cancelKey)]"
        let warningText = Text(fullMessage, style: .warning)
        await warningText.render(in: context)
    }

    /// Show confirmation dialog and get user response
    @MainActor public static func confirm(
        message: String,
        surface: any Surface,
        position: Position,
        confirmKey: Character = "Y",
        cancelKey: Character = "N"
    ) async -> Bool {
        // Show message with warning style
        surface.move(to: position)
        surface.clearToEndOfLine()

        let fullMessage = "\(message) [\(confirmKey)/\(cancelKey)]: "
        await surface.draw(at: position, text: fullMessage, style: .warning)

        // Get single character input
        guard let inputChar = surface.getCharacterInput() else { return false }

        // Clear the message line
        surface.move(to: position)
        surface.clearToEndOfLine()

        // Check if the input matches confirm key (case insensitive)
        return inputChar.lowercased() == confirmKey.lowercased()
    }
}

/// SwiftNCurses-compatible modal dialog container
public struct Modal: Component {
    private let content: any Component
    private let title: String?

    public init(title: String? = nil, @ComponentBuilder content: () -> any Component) {
        self.title = title
        self.content = content()
    }

    public init(title: String? = nil, content: any Component) {
        self.title = title
        self.content = content
    }

    public var intrinsicSize: Size {
        let contentSize = content.intrinsicSize
        let titleHeight: Int32 = title != nil ? 1 : 0
        return Size(
            width: contentSize.width + 4, // Add border padding
            height: contentSize.height + titleHeight + 2 // Add border and title
        )
    }

    @MainActor public func render(in context: DrawingContext) async {
        // Draw border and render content inside
        await BorderedContainer(
            title: title,
            content: {
                // Create inner context for content (inside border)
                let innerBounds = Rect(
                    origin: Position(row: 1, col: 1),
                    size: Size(
                        width: context.bounds.size.width - 2,
                        height: context.bounds.size.height - 2
                    )
                )
                let innerContext = context.subContext(rect: innerBounds)
                await self.content.render(in: innerContext)
            }
        ).render(in: context)
    }
}

// MARK: - SwiftNCurses Extensions for Dialog Support

extension SwiftNCurses {
    /// Show an input dialog and return the user's input
    @MainActor public static func showInputDialog(
        prompt: String,
        on surface: any Surface,
        at position: Position,
        maxLength: Int = 255
    ) -> String? {
        return InputDialog.getInput(
            prompt: prompt,
            surface: surface,
            position: position,
            maxLength: maxLength
        )
    }

    /// Show a confirmation dialog and return the user's choice
    @MainActor public static func showConfirmationDialog(
        message: String,
        on surface: any Surface,
        at position: Position
    ) async -> Bool {
        return await ConfirmationDialog.confirm(
            message: message,
            surface: surface,
            position: position
        )
    }

    /// Show a deletion confirmation dialog
    @MainActor public static func confirmDeletion(
        of itemName: String,
        on surface: any Surface,
        at position: Position
    ) async -> Bool {
        return await ConfirmationDialog.confirm(
            message: "Delete '\(itemName)'?",
            surface: surface,
            position: position
        )
    }
}