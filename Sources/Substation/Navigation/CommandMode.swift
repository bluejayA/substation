import Foundation

@MainActor
final class CommandMode: @unchecked Sendable {
    private var commandHistory: [String] = []
    private var historyIndex: Int = 0
    private let maxHistorySize = 50

    // History persistence
    private let historyFilePath: String
    private var historyLoaded: Bool = false

    // Tab completion state
    private var completionMatches: [String] = []
    private var completionIndex: Int = 0
    private var completionPrefix: String = ""

    // Context switcher for cloud name completion
    weak var contextSwitcher: ContextSwitcher?

    // MARK: - Initialization

    init() {
        // Set up history file path using centralized constants
        self.historyFilePath = AppConstants.commandHistoryPath

        // Ensure config directory exists
        AppConstants.ensureConfigDirectoryExists()
    }

    // MARK: - Command Execution

    enum CommandResult {
        case ignored
        case navigateToView(ViewMode)
        case executeAction(ActionType)
        case showHelp
        case showCommands
        case quit
        case error(String)
        case suggestion(String, String) // (original, suggested)
        case listContexts
        case switchContext(String)
        case configAction(ConfigAction)
        case showTutorial
        case showShortcuts
        case showExamples
        case showWelcome
    }

    /// Configuration actions for system settings
    enum ConfigAction {
        case setCommandMode(NavigationMode)
        case toggleMode
        case showPreferences
    }

    func executeCommand(_ command: String) -> CommandResult {
        let trimmed = command.trimmingCharacters(in: .whitespaces).lowercased()

        // Empty command
        guard !trimmed.isEmpty else {
            return .showCommands
        }

        // Add to history
        addToHistory(trimmed)

        // Handle special commands
        if trimmed == "q" || trimmed == "quit" || trimmed == "exit" {
            return .quit
        }

        if trimmed == "help" || trimmed == "?" {
            return .showHelp
        }

        if trimmed == "commands" || trimmed == "list" {
            return .showCommands
        }

        // Discovery commands (Phase 3)
        if trimmed == "tutorial" {
            return .showTutorial
        }

        if trimmed == "shortcuts" {
            return .showShortcuts
        }

        if trimmed == "examples" {
            return .showExamples
        }

        if trimmed == "welcome" {
            return .showWelcome
        }

        // Context switching commands
        if trimmed == "ctx" || trimmed == "context" {
            return .listContexts
        }

        if trimmed.hasPrefix("ctx ") || trimmed.hasPrefix("context ") {
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            if parts.count == 2 {
                let contextName = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if !contextName.isEmpty {
                    return .switchContext(contextName)
                }
            }
            return .error("Usage: :ctx <cloud-name> or :ctx to list clouds")
        }

        // Configuration commands
        if let configResult = handleConfigCommand(trimmed) {
            return configResult
        }

        // Check if this is an action command
        if let actionType = ResourceRegistry.shared.resolveAction(trimmed) {
            Logger.shared.logUserAction("action_command_received", details: ["action": actionType.rawValue])
            return .executeAction(actionType)
        }

        // Resource navigation - try exact match first
        if let viewMode = ResourceRegistry.shared.resolve(trimmed) {
            Logger.shared.logNavigation("command_mode", to: "\(viewMode)")
            return .navigateToView(viewMode)
        }

        // Try prefix matching - find first command that starts with the input
        let prefixMatch = ResourceRegistry.shared.allCommands()
            .filter { $0.hasPrefix(trimmed) }
            .sorted()
            .first

        if let match = prefixMatch, let viewMode = ResourceRegistry.shared.resolve(match) {
            Logger.shared.logNavigation("command_mode", to: "\(viewMode)", details: ["fuzzy": "prefix", "input": trimmed, "resolved": match])
            return .navigateToView(viewMode)
        }

        // Try fuzzy match for typos
        if let suggestion = ResourceRegistry.shared.fuzzyMatch(trimmed) {
            return .suggestion(trimmed, suggestion)
        }

        return .error("Unknown command: '\(trimmed)'. Type ':help' for available commands.")
    }

    // MARK: - Command History

    /// Load command history from disk (lazy load on first access)
    private func ensureHistoryLoaded() {
        guard !historyLoaded else { return }
        historyLoaded = true

        guard FileManager.default.fileExists(atPath: historyFilePath) else {
            return
        }

        do {
            let contents = try String(contentsOfFile: historyFilePath, encoding: .utf8)
            commandHistory = contents.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .suffix(maxHistorySize)
                .map { String($0) }
            historyIndex = commandHistory.count
        } catch {
            Logger.shared.logError("Failed to load command history: \(error.localizedDescription)")
        }
    }

    /// Save command history to disk
    private func saveHistory() {
        do {
            let contents = commandHistory.joined(separator: "\n")
            try contents.write(toFile: historyFilePath, atomically: true, encoding: .utf8)
        } catch {
            Logger.shared.logError("Failed to save command history: \(error.localizedDescription)")
        }
    }

    private func addToHistory(_ command: String) {
        // Ensure history is loaded before modifying
        ensureHistoryLoaded()

        // Don't add duplicates of the last command
        if commandHistory.last != command {
            commandHistory.append(command)
            if commandHistory.count > maxHistorySize {
                commandHistory.removeFirst()
            }

            // Save to disk after adding
            saveHistory()
        }
        historyIndex = commandHistory.count
    }

    func previousCommand() -> String? {
        ensureHistoryLoaded()
        guard !commandHistory.isEmpty, historyIndex > 0 else { return nil }
        historyIndex -= 1
        return commandHistory[historyIndex]
    }

    func nextCommand() -> String? {
        ensureHistoryLoaded()
        guard !commandHistory.isEmpty, historyIndex < commandHistory.count - 1 else {
            historyIndex = commandHistory.count
            return ""
        }
        historyIndex += 1
        return commandHistory[historyIndex]
    }

    func resetHistoryPosition() {
        ensureHistoryLoaded()
        historyIndex = commandHistory.count
    }

    /// Clear all command history (both in-memory and on disk)
    func clearHistory() {
        commandHistory.removeAll()
        historyIndex = 0
        try? FileManager.default.removeItem(atPath: historyFilePath)
        historyLoaded = true
    }

    // MARK: - Auto-completion

    func getSuggestions(for partial: String) -> [String] {
        return ResourceRegistry.shared.suggestions(for: partial, limit: 5)
    }

    // MARK: - Tab Completion

    /// Handle Tab key press - cycle through completions
    func completeCommand(_ currentInput: String) async -> String? {
        let trimmed = currentInput.trimmingCharacters(in: .whitespaces).lowercased()

        // Check if the input matches one of our completion results (user pressed TAB and now pressing again)
        let isCompletionResult = completionMatches.contains(trimmed)

        // If input changed and it's not a completion result, reset completion state
        if trimmed != completionPrefix && !isCompletionResult {
            resetTabCompletion()
            completionPrefix = trimmed

            // Check if this is a :ctx command
            if trimmed.hasPrefix("ctx ") || trimmed.hasPrefix("context ") {
                // Extract the cloud name prefix after "ctx " or "context "
                let parts = trimmed.split(separator: " ", maxSplits: 1)
                let cloudPrefix = parts.count == 2 ? String(parts[1]) : ""

                // Get available cloud names from context switcher
                if let switcher = contextSwitcher {
                    let clouds = await switcher.availableContexts()
                    let filtered = clouds.filter { cloud in
                        cloudPrefix.isEmpty || cloud.lowercased().hasPrefix(cloudPrefix)
                    }
                    completionMatches = filtered.map { trimmed.hasPrefix("context ") ? "context \($0)" : "ctx \($0)" }
                } else {
                    completionMatches = []
                }
            } else {
                // Regular command completion
                completionMatches = ResourceRegistry.shared.suggestions(for: trimmed, limit: 10)

                // If no matches, try all commands that contain the input
                if completionMatches.isEmpty && !trimmed.isEmpty {
                    completionMatches = ResourceRegistry.shared.allCommands()
                        .filter { $0.contains(trimmed) }
                        .sorted()
                }
            }
        }

        // No matches found
        guard !completionMatches.isEmpty else {
            return nil
        }

        // Get current completion
        let completion = completionMatches[completionIndex]

        // Advance to next match for next Tab press
        completionIndex = (completionIndex + 1) % completionMatches.count

        return completion
    }

    /// Get all current completion matches
    func getCompletionMatches() -> [String] {
        return completionMatches
    }

    /// Get current completion index
    func getCompletionIndex() -> Int {
        return completionIndex
    }

    /// Reset tab completion state
    func resetTabCompletion() {
        completionMatches = []
        completionIndex = 0
        completionPrefix = ""
    }

    /// Check if we're in tab completion mode
    func isInTabCompletion() -> Bool {
        return !completionMatches.isEmpty
    }

    /// Get hint text for current completion state
    func getTabCompletionHint() -> String {
        guard !completionMatches.isEmpty else { return "" }

        if completionMatches.count == 1 {
            return "Tab: \(completionMatches[0])"
        } else {
            let currentMatch = completionMatches[completionIndex]
            return "Tab: \(currentMatch) (\(completionIndex + 1)/\(completionMatches.count))"
        }
    }

    // MARK: - Command Parsing

    struct ParsedCommand {
        let command: String
        let args: [String]

        init(from input: String) {
            let components = input.split(separator: " ").map { String($0) }
            self.command = components.first ?? ""
            self.args = Array(components.dropFirst())
        }
    }

    func parseCommand(_ input: String) -> ParsedCommand {
        return ParsedCommand(from: input)
    }

    // MARK: - Validation

    func isValidCommand(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespaces).lowercased()
        return ResourceRegistry.shared.resolve(trimmed) != nil ||
               ["q", "quit", "exit", "help", "?", "commands", "list"].contains(trimmed)
    }

    // MARK: - Help Generation

    func getQuickHelp() -> String {
        return "Type command name or :help for all commands"
    }

    func getCommandList() -> String {
        let primary = ResourceRegistry.shared.primaryCommands()
        return "Available commands: \(primary.joined(separator: ", "))"
    }

    func getDetailedHelp() -> String {
        return ResourceRegistry.shared.allHelpText()
    }

    // MARK: - Context-Aware Suggestions

    func getContextualSuggestions(currentView: ViewMode) -> [String] {
        // Suggest related resources based on current view
        switch currentView {
        case .servers:
            return ["flavors", "images", "servergroups", "volumes"]
        case .networks:
            return ["subnets", "ports", "routers", "floatingips"]
        case .volumes:
            return ["servers", "images", "archives"]
        case .dashboard:
            return ["servers", "networks", "volumes", "topology"]
        default:
            return ResourceRegistry.shared.primaryCommands().prefix(5).map { String($0) }
        }
    }

    // MARK: - Configuration Command Handling

    /// Handle configuration commands for navigation mode and preferences
    /// - Parameter command: The trimmed, lowercased command string
    /// - Returns: A CommandResult if this is a config command, nil otherwise
    private func handleConfigCommand(_ command: String) -> CommandResult? {
        guard let configCommand = ResourceRegistry.shared.resolveConfigCommand(command) else {
            return nil
        }

        switch configCommand {
        case "command-mode", "mode":
            // Set command mode: :command-mode [hybrid|command-only] or :mode [hybrid|commands]
            let parts = command.split(separator: " ", maxSplits: 1).map { String($0) }
            if parts.count == 1 {
                // Just :command-mode - show current mode
                return .configAction(.showPreferences)
            } else if parts.count == 2 {
                let arg = parts[1].lowercased()
                switch arg {
                case "hybrid", "both":
                    return .configAction(.setCommandMode(.hybrid))
                case "command-only", "commands", "cmd":
                    return .configAction(.setCommandMode(.commandOnly))
                default:
                    return .error("Usage: :command-mode [hybrid|command-only]\n  hybrid = commands + uppercase actions\n  command-only = commands only")
                }
            }

        case "toggle-mode":
            // Toggle between hybrid and command-only
            return .configAction(.toggleMode)

        case "prefs", "preferences", "settings":
            // Show current preferences
            return .configAction(.showPreferences)

        default:
            break
        }

        return nil
    }
}
