import Foundation
import SwiftNCurses

// MARK: - FormTextField Component

/// A unified text field component for forms that provides consistent interaction and styling
/// - Activation: Press SPACE to enter edit mode
/// - Confirmation: Press ENTER to confirm and exit edit mode
/// - Cancellation: Press ESC to cancel and revert changes
/// - Cursor Movement: LEFT/RIGHT arrows, HOME/END keys
/// - History: UP/DOWN arrows to navigate previous values
struct FormTextField {
    let label: String
    let value: String
    let placeholder: String
    let isRequired: Bool
    let isSelected: Bool
    let isActive: Bool
    let maxWidth: Int?
    let validationError: String?
    let cursorPosition: Int? // Cursor position when active (nil = end of text)

    init(
        label: String,
        value: String,
        placeholder: String = "",
        isRequired: Bool = false,
        isSelected: Bool = false,
        isActive: Bool = false,
        maxWidth: Int? = nil,
        validationError: String? = nil,
        cursorPosition: Int? = nil
    ) {
        self.label = label
        self.value = value
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.isSelected = isSelected
        self.isActive = isActive
        self.maxWidth = maxWidth
        self.validationError = validationError
        self.cursorPosition = cursorPosition
    }

    /// Render the text field as a component
    func render() -> any Component {
        var components: [any Component] = []

        // Label with required indicator
        let labelText = isRequired ? label + ": *" : label + ":"
        components.append(
            Text(labelText)
                .styled(.accent)
                .bold()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        )

        // Field value area with state-dependent styling
        let fieldComponent = createFieldComponent()
        components.append(fieldComponent)

        // Validation error message if present
        if let error = validationError {
            components.append(
                Text("  ! " + error)
                    .error()
                    .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
            )
        }

        return VStack(spacing: 0, children: components)
    }

    // MARK: - Private Helper Methods

    private func createFieldComponent() -> any Component {
        // Determine the indicator based on active/selection state
        let indicator: String
        if isActive {
            indicator = "* "  // Active indicator (asterisk shows editing)
        } else if isSelected {
            indicator = "> "  // Selected indicator (arrow shows focused)
        } else {
            indicator = "  "  // Not selected (just spacing)
        }

        // Determine the display text based on state
        let displayText = getDisplayText()

        // Apply truncation if maxWidth is specified
        let truncatedText = truncateIfNeeded(displayText)

        // Determine the style based on state
        let fieldStyle = getFieldStyle()

        let lineItem = HStack(spacing: 0, children: [
            Text(indicator).styled(isSelected ? .accent : .muted),
            Text("[\(truncatedText)]").styled(fieldStyle)
        ]).padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

        return lineItem

    }

    private func getDisplayText() -> String {
        if isActive {
            // Active editing mode: show value with cursor at correct position
            if value.isEmpty {
                return "_"
            } else {
                let cursorPos = cursorPosition ?? value.count
                let safePos = min(max(0, cursorPos), value.count)

                // Insert cursor at the correct position
                let beforeCursor = String(value.prefix(safePos))
                let afterCursor = String(value.dropFirst(safePos))

                if safePos == value.count {
                    // Cursor at end
                    return value + "_"
                } else {
                    // Cursor in middle - show as block cursor over character
                    if let charAtCursor = afterCursor.first {
                        let rest = String(afterCursor.dropFirst())
                        return beforeCursor + "[\(charAtCursor)]" + rest
                    } else {
                        return beforeCursor + "_"
                    }
                }
            }
        } else if isSelected {
            // Selected but not editing: show value or placeholder with activation hint
            if value.isEmpty {
                return placeholder.isEmpty ? "[Press SPACE to edit]" : placeholder + " (SPACE to edit)"
            } else {
                return value
            }
        } else {
            // Not selected: show value or placeholder
            return value.isEmpty ? (placeholder.isEmpty ? "[Empty]" : placeholder) : value
        }
    }

    private func getFieldStyle() -> TextStyle {
        if isActive {
            // Editing: bright white
            return .primary
        } else if isSelected {
            // Selected: yellow warning color
            return .warning
        } else {
            // Not selected: muted gray
            return .secondary
        }
    }

    private func truncateIfNeeded(_ text: String) -> String {
        guard let maxWidth = maxWidth, text.count > maxWidth else {
            return text
        }

        // Truncate with ellipsis
        let truncatePoint = maxWidth - 3
        return String(text.prefix(truncatePoint)) + "..."
    }
}

// MARK: - FormTextField State Management

/// State management for text field editing with cursor support
struct FormTextFieldState {
    var value: String
    var isEditing: Bool
    var originalValue: String // For cancellation
    var cursorPosition: Int // Current cursor position (0 = before first char)
    var history: [String] = [] // Input history
    var historyIndex: Int? = nil // Current position in history (nil = not browsing)
    private let maxHistorySize: Int = 50

    init(initialValue: String = "") {
        self.value = initialValue
        self.isEditing = false
        self.originalValue = initialValue
        self.cursorPosition = initialValue.count
    }

    /// Activate the field for editing
    mutating func activate() {
        isEditing = true
        originalValue = value
        cursorPosition = value.count // Start at end
        historyIndex = nil // Reset history browsing
    }

    /// Confirm the current value and exit editing mode
    mutating func confirm() {
        isEditing = false
        originalValue = value

        // Add to history if not empty and different from last entry
        if !value.isEmpty && (history.isEmpty || history.last != value) {
            history.append(value)
            if history.count > maxHistorySize {
                history.removeFirst()
            }
        }
    }

    /// Cancel editing and revert to original value
    mutating func cancel() {
        isEditing = false
        value = originalValue
        cursorPosition = originalValue.count
        historyIndex = nil
    }

    /// Update the value during editing
    mutating func updateValue(_ newValue: String) {
        value = newValue
        cursorPosition = min(cursorPosition, newValue.count)
    }

    /// Insert a character at the current cursor position
    mutating func insertCharacter(_ char: Character) {
        let index = value.index(value.startIndex, offsetBy: cursorPosition)
        value.insert(char, at: index)
        cursorPosition += 1
    }

    /// Append a character to the current value (for backward compatibility)
    mutating func appendCharacter(_ char: Character) {
        value.append(char)
        cursorPosition = value.count
    }

    /// Delete character at cursor position (backspace)
    mutating func deleteCharacterBeforeCursor() {
        guard cursorPosition > 0 else { return }
        let index = value.index(value.startIndex, offsetBy: cursorPosition - 1)
        value.remove(at: index)
        cursorPosition -= 1
    }

    /// Delete character after cursor position (delete key)
    mutating func deleteCharacterAtCursor() {
        guard cursorPosition < value.count else { return }
        let index = value.index(value.startIndex, offsetBy: cursorPosition)
        value.remove(at: index)
    }

    /// Remove the last character (backspace at end - for backward compatibility)
    mutating func removeLastCharacter() {
        if !value.isEmpty {
            value.removeLast()
            cursorPosition = value.count
        }
    }

    /// Handle special key input when active
    /// Returns true if the key was handled, false otherwise
    mutating func handleSpecialKey(_ keyCode: Int32) -> Bool {
        switch keyCode {
        case Int32(127), Int32(8): // BACKSPACE
            deleteCharacterBeforeCursor()
            return true
        case Int32(330): // DELETE
            deleteCharacterAtCursor()
            return true
        case Int32(259): // KEY_UP
            navigateHistoryUp()
            return true
        case Int32(258): // KEY_DOWN
            navigateHistoryDown()
            return true
        case Int32(260): // KEY_LEFT
            moveCursorLeft()
            return true
        case Int32(261): // KEY_RIGHT
            moveCursorRight()
            return true
        case Int32(262): // KEY_HOME
            moveCursorToStart()
            return true
        case Int32(360), Int32(358): // KEY_END
            moveCursorToEnd()
            return true
        default:
            return false
        }
    }

    // MARK: - Cursor Movement

    /// Move cursor one position to the left
    mutating func moveCursorLeft() {
        if cursorPosition > 0 {
            cursorPosition -= 1
        }
    }

    /// Move cursor one position to the right
    mutating func moveCursorRight() {
        if cursorPosition < value.count {
            cursorPosition += 1
        }
    }

    /// Move cursor to the start of the text
    mutating func moveCursorToStart() {
        cursorPosition = 0
    }

    /// Move cursor to the end of the text
    mutating func moveCursorToEnd() {
        cursorPosition = value.count
    }

    // MARK: - History Navigation

    /// Navigate to previous item in history
    mutating func navigateHistoryUp() {
        guard !history.isEmpty else { return }

        if let currentIndex = historyIndex {
            // Already browsing history, go further back
            if currentIndex > 0 {
                historyIndex = currentIndex - 1
                value = history[currentIndex - 1]
                cursorPosition = value.count
            }
        } else {
            // Start browsing history from the end
            historyIndex = history.count - 1
            value = history[history.count - 1]
            cursorPosition = value.count
        }
    }

    /// Navigate to next item in history
    mutating func navigateHistoryDown() {
        guard let currentIndex = historyIndex else { return }

        if currentIndex < history.count - 1 {
            // Move forward in history
            historyIndex = currentIndex + 1
            value = history[currentIndex + 1]
            cursorPosition = value.count
        } else {
            // Reached the end of history, return to original value
            historyIndex = nil
            value = originalValue
            cursorPosition = value.count
        }
    }

    /// Handle printable character input when active
    mutating func handleCharacterInput(_ char: Character) {
        // Only insert printable characters at cursor position
        if isPrintableCharacter(char) {
            insertCharacter(char)
        }
    }

    /// Check if a character is printable and safe for text input
    private func isPrintableCharacter(_ char: Character) -> Bool {
        if let scalar = char.unicodeScalars.first {
            let value = scalar.value
            // Accept printable ASCII characters (space through tilde)
            return value >= 32 && value <= 126
        }
        return false
    }

    /// Get the current value with cursor indicator at the correct position
    /// Useful for rendering the field
    func getValueWithCursor() -> String {
        guard isEditing else { return value }

        if value.isEmpty {
            return "_"
        }

        let safePos = min(max(0, cursorPosition), value.count)
        let beforeCursor = String(value.prefix(safePos))
        let afterCursor = String(value.dropFirst(safePos))

        if safePos == value.count {
            return value + "_"
        } else if let charAtCursor = afterCursor.first {
            let rest = String(afterCursor.dropFirst())
            return beforeCursor + "[\(charAtCursor)]" + rest
        } else {
            return beforeCursor + "_"
        }
    }

    /// Clear input history (useful when changing contexts)
    mutating func clearHistory() {
        history.removeAll()
        historyIndex = nil
    }

    /// Get current history size
    var historyCount: Int {
        return history.count
    }
}

// MARK: - Convenience Methods for Word Movement

extension FormTextFieldState {
    /// Move cursor to the start of the previous word
    mutating func moveCursorToPreviousWord() {
        guard cursorPosition > 0 else { return }

        var pos = cursorPosition - 1

        // Skip current whitespace
        while pos > 0 && value[value.index(value.startIndex, offsetBy: pos)].isWhitespace {
            pos -= 1
        }

        // Skip word characters
        while pos > 0 && !value[value.index(value.startIndex, offsetBy: pos)].isWhitespace {
            pos -= 1
        }

        cursorPosition = pos
    }

    /// Move cursor to the start of the next word
    mutating func moveCursorToNextWord() {
        guard cursorPosition < value.count else { return }

        var pos = cursorPosition

        // Skip current word
        while pos < value.count && !value[value.index(value.startIndex, offsetBy: pos)].isWhitespace {
            pos += 1
        }

        // Skip whitespace
        while pos < value.count && value[value.index(value.startIndex, offsetBy: pos)].isWhitespace {
            pos += 1
        }

        cursorPosition = pos
    }

    /// Delete the word before cursor (Ctrl+W behavior)
    mutating func deleteWordBeforeCursor() {
        guard cursorPosition > 0 else { return }

        let startPos = cursorPosition
        moveCursorToPreviousWord()

        // Delete from cursor to start position
        if cursorPosition < startPos {
            let startIndex = value.index(value.startIndex, offsetBy: cursorPosition)
            let endIndex = value.index(value.startIndex, offsetBy: startPos)
            value.removeSubrange(startIndex..<endIndex)
        }
    }

    /// Delete from cursor to end of line (Ctrl+K behavior)
    mutating func deleteToEndOfLine() {
        guard cursorPosition < value.count else { return }
        value = String(value.prefix(cursorPosition))
    }
}

// MARK: - FormCheckboxFieldState

/// State management for checkbox fields
struct FormCheckboxFieldState {
    var isChecked: Bool

    init(isChecked: Bool = false) {
        self.isChecked = isChecked
    }

    /// Toggle the checkbox state
    mutating func toggle() {
        isChecked.toggle()
    }
}
