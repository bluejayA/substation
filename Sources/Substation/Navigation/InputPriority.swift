import Foundation

@MainActor
struct InputPriority {

    // MARK: - Priority Categories

    enum Category {
        case navigation    // Enter, arrows, page up/down
        case textInput     // Alphanumeric, backspace, cursor movement
        case command       // Command mode activation (:)
        case fallback      // Everything else (view-specific)
    }

    // MARK: - Key Sets

    /// Navigation keys that require immediate response (highest priority)
    static let navigationKeys: Set<Int32> = [
        10,   // Enter (LF)
        13,   // Enter (CR)
        258,  // DOWN arrow
        259,  // UP arrow
        260,  // LEFT arrow (for cursor in some contexts)
        261,  // RIGHT arrow (for cursor in some contexts)
        338,  // PAGE DOWN
        339,  // PAGE UP
    ]

    /// Text editing keys
    static let textEditingKeys: Set<Int32> = [
        127,  // BACKSPACE (DELETE)
        8,    // BACKSPACE (alternative)
    ]

    /// Command mode activation
    static let commandActivationKeys: Set<Int32> = [
        58,   // : (colon)
    ]

    /// Control keys
    static let controlKeys: Set<Int32> = [
        27,   // ESC
        9,    // TAB
    ]

    /// Alphanumeric printable range
    static let printableRange: ClosedRange<Int32> = 32...126

    // MARK: - Classification

    /// Classify a key press into a priority category
    static func classify(_ key: Int32) -> Category {
        // Navigation has highest priority
        if navigationKeys.contains(key) {
            return .navigation
        }

        // Command activation
        if commandActivationKeys.contains(key) {
            return .command
        }

        // Text input (editing and printable characters)
        if textEditingKeys.contains(key) || printableRange.contains(key) {
            return .textInput
        }

        // Everything else falls back to view-specific handlers
        return .fallback
    }

    /// Check if a key is a navigation key
    static func isNavigation(_ key: Int32) -> Bool {
        return navigationKeys.contains(key)
    }

    /// Check if a key is for text input
    static func isTextInput(_ key: Int32) -> Bool {
        return textEditingKeys.contains(key) || printableRange.contains(key)
    }

    /// Check if a key activates command mode
    static func isCommandActivation(_ key: Int32) -> Bool {
        return commandActivationKeys.contains(key)
    }

    /// Get a human-readable description of a key
    static func describe(_ key: Int32) -> String {
        switch key {
        case 10, 13: return "Enter"
        case 27: return "ESC"
        case 9: return "Tab"
        case 258: return "Down Arrow"
        case 259: return "Up Arrow"
        case 260: return "Left Arrow"
        case 261: return "Right Arrow"
        case 338: return "Page Down"
        case 339: return "Page Up"
        case 127, 8: return "Backspace"
        case 58: return ":"
        case 32: return "Space"
        default:
            if printableRange.contains(key) {
                if let scalar = UnicodeScalar(UInt32(key)) {
                    return "'\(Character(scalar))'"
                }
            }
            return "Unknown(\(key))"
        }
    }

    // MARK: - Input Handling Contract

    /// Protocol defining the contract for input handlers
    /// Views can implement this to declare which keys they handle at Layer 1
    protocol InputHandler {
        /// Keys this handler processes at highest priority (before UnifiedInputView)
        var priorityKeys: Set<Int32> { get }

        /// Handle a high-priority key
        /// Returns true if handled, false to fall through to next layer
        func handlePriorityInput(_ key: Int32) -> Bool
    }

    // MARK: - Debugging

    /// Log input handling flow for debugging
    static func logInput(_ key: Int32, layer: String, handled: Bool) {
        let keyDesc = describe(key)
        let priority = classify(key)
        Logger.shared.logDebug("Input: \(keyDesc) | Priority: \(priority) | Layer: \(layer) | Handled: \(handled)")
    }
}
