import Foundation

/// Navigation mode configuration for the application
/// Defines how users can navigate: commands or both (commands + uppercase actions)
enum NavigationMode: String, Codable {
    /// Hybrid mode - commands and uppercase context-sensitive actions
    case hybrid
    /// Command-only mode - commands only (e.g., ':create')
    case commandOnly

    /// Human-readable display name for the mode
    var displayName: String {
        switch self {
        case .hybrid: return "Hybrid (Commands + Uppercase Actions)"
        case .commandOnly: return "Command-Only"
        }
    }
}

/// User preferences for navigation behavior
/// Manages navigation mode selection and persistence
@MainActor
final class NavigationPreferences: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = NavigationPreferences()

    // MARK: - Properties

    /// Current navigation mode (default: command-only)
    var mode: NavigationMode = .commandOnly

    /// Enable tab completion for commands
    var enableTabCompletion: Bool = true

    /// Enable command history (up/down arrows)
    var enableCommandHistory: Bool = true

    /// Maximum size of command history
    var commandHistorySize: Int = 50

    /// Path to preferences file
    private let configPath: String

    /// Whether preferences have been loaded from disk
    private var preferencesLoaded: Bool = false

    /// Whether this is a first-run (no preferences file exists)
    private(set) var isFirstRun: Bool = false

    // MARK: - Initialization

    private init() {
        // Set up config file path using centralized constants
        self.configPath = AppConstants.preferencesPath

        // Ensure config directory exists
        AppConstants.ensureConfigDirectoryExists()

        // Load preferences on first access
        load()
    }

    // MARK: - Persistence

    /// Load preferences from disk
    func load() {
        guard !preferencesLoaded else { return }
        preferencesLoaded = true

        guard FileManager.default.fileExists(atPath: configPath) else {
            Logger.shared.logDebug("No preferences file found, using defaults (first run)")
            isFirstRun = true
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let decoded = try JSONDecoder().decode(PreferencesData.self, from: data)
            self.mode = decoded.mode
            self.enableTabCompletion = decoded.enableTabCompletion
            self.enableCommandHistory = decoded.enableCommandHistory
            self.commandHistorySize = decoded.commandHistorySize
            Logger.shared.logInfo("Navigation preferences loaded: mode=\(mode.rawValue)")
        } catch {
            Logger.shared.logError("Failed to load navigation preferences: \(error.localizedDescription)")
            // Treat parse errors as first run
            isFirstRun = true
        }
    }

    /// Save preferences to disk
    func save() {
        let data = PreferencesData(
            mode: mode,
            enableTabCompletion: enableTabCompletion,
            enableCommandHistory: enableCommandHistory,
            commandHistorySize: commandHistorySize
        )

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: URL(fileURLWithPath: configPath), options: .atomic)
            Logger.shared.logInfo("Navigation preferences saved successfully: mode=\(mode.rawValue)")
        } catch {
            Logger.shared.logError("Failed to save navigation preferences: \(error.localizedDescription)", context: [
                "configPath": configPath,
                "mode": mode.rawValue,
                "error": error.localizedDescription
            ])
            // Note: Preferences save failure is logged but not fatal
            // User can continue using the application with current settings
        }
    }

    // MARK: - Mode Management

    /// Toggle between navigation modes (hybrid <-> commandOnly)
    func toggleMode() {
        switch mode {
        case .hybrid:
            mode = .commandOnly
        case .commandOnly:
            mode = .hybrid
        }
        save()
    }

    /// Set navigation mode to a specific value
    /// - Parameter newMode: The desired navigation mode
    func setMode(_ newMode: NavigationMode) {
        mode = newMode
        save()
    }

    /// Check if uppercase context-sensitive actions are enabled
    /// In hybrid mode, uppercase actions (C, P, R, S, T, etc.) are available
    var isUppercaseActionsEnabled: Bool {
        return mode == .hybrid
    }

    /// Check if command navigation is enabled (always true in both modes)
    var isCommandNavigationEnabled: Bool {
        return true // Commands always available
    }

    // MARK: - Feature Toggles

    /// Toggle tab completion on/off
    func toggleTabCompletion() {
        enableTabCompletion.toggle()
        save()
    }

    /// Toggle command history on/off
    func toggleCommandHistory() {
        enableCommandHistory.toggle()
        save()
    }

    /// Reset all preferences to defaults
    func resetToDefaults() {
        mode = .commandOnly
        enableTabCompletion = true
        enableCommandHistory = true
        commandHistorySize = 50
        save()
    }

    // MARK: - Status Information

    /// Get a human-readable description of current preferences
    func statusDescription() -> String {
        var lines: [String] = []
        lines.append("Navigation Mode: \(mode.displayName)")
        lines.append("Tab Completion: \(enableTabCompletion ? "Enabled" : "Disabled")")
        lines.append("Command History: \(enableCommandHistory ? "Enabled" : "Disabled")")
        lines.append("History Size: \(commandHistorySize)")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Codable Data Structure

/// Internal data structure for JSON serialization
private struct PreferencesData: Codable {
    var mode: NavigationMode
    var enableTabCompletion: Bool
    var enableCommandHistory: Bool
    var commandHistorySize: Int
}
