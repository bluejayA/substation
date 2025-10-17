import Foundation
import SwiftNCurses
import OSClient

// MARK: - UnifiedInputView
//
// Unified input handling abstraction for Substation TUI application.
// Provides consistent input state management and keyboard handling across views.
//
// ## Input Handling Architecture
//
// The input system uses a 3-layer priority model:
//
// ### Layer 1: View-Specific Navigation Handlers (Highest Priority)
// - Handles navigation keys that require immediate response
// - Examples: Enter key for selection, Arrow keys for navigation
// - Views check these BEFORE delegating to UnifiedInputView
// - Example: AdvancedSearchView.handleInput checks Enter key first
//
// ### Layer 2: UnifiedInputView State Management (Medium Priority)
// - Handles text input, command mode activation, cursor movement
// - Manages InputState (displayText, cursorPosition, isActive, isCommandMode)
// - Returns InputResult enum to indicate what happened
// - Views process the InputResult and take appropriate action
//
// ### Layer 3: Legacy/Fallback Handlers (Lowest Priority)
// - Only reached if Layers 1 and 2 return .ignored
// - Handles view-specific keys not covered by unified system
//
// ## Key Responsibilities
//
// 1. **Command Mode Detection**: Activates when ':' is typed
// 2. **Text Input Buffering**: Manages input text and cursor position
// 3. **State Transitions**: Tracks active/inactive, command/search modes
// 4. **Result Reporting**: Returns InputResult enum to caller
//
// ## Usage Pattern
//
// ```swift
// // In view's handleInput method:
// var state = inputState
// let result = UnifiedInputView.handleInput(key, state: &state)
//
// switch result {
// case .updated:
//     // Text changed, update display
// case .searchEntered(let query):
//     // User pressed Enter in search mode
// case .commandEntered(let command):
//     // User pressed Enter in command mode
// case .cancelled:
//     // User pressed ESC
// // ... etc
// }
// ```
//
// ## Important Notes
//
// - Views should handle navigation keys (Enter, arrows) BEFORE calling UnifiedInputView
// - InputState should ideally be centralized in TUI (single source of truth)
// - Command mode is activated by typing ':' or calling activate(asCommandMode: true)
//
@MainActor
struct UnifiedInputView {

    // MARK: - Input State Model

    struct InputState {
        var displayText: String = ""
        var cursorPosition: Int = 0
        var isActive: Bool = false
        var isCommandMode: Bool = false
        var placeholder: String = "Type to search or : for commands"

        mutating func clear() {
            displayText = ""
            cursorPosition = 0
            isActive = false
            isCommandMode = false
        }

        mutating func activate(asCommandMode: Bool = false) {
            isActive = true
            isCommandMode = asCommandMode
            if asCommandMode && displayText.isEmpty {
                displayText = ":"
                cursorPosition = 1
            }
        }

        mutating func appendCharacter(_ char: Character) {
            if cursorPosition >= displayText.count {
                displayText.append(char)
            } else {
                let insertIndex = displayText.index(displayText.startIndex, offsetBy: cursorPosition)
                displayText.insert(char, at: insertIndex)
            }
            cursorPosition += 1

            // Detect command mode activation
            if displayText.hasPrefix(":") && !isCommandMode {
                isCommandMode = true
            }
        }

        mutating func deleteCharacter() -> Bool {
            guard !displayText.isEmpty && cursorPosition > 0 else {
                return displayText.isEmpty
            }

            displayText.remove(at: displayText.index(displayText.startIndex, offsetBy: cursorPosition - 1))
            cursorPosition -= 1

            // Exit command mode if : is deleted
            if !displayText.hasPrefix(":") && isCommandMode {
                isCommandMode = false
            }

            return true
        }

        mutating func moveCursorLeft() {
            cursorPosition = max(0, cursorPosition - 1)
        }

        mutating func moveCursorRight() {
            cursorPosition = min(displayText.count, cursorPosition + 1)
        }

        var command: String? {
            guard isCommandMode && displayText.hasPrefix(":") else { return nil }
            return String(displayText.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        var searchQuery: String {
            return isCommandMode ? "" : displayText
        }
    }

    // MARK: - Component Creation

    static func createInputComponent(
        state: InputState,
        width: Int32,
        statusIndicator: String = "",
        resultsSummary: String = "",
        hints: String = ""
    ) -> any Component {
        var components: [any Component] = []
        let availableWidth = Int(width) - 4

        // Title line with status
        let titleText = state.isCommandMode ? "Command Mode \(statusIndicator)" : "Search \(statusIndicator)"
        components.append(
            Text(titleText)
                .emphasis()
                .bold()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        )

        // Input prompt line
        let searchPrompt = state.isCommandMode ? ":" : "> "
        let promptWidth = searchPrompt.count
        let inputWidth = availableWidth - promptWidth - 15

        let queryDisplay = createQueryDisplay(
            query: state.displayText,
            cursor: state.cursorPosition,
            maxWidth: inputWidth,
            isActive: state.isActive,
            isCommandMode: state.isCommandMode
        )

        let inputPadding = max(0, availableWidth - promptWidth - queryDisplay.count - statusIndicator.count - 2)
        let paddingSpaces = String(repeating: " ", count: inputPadding)

        let searchStack = HStack(spacing: 0, children: [
            Text(" \(searchPrompt)").styled(.primary),
            Text(" \(queryDisplay)").styled(.secondary),
            Text(" \(paddingSpaces)").styled(.secondary),
        ]).border().padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))

        components.append(searchStack)

        // Results summary line
        if !resultsSummary.isEmpty {
            components.append(
                Text(resultsSummary)
                    .secondary()
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
            )
        }

        // Contextual hints
        if !hints.isEmpty {
            let truncatedHints = String(hints.prefix(availableWidth))
            components.append(
                Text(truncatedHints)
                    .muted()
                    .padding(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 0))
            )
        }

        return VStack(spacing: 0, children: components)
    }

    // MARK: - Query Display Helper

    private static func createQueryDisplay(
        query: String,
        cursor: Int,
        maxWidth: Int,
        isActive: Bool,
        isCommandMode: Bool
    ) -> String {
        if query.isEmpty {
            return isActive ? "|" : "_"
        }

        let displayQuery = query.count > maxWidth ? String(query.suffix(maxWidth)) : query

        if !isActive {
            return displayQuery
        }

        // Show cursor position within query
        let safeCursor = min(cursor, displayQuery.count)
        if safeCursor >= displayQuery.count {
            return "\(displayQuery)_"
        } else {
            let beforeCursor = String(displayQuery.prefix(safeCursor))
            let atCursor = safeCursor < displayQuery.count ?
                String(displayQuery[displayQuery.index(displayQuery.startIndex, offsetBy: safeCursor)]) : "_"
            let afterCursor = safeCursor < displayQuery.count - 1 ?
                String(displayQuery.suffix(displayQuery.count - safeCursor - 1)) : ""
            return "\(beforeCursor)[\(atCursor)]\(afterCursor)"
        }
    }

    // MARK: - Input Handling

    static func handleInput(_ key: Int32, state: inout InputState) -> InputResult {
        switch key {
        case 27: // ESC
            if state.isActive && !state.displayText.isEmpty {
                state.clear()
                return .cleared
            }
            return .cancelled

        case 10, 13: // ENTER
            if state.isCommandMode {
                if let command = state.command {
                    return .commandEntered(command)
                }
                return .ignored
            } else if !state.searchQuery.isEmpty {
                return .searchEntered(state.searchQuery)
            }
            return .ignored

        case 9: // TAB
            // Tab completion only works in command mode
            if state.isCommandMode {
                if let command = state.command {
                    return .tabCompletion(command)
                }
            }
            return .ignored

        case 127, 8: // BACKSPACE
            return state.deleteCharacter() ? .updated : .ignored

        case 259: // UP arrow
            // History navigation only works in command mode
            if state.isCommandMode {
                return .historyPrevious
            }
            return .ignored

        case 258: // DOWN arrow
            // History navigation only works in command mode
            if state.isCommandMode {
                return .historyNext
            }
            return .ignored

        case 260: // LEFT arrow
            state.moveCursorLeft()
            return .updated

        case 261: // RIGHT arrow
            state.moveCursorRight()
            return .updated

        case 58: // ':' - activate command mode
            if !state.isActive || state.displayText.isEmpty {
                state.activate(asCommandMode: true)
                return .updated
            }
            fallthrough

        default:
            // Handle character input
            if key >= 32 && key < 127 {
                let character = Character(UnicodeScalar(Int(key))!)
                if !state.isActive {
                    state.activate(asCommandMode: false)
                }
                state.appendCharacter(character)
                return .updated
            }
            return .ignored
        }
    }

    // MARK: - Input Result

    enum InputResult {
        case ignored
        case updated
        case cleared
        case cancelled
        case commandEntered(String)
        case searchEntered(String)
        case tabCompletion(String) // Request tab completion for this partial input
        case historyPrevious // Navigate to previous command in history
        case historyNext // Navigate to next command in history
    }

    // MARK: - Helper Functions

    static func createDefaultHints(for state: InputState) -> String {
        if state.isCommandMode {
            if let command = state.command, !command.isEmpty {
                return "ENTER: Execute command | ESC: Cancel"
            }
            return "Type command name | ESC: Cancel | Examples: servers, networks, volumes"
        } else {
            if !state.searchQuery.isEmpty {
                return "ENTER: Search | ESC: Clear | Type to filter"
            }
            return "Type to search | : for commands"
        }
    }

    static func createStatusIndicator(
        isSearching: Bool = false,
        resultCount: Int? = nil,
        elapsed: TimeInterval? = nil
    ) -> String {
        if isSearching {
            let spinner = ["|", "/", "-", "\\"]
            let spinnerChar = spinner[Int(Date().timeIntervalSinceReferenceDate * 4) % spinner.count]
            return "[\(spinnerChar)]"
        } else if let count = resultCount {
            return "[\(count)]"
        } else {
            return "[ready]"
        }
    }

    static func createResultsSummary(
        isSearching: Bool = false,
        totalResults: Int = 0,
        filteredCount: Int? = nil,
        searchTime: TimeInterval? = nil
    ) -> String {
        if isSearching {
            return "  Searching..."
        } else if totalResults == 0 {
            return "  No results"
        } else {
            let count = filteredCount ?? totalResults
            var summary = "  \(count)"
            if let filtered = filteredCount, filtered != totalResults {
                summary += "/\(totalResults)"
            }
            summary += " results"
            if let time = searchTime {
                let timeMs = String(format: "%.0f", time * 1000)
                summary += " (\(timeMs)ms)"
            }
            return summary
        }
    }
}
