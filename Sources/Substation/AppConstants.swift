import Foundation

/// Application-wide constants for Substation
/// Centralizes configuration paths, app metadata, and system defaults
enum AppConstants {

    // MARK: - Configuration Paths

    /// Base configuration directory path
    /// Location: ~/.config/substation
    static var configDirectory: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.config/substation"
    }

    /// Command history file path
    /// Location: ~/.config/substation/command_history
    static var commandHistoryPath: String {
        return "\(configDirectory)/command_history"
    }

    /// Navigation preferences file path
    /// Location: ~/.config/substation/preferences.json
    static var preferencesPath: String {
        return "\(configDirectory)/preferences.json"
    }

    /// Welcome screen marker file path
    /// Location: ~/.config/substation/.welcome_shown
    static var welcomeMarkerPath: String {
        return "\(configDirectory)/.welcome_shown"
    }

    // MARK: - Directory Management

    /// Ensure config directory exists
    /// Creates the directory if it doesn't exist
    /// - Returns: True if directory exists or was created successfully
    @discardableResult
    static func ensureConfigDirectoryExists() -> Bool {
        do {
            try FileManager.default.createDirectory(
                atPath: configDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return true
        } catch {
            Logger.shared.logError("Failed to create config directory: \(error.localizedDescription)", context: [
                "path": configDirectory,
                "error": error.localizedDescription
            ])
            return false
        }
    }
}
