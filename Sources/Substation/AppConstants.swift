import Foundation

/// Application-wide constants for Substation
/// Centralizes configuration paths, app metadata, and system defaults
enum AppConstants {

    // MARK: - Application Info

    /// Application name
    static let appName = "Substation"

    /// Application version
    static let appVersion = "2.0.0"

    /// Application identifier
    static let appIdentifier = "com.openstack.substation"

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

    /// OpenStack clouds configuration path (standard location)
    /// Location: ~/.config/openstack/clouds.yaml
    static var cloudsConfigPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.config/openstack/clouds.yaml"
    }

    // MARK: - Default Values

    /// Default command history size
    static let defaultCommandHistorySize = 50

    /// Default navigation mode
    static let defaultNavigationMode = "commandOnly"

    /// Default tab completion enabled
    static let defaultTabCompletionEnabled = true

    /// Default command history enabled
    static let defaultCommandHistoryEnabled = true

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
