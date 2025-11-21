import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

/// Service layer for shared UI helper operations
///
/// This service encapsulates shared UI-related operations including:
/// - Dialog displays (console output, private key)
/// - Batch operation result handling
/// - Text utilities
///
/// Module-specific operations have been moved to their respective modules:
/// - ServersModule: Server dialogs and selection
/// - VolumesModule: Volume management operations
/// - NetworksModule: Network management operations
/// - SecurityGroupsModule: Security group management operations
/// - FloatingIPsModule: Floating IP management operations
/// - SubnetsModule: Subnet-router management operations
@MainActor
final class UIHelpers {
    private let tui: TUI

    init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Convenience Accessors

    private var dataManager: DataManager { tui.dataManager }
    private var statusMessage: String? {
        get { tui.statusMessage }
        set { tui.statusMessage = newValue }
    }
    private var screenRows: Int32 { tui.screenRows }
    private var screenCols: Int32 { tui.screenCols }

    // MARK: - Console Output Dialog

    /// Display console output in a full-screen scrollable dialog
    ///
    /// Shows console output with vertical and horizontal scrolling support.
    /// Used for displaying server console logs and other text output.
    ///
    /// - Parameters:
    ///   - serverName: Name of the server for the title
    ///   - output: The console output text to display
    ///   - screen: The ncurses screen pointer
    internal func showConsoleOutputDialog(serverName: String, output: String, screen: OpaquePointer?) async {
        // Disable nodelay for dialog interaction
        let _ = SwiftNCurses.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftNCurses.setNodelay(WindowHandle(screen), true)
        }

        var verticalScrollOffset = 0
        var horizontalScrollOffset = 0
        let lines = output.components(separatedBy: .newlines)
        let totalLines = lines.count

        // Calculate maximum line width for horizontal scrolling
        let maxLineWidth = lines.map { $0.count }.max() ?? 0

        while true {
            // Fill background with consistent secondary styling to match other views
            let surface = SwiftNCurses.surface(from: screen)
            let fullScreenBounds = Rect(x: 0, y: 0, width: screenCols, height: screenRows)
            await surface.fill(rect: fullScreenBounds, character: " ", style: .secondary)

            // Full screen dialog dimensions
            let dialogWidth = screenCols
            let dialogHeight = screenRows

            // Title bar using SwiftNCurses
            let titleBounds = Rect(x: 0, y: 0, width: screenCols, height: 1)
            let titleComponent = Text("Console Output: \(serverName)").accent().bold()
            await SwiftNCurses.render(titleComponent, on: surface, in: titleBounds)

            // Help bar at bottom using SwiftNCurses
            let helpBounds = Rect(x: 0, y: screenRows - 1, width: screenCols, height: 1)
            let helpComponent = Text("UP/DOWN,j/k:scroll vertical  LEFT/RIGHT,h/l:scroll horizontal  PgUp/PgDn,Home/End  ESC:close").info()
            await SwiftNCurses.render(helpComponent, on: surface, in: helpBounds)

            // Console output content area
            let contentHeight = Int(dialogHeight - 2) // Leave space for title and help bars
            let contentWidth = Int(dialogWidth)

            // Create console content components
            var contentComponents: [any Component] = []

            for i in 0..<contentHeight {
                let lineIndex = verticalScrollOffset + i
                if lineIndex < totalLines {
                    let fullLine = lines[lineIndex]
                    // Apply horizontal scrolling
                    let startPos = horizontalScrollOffset
                    let endPos = min(startPos + contentWidth, fullLine.count)

                    let visibleLine: String
                    if startPos < fullLine.count {
                        let startIndex = fullLine.index(fullLine.startIndex, offsetBy: startPos)
                        let endIndex = fullLine.index(fullLine.startIndex, offsetBy: endPos)
                        visibleLine = String(fullLine[startIndex..<endIndex])
                    } else {
                        visibleLine = ""
                    }

                    contentComponents.append(Text(visibleLine).info())
                } else {
                    contentComponents.append(Text("").info())
                }
            }

            // Render console content
            let contentBounds = Rect(x: 0, y: 1, width: screenCols, height: Int32(contentHeight))
            let contentView = VStack(spacing: 0, children: contentComponents)
            await SwiftNCurses.render(contentView, on: surface, in: contentBounds)

            // Scroll indicators using SwiftNCurses
            if totalLines > contentHeight {
                let scrollInfo = "Line \(verticalScrollOffset + 1)/\(totalLines)"
                let scrollBounds = Rect(x: screenCols - 20, y: screenRows - 2, width: 20, height: 1)
                await SwiftNCurses.render(Text(scrollInfo).accent(), on: surface, in: scrollBounds)
            }

            if maxLineWidth > contentWidth {
                let maxHorizontalScroll = maxLineWidth - contentWidth
                if maxHorizontalScroll > 0 {
                    let scrollInfo = "Col \(horizontalScrollOffset + 1)/\(maxLineWidth)"
                    let scrollBounds = Rect(x: 2, y: screenRows - 2, width: 20, height: 1)
                    await SwiftNCurses.render(Text(scrollInfo).accent(), on: surface, in: scrollBounds)
                }
            }

            SwiftNCurses.batchedRefresh(WindowHandle(screen))

            let ch = SwiftNCurses.getInput(WindowHandle(screen))

            switch ch {
            case Int32(27): // ESC - Close dialog
                // Clear screen before returning to prevent artifacts
                SwiftNCurses.clear(WindowHandle(screen))
                tui.forceRedraw()
                return
            case Int32(259), Int32(258): // UP/DOWN - Scroll vertical
                if ch == Int32(259) {
                    verticalScrollOffset = max(0, verticalScrollOffset - 1)
                } else {
                    verticalScrollOffset = min(max(0, totalLines - contentHeight), verticalScrollOffset + 1)
                }
            case Int32(260), Int32(261): // LEFT/RIGHT - Scroll horizontal
                if ch == Int32(260) {
                    horizontalScrollOffset = max(0, horizontalScrollOffset - 5)
                } else {
                    let maxHorizontalScroll = max(0, maxLineWidth - contentWidth)
                    horizontalScrollOffset = min(maxHorizontalScroll, horizontalScrollOffset + 5)
                }
            case Int32(338), Int32(339): // PAGE_DOWN/PAGE_UP
                if ch == Int32(338) {
                    verticalScrollOffset = min(max(0, totalLines - contentHeight), verticalScrollOffset + contentHeight)
                } else {
                    verticalScrollOffset = max(0, verticalScrollOffset - contentHeight)
                }
            case Int32(262), Int32(360): // HOME/END
                if ch == Int32(262) {
                    verticalScrollOffset = 0
                    horizontalScrollOffset = 0
                } else {
                    verticalScrollOffset = max(0, totalLines - contentHeight)
                    let maxHorizontalScroll = max(0, maxLineWidth - contentWidth)
                    horizontalScrollOffset = maxHorizontalScroll
                }
            default:
                break
            }
        }
    }
}
