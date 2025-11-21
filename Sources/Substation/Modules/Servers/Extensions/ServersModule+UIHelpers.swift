// Sources/Substation/Modules/Servers/Extensions/ServersModule+UIHelpers.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Server UI Helper Functions

extension ServersModule {
    /// Select a server from a dialog
    ///
    /// Displays a modal dialog allowing the user to select a server from the cached servers list.
    /// The dialog supports keyboard navigation with UP/DOWN arrows, ENTER to select, and ESC to cancel.
    ///
    /// - Parameters:
    ///   - screen: The ncurses screen pointer for rendering
    ///   - title: The title to display at the top of the selection dialog
    /// - Returns: The ID of the selected server, or nil if cancelled
    internal func selectServer(screen: OpaquePointer?, title: String) async -> String? {
        guard let tui = tui else { return nil }

        let cachedServers = tui.cacheManager.cachedServers
        guard !cachedServers.isEmpty else {
            return nil
        }

        // Create a simple selection dialog
        var serverSelectedIndex = 0

        while true {
            // Use SwiftNCurses to render the server selection dialog
            let surface = SwiftNCurses.surface(from: screen)
            let startRow = 5
            let dialogHeight = min(cachedServers.count + 4, Int(tui.screenRows) - 10)
            let dialogWidth = tui.screenCols - 4

            // Clear dialog area
            let dialogBounds = Rect(x: 2, y: Int32(startRow), width: dialogWidth, height: Int32(dialogHeight))
            surface.clear(rect: dialogBounds)

            // Create bordered container with title and server list
            var serverComponents: [any Component] = []

            let maxServersToShow = dialogHeight - 5
            let startIndex = max(0, serverSelectedIndex - maxServersToShow/2)
            let endIndex = min(cachedServers.count, startIndex + maxServersToShow)

            for serverIndex in startIndex..<endIndex {
                let server = cachedServers[serverIndex]
                let isSelected = serverIndex == serverSelectedIndex
                let serverName = server.name ?? "Unnamed Server"
                let truncatedName = String(serverName.prefix(Int(tui.screenCols) - 10))

                let serverText = Text(truncatedName).styled(isSelected ? .primary.reverse() : .secondary)
                serverComponents.append(serverText)
            }

            // Add instructions
            serverComponents.append(Text("Press ENTER to select, ESC to cancel, UP/DOWN to navigate").info())

            let dialogContent = VStack(spacing: 0, children: serverComponents)
                .padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))

            let borderedDialog = BorderedContainer(title: title, content: {
                // Empty content closure since we render manually
            })

            await SwiftNCurses.render(borderedDialog, on: surface, in: dialogBounds)
            await SwiftNCurses.render(dialogContent, on: surface, in: dialogBounds)

            SwiftNCurses.batchedRefresh(WindowHandle(screen))

            let ch = SwiftNCurses.getInput(WindowHandle(screen))

            switch ch {
            case Int32(259), Int32(258): // UP/DOWN - Navigate server list
                if ch == Int32(259) {
                    if serverSelectedIndex > 0 {
                        serverSelectedIndex -= 1
                    }
                } else {
                    if serverSelectedIndex < cachedServers.count - 1 {
                        serverSelectedIndex += 1
                    }
                }
            case 10, 13: // Enter key
                await tui.draw(screen: screen) // Redraw main interface
                return cachedServers[serverSelectedIndex].id
            case 27: // ESC key
                await tui.draw(screen: screen) // Redraw main interface
                return nil
            default:
                break
            }
        }
    }

    /// Show a dialog for entering a snapshot name
    ///
    /// Displays a modal dialog for the user to enter a name for a server snapshot.
    /// The dialog pre-populates a default name based on the server name and timestamp.
    /// Supports text editing with backspace, cursor movement with LEFT/RIGHT arrows,
    /// ENTER to confirm, and ESC to cancel.
    ///
    /// - Parameters:
    ///   - serverName: The name of the server being snapshotted (used for default name)
    ///   - screen: The ncurses screen pointer for rendering
    /// - Returns: The entered snapshot name, or nil if cancelled
    internal func showSnapshotNameDialog(serverName: String, screen: OpaquePointer?) async -> String? {
        guard let tui = tui else { return nil }

        var snapshotName = "\(serverName)-snapshot-\(Int(Date().timeIntervalSince1970))"
        var cursorPosition = snapshotName.count

        // Disable nodelay for dialog interaction
        let _ = SwiftNCurses.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftNCurses.setNodelay(WindowHandle(screen), true)
        }

        while true {
            // Clear screen
            SwiftNCurses.clear(WindowHandle(screen))

            // Draw the snapshot dialog
            let dialogWidth: Int32 = 60
            let dialogHeight: Int32 = 10
            let dialogStartRow = (tui.screenRows - dialogHeight) / 2
            let dialogStartCol = (tui.screenCols - dialogWidth) / 2

            // Draw dialog box using SwiftNCurses
            let surface = SwiftNCurses.surface(from: screen)
            let dialogBounds = Rect(x: dialogStartCol, y: dialogStartRow, width: dialogWidth, height: dialogHeight)
            await surface.fill(rect: dialogBounds, character: " ", style: .accent)

            // Draw border using SwiftNCurses
            let topBorderBounds = Rect(x: dialogStartCol, y: dialogStartRow, width: dialogWidth, height: 1)
            let bottomBorderBounds = Rect(x: dialogStartCol, y: dialogStartRow + dialogHeight - 1, width: dialogWidth, height: 1)
            await SwiftNCurses.render(Text(String(repeating: "-", count: Int(dialogWidth))).muted(), on: surface, in: topBorderBounds)
            await SwiftNCurses.render(Text(String(repeating: "-", count: Int(dialogWidth))).muted(), on: surface, in: bottomBorderBounds)

            // Create dialog content using SwiftNCurses
            let dialogComponents: [any Component] = [
                Text(""),  // Spacer for top border
                Text("  Create Server Snapshot").accent().bold(),
                Text(""),  // Spacer
                Text("  Server: \(serverName)").secondary(),
                Text(""),  // Spacer
                Text("  Snapshot Name:").secondary(),
                Text("  \(String(snapshotName.prefix(Int(dialogWidth) - 6)))").primary(),
                Text(""),  // Spacer
                Text("  ENTER: Create snapshot  ESC: Cancel").info()
            ]

            let dialogContent = VStack(spacing: 0, children: dialogComponents)
            let contentBounds = Rect(x: dialogStartCol, y: dialogStartRow, width: dialogWidth, height: dialogHeight)
            await SwiftNCurses.render(dialogContent, on: surface, in: contentBounds)

            // Position cursor manually for input field
            let displayName = String(snapshotName.prefix(Int(dialogWidth) - 6))
            let cursorCol = dialogStartCol + 2 + Int32(min(cursorPosition, displayName.count))
            SwiftNCurses.moveCursor(WindowHandle(screen), to: Point(x: cursorCol, y: dialogStartRow + 6))

            SwiftNCurses.batchedRefresh(WindowHandle(screen))

            let ch = SwiftNCurses.getInput(WindowHandle(screen))

            switch ch {
            case Int32(27): // ESC - Cancel
                return nil
            case Int32(10), Int32(13): // ENTER - Confirm
                tui.renderCoordinator.needsRedraw = true
                if !snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return snapshotName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case Int32(127), Int32(8): // Backspace
                if cursorPosition > 0 {
                    snapshotName.remove(at: snapshotName.index(snapshotName.startIndex, offsetBy: cursorPosition - 1))
                    cursorPosition -= 1
                }
            case Int32(260): // KEY_LEFT
                cursorPosition = max(0, cursorPosition - 1)
            case Int32(261): // KEY_RIGHT
                cursorPosition = min(snapshotName.count, cursorPosition + 1)
            default:
                // Handle printable characters
                if ch >= 32 && ch <= 126 {
                    let character = Character(UnicodeScalar(Int(ch))!)
                    snapshotName.insert(character, at: snapshotName.index(snapshotName.startIndex, offsetBy: cursorPosition))
                    cursorPosition += 1
                }
            }
        }
    }

    /// Show a dialog displaying remote console information
    ///
    /// Displays console connection information for a server including the console URL,
    /// protocol type, and console type. For noVNC consoles, provides an option to open
    /// the console in a web browser.
    ///
    /// The dialog supports:
    /// - ESC to close
    /// - O to open noVNC console in default browser
    ///
    /// - Parameters:
    ///   - console: The RemoteConsole object containing connection details
    ///   - serverName: The name of the server for display purposes
    ///   - screen: The ncurses screen pointer for rendering
    internal func showConsoleDialog(console: RemoteConsole, serverName: String, screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Disable nodelay for dialog interaction
        let _ = SwiftNCurses.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftNCurses.setNodelay(WindowHandle(screen), true)
        }

        // Calculate main panel dimensions (matching MainPanelView layout)
        let sidebarWidth: Int32 = 20
        let mainStartCol: Int32 = sidebarWidth > 0 ? sidebarWidth + 1 : 0
        let mainWidth = max(10, tui.screenCols - mainStartCol - 1)
        let mainStartRow: Int32 = 2
        let bottomReserved: Int32 = 3
        let mainHeight = max(5, tui.screenRows - mainStartRow - bottomReserved)

        while true {
            // Draw the full UI to maintain context
            await tui.draw(screen: screen)

            // Draw console information in main panel area
            var row: Int32 = mainStartRow

            let title = "Server Console: \(serverName)"
            SwiftNCurses.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: title, color: .accent)
            row += 2

            SwiftNCurses.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: "Protocol: \(console.protocol)", color: .info)
            row += 1

            SwiftNCurses.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: "Type: \(console.type)", color: .info)
            row += 2

            SwiftNCurses.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: "Console URL:", color: .accent)
            row += 1

            // Word wrap the URL to fit in main panel
            let url = console.url
            let contentWidth = Int(mainWidth - 2)
            let urlLines = wrapText(url, maxWidth: contentWidth)
            for line in urlLines {
                if row < mainStartRow + mainHeight - 3 {
                    SwiftNCurses.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: line, color: .success)
                    row += 1
                }
            }

            // Draw help text at bottom of main panel
            row = mainStartRow + mainHeight - 2
            let helpText: String
            if console.type.lowercased() == "novnc" {
                helpText = "Press O to open in browser, ESC to close"
            } else {
                helpText = "Press ESC to close"
            }
            SwiftNCurses.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: helpText, color: .warning)

            SwiftNCurses.batchedRefresh(WindowHandle(screen))

            let ch = SwiftNCurses.getInput(WindowHandle(screen))

            switch ch {
            case Int32(27): // ESC - Close dialog
                return
            case Int32(79), Int32(111): // 'O' or 'o' - Open in browser
                if console.type.lowercased() == "novnc" {
                    await openURLInBrowser(console.url)
                    tui.statusMessage = "Opening console in default browser..."
                }
            default:
                break
            }
        }
    }

    /// Wrap text to fit within a maximum width
    ///
    /// Breaks long text into multiple lines, each no longer than the specified width.
    /// This is a character-based wrap without word boundary consideration.
    ///
    /// - Parameters:
    ///   - text: The text to wrap
    ///   - maxWidth: The maximum width per line
    /// - Returns: Array of text lines
    private func wrapText(_ text: String, maxWidth: Int) -> [String] {
        var lines: [String] = []
        var currentLine = ""

        for char in text {
            if currentLine.count >= maxWidth {
                lines.append(currentLine)
                currentLine = String(char)
            } else {
                currentLine.append(char)
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }

    /// Open a URL in the default system browser
    ///
    /// Uses the appropriate system command to open URLs:
    /// - macOS: Uses /usr/bin/open
    /// - Linux: Uses /usr/bin/xdg-open
    ///
    /// - Parameter url: The URL string to open
    private func openURLInBrowser(_ url: String) async {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
        #elseif os(Linux)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        process.arguments = [url]
        try? process.run()
        #endif
    }
}
