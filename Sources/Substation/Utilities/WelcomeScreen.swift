import Foundation
import SwiftTUI

/// Welcome screen for new users showing command-based navigation
/// Displays tutorial and first-run information for Substation
@MainActor
final class WelcomeScreen: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = WelcomeScreen()

    // MARK: - Properties

    private let welcomePath: String
    private var hasShownWelcome: Bool = false

    // MARK: - Initialization

    private init() {
        // Set up welcome marker file path using centralized constants
        self.welcomePath = AppConstants.welcomeMarkerPath

        // Ensure config directory exists
        AppConstants.ensureConfigDirectoryExists()
    }

    // MARK: - First Run Detection

    /// Check if this is the first run (no welcome marker exists)
    /// - Returns: True if first run, false otherwise
    func isFirstRun() -> Bool {
        return !FileManager.default.fileExists(atPath: welcomePath)
    }

    /// Mark welcome as shown (create marker file)
    func markWelcomeShown() {
        do {
            try "1".write(toFile: welcomePath, atomically: true, encoding: .utf8)
            hasShownWelcome = true
            Logger.shared.logInfo("Welcome screen marked as shown successfully")
        } catch {
            Logger.shared.logError("Failed to mark welcome as shown: \(error.localizedDescription)", context: [
                "welcomePath": welcomePath,
                "error": error.localizedDescription
            ])
            // Note: Failure to mark welcome as shown is not fatal
            // User may see welcome screen again on next run, but this is acceptable
        }
    }

    // MARK: - Welcome Messages


    /// Get welcome screen content as DetailView sections
    /// Conforms to the application's DetailView component pattern
    /// - Returns: Array of DetailSection objects for rendering
    func getWelcomeSections() -> [DetailSection] {
        var sections: [DetailSection] = []

        // Introduction
        sections.append(DetailSection(
            title: "Welcome to Substation!",
            items: [
                .field(label: "Description", value: "Terminal User Interface for OpenStack", style: .primary),
                .field(label: "Version", value: "Command-Based Navigation", style: .accent),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Getting Started
        sections.append(DetailSection(
            title: "Getting Started",
            items: [
                .field(label: "Step 1", value: "Press : (colon) to enter command mode", style: .info),
                .field(label: "Step 2", value: "Press Tab to see available commands", style: .info),
                .field(label: "Step 3", value: "Type a command and press Enter", style: .info),
                .spacer
            ]
        ))

        // Essential Commands
        sections.append(DetailSection(
            title: "Essential Commands",
            items: [
                .field(label: ":servers", value: "View and manage servers (instances)", style: .secondary),
                .field(label: ":networks", value: "View and manage networks", style: .secondary),
                .field(label: ":volumes", value: "View and manage block storage", style: .secondary),
                .field(label: ":images", value: "View available images", style: .secondary),
                .field(label: ":create", value: "Create new resource (context-aware)", style: .secondary),
                .field(label: ":delete", value: "Delete selected resource", style: .secondary),
                .field(label: ":help", value: "Show detailed help documentation", style: .secondary),
                .field(label: ":quit", value: "Exit application", style: .secondary),
                .spacer
            ]
        ))

        // Navigation
        sections.append(DetailSection(
            title: "Navigation",
            items: [
                .field(label: "Arrow Keys", value: "Navigate lists and menus", style: .secondary),
                .field(label: "SPACE", value: "View details / Enter directory", style: .secondary),
                .field(label: "ESC", value: "Go back / Cancel", style: .secondary),
                .field(label: "/", value: "Search within current view", style: .secondary),
                .field(label: "?", value: "Show context-sensitive help", style: .secondary),
                .field(label: ":", value: "Enter command mode", style: .secondary),
                .spacer
            ]
        ))

        // Tips
        sections.append(DetailSection(
            title: "Tips",
            items: [
                .field(label: "Tab Completion", value: "Start typing and press Tab!", style: .info),
                .field(label: "History", value: "Use UP/DOWN arrows in command mode", style: .info),
                .field(label: "Tutorial", value: "Type :tutorial for guided tour", style: .info),
                .field(label: "Shortcuts", value: "Type :shortcuts for command list", style: .info),
                .field(label: "Examples", value: "Type :examples for workflows", style: .info),
                .spacer
            ]
        ))

        // Learn More
        sections.append(DetailSection(
            title: "Learn More",
            items: [
                .field(label: ":help", value: "Comprehensive help documentation", style: .accent),
                .field(label: ":tutorial", value: "Interactive walkthrough", style: .accent),
                .field(label: ":examples", value: "Common workflow examples", style: .accent),
                .field(label: "?", value: "Context-sensitive help (any screen)", style: .accent),
                .spacer,
                .spacer,
                .customComponent(Text("Press any key to start using Substation...").success().bold())
            ]
        ))

        return sections
    }

    /// Get a brief welcome hint for the status bar
    /// - Returns: Short hint message
    func getWelcomeHint() -> String {
        return "Welcome! Type : for commands or :tutorial for interactive guide"
    }

    // MARK: - Tutorial Content

    /// Get interactive tutorial as DetailView sections
    /// - Returns: Array of DetailSection for tutorial
    func getTutorialSections() -> [DetailSection] {
        var sections: [DetailSection] = []

        // Step 1: Command Mode
        sections.append(DetailSection(
            title: "Step 1: Command Mode",
            items: [
                .field(label: "How", value: "Press : (colon) to enter command mode", style: .info),
                .field(label: "Result", value: "Command prompt appears at bottom of screen", style: .secondary),
                .field(label: "Try it", value: "Press : now to see the command prompt", style: .accent),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Step 2: Tab Completion
        sections.append(DetailSection(
            title: "Step 2: Tab Completion",
            items: [
                .field(label: "How", value: "Press Tab to see all available commands", style: .info),
                .field(label: "Tip", value: "Type partial command and Tab completes it", style: .secondary),
                .field(label: "Try it", value: "Type :serv and press Tab", style: .accent),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Step 3: Navigation Commands
        sections.append(DetailSection(
            title: "Step 3: Navigation Commands",
            items: [
                .field(label: ":servers", value: "View all servers", style: .secondary),
                .field(label: ":networks", value: "View all networks", style: .secondary),
                .field(label: ":volumes", value: "View all volumes", style: .secondary),
                .field(label: ":dashboard", value: "View dashboard", style: .secondary),
                .field(label: "Try it", value: ":dashboard to see your overview", style: .accent),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Step 4: Action Commands
        sections.append(DetailSection(
            title: "Step 4: Action Commands",
            items: [
                .field(label: ":create", value: "Create a new resource", style: .secondary),
                .field(label: ":delete", value: "Delete selected resource", style: .secondary),
                .field(label: ":start", value: "Start server", style: .secondary),
                .field(label: ":stop", value: "Stop server", style: .secondary),
                .field(label: ":restart", value: "Restart server", style: .secondary),
                .field(label: "Try it", value: "Select a resource and try :details", style: .accent),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Step 5: Context Switching
        sections.append(DetailSection(
            title: "Step 5: Context Switching",
            items: [
                .field(label: ":ctx", value: "List available clouds", style: .secondary),
                .field(label: ":ctx <name>", value: "Switch to a cloud", style: .secondary),
                .field(label: "Try it", value: ":ctx to see your clouds", style: .accent),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Step 6: Search & Filters
        sections.append(DetailSection(
            title: "Step 6: Search & Filters",
            items: [
                .field(label: "/ (slash)", value: "Start search", style: .info),
                .field(label: "ESC", value: "Clear search", style: .info),
                .field(label: "Tip", value: "Search by name, status, or properties", style: .secondary),
                .field(label: "Try it", value: "Press / and type a search term", style: .accent),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Step 7: Getting Help
        sections.append(DetailSection(
            title: "Step 7: Getting Help",
            items: [
                .field(label: "?", value: "Context-sensitive help", style: .secondary),
                .field(label: ":help", value: "Full documentation", style: .secondary),
                .field(label: ":shortcuts", value: "Common commands", style: .secondary),
                .field(label: ":examples", value: "Command workflows", style: .secondary),
                .field(label: "Try it", value: "Type ? to see help", style: .accent),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Tutorial Complete
        sections.append(DetailSection(
            title: "Tutorial Complete!",
            items: [
                .field(label: "Remember", value: ": (colon) enters command mode", style: .success),
                .field(label: "", value: "Tab shows completions", style: .success),
                .field(label: "", value: "? shows help", style: .success),
                .field(label: "", value: "ESC cancels or goes back", style: .success),
                .spacer,
                .customComponent(Text("Type :help anytime for more information").accent()),
                .spacer,
                .customComponent(Text("You're ready to use Substation!").success().bold())
            ],
            titleStyle: .success
        ))

        return sections
    }


    /// Get shortcuts reference as DetailView sections
    /// - Returns: Array of DetailSection for frequently used commands
    func getShortcutsSections() -> [DetailSection] {
        var sections: [DetailSection] = []

        // Navigation Commands
        sections.append(DetailSection(
            title: "Navigation Commands",
            items: [
                .field(label: ":dashboard", value: "Main dashboard view", style: .secondary),
                .field(label: ":servers", value: "Server management", style: .secondary),
                .field(label: ":networks", value: "Network management", style: .secondary),
                .field(label: ":volumes", value: "Volume management", style: .secondary),
                .field(label: ":images", value: "Image catalog", style: .secondary),
                .field(label: ":flavors", value: "Flavor specifications", style: .secondary),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Action Commands
        sections.append(DetailSection(
            title: "Action Commands",
            items: [
                .field(label: ":create", value: "Create resource (context-aware)", style: .secondary),
                .field(label: ":delete", value: "Delete selected resource", style: .secondary),
                .field(label: ":start", value: "Start server", style: .secondary),
                .field(label: ":stop", value: "Stop server", style: .secondary),
                .field(label: ":restart", value: "Restart server", style: .secondary),
                .field(label: ":refresh", value: "Refresh current view", style: .secondary),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Utility Commands
        sections.append(DetailSection(
            title: "Utility Commands",
            items: [
                .field(label: ":ctx", value: "List/switch clouds", style: .secondary),
                .field(label: ":help", value: "Show help", style: .secondary),
                .field(label: ":shortcuts", value: "This reference", style: .secondary),
                .field(label: ":tutorial", value: "Interactive tutorial", style: .secondary),
                .field(label: ":quit", value: "Exit application", style: .secondary),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Universal Keys
        sections.append(DetailSection(
            title: "Universal Keys",
            items: [
                .field(label: "UP/DOWN", value: "Navigate items", style: .info),
                .field(label: "SPACE", value: "View details", style: .info),
                .field(label: "ESC", value: "Go back/cancel", style: .info),
                .field(label: "/", value: "Search", style: .info),
                .field(label: "?", value: "Context help", style: .info),
                .field(label: "^C", value: "Quit", style: .info),
                .spacer
            ],
            titleStyle: .accent
        ))

        return sections
    }

    /// Get shortcuts reference (frequently used commands) - Legacy text format
    /// Deprecated: Use getShortcutsSections() for DetailView component
    /// - Returns: Formatted shortcuts text
    @available(*, deprecated, message: "Use getShortcutsSections() instead")
    func getShortcutsReference() -> String {
        return """
        FREQUENTLY USED COMMANDS:

        NAVIGATION:
        :dashboard    - Main dashboard view
        :servers      - Server management
        :networks     - Network management
        :volumes      - Volume management
        :images       - Image catalog
        :flavors      - Flavor specifications

        ACTIONS:
        :create       - Create resource (context-aware)
        :delete       - Delete selected resource
        :start        - Start server
        :stop         - Stop server
        :restart      - Restart server
        :refresh      - Refresh current view

        UTILITIES:
        :ctx          - List/switch clouds
        :help         - Show help
        :shortcuts    - This reference
        :tutorial     - Interactive tutorial
        :quit         - Exit application

        UNIVERSAL KEYS:
        UP/DOWN       - Navigate items
        SPACE         - View details
        ESC           - Go back/cancel
        /             - Search
        ?             - Context help
        ^C            - Quit
        """
    }

    /// Get command workflow examples as DetailView sections
    /// - Returns: Array of DetailSection for command examples
    func getExamplesSections() -> [DetailSection] {
        var sections: [DetailSection] = []

        // Example 1: Create a Server
        sections.append(DetailSection(
            title: "Example 1: Create a New Server",
            items: [
                .field(label: "Step 1", value: "Type :servers (navigate to servers view)", style: .info),
                .field(label: "Step 2", value: "Type :create (open server creation form)", style: .info),
                .field(label: "Step 3", value: "Use Tab to navigate fields", style: .info),
                .field(label: "Step 4", value: "Press Enter to create", style: .info),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Example 2: Restart a Server
        sections.append(DetailSection(
            title: "Example 2: Restart a Server",
            items: [
                .field(label: "Step 1", value: "Type :servers", style: .info),
                .field(label: "Step 2", value: "Use UP/DOWN to select a server", style: .info),
                .field(label: "Step 3", value: "Type :restart", style: .info),
                .field(label: "Step 4", value: "Confirm the action", style: .info),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Example 3: Attach a Volume
        sections.append(DetailSection(
            title: "Example 3: Attach a Volume",
            items: [
                .field(label: "Step 1", value: "Type :volumes", style: .info),
                .field(label: "Step 2", value: "Select a volume with UP/DOWN", style: .info),
                .field(label: "Step 3", value: "Type :manage", style: .info),
                .field(label: "Step 4", value: "Choose attach option", style: .info),
                .field(label: "Step 5", value: "Select target server", style: .info),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Example 4: Search for a Network
        sections.append(DetailSection(
            title: "Example 4: Search for a Network",
            items: [
                .field(label: "Step 1", value: "Type :networks", style: .info),
                .field(label: "Step 2", value: "Press / (slash)", style: .info),
                .field(label: "Step 3", value: "Type search term", style: .info),
                .field(label: "Step 4", value: "Use UP/DOWN to navigate results", style: .info),
                .field(label: "Step 5", value: "Press ESC to clear search", style: .info),
                .spacer
            ],
            titleStyle: .accent
        ))

        // Example 5: Switch Cloud Context
        sections.append(DetailSection(
            title: "Example 5: Switch Cloud Context",
            items: [
                .field(label: "Step 1", value: "Type :ctx (list clouds)", style: .info),
                .field(label: "Step 2", value: "Note the cloud name", style: .info),
                .field(label: "Step 3", value: "Type :ctx <cloud-name>", style: .info),
                .field(label: "Step 4", value: "Wait for context switch", style: .info),
                .spacer,
                .spacer,
                .customComponent(Text("For more examples, type :help").accent())
            ],
            titleStyle: .accent
        ))

        return sections
    }
}

