import Foundation
import CNCurses

// MARK: - Confirmation Modal Component

/// A centered modal dialog for confirmations (Yes/No)
@MainActor
public struct ConfirmationModal {
    private let message: String
    private let title: String
    private let details: [String]

    public init(title: String = "Confirm", message: String, details: [String] = []) {
        self.title = title
        self.message = message
        self.details = details
    }

    /// Show the confirmation modal and wait for user response
    /// Returns true if user pressed Y/y, false otherwise
    public static func show(
        title: String = "Confirm",
        message: String,
        details: [String] = [],
        screen: OpaquePointer?,
        screenRows: Int32,
        screenCols: Int32
    ) async -> Bool {
        // Set blocking mode for input
        let _ = SwiftTUI.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftTUI.setNodelay(WindowHandle(screen), true)
        }

        let surface = SwiftTUI.surface(from: screen)

        // Calculate modal dimensions based on content
        let modalWidth: Int32 = min(60, screenCols - 4)
        let baseHeight: Int32 = 7
        let detailsHeight = min(Int32(details.count), 10)
        let modalHeight = baseHeight + detailsHeight
        let modalX = (screenCols - modalWidth) / 2
        let modalY = (screenRows - modalHeight) / 2

        let modalBounds = Rect(x: modalX, y: modalY, width: modalWidth, height: modalHeight)

        // Draw modal background and border
        await drawModalBackground(surface: surface, bounds: modalBounds)

        // Draw title
        let titleY = modalY + 1
        let titleText = " \(title) "
        let titleX = modalX + (modalWidth - Int32(titleText.count)) / 2
        await surface.draw(at: Position(x: titleX, y: titleY), text: titleText, style: .accent)

        // Draw message (word-wrapped if needed)
        var currentY = modalY + 3
        let messageMaxWidth = Int(modalWidth - 4)
        let wrappedLines = wordWrap(message, maxWidth: messageMaxWidth)
        for (index, line) in wrappedLines.prefix(2).enumerated() {
            let lineX = modalX + 2
            let lineY = currentY + Int32(index)
            await surface.draw(at: Position(x: lineX, y: lineY), text: line, style: .primary)
        }
        currentY += Int32(min(wrappedLines.count, 2))

        // Draw details if provided
        if !details.isEmpty {
            currentY += 1
            for (index, detail) in details.prefix(10).enumerated() {
                let lineX = modalX + 2
                let lineY = currentY + Int32(index)
                let truncatedDetail = truncateString(detail, maxWidth: messageMaxWidth)
                await surface.draw(at: Position(x: lineX, y: lineY), text: "  - \(truncatedDetail)", style: .secondary)
            }
            currentY += Int32(min(details.count, 10))
        }

        // Draw prompt
        let promptY = modalY + modalHeight - 2
        let promptText = "[Y]es / [N]o: "
        let promptX = modalX + (modalWidth - Int32(promptText.count)) / 2
        await surface.draw(at: Position(x: promptX, y: promptY), text: promptText, style: .warning)

        // Flush buffer and refresh screen to show modal
        surface.flushBuffer()
        let _ = compatWRefresh(WindowHandle(screen))

        // Get input
        let ch = SwiftTUI.getInput(WindowHandle(screen))

        // Clear modal area immediately
        surface.clear(rect: modalBounds)
        surface.flushBuffer()
        let _ = compatWRefresh(WindowHandle(screen))

        // Check if user confirmed
        return ch == Int32(89) || ch == Int32(121) // 'Y' or 'y'
    }

    /// Draw the modal background with border
    private static func drawModalBackground(surface: any Surface, bounds: Rect) async {
        // Fill background with error style to ensure it stands out and covers content behind it
        await surface.fill(rect: bounds, character: " ", style: .error)

        // Draw border
        let topLeft = bounds.origin
        let topRight = Position(x: bounds.origin.x + bounds.size.width - 1, y: bounds.origin.y)
        let bottomLeft = Position(x: bounds.origin.x, y: bounds.origin.y + bounds.size.height - 1)
        let bottomRight = Position(x: bounds.origin.x + bounds.size.width - 1, y: bounds.origin.y + bounds.size.height - 1)

        // Top and bottom borders
        for x in (bounds.origin.x + 1)..<(bounds.origin.x + bounds.size.width - 1) {
            await surface.draw(at: Position(x: x, y: bounds.origin.y), character: "-", style: .border)
            await surface.draw(at: Position(x: x, y: bounds.origin.y + bounds.size.height - 1), character: "-", style: .border)
        }

        // Left and right borders
        for y in (bounds.origin.y + 1)..<(bounds.origin.y + bounds.size.height - 1) {
            await surface.draw(at: Position(x: bounds.origin.x, y: y), character: "|", style: .border)
            await surface.draw(at: Position(x: bounds.origin.x + bounds.size.width - 1, y: y), character: "|", style: .border)
        }

        // Corners
        await surface.draw(at: topLeft, character: "+", style: .border)
        await surface.draw(at: topRight, character: "+", style: .border)
        await surface.draw(at: bottomLeft, character: "+", style: .border)
        await surface.draw(at: bottomRight, character: "+", style: .border)
    }

    /// Word wrap text to fit within maxWidth
    private static func wordWrap(_ text: String, maxWidth: Int) -> [String] {
        var lines: [String] = []
        var currentLine = ""
        let words = text.split(separator: " ")

        for word in words {
            let wordStr = String(word)
            let testLine = currentLine.isEmpty ? wordStr : "\(currentLine) \(wordStr)"

            if testLine.count <= maxWidth {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = wordStr
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }

    /// Truncate string to fit within maxWidth
    private static func truncateString(_ text: String, maxWidth: Int) -> String {
        if text.count <= maxWidth {
            return text
        }
        let truncateIndex = text.index(text.startIndex, offsetBy: maxWidth - 3)
        return String(text[..<truncateIndex]) + "..."
    }
}
